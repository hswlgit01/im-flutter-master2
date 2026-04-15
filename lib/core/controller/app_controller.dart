import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart' as im;
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:openim/core/im_callback.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:vibration/vibration.dart';

import '../../utils/upgrade_manager.dart';
import '../../utils/log_util.dart';
import '../../utils/hot_update_manager.dart';
import '../../utils/apk_update_manager.dart';
import '../../utils/update_service.dart';
import 'im_controller.dart';
import '../security_manager.dart';

class AppController extends GetxController with UpgradeManger {
  var isRunningBackground = false;

  // 热更新状态管理,防止重复操作
  bool _isProcessingUpdate = false;

  // 统一的更新服务
  final UpdateService _updateService = UpdateService();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  String? currentActiveConversationId;

  final initializationSettingsAndroid =
      const AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsDarwin =
      const DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  RTCBridge? get rtcBridge => PackageBridge.rtcBridge;

  bool get shouldMuted =>
      rtcBridge?.hasConnection == true ||
      Get.find<IMController>().imSdkStatusSubject.values.last.status !=
          IMSdkStatus.syncEnded;

  final _ring = 'assets/audio/message_ring.wav';
  final _audioPlayer = AudioPlayer();
  final _audioSessionManager = AudioSessionManager();
  late AudioSession session;

  late BaseDeviceInfo deviceInfo;

  final clientConfigMap = <String, dynamic>{}.obs;

  Future<void> runningBackground(bool run) async {
    Logger.print('-----App running background : $run-------------');

    if (isRunningBackground && !run) {}
    isRunningBackground = run;

    // 通知音视频通话模块后台状态变化
    try {
      final imController = Get.find<IMController>();
      imController.backgroundSubject.add(run);
      Logger.print('[AppController] 已通知 IMController 后台状态: $run');
    } catch (e) {
      Logger.print('[AppController] 通知 IMController 后台状态失败: $e');
    }

    if (!run) {
      _cancelAllNotifications();
    }
  }

  @override
  void onInit() {
    _initPlayer();
    super.onInit();
    _getDeviceInfo();
    _restoreSecurityServices();
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showNotification(im.Message message,
      {bool showNotification = true}) async {
    // 允许的系统通知类型: 1400(OA通知), 1201(好友申请通过), 1204(好友添加)
    final allowedSystemNotifications = [1400, 1201, 1204];

    if (_isGlobalNotDisturb() ||
        message.attachedInfoElem?.notSenderNotificationPush == true ||
        message.contentType == im.MessageType.typing ||
        message.sendID == OpenIM.iMManager.userID ||
        (message.contentType! >= 1000 && !allowedSystemNotifications.contains(message.contentType))) return;

    // 过滤通话信令消息，这些消息不应该显示通知
    if (message.contentType == 110 && message.customElem != null) {
      try {
        final data = jsonDecode(message.customElem!.data!);
        final customType = data['customType'];

        // 通话信令消息(200-204)由通话模块专门处理，不显示普通通知
        if (customType == 200 || customType == 201 || customType == 202 ||
            customType == 203 || customType == 204 || customType == 2005) {
          Logger.print('[AppController] 跳过通话信令消息通知，customType=$customType');
          return;
        }
      } catch (e) {
        Logger.print('[AppController] 解析自定义消息失败: $e');
      }
    }

    var sourceID = message.sessionType == ConversationType.single
        ? message.sendID
        : message.groupID;
    if (sourceID != null && message.sessionType != null) {
      var i = await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: sourceID,
        sessionType: message.sessionType!,
      );
      if (i.recvMsgOpt != 0) return;

      if (showNotification && !_isMessageFromActiveConversation(message, i)) {
        promptSoundOrNotification(message);
      }
    }
  }

  // 设置当前活跃会话
  void setActiveConversation(String? conversationId) {
    currentActiveConversationId = conversationId;
  }

  // 清除当前活跃会话
  void clearActiveConversation() {
    currentActiveConversationId = null;
  }

  // 检查消息是否来自当前活跃会话
  bool _isMessageFromActiveConversation(
      im.Message message, ConversationInfo? conversationInfo) {
    if (currentActiveConversationId == null) {
      return false;
    }

    if (conversationInfo == null) {
      return false;
    }

    return conversationInfo.conversationID == currentActiveConversationId;
  }

