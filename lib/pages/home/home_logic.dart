import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/utils/user_util.dart';
import 'package:openim_common/openim_common.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';
import '../../widgets/screen_lock_title.dart';
import '../../utils/log_util.dart';
import 'package:openim_common/openim_common.dart' show Apis;
import '../../core/data_sp.dart' as app_sp;
import '../../core/api_service.dart' as app_api;

class HomeLogic extends SuperController {
  final pushLogic = Get.find<PushController>();
  final imLogic = Get.find<IMController>();
  final cacheLogic = Get.find<CacheController>();
  final initLogic = Get.find<AppController>();
  final index = 0.obs;
  final unreadMsgCount = 0.obs;
  final unhandledFriendApplicationCount = 0.obs;
  final unhandledGroupApplicationCount = 0.obs;
  final unhandledCount = 0.obs;
  String? _lockScreenPwd;
  bool _isShowScreenLock = false;
  bool? _isAutoLogin;
  final auth = LocalAuthentication();
  final _errorController = PublishSubject<String>();
  var conversationsAtFirstPage = <ConversationInfo>[];

  switchTab(index) {
    this.index.value = index;
  }


  void getUnhandledFriendApplicationCount() async {
    var i = 0;
    var list = await OpenIM.iMManager.friendshipManager.getFriendApplicationListAsRecipient();
    var haveReadList = DataSp.getHaveReadUnHandleFriendApplication();
    haveReadList ??= <String>[];
    for (var info in list) {
      var id = IMUtils.buildFriendApplicationID(info);
      if (!haveReadList.contains(id)) {
        if (info.handleResult == 0) i++;
      }
    }
    unhandledFriendApplicationCount.value = i;
    unhandledCount.value = unhandledGroupApplicationCount.value + i;
  }

  void getUnhandledGroupApplicationCount() async {
    var i = 0;
    var list = await OpenIM.iMManager.groupManager.getGroupApplicationListAsRecipient();
    var haveReadList = DataSp.getHaveReadUnHandleGroupApplication();
    haveReadList ??= <String>[];
    for (var info in list) {
      var id = IMUtils.buildGroupApplicationID(info);
      if (!haveReadList.contains(id)) {
        if (info.handleResult == 0) i++;
      }
    }
    unhandledGroupApplicationCount.value = i;
    unhandledCount.value = unhandledFriendApplicationCount.value + i;
  }

  @override
  void onInit() {
    _isAutoLogin = Get.arguments != null ? Get.arguments['isAutoLogin'] : false;
    if (_isAutoLogin == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLockScreenPwd());
    }
    if (Get.arguments != null) {
      conversationsAtFirstPage = Get.arguments['conversations'] ?? [];
    }
    imLogic.unreadMsgCountEventSubject.listen((value) {
      unreadMsgCount.value = value;
    });
    imLogic.friendApplicationChangedSubject.listen((value) {
      getUnhandledFriendApplicationCount();
    });
    imLogic.groupApplicationChangedSubject.listen((value) {
      getUnhandledGroupApplicationCount();
    });

    imLogic.imSdkStatusPublishSubject.listen((value) {
      if (value.status == IMSdkStatus.syncStart) {
        _getRTCInvitationStart();
      } else if (value.status == IMSdkStatus.syncEnded) {
        // dawn 2026-05-14 修复好友/群通知离线无红点：SDK 同步完成后主动重算申请未处理数量。
        getUnhandledFriendApplicationCount();
        getUnhandledGroupApplicationCount();
      }
    });

    Apis.kickoffController.stream.listen((event) {
      UserUtil.logout();
    });
    super.onInit();
  }

  @override
  void onReady() {
    _getRTCInvitationStart();
    // Removed _getUnreadMsgCount() to avoid data race
    // The unreadMsgCount will be updated via imLogic.unreadMsgCountEventSubject listener
    getUnhandledFriendApplicationCount();
    getUnhandledGroupApplicationCount();
    cacheLogic.initCallRecords();
    checkWalletStatus();
    requestNotificationPermission();
    super.onReady();
  }

  @override
  void onClose() {
    _errorController.close();
    super.onClose();
  }

  _localAuth() async {
    final didAuthenticate = await IMUtils.checkingBiometric(auth);
    if (didAuthenticate) {
      Get.back();
    }
  }

  _showLockScreenPwd() async {
    if (_isShowScreenLock) return;
    _lockScreenPwd = DataSp.getLockScreenPassword();
    if (null != _lockScreenPwd) {
      final isEnabledBiometric = DataSp.isEnabledBiometric() == true;
      bool enabled = false;
      if (isEnabledBiometric) {
        final isSupportedBiometrics = await auth.isDeviceSupported();
        final canCheckBiometrics = await auth.canCheckBiometrics;
        enabled = isSupportedBiometrics && canCheckBiometrics;
      }
      _isShowScreenLock = true;
      screenLock(
        context: Get.context!,
        correctString: _lockScreenPwd!,
        maxRetries: 3,
        title: ScreenLockTitle(stream: _errorController.stream),
        canCancel: false,
        customizedButtonChild: enabled ? const Icon(Icons.fingerprint) : null,
        customizedButtonTap: enabled ? () async => await _localAuth() : null,
        onUnlocked: () {
          _isShowScreenLock = false;
          Get.back();
        },
        onMaxRetries: (_) async {
          Get.back();
          await LoadingView.singleton.wrap(asyncFunction: () async {
            await DataSp.clearLockScreenPassword();
            await DataSp.closeBiometric();
            UserUtil.logout();
          });
          AppNavigator.startLogin();
        },
        onError: (retries) {
          _errorController.sink.add(
            retries.toString(),
          );
        },
      );
    }
  }

  @override
  void onDetached() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {
    /// 应用切到前台更新下用户权限
    final orgController = Get.find<OrgController>();
    orgController.refreshOrg();
  }

  void _getRTCInvitationStart() async {}

  @override
  void onHidden() {}

  /// 检查钱包是否开通
  Future<void> checkWalletStatus() async {
    try {
     
      final apiService = app_api.ApiService();
      final exist = await apiService.checkWalletExist();
     
      // 更新本地存储的钱包状态
      await app_sp.DataSp.putWalletStatus(exist);
    } catch (e) {
      LogUtil.e('HomeLogic', '检查钱包状态失败: $e');
    }
  }

  /// 请求通知权限
  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      // 请求权限
      var result = await Permission.notification.request();
      if (result.isGranted) {
        print("通知权限已授权");
      } else {
        print("通知权限被拒绝");
      }
    } else {
      print("通知权限已授权");
    }
  }
}
