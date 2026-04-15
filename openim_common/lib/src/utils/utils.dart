import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:azlistview/azlistview.dart';
import 'package:collection/collection.dart';
import 'package:common_utils/common_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_date/dart_date.dart';
import 'package:extended_image/extended_image.dart';
// ffmpeg_kit_flutter 暂移：v1 embedding 与 Flutter 3.38 不兼容，以下两处用占位实现
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:mime/mime.dart';
import 'package:mobile_device_identifier/mobile_device_identifier.dart';
import 'package:open_filex/open_filex.dart';
import 'package:openim_common/openim_common.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sprintf/sprintf.dart';
import 'package:uri_to_file/uri_to_file.dart';

class IntervalDo {
  DateTime? last;
  Timer? lastTimer;

  void run({required Function() fuc, int milliseconds = 0}) {
    DateTime now = DateTime.now();
    if (null == last ||
        now.difference(last ?? now).inMilliseconds > milliseconds) {
      last = now;
      fuc();
    }
  }

  void drop({required Function() fun, int milliseconds = 0}) {
    lastTimer?.cancel();
    lastTimer = null;
    lastTimer = Timer(Duration(milliseconds: milliseconds), () {
      lastTimer!.cancel();
      lastTimer = null;
      fun.call();
    });
  }
}

class IMUtils {
  IMUtils._();