  Future<void> promptSoundOrNotification(im.Message message) async {
    var status = Get.find<IMController>().imSdkStatusSubject.values;
    if (status.lastOrNull?.status != IMSdkStatus.syncEnded) {
      return;
    }
    if (!isRunningBackground) {
      _playMessageSound();
    } else {
      if (Platform.isAndroid) {
        final id = message.seq!;

        const androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'chat', 'FreeChat message',
            channelDescription: 'from FreeChat message',
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            ticker: 'ticker');
        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);
            final sourceID = message.sessionType == ConversationType.single
                ? message.sendID
                : message.groupID;

            final sessionType = message.sessionType;
        await flutterLocalNotificationsPlugin.show(
            id, message.senderNickname, IMUtils.parseMsg(message), platformChannelSpecifics,
            payload: "chat://$sessionType/$sourceID");
      }
    }
  }

  /// 显示好友申请系统通知
  Future<void> showFriendApplicationSystemNotification(FriendApplicationInfo info) async {
    if (!Platform.isAndroid) return;

    try {
      // 使用和聊天消息相同的通知配置
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'chat', // 使用相同的channel ID，保持一致性
        'FreeChat message',
        channelDescription: 'from FreeChat message',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        ticker: 'ticker',
        playSound: true, // 明确启用声音
        enableVibration: true, // 明确启用震动
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final title = '新的好友申请';
      final body = '${info.fromNickname ?? info.fromUserID} 请求添加你为好友';

      await flutterLocalNotificationsPlugin.show(
        info.fromUserID.hashCode, // 使用userID的hashCode作为通知ID
        title,
        body,
        platformChannelSpecifics,
        payload: "friend_application://${info.fromUserID}",
      );

      Logger.print('已显示好友申请系统通知: ${info.fromNickname}');
    } catch (e) {
      Logger.print('显示好友申请系统通知失败: $e');
    }
  }

  /// 显示好友申请通过系统通知
  /// 当对方通过我的好友申请时调用
  Future<void> showFriendApprovedSystemNotification(FriendInfo friend) async {
    if (!Platform.isAndroid) return;

    try {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'chat',
        'FreeChat message',
        channelDescription: 'from FreeChat message',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final title = '好友申请已通过';
      final body = '${friend.nickname ?? friend.userID} 已通过你的好友申请';

      await flutterLocalNotificationsPlugin.show(
        friend.userID.hashCode,
        title,
        body,
        platformChannelSpecifics,
        payload: "friend_approved://${friend.userID}",
      );

      Logger.print('已显示好友申请通过系统通知: ${friend.nickname}');
    } catch (e) {
      Logger.print('显示好友申请通过系统通知失败: $e');
    }
  }

  /// 显示好友添加成功系统通知
  /// 当成功建立好友关系时调用
  Future<void> showFriendAddedSystemNotification(FriendInfo friend) async {
    if (!Platform.isAndroid) return;

    try {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'chat',
        'FreeChat message',
        channelDescription: 'from FreeChat message',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final title = '成为好友';
      final body = '你和 ${friend.nickname ?? friend.userID} 已经是好友了,开始聊天吧!';

      await flutterLocalNotificationsPlugin.show(
        friend.userID.hashCode + 1, // 避免ID冲突
        title,
        body,
        platformChannelSpecifics,
        payload: "friend_added://${friend.userID}",
      );

      Logger.print('已显示好友添加成功系统通知: ${friend.nickname}');
    } catch (e) {
      Logger.print('显示好友添加成功系统通知失败: $e');
    }
  }

  Future<void> _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _startForegroundService() async {
    await getAppInfo();
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'pro', 'FreeChat后台进程',
        channelDescription: '保证app能收到信息',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.startForegroundService(1, packageInfo!.appName, '正在运行...',
            notificationDetails: androidPlatformChannelSpecifics, payload: '');
  }

  Future<void> _stopForegroundService() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.stopForegroundService();
  }

  void showBadge(count) {
    OpenIM.iMManager.messageManager.setAppBadge(count);

    if (count == 0) {
      removeBadge();
    } else {
      FlutterNewBadger.setBadge(count);
    }
  }

  void removeBadge() {
    FlutterNewBadger.removeBadge();
  }

  @override
  void onClose() {
    closeSubject();
    _audioPlayer.dispose();
    super.onClose();
  }

  Locale? getLocale() {
    var index = DataSp.getLanguage() ?? 0;
    switch (index) {
      case 1:
        return const Locale('zh', 'CN');
      case 2:
        return const Locale('en', 'US');
      case 3:
        return const Locale('zh', 'HK');
      case 0:
      default:
        // 跟随系统：获取系统语言并映射到应用支持的语言
        return _getSystemMappedLocale();
    }
  }

  /// 根据系统语言获取对应的应用语言设置
  Locale _getSystemMappedLocale() {
    final systemLocale = Get.deviceLocale;
    if (systemLocale == null) {
      // 如果无法获取系统语言，默认使用中文
      return const Locale('zh', 'CN');
    }
    
    final languageCode = systemLocale.languageCode.toLowerCase();
    final countryCode = systemLocale.countryCode?.toUpperCase();
    
    // 根据系统语言映射到应用支持的语言
    if (languageCode == 'zh') {
      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        // 繁体中文地区
        return const Locale('zh', 'HK');
      } else {
        // 简体中文地区
        return const Locale('zh', 'CN');
      }
    } else if (languageCode == 'en') {
      return const Locale('en', 'US');
    } else {
      // 其他语言默认使用英文
      return const Locale('en', 'US');
    }
  }

  @override
  void onReady() {
    queryClientConfig();
    _getDeviceInfo();
    _cancelAllNotifications();
    _restoreSecurityServices();
    _initAppUpdates(); // 统一初始化更新检查
    super.onReady();
  }

  /// 统一初始化更新检查
  /// 使用UpdateService检查所有更新
  void _initAppUpdates() {
    LogUtil.i('AppController', '准备初始化应用更新检查');

    // 延迟3秒后开始更新检查，避免影响应用启动性能
    Future.delayed(const Duration(seconds: 3), () async {
      LogUtil.i('AppController', '延迟3秒后开始更新检查');

      try {
        // 使用统一的更新服务进行检查
        await _updateService.checkForUpdates(
          showNoUpdateToast: false, // 不显示无更新提示
          showUpdateDialog: true,    // 有更新时显示对话框
        );
      } catch (e, stackTrace) {
        LogUtil.e('AppController', '应用更新检查失败', e, stackTrace);
      }
    });
  }

  /// 初始化 Shorebird 热更新
  ///
  /// 延迟3秒后检查更新,避免影响应用启动性能
  /// 如果发现新版本,主动提醒用户
  void _initShorebirdAutoUpdate() {
    LogUtil.i('AppController', '准备初始化 Shorebird 热更新检查');

    Future.delayed(const Duration(seconds: 3), () {
      LogUtil.i('AppController', '延迟3秒后开始 Shorebird 更新检查');
      HotUpdateManager().checkUpdateOnStartup(
        onUpdateAvailable: (currentVersion) {
          // 发现新版本,显示更新提示对话框
          LogUtil.i('AppController', '发现新版本,当前补丁: $currentVersion');
          _showUpdateDialog(currentVersion);
        },
      );
    });
  }

  /// 显示更新提示对话框
  void _showUpdateDialog(String currentVersion) {
    LogUtil.i('AppController', '显示更新提示对话框');

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // 禁止返回键关闭
        child: AlertDialog(
          title: const Text('发现新版本'),
          content: Text(
            '检测到新的热更新补丁可用\n\n'
            '当前补丁: $currentVersion\n'
            '是否立即更新?',
          ),
          actions: [
            TextButton(
              child: const Text('稍后更新'),
              onPressed: () {
                LogUtil.i('AppController', '用户选择稍后更新');
                Get.back();
              },
            ),
            TextButton(
              child: const Text('立即更新'),
              onPressed: () {
                LogUtil.i('AppController', '用户选择立即更新');
                Get.back();
                _startUpdateProcess();
              },
            ),
          ],
        ),
      ),
      barrierDismissible: false, // 禁止点击外部关闭
    );
  }

  /// 开始更新流程 (不可中断)
  Future<void> _startUpdateProcess() async {
    // 防止重复触发
    if (_isProcessingUpdate) {
      LogUtil.w('AppController', '更新流程已在进行中,忽略重复调用');
      return;
    }

    _isProcessingUpdate = true;
    LogUtil.i('AppController', '开始更新流程');

    try {
      // 显示不可取消的下载对话框
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // 禁止返回键
          child: const AlertDialog(
            title: Text('正在更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载更新补丁,请稍候...'),
              ],
            ),
          ),
        ),
        barrierDismissible: false, // 禁止点击外部关闭
      );

      // 下载补丁
      final success = await HotUpdateManager().downloadUpdateWithProgress();

      // 关闭下载对话框
      Get.back();

      if (success) {
        LogUtil.i('AppController', '补丁下载成功,显示重启对话框');
        // 下载成功,显示强制重启对话框
        _showRestartDialog();
      } else {
        LogUtil.e('AppController', '补丁下载失败');
        // 下载失败,提示用户
        IMViews.showToast('更新下载失败,请稍后重试');
      }
    } finally {
      _isProcessingUpdate = false;
    }
  }

  /// 显示强制重启对话框 (只有一个按钮)
  void _showRestartDialog() {
    LogUtil.i('AppController', '显示强制重启对话框');

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // 禁止返回键
        child: AlertDialog(
          title: const Text('更新完成'),
          content: const Text(
            '热更新补丁已下载完成\n'
            '需要重新启动应用才能应用更新\n'
            '点击立即重启后应用将自动关闭',
          ),
          actions: [
            TextButton(
              child: const Text('立即重启'),
              onPressed: () {
                LogUtil.i('AppController', '用户点击立即重启');
                _restartApp();
              },
            ),
          ],
        ),
      ),
      barrierDismissible: false, // 禁止点击外部关闭
    );
  }

  /// 重启应用
  void _restartApp() {
    LogUtil.i('AppController', '准备重启应用');

    if (Platform.isAndroid) {
      // Android: 直接退出应用
      LogUtil.i('AppController', 'Android 平台,调用 SystemNavigator.pop() 退出应用');
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      // iOS: 苹果不允许程序自杀,提示用户手动关闭
      LogUtil.i('AppController', 'iOS 平台,提示用户手动重启');
      Get.back();
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // 禁止返回键
          child: AlertDialog(
            title: const Text('请手动重启应用'),
            content: const Text(
              '由于iOS系统限制，应用无法自动关闭\n'
              '请按Home键退出，然后重新打开应用以完成更新'
            ),
            actions: [
              TextButton(
                child: const Text('知道了'),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ),
        barrierDismissible: false, // 禁止点击外部关闭
      );
    }
  }

  bool _isGlobalNotDisturb() {
    bool isRegistered = Get.isRegistered<IMController>();
    if (isRegistered) {
      var logic = Get.find<IMController>();
      return logic.userInfo.value.globalRecvMsgOpt == 2;
    }
    return false;
  }

  void _initPlayer() async {
    // 使用统一的音频会话管理器获取通知音频会话
    session = await _audioSessionManager.getNotificationAudioSession();

    _audioPlayer.setAsset(_ring, package: 'openim_common');
    _audioPlayer.playerStateStream.listen((state) {
      switch (state.processingState) {
        case ProcessingState.idle:
        case ProcessingState.loading:
        case ProcessingState.buffering:
        case ProcessingState.ready:
          break;
        case ProcessingState.completed:
          _stopMessageSound();

          break;
      }
    });
  }

  /// 公开方法：播放消息声音（供好友申请等系统通知使用）
  void playMessageSound() async {
    _playMessageSound();
  }

  void _playMessageSound() async {
    if (shouldMuted) {
      return;
    }
    bool isRegistered = Get.isRegistered<IMController>();
    bool isAllowVibration = true;
    bool isAllowBeep = true;
    if (isRegistered) {
      var logic = Get.find<IMController>();
      isAllowVibration = logic.userInfo.value.allowVibration == 1;
      isAllowBeep = logic.userInfo.value.allowBeep == 1;
    }

    RingerModeStatus ringerStatus = await SoundMode.ringerModeStatus;

    Logger.print(
        'System ringer status: $ringerStatus, user is allow beep: $isAllowBeep',
        fileName: 'app_controller.dart');

    if (!_audioPlayer.playerState.playing &&
        isAllowBeep &&
        (ringerStatus == RingerModeStatus.normal ||
            ringerStatus == RingerModeStatus.unknown)) {
      await _audioSessionManager.setActive(true);
      _audioPlayer.setAsset(_ring, package: 'openim_common');
      _audioPlayer.setLoopMode(LoopMode.off);
      _audioPlayer.setVolume(1.0);
      _audioPlayer.play();
    }

    if (isAllowVibration &&
        (ringerStatus == RingerModeStatus.normal ||
            ringerStatus == RingerModeStatus.vibrate ||
            ringerStatus == RingerModeStatus.unknown)) {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate();
      }
    }
  }

  void _stopMessageSound() async {
    if (_audioPlayer.playerState.playing) {
      _audioPlayer.stop();
    }
    await _audioSessionManager.setActive(false);
  }

  void _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    deviceInfo = await deviceInfoPlugin.deviceInfo;
  }

  Future queryClientConfig() async {
    final map = await Apis.getClientConfig();
    clientConfigMap.assignAll(map);

    return clientConfigMap;
  }

  // 恢复安全服务
  void _restoreSecurityServices() async {
    try {
      final securityManager = SecurityManager();
      final result = await securityManager.checkAndRestoreKeys();
      if (result) {
        LogUtil.i('AppController', '安全服务恢复成功');
      } else {
        LogUtil.w('AppController', '未找到安全密钥或恢复失败');

        // 尝试重新初始化安全服务
        final initResult = await securityManager.initAfterLogin();
        if (initResult) {
          LogUtil.i('AppController', '安全服务重新初始化成功');
        } else {
          LogUtil.e('AppController', '安全服务重新初始化失败');
        }
      }
    } catch (e) {
      LogUtil.e('AppController', '恢复安全服务失败: $e');
    }
  }
}
