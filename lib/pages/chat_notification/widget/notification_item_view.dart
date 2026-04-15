import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:get/get.dart';
import 'package:openim/pages/chat/widget/banner_notification.dart';
import 'package:openim/pages/chat/widget/refund_notification.dart';
import 'package:openim/pages/chat_notification/widget/picture_notity.dart';
import 'package:openim/pages/chat_notification/widget/text_notify.dart';
import 'package:openim/pages/chat_notification/widget/video_notity.dart';
import 'package:openim_common/openim_common.dart';

typedef ItemVisibilityChange = void Function(
  Message message,
  bool visible,
);

class NotificationItemView extends StatelessWidget {
  final Message message;
  final double textScaleFactor;
  final VoidCallback? onTap;
  final ItemVisibilityChange? visibilityChange;

  const NotificationItemView({
    super.key,
    required this.message,
    this.onTap,
    this.textScaleFactor = 1.0,
    this.visibilityChange,
  });

  NotifyContent get content => NotifyContent.fromJson(
      jsonDecode(message.notificationElem?.detail ?? ''));

  String get formattedTime {
    if (message.sendTime == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(message.sendTime!);
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final showTime = message.exMap['showTime'] ?? false;

    return FocusDetector(
      child: content.notificationType == 1
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 使用NotificationAccountController动态获取最新通知账号信息
                GetBuilder<NotificationAccountController>(
                  id: message.sendID ?? 'unknown',
                  builder: (controller) {
                    // 尝试获取最新通知账号信息
                    if (message.sendID != null) {
                      controller.getNotificationAccount(message.sendID).then((userInfo) {
                        // 通过异步获取，无需处理返回值，GetBuilder会自动更新UI
                      });
                    }

                    return AvatarView(
                      width: 44.w,
                      height: 44.h,
                      textStyle: Styles.ts_FFFFFF_14sp_medium,
                      url: _getAvatarUrl(controller, message),
                      text: _getNickname(controller, message),
                      convertUrl: true,
                    );
                  },
                ),
                10.horizontalSpace,
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ChatNicknameView(
                      nickname: message.senderNickname ?? '',
                      timeStr: IMUtils.getChatTimeline(
                          message.sendTime!, 'HH:mm:ss'),
                    ),
                    4.verticalSpace,
                    _buildCardItem(),
                  ],
                )),
              ],
            )
          : Container(
              margin: EdgeInsets.only(top: !showTime ? 0 : 20.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (showTime)
                    Text(
                      formattedTime,
                      style: Styles.ts_0C1C33_12sp,
                    ),
                  _buildCardItem(),
                ],
              )),
      onVisibilityLost: () {
        visibilityChange?.call(message, false);
      },
      onVisibilityGained: () {
        visibilityChange?.call(message, true);
      },
    );
  }

  Widget _buildCardItem() {
    Widget? child;
    if (content.notificationType == 1) {
      if (content.mixType == 0) {
        child =
            TextNotify(text: content.text, externalUrl: content.externalUrl);
      } else if (content.mixType == 1) {
        child = PictureNotity(
            text: content.text,
            notifyPictureElem: content.pictureElem,
            externalUrl: content.externalUrl);
      } else if (content.mixType == 2) {
        child = VideoNotity(
            text: content.text,
            notifyVideoElem: content.videoElem,
            externalUrl: content.externalUrl);
      }
    } else if (content.notificationType == 500) {
      child = RefundNotification(message: message);
    } else if (content.notificationType == 600) {
      child = BannerNotification(
        message: message,
        textScaleFactor: textScaleFactor,
      );
    }

    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.w),
        child: Card(
          color: Styles.c_FFFFFF,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: child ?? TextNotify(text: StrRes.unsupportedMessage),
        ),
      ),
    );
  }

  /// 获取通知账号的最新头像URL
  String _getAvatarUrl(NotificationAccountController controller, Message message) {
    // 尝试获取缓存的用户信息
    final cachedUserInfo = controller.getCachedUserInfo(message.sendID);
    if (cachedUserInfo != null && cachedUserInfo.faceURL != null && cachedUserInfo.faceURL!.isNotEmpty) {
      // 如果有缓存的用户信息，使用缓存的头像URL并添加刷新参数
      return _addCacheRefreshParam(cachedUserInfo.faceURL!);
    }

    // 缓存不存在或无效，使用消息中的头像URL
    return _addCacheRefreshParam(message.senderFaceUrl);
  }

  /// 获取通知账号的最新昵称
  String _getNickname(NotificationAccountController controller, Message message) {
    // 尝试获取缓存的用户信息
    final cachedUserInfo = controller.getCachedUserInfo(message.sendID);
    if (cachedUserInfo != null && cachedUserInfo.nickname != null && cachedUserInfo.nickname!.isNotEmpty) {
      // 如果有缓存的用户信息，使用缓存的昵称
      return cachedUserInfo.nickname!;
    }

    // 缓存不存在或无效，使用消息中的昵称
    return message.senderNickname ?? '';
  }

  /// 为头像URL添加缓存刷新参数，确保每次都加载最新头像
  String _addCacheRefreshParam(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    // 如果已经有刷新参数，直接返回
    if (url.contains('_refresh=')) {
      return url;
    }

    // 添加随机刷新参数
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);

    String result;
    if (url.contains('?')) {
      result = '$url&_refresh=${timestamp}_$random';
    } else {
      result = '$url?_refresh=${timestamp}_$random';
    }

    return result;
  }
}