  static Future<CroppedFile?> uCrop(String path) {
    return ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: Styles.c_0089FF,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(
          title: '',
        ),
      ],
    );
  }

  static String getSuffix(String url) {
    if (!url.contains(".")) return "";
    return url.substring(url.lastIndexOf('.'), url.length);
  }

  static bool isGif(String url) {
    return IMUtils.getSuffix(url).contains("gif");
  }

  static void copy({required String text}) {
    Clipboard.setData(ClipboardData(text: text));
    IMViews.showToast(StrRes.copySuccessfully);
  }

  static List<ISuspensionBean> convertToAZList(List<ISuspensionBean> list) {
    for (int i = 0, length = list.length; i < length; i++) {
      setAzPinyinAndTag(list[i]);
    }

    SuspensionUtil.sortListBySuspensionTag(list);

    SuspensionUtil.setShowSuspensionStatus(list);

    return list;
  }

  static ISuspensionBean setAzPinyinAndTag(ISuspensionBean info) {
    if (info is ISUserInfo) {
      String pinyin = PinyinHelper.getPinyinE(info.showName);
      if (pinyin.trim().isEmpty) {
        info.tagIndex = "#";
      } else {
        String tag = pinyin.substring(0, 1).toUpperCase();
        info.namePinyin = pinyin.toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          info.tagIndex = tag;
        } else {
          info.tagIndex = "#";
        }
      }
    } else if (info is ISGroupMembersInfo) {
      String pinyin = PinyinHelper.getPinyinE(info.nickname!);
      if (pinyin.trim().isEmpty) {
        info.tagIndex = "#";
      } else {
        String tag = pinyin.substring(0, 1).toUpperCase();
        info.namePinyin = pinyin.toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          info.tagIndex = tag;
        } else {
          info.tagIndex = "#";
        }
      }
    }
    return info;
  }

  static saveMediaToGallery(String mimeType, String cachePath) async {
    if (mimeType.contains('video') || mimeType.contains('image')) {
      await ImageGallerySaverPlus.saveFile(cachePath);
    }
  }

  static String? emptyStrToNull(String? str) =>
      (null != str && str.trim().isEmpty) ? null : str;

  static bool isNotNullEmptyStr(String? str) => null != str && "" != str.trim();

  static bool isChinaMobile(String mobile) {
    RegExp exp = RegExp(
        r'^((13[0-9])|(14[0-9])|(15[0-9])|(16[0-9])|(17[0-9])|(18[0-9])|(19[0-9]))\d{8}$');
    return exp.hasMatch(mobile);
  }

  static bool isMobile(String areaCode, String mobile) =>
      (areaCode == '+86' || areaCode == '86') ? isChinaMobile(mobile) : true;

  static Future<File> getVideoThumbnail(File file) async {
    final path = file.path;
    final names = path.substring(path.lastIndexOf("/") + 1).split('.');
    final name = '${names.first}.png';
    final directory = await createTempDir(dir: 'video');
    final targetPath = '$directory/$name';
    // 占位：ffmpeg_kit_flutter 已移除以兼容 Flutter 3.38，生成 1x1 占位图避免 UI 报错
    final minimalPng = Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
      0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
    ]);
    await File(targetPath).writeAsBytes(minimalPng);
    return File(targetPath);
  }

  static Future<File> saveThumbToFile(Uint8List thumb, String assetId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${assetId}_thumb.jpg');
    await file.writeAsBytes(thumb);
    return file;
  }

  static Future<File?> compressVideoAndGetFile(File file) async {
    final path = file.path;
    final name = path.substring(path.lastIndexOf("/") + 1);
    final directory = await createTempDir(dir: 'video');
    final targetPath = '$directory/$name';
    // 占位：ffmpeg 已移除，直接复制原文件返回
    file.copySync(targetPath);
    return File(targetPath);
  }

  static Future<File?> compressImageAndGetFile(File file,
      {int quality = 80}) async {
    var path = file.path;
    var name = path.substring(path.lastIndexOf("/") + 1).toLowerCase();

    if (name.endsWith('.gif')) {
      return file;
    }

    CompressFormat format = CompressFormat.jpeg;
    if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
      format = CompressFormat.jpeg;
    } else if (name.endsWith(".png")) {
      format = CompressFormat.png;
    } else if (name.endsWith(".heic")) {
      format = CompressFormat.heic;
    } else if (name.endsWith(".webp")) {
      format = CompressFormat.webp;
    }

    var targetDirectory = await getTempDirectory(name);

    if (file.path == targetDirectory.path) {
      targetDirectory = await getTempDirectory('compressed-$name');
    }

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetDirectory.path,
      quality: quality,
      minWidth: 1280,
      minHeight: 720,
      format: format,
    );

    return result != null ? File(result.path) : file;
  }

  static Future<String> createTempFile({
    required String dir,
    required String name,
  }) async {
    final storage = await createTempDir(dir: dir);
    File file = File('$storage/$name');
    if (!(await file.exists())) {
      file.create();
    }
    return file.path;
  }

  static Future<String> createTempDir({
    required String dir,
  }) async {
    Directory directory = await getTempDirectory(dir);

    if (!(await directory.exists())) {
      directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<Directory> getTempDirectory(String dir) async {
    final storage = await getApplicationCacheDirectory();
    Directory directory = Directory('${storage.path}/$dir');

    return directory;
  }

  static int compareVersion(String val1, String val2) {
    var arr1 = val1.split(".");
    var arr2 = val2.split(".");
    int length = arr1.length >= arr2.length ? arr1.length : arr2.length;
    int diff = 0;
    int v1;
    int v2;
    for (int i = 0; i < length; i++) {
      v1 = i < arr1.length ? int.parse(arr1[i]) : 0;
      v2 = i < arr2.length ? int.parse(arr2[i]) : 0;
      diff = v1 - v2;
      if (diff == 0) {
        continue;
      } else {
        return diff > 0 ? 1 : -1;
      }
    }
    return diff;
  }

  static int getPlatform() {
    final context = Get.context!;
    if (Platform.isAndroid) {
      return context.isTablet ? 8 : 2;
    } else {
      return context.isTablet ? 9 : 1;
    }
  }

  static String? generateMD5(String? data) {
    if (null == data) return null;
    var content = const Utf8Encoder().convert(data);
    var digest = md5.convert(content);
    return digest.toString();
  }

  static String buildGroupApplicationID(GroupApplicationInfo info) {
    return '${info.groupID}-${info.creatorUserID}-${info.reqTime}-${info.userID}--${info.inviterUserID}';
  }

  static String buildFriendApplicationID(FriendApplicationInfo info) {
    return '${info.fromUserID}-${info.toUserID}-${info.createTime}';
  }

  static Future<String> getCacheFileDir() async {
    return (await getTemporaryDirectory()).absolute.path;
  }

  static Future<String> getDownloadFileDir() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath =
            await PathProviderPlatform.instance.getDownloadsPath();
      } catch (err, st) {
        Logger.print('failed to get downloads path: $err, $st');
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath!;
  }

  static Future<String> toFilePath(String path) async {
    var filePrefix = 'file://';
    var uriPrefix = 'content://';
    if (path.contains(filePrefix)) {
      path = path.substring(filePrefix.length);
    } else if (path.contains(uriPrefix)) {
      File file = await toFile(path);
      path = file.path;
    }
    return path;
  }

  static List<Message> calChatTimeInterval(List<Message> list,
      {bool calculate = true}) {
    if (!calculate) return list;
    var milliseconds = list.firstOrNull?.sendTime;
    if (null == milliseconds) return list;
    list.first.exMap['showTime'] = true;
    var lastShowTimeStamp = milliseconds;
    for (var i = 0; i < list.length; i++) {
      var index = i + 1;
      if (index <= list.length - 1) {
        var cur = getDateTimeByMs(lastShowTimeStamp);
        var milliseconds = list.elementAt(index).sendTime!;
        var next = getDateTimeByMs(milliseconds);
        if (next.difference(cur).inMinutes > 5) {
          lastShowTimeStamp = milliseconds;
          list.elementAt(index).exMap['showTime'] = true;
        }
      }
    }
    return list;
  }

  static String getChatTimeline(int ms, [String formatToday = 'HH:mm']) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(ms);
    final languageCode = Get.locale?.languageCode ?? 'zh';
    final isChinese = languageCode == 'zh';
    final now = DateTime.now();
    final formatter = DateFormat(formatToday);

    if (isSameDay(dateTime, now)) {
      return formatter.format(
        dateTime,
      );
    }

    final yesterday = now.subtract(Duration(days: 1));

    if (isSameDay(dateTime, yesterday)) {
      return isChinese
          ? '昨天 ${formatter.format(dateTime)}'
          : 'Yesterday ${formatter.format(dateTime)}';
    }

    if (isSameWeek(dateTime, now)) {
      final weekDay = DateFormat('EEEE').format(dateTime);
      final weekDayChinese = {
        'Monday': StrRes.monday,
        'Tuesday': StrRes.tuesday,
        'Wednesday': StrRes.wednesday,
        'Thursday': StrRes.thursday,
        'Friday': StrRes.friday,
        'Saturday': StrRes.saturday,
        'Sunday': StrRes.sunday,
      };
      return '${isChinese ? weekDayChinese[weekDay]! : weekDay} ${formatter.format(dateTime)}';
    }

    if (dateTime.year == now.year) {
      final dateFormat = isChinese ? 'MM月dd HH:mm' : 'MM/dd HH:mm';
      return DateFormat(dateFormat).format(dateTime);
    }

    final dateFormat = isChinese ? 'yyyy年MM月dd HH:mm' : 'yyyy/MM/dd HH:mm';
    return DateFormat(dateFormat).format(dateTime);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isSameWeek(DateTime date1, DateTime date2) {
    final weekStart = date2.subtract(Duration(days: date2.weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));
    return date1.isAfter(weekStart.subtract(Duration(days: 1))) &&
        date1.isBefore(weekEnd.add(Duration(days: 1)));
  }

  static String getCallTimeline(int milliseconds) {
    if (DateUtil.yearIsEqualByMs(milliseconds, DateUtil.getNowDateMs())) {
      return formatDateMs(milliseconds, format: 'MM/dd');
    } else {
      return formatDateMs(milliseconds, format: 'yyyy/MM/dd');
    }
  }

  static DateTime getDateTimeByMs(int ms, {bool isUtc = false}) {
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: isUtc);
  }

  static String formatDateMs(int ms, {bool isUtc = false, String? format}) {
    return DateUtil.formatDateMs(ms, format: format, isUtc: isUtc);
  }

  static String seconds2HMS(int seconds) {
    int h = 0;
    int m = 0;
    int s = 0;
    int temp = seconds % 3600;
    if (seconds > 3600) {
      h = seconds ~/ 3600;
      if (temp != 0) {
        if (temp > 60) {
          m = temp ~/ 60;
          if (temp % 60 != 0) {
            s = temp % 60;
          }
        } else {
          s = temp;
        }
      }
    } else {
      m = seconds ~/ 60;
      if (seconds % 60 != 0) {
        s = seconds % 60;
      }
    }
    if (h == 0) {
      return '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';
    }
    return "${h < 10 ? '0$h' : h}:${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}";
  }

  static Map<String, List<Message>> groupingMessage(List<Message> list) {
    var languageCode = Get.locale?.languageCode ?? 'zh';
    var group = <String, List<Message>>{};
    for (var message in list) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(message.sendTime!);
      String dateStr;
      if (DateUtil.isToday(message.sendTime!)) {
        dateStr = languageCode == 'zh' ? '今天' : 'Today';
      } else if (DateUtil.isWeek(message.sendTime!)) {
        dateStr = languageCode == 'zh' ? '本周' : 'This Week';
      } else if (dateTime.isThisMonth) {
        dateStr = languageCode == 'zh' ? '这个月' : 'This Month';
      } else {
        dateStr = DateUtil.formatDate(dateTime, format: 'yyyy/MM');
      }
      group[dateStr] = (group[dateStr] ?? <Message>[])..add(message);
    }
    return group;
  }

  static String mutedTime(int mss) {
    int days = mss ~/ (60 * 60 * 24);
    int hours = (mss % (60 * 60 * 24)) ~/ (60 * 60);
    int minutes = (mss % (60 * 60)) ~/ 60;
    int seconds = mss % 60;
    return "${_combTime(days, StrRes.day)}${_combTime(hours, StrRes.hours)}${_combTime(minutes, StrRes.minute)}${_combTime(seconds, StrRes.seconds)}";
  }

  static String _combTime(int value, String unit) =>
      value > 0 ? '$value$unit' : '';

  static String calContent({
    required String content,
    required String key,
    required TextStyle style,
    required double usedWidth,
  }) {
    var size = calculateTextSize(content, style);
    var lave = 1.sw - usedWidth;
    if (size.width < lave) {
      return content;
    }
    var index = content.indexOf(key);
    if (index == -1 || index > content.length - 1) return content;
    var start = content.substring(0, index);
    var end = content.substring(index);
    var startSize = calculateTextSize(start, style);
    var keySize = calculateTextSize(key, style);
    if (startSize.width + keySize.width > lave) {
      if (index - 4 > 0) {
        return "...${content.substring(index - 4)}";
      } else {
        return "...$end";
      }
    } else {
      return content;
    }
  }

  static Size calculateTextSize(
    String text,
    TextStyle style, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: maxLines,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.size;
  }

  static TextPainter getTextPainter(
    String text,
    TextStyle style, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) =>
      TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr)
        ..layout(minWidth: 0, maxWidth: maxWidth);

  static bool isUrlValid(String? url) {
    if (null == url || url.isEmpty) {
      return false;
    }
    return url.startsWith("http://") || url.startsWith("https://");
  }

  static bool isValidUrl(String? urlString) {
    if (null == urlString || urlString.isEmpty) {
      return false;
    }
    Uri? uri = Uri.tryParse(urlString);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return true;
    }
    return false;
  }

  static String getGroupMemberShowName(GroupMembersInfo membersInfo) {
    return membersInfo.userID == OpenIM.iMManager.userID
        ? StrRes.you
        : membersInfo.nickname!;
  }

  static String getShowName(String? userID, String? nickname) {
    return (userID == OpenIM.iMManager.userID
            ? OpenIM.iMManager.userInfo.nickname
            : nickname) ??
        '';
  }

  static String? parseNtf(
    Message message, {
    bool isConversation = false,
  }) {
    String? text;
    try {
      if (message.contentType! >= 1000) {
        final elem = message.notificationElem!;
        final map = json.decode(elem.detail!);
        switch (message.contentType) {
          case MessageType.groupCreatedNotification:
            {
              final ntf = GroupNotification.fromJson(map);

              final label = StrRes.createGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupInfoSetNotification:
            {
              final ntf = GroupNotification.fromJson(map);
              if (ntf.group?.notification != null &&
                  ntf.group!.notification!.isNotEmpty) {
                return isConversation ? ntf.group!.notification! : null;
              }

              final label = StrRes.editGroupInfoNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.memberQuitNotification:
            {
              final ntf = QuitGroupNotification.fromJson(map);

              final label = StrRes.quitGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.quitUser!)]);
            }
            break;
          case MessageType.memberInvitedNotification:
            {
              final ntf = InvitedJoinGroupNotification.fromJson(map);

              final label = StrRes.invitedJoinGroupNtf;
              final b = ntf.invitedUserList
                  ?.map((e) => getGroupMemberShowName(e))
                  .toList()
                  .join('、');
              text = sprintf(
                  label, [getGroupMemberShowName(ntf.opUser!), b ?? '']);
            }
            break;
          case MessageType.memberKickedNotification:
            {
              final ntf = KickedGroupMemeberNotification.fromJson(map);

              final label = StrRes.kickedGroupNtf;
              final b = ntf.kickedUserList!
                  .map((e) => getGroupMemberShowName(e))
                  .toList()
                  .join('、');
              text = sprintf(label, [b, getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.memberEnterNotification:
            {
              final ntf = EnterGroupNotification.fromJson(map);

              final label = StrRes.joinGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.entrantUser!)]);
            }
            break;
          case MessageType.dismissGroupNotification:
            {
              final ntf = GroupNotification.fromJson(map);

              final label = StrRes.dismissGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupOwnerTransferredNotification:
            {
              final ntf = GroupRightsTransferNoticication.fromJson(map);

              final label = StrRes.transferredGroupNtf;
              text = sprintf(label, [
                getGroupMemberShowName(ntf.opUser!),
                getGroupMemberShowName(ntf.newGroupOwner!)
              ]);
            }
            break;
          case MessageType.groupMemberMutedNotification:
            {
              // final ntf = MuteMemberNotification.fromJson(map);

              // final label = StrRes.muteMemberNtf;
              // final c = ntf.mutedSeconds;
              // text = sprintf(label, [
              //   getGroupMemberShowName(ntf.mutedUser!),
              //   getGroupMemberShowName(ntf.opUser!),
              //   mutedTime(c!)
              // ]);
              text = " ";
            }
            break;
          case MessageType.groupMemberCancelMutedNotification:
            {
              // final ntf = MuteMemberNotification.fromJson(map);

              // final label = StrRes.muteCancelMemberNtf;
              // text = sprintf(label, [
              //   getGroupMemberShowName(ntf.mutedUser!),
              //   getGroupMemberShowName(ntf.opUser!)
              // ]);
              text = " ";
            }
            break;
          case MessageType.groupMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupCancelMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteCancelGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.friendApplicationApprovedNotification:
            {
              text = StrRes.friendAddedNtf;
            }
            break;
          case 1203: // 好友申请通知 - 建立好友关系后的临时显示
            {
              text = '你们已经是好友了,开始聊天吧';
            }
            break;
          case MessageType.burnAfterReadingNotification:
            {
              final ntf = BurnAfterReadingNotification.fromJson(map);
              if (ntf.isPrivate == true) {
                text = StrRes.openPrivateChatNtf;
              } else {
                text = StrRes.closePrivateChatNtf;
              }
            }
            break;
          case MessageType.groupMemberInfoChangedNotification:
            final ntf = GroupMemberInfoChangedNotification.fromJson(map);
            text = sprintf(StrRes.memberInfoChangedNtf,
                [getGroupMemberShowName(ntf.opUser!)]);
            break;
          case MessageType.groupInfoSetAnnouncementNotification:
            if (isConversation) {
              final ntf = GroupNotification.fromJson(map);
              text = ntf.group?.notification ?? '';
            }
            break;
          case MessageType.groupInfoSetNameNotification:
            final ntf = GroupNotification.fromJson(map);
            text = sprintf(StrRes.whoModifyGroupName,
                [getGroupMemberShowName(ntf.opUser!), ntf.group?.groupName]);
            break;
        }
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    return text;
  }

  static String parseMsg(
    Message message, {
    bool isConversation = false,
    bool replaceIdToNickname = false,
  }) {
    String? content;
    try {
      switch (message.contentType) {
        case MessageType.text:
          content = message.textElem!.content!;
          break;
        case MessageType.voice:
          content = '[语音] ${message.soundElem!.duration!}″';
          break;
        case MessageType.video:
          content = "[视频]";
        case MessageType.revokeMessageNotification:
          final map = json.decode(message.notificationElem!.detail!);
          final revokedInfo = RevokedInfo.fromJson(map);
          bool isIrevoked =
              revokedInfo.revokerID == revokedInfo.sourceMessageSendID;
          String a = revokedInfo.revokerID == OpenIM.iMManager.userID
              ? StrRes.you
              : revokedInfo.revokerNickname ?? '';
          String b = revokedInfo.sourceMessageSendID == OpenIM.iMManager.userID
              ? StrRes.you
              : revokedInfo.sourceMessageSenderNickname ?? '';
          if (isIrevoked) {
            content = sprintf(StrRes.revokeMsg, [a]);
          } else {
            content = sprintf(StrRes.aRevokeBMsg, [a, b]);
          }
          break;
        case MessageType.atText:
          content = message.atTextElem!.text;

          if (content != null) content = '$content ';
          content = content?.replaceAllMapped(RegExp(r'@(\w+?)\s'), (match) {
            if (match.group(1) == 'AtAllTag') {
              return "@${StrRes.everyone} ";
            }
            var info = message.atTextElem?.atUsersInfo
                ?.where((item) => item.atUserID == match.group(1));
            if (info != null && info.isNotEmpty) {
              return "@${info.first.groupNickname} ";
            }
            return match.group(0) ?? '';
          });
          break;
        case MessageType.merger:
          content = '[${StrRes.chatRecord}]';
          break;
        case MessageType.quote:
          content = '${message.quoteElem?.text}';
          break;
        case MessageType.file:
          content = '[${StrRes.file}]';
          break;
        case MessageType.picture:
          content = '[${StrRes.picture}]';
          break;
        case MessageType.custom:
          final map = _unwrapCustomData(message.customElem?.data);
          final customType = map?['customType'];

          switch (customType) {
            case CustomMessageType.blockedByFriend:
              content = StrRes.blockedByFriendHint;
              break;
            case CustomMessageType.deletedByFriend:
              content = sprintf(
                StrRes.deletedByFriendHint,
                [''],
              );
              break;
            case CustomMessageType.removedFromGroup:
              content = StrRes.removedFromGroupHint;
              break;
            case CustomMessageType.groupDisbanded:
              content = StrRes.groupDisbanded;
              break;
            case CustomMessageType.groupCard:
              content = "[${StrRes.groupCard}]";
              break;
            case CustomMessageType.refundNotification:
              content = "[${StrRes.refundNotification}]";
              break;
            case CustomMessageType.luckMoney:
              content = '[${StrRes.redPacket}]';
              break;
            case CustomMessageType.infoChange:
              // 组织/权限/CanSendFreeMsg 变更通知（Free-IM-Chat organization 模块 customType 10011）
              final dataContent = map?['content']?.toString();
              content = (dataContent != null && dataContent.isNotEmpty)
                  ? dataContent
                  : '[组织/权限通知]';
              break;
            default:
              // 未知 customType：优先从 data.content/text/remark 等提取可读文案，减少「暂不支持的消息类型」展示
              content = _buildPreviewFromUnknown(message) ?? '[${StrRes.unsupportedMessage}]';
              break;
          }
          break;
        case MessageType.oaNotification:
          var detail = NotifyContent.fromJson(
              jsonDecode(message.notificationElem?.detail ?? ''));
          content = detail.text;
          break;
        case 1201: // FriendApplicationApprovedNotification - 好友申请通过
          content = '[好友申请已通过]';
          break;
        case 1204: // FriendAddedNotification - 好友添加成功
          content = '[成为好友]';
          break;
        default:
          // 未显式支持的消息类型：尝试从自定义数据或文本中提取可读内容，
          // 例如 data.content / data.text / data.remark 等，保证会话列表尽量能预览实际内容
          content = _buildPreviewFromUnknown(message) ?? '[${StrRes.otherMessage}]';
          break;
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    content = content?.replaceAll("\n", " ");
    // 最终兜底：统一用“新消息”占位，保证会话列表始终可预览
    return content ?? '[${StrRes.otherMessage}]';
  }

  /// 解析 customElem.data，兼容服务端双层 JSON（data 为字符串）格式，返回统一后的 Map。
  /// 例如服务端下发 {"data":"{\"customType\":1001,\"data\":{...}}"} 时，会解析内层并返回 { customType: 1001, data: {...} }。
  static Map<String, dynamic>? _unwrapCustomData(String? rawData) {
    if (rawData == null || rawData.isEmpty) return null;
    try {
      final map = jsonDecode(rawData) as Map<String, dynamic>?;
      if (map == null) return null;
      final customType = map['customType'];
      final dataValue = map['data'];
      if (customType != null) return map;
      if (dataValue is String) {
        final inner = jsonDecode(dataValue);
        if (inner is Map<String, dynamic>) return inner;
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  /// 针对未知消息类型，尽量从 message 中提取一段可阅读的预览文本，
  /// 优先使用 textElem.content 或 customElem.data 中的 data.content/text/remark 字段。
  static String? _buildPreviewFromUnknown(Message message, {int maxLen = 50}) {
    try {
      // 0. 通知类消息（如 contentType 1400 支付/退款）从 notificationElem.detail 提取 text
      if (message.contentType != null && message.contentType! >= 1000) {
        final detail = message.notificationElem?.detail;
        if (detail != null && detail.isNotEmpty) {
          try {
            final map = jsonDecode(detail);
            if (map is Map) {
              final text = (map['text'] ?? map['content'])?.toString();
              if (text != null && text.isNotEmpty) {
                return text.length > maxLen ? text.substring(0, maxLen) : text;
              }
            }
          } catch (_) {}
        }
      }
      // 1. 如果有 textElem，直接使用文本内容
      final text = message.textElem?.content;
      if (text != null && text.isNotEmpty) {
        return text.length > maxLen ? text.substring(0, maxLen) : text;
      }

      // 2. 如果有自定义数据，尝试解析 JSON 并提取常见字段（兼容双层 JSON）
      final raw = message.customElem?.data;
      if (raw != null && raw.isNotEmpty) {
        try {
          final obj = _unwrapCustomData(raw) ?? jsonDecode(raw);
          if (obj is Map) {
            dynamic data = obj['data'] ?? obj;
            if (data is Map) {
              final candidate = (data['content'] ??
                      data['text'] ??
                      data['remark'] ??
                      data['msg'] ??
                      data['title'])
                  ?.toString();
              if (candidate != null && candidate.isNotEmpty) {
                return candidate.length > maxLen
                    ? candidate.substring(0, maxLen)
                    : candidate;
              }
            }
          }
        } catch (_) {
          // 如果不是 JSON，就直接返回原始字符串（截断）
          return raw.length > maxLen ? raw.substring(0, maxLen) : raw;
        }
      }
    } catch (_) {}
    return null;
  }

  static dynamic parseCustomMessage(Message message) {
    try {
      LogUtil.d(
          'parseCustomMessage---------------------------------------${message.contentType}');
      switch (message.contentType) {
        // 如果是文件消息，使用自定义的文件消息视图

        case MessageType.file:
          {
            // map['data']['viewType'] = CustomMessageType.transfer;
            // return map['data'];
          }
        case MessageType.custom:
          {
            final map = _unwrapCustomData(message.customElem?.data);
            if (map == null) return null;
            final customType = map['customType'];
            final dataValue = map['data'];

            // 先做一次红包/转账的智能识别，兼容历史/异构结构：
            // - 有些老红包可能没有 customType 字段，但 data/code 中包含红包标识
            // - 有些红包 data 本身就是顶层 Map 而不是嵌套在 data 里
            // 这里尽量从 map 和 dataValue 中识别出红包/转账 payload，避免显示「暂不支持的消息类型」
            Map<String, dynamic>? _tryExtractLuckMoneyPayload(
                Map<String, dynamic> m) {
              final code = m['code']?.toString();
              if (code != null &&
                  code.startsWith('IM_CHART_LUCKYMONEY_')) {
                final payload = Map<String, dynamic>.from(m);
                payload['viewType'] = CustomMessageType.luckMoney;
                return payload;
              }
              final ext = m['extension'];
              if (ext is Map && ext['lucky_money_scene'] != null) {
                final payload = Map<String, dynamic>.from(m);
                payload['viewType'] = CustomMessageType.luckMoney;
                return payload;
              }
              return null;
            }

            // 如果 dataValue 本身看起来就是红包结构，直接当红包处理
            if (dataValue is Map<String, dynamic>) {
              final luckPayload = _tryExtractLuckMoneyPayload(dataValue);
              if (luckPayload != null) return luckPayload;
            }
            // 否则尝试从顶层 map 中识别红包
            final luckPayload = _tryExtractLuckMoneyPayload(
                Map<String, dynamic>.from(map));
            if (luckPayload != null) return luckPayload;

            switch (customType) {
              case CustomMessageType.transfer:
                if (dataValue is Map) {
                  (dataValue as Map<String, dynamic>)['viewType'] =
                      CustomMessageType.transfer;
                  return dataValue;
                }
                map['viewType'] = CustomMessageType.transfer;
                return map;

              case CustomMessageType.call:
                {
                  final callData =
                      dataValue is Map ? dataValue as Map : map['data'];
                  if (callData is! Map) break;
                  final duration = callData['duration'];
                  final state = callData['state'];
                  final type = callData['type'];
                  String? content;

                  switch (state) {
                    case 'beHangup':
                    case 'hangup':
                      content = sprintf(
                          StrRes.callDuration, [seconds2HMS(duration)]);
                      break;
                    case 'cancel':
                      content = StrRes.cancelled;
                      break;
                    case 'beCanceled':
                      content = StrRes.cancelledByCaller;
                      break;
                    case 'reject':
                      content = StrRes.rejected;
                      break;
                    case 'beRejected':
                      content = StrRes.rejectedByCaller;
                      break;
                    case 'timeout':
                      content = StrRes.callTimeout;
                      break;
                    case 'networkError':
                      content = StrRes.networkAnomaly;
                      break;
                    default:
                      break;
                  }
                  if (content != null) {
                    return {
                      'viewType': CustomMessageType.call,
                      'type': type,
                      'content': content,
                    };
                  }
                }
                break;
              case CustomMessageType.luckMoney:
                if (dataValue is Map<String, dynamic>) {
                  final payload = Map<String, dynamic>.from(dataValue);
                  payload['viewType'] = CustomMessageType.luckMoney;
                  return payload;
                }
                map['viewType'] = CustomMessageType.luckMoney;
                return map;
              case CustomMessageType.emoji:
                if (dataValue is Map<String, dynamic>) {
                  final payload = Map<String, dynamic>.from(dataValue);
                  payload['viewType'] = CustomMessageType.emoji;
                  return payload;
                }
                return map;
              case CustomMessageType.tag:
                if (dataValue is Map<String, dynamic>) {
                  final payload = Map<String, dynamic>.from(dataValue);
                  payload['viewType'] = CustomMessageType.tag;
                  return payload;
                }
                return map;
              case CustomMessageType.meeting:
                if (dataValue is Map<String, dynamic>) {
                  final payload = Map<String, dynamic>.from(dataValue);
                  payload['viewType'] = CustomMessageType.meeting;
                  return payload;
                }
                return map;
              case CustomMessageType.deletedByFriend:
              case CustomMessageType.blockedByFriend:
              case CustomMessageType.removedFromGroup:
              case CustomMessageType.groupDisbanded:
                return {'viewType': customType};
              case CustomMessageType.recover:
                return {
                  'viewType': CustomMessageType.recover,
                  'type': 'notification',
                  'content': map['content'] ?? '',
                };
              case CustomMessageType.groupCard:
                return {
                  'viewType': CustomMessageType.groupCard,
                };
              case CustomMessageType.refundNotification:
                return {
                  'viewType': CustomMessageType.refundNotification,
                };
              case CustomMessageType.infoChange:
                // 组织/权限/CanSendFreeMsg 变更通知（Free-IM-Chat organization 模块）
                final content = map['content']?.toString();
                return {
                  'viewType': CustomMessageType.infoChange,
                  'content': (content != null && content.isNotEmpty)
                      ? content
                      : '组织/权限通知',
                };
              default:
                // 未知 customType：返回可读文案用于会话内展示，避免「暂不支持的消息类型」
                final preview = _buildPreviewFromUnknown(message);
                return {
                  'viewType': CustomMessageType.unknown,
                  'content': (preview != null && preview.isNotEmpty)
                      ? preview
                      : StrRes.otherMessage,
                };
            }
          }
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    return null;
  }

  static Map<String, String> getAtMapping(
    Message message,
    Map<String, String> newMapping,
  ) {
    final mapping = <String, String>{};
    try {
      if (message.contentType == MessageType.atText) {
        final atUserIDs = message.atTextElem!.atUserList!;
        final atUserInfos = message.atTextElem!.atUsersInfo!;

        for (final userID in atUserIDs) {
          final groupNickname = (newMapping[userID] ??
                  atUserInfos
                      .firstWhere((e) => e.atUserID == userID)
                      .groupNickname) ??
              userID;
          mapping[userID] = getAtNickname(userID, groupNickname);
        }
      }
    } catch (_) {}
    return mapping;
  }

  static String getAtNickname(String atUserID, String atNickname) {
    return atUserID == 'atAllTag' ? StrRes.everyone : atNickname;
  }

  static void previewUrlPicture(
    List<MediaSource> sources, {
    int currentIndex = 0,
    String? heroTag,
  }) =>
      navigator?.push(TransparentRoute(
        builder: (BuildContext context) => GestureDetector(
          onTap: () => Get.back(),
          child: ChatPicturePreview(
            currentIndex: currentIndex,
            images: sources,
            heroTag: heroTag,
            onLongPress: (url) {
              IMViews.openDownloadSheet(
                url,
                onDownload: () => saveImage(context, url),
              );
            },
          ),
        ),
      ));

  /*Get.to(
        () => ChatPicturePreview(
          currentIndex: currentIndex,
          images: urls,

          heroTag: urls.elementAt(currentIndex),
          onLongPress: (url) {
            IMViews.openDownloadSheet(
              url,
              onDownload: () => HttpUtil.saveUrlPicture(url),
            );
          },
        ),

        transition: Transition.cupertino,


      );*/

  static void previewPicture(
    Message message, {
    List<Message> allList = const [],
  }) {
    if (allList.isEmpty) {
      previewUrlPicture(
        [
          MediaSource(
              url: message.pictureElem!.sourcePicture!.url!,
              thumbnail: message.pictureElem!.snapshotPicture!.url!)
        ],
        currentIndex: 0,
      );
    } else {
      final picList = allList
          .where((element) =>
              element.contentType == MessageType.picture ||
              element.contentType == MessageType.video)
          .toList();
      final index = picList.indexOf(message);
      final urls = picList.map((e) {
        if (e.contentType == MessageType.picture) {
          return MediaSource(
              url: e.pictureElem!.sourcePicture!.url!,
              thumbnail: e.pictureElem!.snapshotPicture!.url!);
        } else {
          return MediaSource(
              url: e.videoElem!.videoUrl!,
              thumbnail: e.videoElem!.snapshotUrl!);
        }
      }).toList();
      previewUrlPicture(urls, currentIndex: index == -1 ? 0 : index);
    }
  }

//原来的previewFile
  // static void previewFile(Message message) async {
  //   final fileElem = message.fileElem;
  //   if (null != fileElem) {
  //     final sourcePath = fileElem.filePath;
  //     final url = fileElem.sourceUrl;
  //     final fileName = fileElem.fileName;
  //     final fileSize = fileElem.fileSize;
  //     final nameAndExt = fileName?.split('.');
  //     final name = nameAndExt?.first;
  //     final ext = nameAndExt?.last;

  //     final dir = await getDownloadFileDir();

  //     var cachePath = '$dir/${name}_${message.clientMsgID}.$ext';

  //     final isExitSourcePath = await isExitFile(sourcePath);

  //     final isExitCachePath = await isExitFile(cachePath);

  //     Logger.print('isExitSourcePath:$isExitSourcePath, isExitCachePath:$isExitCachePath, cachePath:$cachePath');

  //     final isExitNetwork = isUrlValid(url);
  //     String? availablePath;
  //     if (isExitSourcePath) {
  //       availablePath = sourcePath;
  //     } else if (isExitCachePath) {
  //       availablePath = cachePath;
  //     }
  //     final isAvailableFileSize =
  //         isExitSourcePath || isExitCachePath ? (await File(availablePath!).length() == fileSize) : false;
  //     Logger.print('previewFile isAvailableFileSize: $isAvailableFileSize   isExitNetwork: $isExitNetwork');
  //     if (isAvailableFileSize) {
  //       String? mimeType = lookupMimeType(fileName ?? '');
  //       if (null != mimeType && allowVideoType(mimeType)) {
  //       } else if (null != mimeType && mimeType.contains('image')) {
  //         previewPicture(Message()
  //           ..clientMsgID = message.clientMsgID
  //           ..contentType = MessageType.picture
  //           ..pictureElem = PictureElem(sourcePath: availablePath, sourcePicture: PictureInfo(url: url)));
  //       } else {
  //         openFileByOtherApp(availablePath);
  //       }
  //     } else {}
  //   }
  // }
  // 静态变量用于跟踪正在下载的文件
  static final Set<String> _downloadingFiles = {};
  
  static Future<void> previewFile(Message message) async {
    // 先显示初始加载提示
    EasyLoading.show(status: StrRes.processingFile, maskType: EasyLoadingMaskType.black);
    
    try {
      final elem = message.fileElem!;
      final sourcePath = elem.filePath;
      final fileName = elem.fileName;
      final dir = await getDownloadFileDir();
      final savePath = '$dir/$fileName';
      
      // 使用文件URL作为唯一标识符
      final fileKey = elem.sourceUrl ?? savePath;

      Logger.print('文件信息:');
      Logger.print('源路径: $sourcePath');
      Logger.print('保存路径: $savePath');
      Logger.print('下载链接: ${elem.sourceUrl}');
      Logger.print('文件名: $fileName');
      Logger.print('文件大小: ${elem.fileSize}');

      File? file;
      if (sourcePath != null && await File(sourcePath).exists()) {
        Logger.print('文件存在于源路径');
        file = File(sourcePath);
        // 文件已存在，隐藏loading
        EasyLoading.dismiss();
      } else if (await File(savePath).exists()) {
        Logger.print('文件存在于下载目录');
        file = File(savePath);
        // 文件已存在，隐藏loading
        EasyLoading.dismiss();
      } else if (elem.sourceUrl != null) {
        // 检查是否正在下载
        if (_downloadingFiles.contains(fileKey)) {
          Logger.print('文件正在下载中，忽略重复请求: $fileName');
          EasyLoading.showToast(StrRes.fileDownloading);
          return;
        }
        
        // 标记为正在下载
        _downloadingFiles.add(fileKey);
        Logger.print('开始下载文件...');
        
        try {
          await HttpUtil.download(
            UrlConverter.convertMediaUrl(elem.sourceUrl!),
            cachePath: savePath,
            onProgress: (count, total) {
              if (total > 0) {
                final progress = count / total;
                final progressPercent = (progress * 100).round();
                Logger.print('下载进度: $progressPercent%');
                
                // 显示下载进度
                EasyLoading.showProgress(
                  progress,
                  status: StrRes.downloadingProgress(progressPercent),
                  maskType: EasyLoadingMaskType.black,
                );
              }
            },
          );

          if (await File(savePath).exists()) {
            file = File(savePath);
            Logger.print('文件下载完成: $savePath');
            // 下载完成后立即隐藏进度
            EasyLoading.dismiss();
          } else {
            Logger.print('文件下载失败: 文件不存在');
            EasyLoading.showError(
              StrRes.downloadFailed,
              duration: const Duration(seconds: 2),
              maskType: EasyLoadingMaskType.black,
            );
            return;
          }
        } catch (e) {
          Logger.print('文件下载失败: $e');
          EasyLoading.showError(
            StrRes.downloadFailed,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.black,
          );
          return;
        } finally {
          // 无论成功失败都要移除下载标记
          _downloadingFiles.remove(fileKey);
        }
      } else {
        Logger.print('无法获取文件: 没有可用的文件路径或下载链接');
        EasyLoading.showError(
          StrRes.cannotGetFile,
          duration: const Duration(seconds: 2),
          maskType: EasyLoadingMaskType.black,
        );
        return;
      }

      final mimeType = lookupMimeType(file.path);
      Logger.print('文件类型: $mimeType');

      if (mimeType?.startsWith('image/') == true) {
        final newMessage = Message()
          ..clientMsgID = message.clientMsgID
          ..contentType = MessageType.picture
          ..pictureElem = PictureElem(
            sourcePath: file.path,
            sourcePicture: PictureInfo(
              width: 0,
              height: 0,
              type: mimeType,
            ),
          );
        
        // 直接预览图片
        previewPicture(newMessage);
      } else {
        final result = await OpenFilex.open(file.path);
        Logger.print('打开文件结果: $result');

        // 只在出错时显示错误提示
        if (result.type == ResultType.noAppToOpen) {
          EasyLoading.showError(
            StrRes.noAppToOpenFile,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.black,
          );
        } else if (result.type == ResultType.permissionDenied) {
          EasyLoading.showError(
            StrRes.noPermissionToAccessFile,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.black,
          );
        } else if (result.type == ResultType.fileNotFound) {
          EasyLoading.showError(
            StrRes.fileNotExistOrDeleted,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.black,
          );
        } else if (result.type == ResultType.error) {
          EasyLoading.showError(
            StrRes.openFileFailed,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.black,
          );
        }
        // 成功打开文件时不显示任何提示
      }
    } catch (e, s) {
      Logger.print('处理文件错误: $e\n$s');
      EasyLoading.showError(
        StrRes.processingFailed,
        duration: const Duration(seconds: 2),
        maskType: EasyLoadingMaskType.black,
      );
    } finally {
      // 确保在任何情况下都能清理状态
      try {
        final elem = message.fileElem;
        if (elem != null) {
          final dir = await getDownloadFileDir();
          final savePath = '$dir/${elem.fileName}';
          final fileKey = elem.sourceUrl ?? savePath;
          _downloadingFiles.remove(fileKey);
        }
        // 确保loading被隐藏
        if (EasyLoading.isShow) {
          EasyLoading.dismiss();
        }
      } catch (_) {
        // 忽略清理过程中的异常
      }
    }
  }

  static Future previewMediaFile(
      {required BuildContext context,
      required Message message,
      bool muted = false,
      bool Function(int)? onAutoPlay,
      ValueChanged<int>? onPageChanged,
      bool onlySave = false}) {
    final sources = message.isVideoType
        ? MediaSource(
            url: message.videoElem?.videoUrl != null ? UrlConverter.convertMediaUrl(message.videoElem!.videoUrl!) : null,
            thumbnail: message.videoElem!.snapshotUrl != null 
                ? UrlConverter.convertMediaUrl(message.videoElem!.snapshotUrl!.adjustThumbnailAbsoluteString(960) ?? '')
                : '',
            file: message.videoElem?.videoPath == null ? null : File(message.videoElem!.videoPath!),
            tag: message.clientMsgID,
            isVideo: true,
          )
        : MediaSource(
            url: message.pictureElem?.sourcePicture?.url != null ? UrlConverter.convertMediaUrl(message.pictureElem!.sourcePicture!.url!) : null,
            thumbnail: message.pictureElem!.snapshotPicture?.url != null
                ? UrlConverter.convertMediaUrl(message.pictureElem!.snapshotPicture!.url!.adjustThumbnailAbsoluteString(960) ?? '')
                : '',
            file: message.pictureElem!.sourcePath != null
                ? File(message.pictureElem!.sourcePath!)
                : null,
            tag: message.clientMsgID,
          );

    final mb = MediaBrowser(
      sources: [sources],
      initialIndex: 0,
      onAutoPlay: (index) => onAutoPlay != null ? onAutoPlay(index) : false,
      muted: muted,
      onSave: (value) async {
        final source = sources;
        try {
          if (source.isVideo) {
            await HttpUtil.saveUrlVideo(source.url!);
          } else {
            if (source.file != null && await source.file!.exists()) {
              await HttpUtil.saveFileToGallerySaver(source.file!);
            } else if (source.url != null) {
              final imageFile = await getCachedImageFile(source.url!);
              if (imageFile != null) {
                await HttpUtil.saveFileToGallerySaver(
                  imageFile,
                  name: source.url!.split('/').last,
                );
              } else {
                await HttpUtil.saveUrlPicture(source.url!);
              }
            }
          }
        } catch (e, s) {
          Logger.print('保存失败: $e\n$s');
        }
      },
    );
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return mb;
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static void saveImage(BuildContext ctx, String url) async {
    EasyLoading.show(dismissOnTap: true);
    final imageFile = await getCachedImageFile(url);

    if (imageFile != null) {
      await HttpUtil.saveFileToGallerySaver(
        imageFile,
        name: url.split('/').last,
      );

      EasyLoading.dismiss();
    } else {
      HttpUtil.saveUrlPicture(url, onCompletion: () {
        EasyLoading.dismiss();
      });
    }
  }

  static openFileByOtherApp(String path) async {
    OpenResult result = await OpenFilex.open(path);
    if (result.type == ResultType.noAppToOpen) {
      IMViews.showToast("No supported app available");
    } else if (result.type == ResultType.permissionDenied) {
      IMViews.showToast("No permission to access");
    } else if (result.type == ResultType.fileNotFound) {
      IMViews.showToast("File no longer valid");
    }
  }

  static void parseClickEvent(
    Message message, {
    Function(UserInfo userInfo)? onViewUserInfo,
  }) async {
    if (message.contentType == MessageType.picture ||
        message.contentType == MessageType.video) {
      previewMediaFile(
        context: Get.context!,
        message: message,
      );
    } else if (message.contentType == MessageType.file) {
      previewFile(message);
    }
  }

  static Future<bool> isExitFile(String? path) async {
    return isNotNullEmptyStr(path) ? await File(path!).exists() : false;
  }

  static String? getMediaType(final String filePath) {
    var fileName = filePath.substring(filePath.lastIndexOf("/") + 1);
    var fileExt = fileName.substring(fileName.lastIndexOf("."));
    switch (fileExt.toLowerCase()) {
      case ".jpg":
      case ".jpeg":
      case ".jpe":
        return "image/jpeg";
      case ".png":
        return "image/png";
      case ".bmp":
        return "image/bmp";
      case ".gif":
        return "image/gif";
      case ".json":
        return "application/json";
      case ".svg":
      case ".svgz":
        return "image/svg+xml";
      case ".mp3":
        return "audio/mpeg";
      case ".mp4":
        return "video/mp4";
      case ".mov":
        return "video/mov";
      case ".htm":
      case ".html":
        return "text/html";
      case ".css":
        return "text/css";
      case ".csv":
        return "text/csv";
      case ".txt":
      case ".text":
      case ".conf":
      case ".def":
      case ".log":
      case ".in":
        return "text/plain";
    }
    return null;
  }

  static String formatBytes(int bytes) {
    int kb = 1024;
    int mb = kb * 1024;
    int gb = mb * 1024;
    if (bytes >= gb) {
      return sprintf("%.1f GB", [bytes / gb]);
    } else if (bytes >= mb) {
      double f = bytes / mb;
      return sprintf(f > 100 ? "%.0f MB" : "%.1f MB", [f]);
    } else if (bytes > kb) {
      double f = bytes / kb;
      return sprintf(f > 100 ? "%.0f KB" : "%.1f KB", [f]);
    } else {
      return sprintf("%d B", [bytes]);
    }
  }

  static String formatDate(
    int? timestamp, {
    String format = 'yyyy-MM-dd HH:mm:ss',
  }) {
    if (timestamp == null) return '';
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat(format).format(dateTime);
  }

  static String formatIsoDate(String isoDate,
      {String format = 'yyyy-MM-dd HH:mm:ss'}) {
    try {
      DateTime dateTime = DateTime.parse(isoDate).toLocal();
      return DateFormat(format).format(dateTime);
    } catch (e) {
      return isoDate; // 如果解析失败，返回原始字符串
    }
  }

  static bool allowImageType(String? mimeType) {
    final result = mimeType?.contains('png') == true ||
        mimeType?.contains('jpeg') == true ||
        mimeType?.contains('gif') == true ||
        mimeType?.contains('bmp') == true ||
        mimeType?.contains('webp') == true ||
        mimeType?.contains('heic') == true;

    return result;
  }

  static bool allowVideoType(String? mimeType) {
    final result = mimeType?.contains('mp4') == true ||
        mimeType?.contains('3gpp') == true ||
        mimeType?.contains('webm') == true ||
        mimeType?.contains('x-msvideo') == true ||
        mimeType?.contains('quicktime') == true;

    return result;
  }

  static String fileIcon(String fileName) {
    var mimeType = lookupMimeType(fileName) ?? '';
    if (mimeType == 'application/pdf') {
      return ImageRes.filePdf;
    } else if (mimeType == 'application/msword' ||
        mimeType ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return ImageRes.fileWord;
    } else if (mimeType == 'application/vnd.ms-excel' ||
        mimeType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return ImageRes.fileExcel;
    } else if (mimeType == 'application/vnd.ms-powerpoint') {
      return ImageRes.filePpt;
    } else if (mimeType.startsWith('audio/')) {
    } else if (mimeType == 'application/zip' ||
        mimeType == 'application/x-rar-compressed') {
      return ImageRes.fileZip;
    }
    /*else if (mimeType.startsWith('audio/')) {
      return FontAwesomeIcons.solidFileAudio;
    } else if (mimeType.startsWith('video/')) {
      return FontAwesomeIcons.solidFileVideo;
    } else if (mimeType.startsWith('image/')) {
      return FontAwesomeIcons.solidFileImage;
    } else if (mimeType == 'text/plain') {
      return FontAwesomeIcons.solidFileCode;
    }*/
    return ImageRes.fileUnknown;
  }

  static String createSummary(Message message) {
    return '${message.senderNickname}：${parseMsg(message, replaceIdToNickname: true)}';
  }

  static List<UserInfo>? convertSelectContactsResultToUserInfo(result) {
    if (result is Map) {
      final checkedList = <UserInfo>[];
      final values = result.values;
      for (final value in values) {
        if (value is ISUserInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is UserFullInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is FriendInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is UserInfo) {
          checkedList.add(value);
        }
      }
      return checkedList;
    }
    return null;
  }

  static List<String>? convertSelectContactsResultToUserID(result) {
    if (result is Map) {
      final checkedList = <String>[];
      final values = result.values;
      for (final value in values) {
        if (value is UserInfo ||
            value is FriendInfo ||
            value is UserFullInfo ||
            value is ISUserInfo) {
          checkedList.add(value.userID!);
        }
      }
      return checkedList;
    }
    return null;
  }

  static convertCheckedListToMap(List<dynamic>? checkedList) {
    if (null == checkedList) return null;
    final checkedMap = <String, dynamic>{};
    for (var item in checkedList) {
      if (item is ConversationInfo) {
        checkedMap[item.isSingleChat ? item.userID! : item.groupID!] = item;
      } else if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        checkedMap[item.userID!] = item;
      } else if (item is GroupInfo) {
        checkedMap[item.groupID] = item;
      }
    }
    return checkedMap;
  }

  static List<Map<String, String?>> convertCheckedListToForwardObj(
      List<dynamic> checkedList) {
    final map = <Map<String, String?>>[];
    for (var item in checkedList) {
      if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        map.add({'nickname': item.nickname, 'faceURL': item.faceURL});
      } else if (item is GroupInfo) {
        map.add({'nickname': item.groupName, 'faceURL': item.faceURL});
      } else if (item is ConversationInfo) {
        map.add({'nickname': item.showName, 'faceURL': item.faceURL});
      }
    }
    return map;
  }

  static String? convertCheckedToUserID(dynamic info) {
    if (info is UserInfo ||
        info is UserFullInfo ||
        info is ISUserInfo ||
        info is FriendInfo) {
      return info.userID;
    } else if (info is ConversationInfo) {
      return info.userID;
    }

    return null;
  }

  /// 创建群卡片消息
  static Future<Message> createGroupCardMessage(
      {required String groupID,
      required String groupName,
      required String groupAvatar}) {
    final groupCardData = GroupCardData(
        customType: CustomMessageType.groupCard,
        data: GroupData(
            groupID: groupID, groupName: groupName, groupAvatar: groupAvatar));
    final jsonData = jsonEncode(groupCardData.toJson());
    return OpenIM.iMManager.messageManager.createCustomMessage(
        data: jsonData, extension: "", description: "群聊名片消息");
  }

  static String? convertCheckedToGroupID(dynamic info) {
    if (info is GroupInfo) {
      return info.groupID;
    } else if (info is ConversationInfo) {
      return info.groupID;
    }

    return null;
  }

  static List<Map<String, String?>> convertCheckedListToShare(
      Iterable<dynamic> checkedList) {
    final map = <Map<String, String?>>[];
    for (var item in checkedList) {
      if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        map.add({'userID': item.userID, 'groupID': null});
      } else if (item is GroupInfo) {
        map.add({'userID': null, 'groupID': item.groupID});
      } else if (item is ConversationInfo) {
        map.add({'userID': item.userID, 'groupID': item.groupID});
      }
    }
    return map;
  }

  static String getWorkMomentsTimeline(int ms) {
    final locTimeMs = DateTime.now().millisecondsSinceEpoch;
    final languageCode = Get.locale?.languageCode ?? 'zh';
    final isZH = languageCode == 'zh';

    if (DateUtil.isToday(ms, locMs: locTimeMs)) {
      return isZH ? '今天' : 'Today';
    }

    if (DateUtil.isYesterdayByMs(ms, locTimeMs)) {
      return isZH ? '昨天' : 'Yesterday';
    }

    if (DateUtil.isWeek(ms, locMs: locTimeMs)) {
      return DateUtil.getWeekdayByMs(ms, languageCode: languageCode);
    }

    if (DateUtil.yearIsEqualByMs(ms, locTimeMs)) {
      return formatDateMs(ms, format: isZH ? 'MM月dd' : 'MM/dd');
    }

    return formatDateMs(ms, format: isZH ? 'yyyy年MM月dd' : 'yyyy/MM/dd');
  }

  static Future<bool> checkingBiometric(LocalAuthentication auth) =>
      auth.authenticate(
        localizedReason:
            'Scan your fingerprint (or face or other) to authenticate.',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
        authMessages: <AuthMessages>[
          const AndroidAuthMessages(
            cancelButton: 'No, thanks',
            biometricNotRecognized: 'Biometric not recognized. Try again.',
            biometricHint: 'Verify identity',
            biometricSuccess: 'Success',
            biometricRequiredTitle: 'Authentication required',
            goToSettingsDescription:
                "No biometric authentication is set up on your device. Go to Settings > Security to add biometric authentication.",
            goToSettingsButton: 'Go to settings',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription: 'Device credentials required',
            signInTitle: 'Authentication required',
          ),
          const IOSAuthMessages(
            cancelButton: 'No, thanks',
            goToSettingsButton: 'Go to settings',
            goToSettingsDescription:
                'No biometric authentication is set up on your device. Please enable Touch ID or Face ID on your phone.',
            lockOut:
                'Biometric authentication is disabled. Please lock and unlock your screen to enable it.',
          ),
        ],
      );

  static String safeTrim(String text) {
    return text.trim();
  }

  static String getTimeFormat1() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'yyyy年MM月dd日' : 'yyyy/MM/dd';
  }

  static String getTimeFormat2() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'yyyy年MM月dd日 HH时mm分' : 'yyyy/MM/dd HH:mm';
  }

  static String getTimeFormat3() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'MM月dd日 HH时mm分' : 'MM/dd HH:mm';
  }

  static bool isValidPassword(String password) => password.length >= 6;

  static TextInputFormatter getPasswordFormatter() =>
      FilteringTextInputFormatter.allow(
        RegExp(r'[a-zA-Z0-9\S]'),
      );

  static Future requestBackgroundPermission(
      {required String title,
      required String text,
      bool isRetry = false}) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!isRetry) {
        hasPermissions = await FlutterBackground.initialize(
            androidConfig: FlutterBackgroundAndroidConfig(
                notificationTitle: title,
                notificationText: text,
                notificationImportance: AndroidNotificationImportance.normal,
                notificationIcon: const AndroidResource(
                    name: 'ic_launcher', defType: 'mipmap'),
                shouldRequestBatteryOptimizationsOff: false));
      }
      if (hasPermissions && !FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      if (!isRetry) {
        return await Future<void>.delayed(
            const Duration(seconds: 1),
            () => requestBackgroundPermission(
                title: title, text: text, isRetry: true));
      }
    }
  }

  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case "USD":
      case "AUD":
      case "CAD":
      case "HKD":
      case "SGD":
      case "NZD":
      case "MXN":
        return "\$";
      case "CNY":
      case "JPY":
        return "¥";
      case "USDT":
        return "₮";
      case "EUR":
        return "€";
      case "GBP":
        return "£";
      case "INR":
        return "₹";
      case "RUB":
        return "₽";
      case "KRW":
        return "₩";
      case "TRY":
        return "₺";
      case "BRL":
        return "R\$";
      case "THB":
        return "฿";
      case "CHF":
        return "Fr";
      case "ZAR":
        return "R";
      case "SEK":
      case "NOK":
      case "DKK":
        return "kr";
      case "ILS":
        return "₪";
      case "PLN":
        return "zł";
      case "PHP":
        return "₱";
      case "AED":
        return "د.إ";
      case "SAR":
        return "﷼";
      case "VND":
        return "₫";
      case "IDR":
        return "Rp";
      case "MYR":
        return "RM";
      case "CZK":
        return "Kč";
      case "HUF":
        return "Ft";
      case "UAH":
        return "₴";
      case "BTC":
        return "₿";
      case "ETH":
        return "Ξ";
      default:
        return "\$";
    }
  }

  /// 格式化数字为千分位并保留两位小数（支持String/num输入）
  ///
  /// 参数：
  ///   - input: 要格式化的数字（支持String/int/double/num）
  ///   - decimalDigits: 小数位数（默认2位）
  ///   - locale: 本地化设置（默认'en_US'）
  ///
  /// 返回：
  ///   - 格式化后的字符串，如 "1,234.56"
  ///   - 如果输入无效则返回原字符串（针对String输入）或"0.00"（针对num输入）
  static String formatNumberWithCommas(
    dynamic input, {
    int decimalDigits = 2,
    String locale = 'en_US',
  }) {
    // 实际格式化逻辑
    String _format(num number, int decimalDigits, String locale) {
      return NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimalDigits,
      ).format(number);
    }

    try {
      // 处理String类型输入
      if (input is String) {
        // 移除可能存在的千分位分隔符
        final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');
        final number = num.tryParse(cleaned) ?? double.nan;
        if (number.isNaN) return input; // 无法解析时返回原字符串
        return _format(number, decimalDigits, locale);
      }
      // 处理num类型输入
      else if (input is num) {
        return _format(input, decimalDigits, locale);
      }
      // 其他类型尝试转换
      else {
        final number = num.tryParse(input.toString()) ?? double.nan;
        return number.isNaN
            ? input.toString()
            : _format(number, decimalDigits, locale);
      }
    } catch (e) {
      return input is String ? input : '0.00';
    }
  }

  static String getFirstNonEmptyString(
      List<String?> values, String defaultValue) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return defaultValue;
  }
  static Future<String> getDeviceId() async {
    String mobileDeviceIdentifier;
    String? deviceId = await MobileDeviceIdentifier().getDeviceId();
    if (deviceId != null && deviceId.isNotEmpty) {
      mobileDeviceIdentifier = deviceId;
    } else {
      // 如果无法获取设备ID，则使用UUID作为替代，且需要做持久化,优先从shared_preferences中获取
      const String deviceIdKey = 'device_id_fallback';
      final sp = SpUtil();
      String? savedDeviceId = sp.getString(deviceIdKey);
      
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        mobileDeviceIdentifier = savedDeviceId;
      } else {
        // 生成一个基于时间戳和随机因子的唯一ID
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final randomSuffix = (timestamp % 10000).toString().padLeft(4, '0');
        final uniqueId = 'fallback_${timestamp}_$randomSuffix';
        
        // 使用MD5加密以获得更短的ID
        mobileDeviceIdentifier = generateMD5(uniqueId) ?? uniqueId;
        
        // 持久化保存
        await sp.putString(deviceIdKey, mobileDeviceIdentifier);
      }
    }
    return mobileDeviceIdentifier;
  }

  static Future<File?> compressImageAndGetFileFromBytes(Uint8List image, {int quality = 80}) async {
    try {
      // 生成一个唯一的文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'compressed_image_$timestamp.png';
      
      // 获取临时目录
      final targetDirectory = await getTempDirectory(fileName);
      
      // 使用 FlutterImageCompress 压缩字节数据
      final result = await FlutterImageCompress.compressWithList(
        image,
        quality: quality,
        minWidth: 1280,
        minHeight: 720,
        format: CompressFormat.png,
      );
      
      // 将压缩后的字节数据写入文件
      final file = File(targetDirectory.path);
      await file.writeAsBytes(result);
      
      return file;
    } catch (e) {
      // 如果压缩失败，创建原始文件
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'image_$timestamp.png';
        final targetDirectory = await getTempDirectory(fileName);
        final file = File(targetDirectory.path);
        await file.writeAsBytes(image);
        return file;
      } catch (e) {
        return null;
      }
    }
  }
}

extension PlatformExt on Platform {
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  static bool get isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
