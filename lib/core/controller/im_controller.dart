import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/utils/cache_clear_util.dart';
import 'package:openim/utils/user_util.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/openim_live.dart';
import 'package:rxdart/transformers.dart';

import '../im_callback.dart';
import '../transaction_sync_service.dart';
import 'app_controller.dart';

class IMController extends GetxController with IMCallback, OpenIMLive {
  late Rx<UserFullInfo> userInfo;
  late String atAllTag;

  /// 上次因「消息过大」触发自动恢复的时间，用于限频（如 60 秒内只触发一次）
  static DateTime? _lastMessageTooLargeRecoveryAt;

  @override
  void onClose() {
    super.close();
    onCloseLive();
    super.onClose();
  }

  @override
  void onInit() async {
    super.onInit();
    onInitLive();

    // 初始化通知账号控制器
    Get.put(NotificationAccountController());

    // 设置通话通知回调
    onShowCallNotification = _showCallNotificationImpl;

    WidgetsBinding.instance.addPostFrameCallback((_) => initOpenIM());
    // 监听下线监听
    onKickedOfflineSubject.stream
        .distinct()
        .debounceTime(const Duration(milliseconds: 3000))
        .listen((value) {
      if (value == KickoffType.userTokenInvalid) {
        handleKickedOffline(tips: StrRes.tokenInvalid);
      } else {
        handleKickedOffline();
      }
    });
  }

  /// 检测「消息过大」等导致的连接失败，自动清空缓存并重连（限频）
  void _tryRecoverFromMessageTooLarge(dynamic error) {
    if (error == null) return;
    final errStr = error.toString().toLowerCase();
    final isMessageTooLarge = errStr.contains('message') &&
        (errStr.contains('websocket: read limit exceeded') || errStr.contains('read limit exceeded'));
    if (!isMessageTooLarge) return;
    final now = DateTime.now();
    if (_lastMessageTooLargeRecoveryAt != null &&
        now.difference(_lastMessageTooLargeRecoveryAt!).inSeconds < 60) {
      return;
    }
    _lastMessageTooLargeRecoveryAt = now;
    Future.microtask(() async {
      try {
        // 深度清空（含 IM 数据目录），与安卓「清除数据」效果一致，可彻底缓解 read limit exceeded
        await CacheClearUtil.clearAppCache(includeImDataDir: true);
        IMViews.showToast(StrRes.messageTooLargeRecovered);
        final cert = DataSp.getLoginCertificate();
        if (cert != null && cert.imToken.isNotEmpty) {
          await login(cert.userID, cert.imToken);
        }
      } catch (e) {
        Logger.print('[IMController] message too large 自动恢复失败: $e');
      }
    });
  }

  void handleKickedOffline({String? tips}) async {
    if (EasyLoading.isShow) {
      EasyLoading.dismiss();
    }
    Get.snackbar(StrRes.accountWarn, tips ?? StrRes.accountException);
    UserUtil.logout();
  }

  void initOpenIM() async {
    print('初始化OpenIM SDK...');
    print('使用API地址: ${Config.imApiUrl}');
    print('使用WebSocket地址: ${Config.imWsUrl}');

    final initialized = await OpenIM.iMManager.initSDK(
      platformID: IMUtils.getPlatform(),
      apiAddr: Config.imApiUrl,
      wsAddr: Config.imWsUrl,
      dataDir: Config.cachePath,
      logLevel: Config.logLevel,
      logFilePath: Config.cachePath,
      listener: OnConnectListener(
        onConnecting: () {
          print('======================================');
          print('[IMController] 🔌 WebSocket连接中...');
          print('======================================');
          imSdkStatus(IMSdkStatus.connecting);
        },
        onConnectFailed: (code, error) {
          print('======================================');
          print('[IMController] ❌ WebSocket连接失败');
          print('[IMController] code=$code, error=$error');
          print('======================================');
          imSdkStatus(IMSdkStatus.connectionFailed);
          _tryRecoverFromMessageTooLarge(error);
        },
        onConnectSuccess: () {
          print('======================================');
          print('[IMController] ✅ WebSocket连接成功');
          print('======================================');
          imSdkStatus(IMSdkStatus.connectionSucceeded);
        },
        onKickedOffline: kickedOffline,
        onUserTokenExpired: kickedOffline,
        onUserTokenInvalid: userTokenInvalid,
      ),
    );

    await _setupListenersSafe();

    if (initialized) {
      print('OpenIM SDK初始化成功');
    } else {
      print('OpenIM SDK初始化失败');
    }

    initializedSubject.sink.add(initialized);
  }

  /// 安全设置监听器：若遇 10006(sdk not init) 则延迟后重试一次
  Future<void> _setupListenersSafe() async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        _setupListeners();
        return;
      } on PlatformException catch (e) {
        if (e.code == '10006' && attempt == 0) {
          print('[IMController] 监听器设置遇 10006，400ms 后重试');
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
        rethrow;
      }
    }
  }

  /// 设置各种监听器
  void _setupListeners() {
    print('[IMController] 开始设置监听器...');
    OpenIM.iMManager
      ..setUploadLogsListener(
          OnUploadLogsListener(onUploadProgress: uploadLogsProgress))
      ..userManager.setUserListener(OnUserListener(
          onSelfInfoUpdated: (u) {
            selfInfoUpdated(u);

            userInfo.update((val) {
              val?.nickname = u.nickname;
              val?.faceURL = u.faceURL;

              val?.remark = u.remark;
              val?.ex = u.ex;
              val?.globalRecvMsgOpt = u.globalRecvMsgOpt;
            });
          },
          onUserStatusChanged: userStausChanged))
      ..messageManager.setAdvancedMsgListener(OnAdvancedMsgListener(
        onRecvC2CReadReceipt: recvC2CMessageReadReceipt,
        onRecvNewMessage: (msg) {
          print('============================================');
          print('[IMController] 🔔 收到新消息');
          print('[IMController] contentType=${msg.contentType}');
          print('[IMController] sendID=${msg.sendID}');
          print('[IMController] recvID=${msg.recvID}');
          print('[IMController] clientMsgID=${msg.clientMsgID}');
          print('============================================');
          recvNewMessage(msg);
        },
        onNewRecvMessageRevoked: recvMessageRevoked,
        onRecvOfflineNewMessage: (msg) {
          print('============================================');
          print('[IMController] 🔔 收到离线消息');
          print('[IMController] contentType=${msg.contentType}');
          print('[IMController] sendID=${msg.sendID}');
          print('[IMController] recvID=${msg.recvID}');
          print('[IMController] clientMsgID=${msg.clientMsgID}');

          // 打印自定义消息的 customType
          if (msg.contentType == 110 && msg.customElem != null) {
            try {
              final data = jsonDecode(msg.customElem!.data!);
              print('[IMController] 📋 customType=${data['customType']}');
              print('[IMController] 📋 data=${data['data']}');
            } catch (e) {
              print('[IMController] ❌ 解析 customElem 失败: $e');
            }
          }

          print('============================================');
          recvOfflineMessage(msg);
        },
        onRecvOnlineOnlyMessage: (msg) {
          print('============================================');
          print('[IMController] 🔔 收到仅在线消息 (OnlineOnly)');
          print('[IMController] contentType=${msg.contentType}');
          print('[IMController] sendID=${msg.sendID}');
          print('[IMController] recvID=${msg.recvID}');
          print('============================================');

          if (msg.isCustomType) {
            final data = msg.customElem!.data;
            final map = jsonDecode(data!);
            final customType = map['customType'];
            print('[IMController] 自定义消息类型: customType=$customType');

            if (customType == CustomMessageType.callingInvite ||
                customType == CustomMessageType.callingAccept ||
                customType == CustomMessageType.callingReject ||
                customType == CustomMessageType.callingCancel ||
                customType == CustomMessageType.callingHungup ||
                customType == CustomMessageType.syncCallStatus) {
              final signaling = SignalingInfo(
                  invitation: InvitationInfo.fromJson(map['data']));
              signaling.userID = signaling.invitation?.inviterUserID;

              switch (customType) {
                case CustomMessageType.callingInvite:
                  print('[IMController] 🎯 处理通话邀请信令 (OnlineOnly)');
                  receiveNewInvitation(signaling);
                  break;
                case CustomMessageType.callingAccept:
                  print('[IMController] 处理通话接受信令 (OnlineOnly)');
                  inviteeAccepted(signaling);
                  break;
                case CustomMessageType.callingReject:
                  print('[IMController] 处理通话拒绝信令 (OnlineOnly)');
                  inviteeRejected(signaling);
                  break;
                case CustomMessageType.callingCancel:
                  print('[IMController] 处理通话取消信令 (OnlineOnly)');
                  invitationCancelled(signaling);
                  break;
                case CustomMessageType.callingHungup:
                  print('[IMController] 处理通话挂断信令 (OnlineOnly)');
                  beHangup(signaling);
                  break;
                case CustomMessageType.syncCallStatus:
                  print('[IMController] 处理同步通话状态信令 (OnlineOnly)');
                  syncCall(msg);
                  break;
              }
            } else if (customType == CustomMessageType.infoChange) {
              final viewType = map['viewType'];
              final orgController = Get.find<OrgController>();
              switch (viewType) {
                case InfoChangeViewType.orgRole:
                  orgController.refreshOrg();
                  break;
                case InfoChangeViewType.rolePermission:
                  orgController.refreshRules();
                  break;
                case InfoChangeViewType.userInfo:
                  _queryMyFullInfo();
                  break;
                default:
                  Logger.print('未知的自定义信息变更类型: $viewType');
              }
            }
          }
        },
      ))
      ..messageManager.setMsgSendProgressListener(OnMsgSendProgressListener(
        onProgress: progressCallback,
      ))
      ..messageManager.setCustomBusinessListener(OnCustomBusinessListener(
        onRecvCustomBusinessMessage: recvCustomBusinessMessage,
      ))
      ..friendshipManager.setFriendshipListener(OnFriendshipListener(
        onBlackAdded: blacklistAdded,
        onBlackDeleted: blacklistDeleted,
        onFriendApplicationAccepted: friendApplicationAccepted,
        onFriendApplicationAdded: (u) {
          print('[IMController] 好友监听器触发: friendApplicationAdded');
          friendApplicationAdded(u);
        },
        onFriendApplicationDeleted: friendApplicationDeleted,
        onFriendApplicationRejected: friendApplicationRejected,
        onFriendInfoChanged: friendInfoChanged,
        onFriendAdded: (info) {
          print('[IMController] ✅ 好友添加成功: ${info.userID}');
          friendAdded(info);
        },
        onFriendDeleted: friendDeleted,
      ))
      ..conversationManager.setConversationListener(OnConversationListener(
          onConversationChanged: (list) {
            print('[IMController] 🔔 会话变更: ${list.length} 个会话');
            for (var conv in list) {
              print('[IMController]   - ${conv.conversationID}, latestMsgType=${conv.latestMsg?.contentType}');
            }
            conversationChanged(list);
          },
          onNewConversation: (list) {
            print('[IMController] 🔔 新会话: ${list.length} 个');
            for (var conv in list) {
              print('[IMController]   - ${conv.conversationID}, latestMsgType=${conv.latestMsg?.contentType}');
            }
            newConversation(list);
          },
          onTotalUnreadMessageCountChanged: totalUnreadMsgCountChanged,
          onInputStatusChanged: inputStateChanged,
          onSyncServerFailed: (reInstall) {
            imSdkStatus(IMSdkStatus.syncFailed, reInstall: reInstall ?? false);
          },
          onSyncServerFinish: (reInstall) {
            imSdkStatus(IMSdkStatus.syncEnded, reInstall: reInstall ?? false);
            // if (Platform.isAndroid) {
            //   Permissions.request([Permission.systemAlertWindow]);
            // }
          },
          onSyncServerStart: (reInstall) {
            imSdkStatus(IMSdkStatus.syncStart, reInstall: reInstall ?? false);
          },
          onSyncServerProgress: (progress) {
            imSdkStatus(IMSdkStatus.syncProgress, progress: progress);
          }))
      ..groupManager.setGroupListener(OnGroupListener(
        onGroupApplicationAccepted: groupApplicationAccepted,
        onGroupApplicationAdded: groupApplicationAdded,
        onGroupApplicationDeleted: groupApplicationDeleted,
        onGroupApplicationRejected: groupApplicationRejected,
        onGroupInfoChanged: groupInfoChanged,
        onGroupMemberAdded: groupMemberAdded,
        onGroupMemberDeleted: groupMemberDeleted,
        onGroupMemberInfoChanged: groupMemberInfoChanged,
        onJoinedGroupAdded: joinedGroupAdded,
        onJoinedGroupDeleted: joinedGroupDeleted,
      ));
    print('[IMController] 监听器设置完成');
  }

  Future login(String userID, String token) async {
    try {
      var user = await OpenIM.iMManager.login(
        userID: userID,
        token: token,
        defaultValue: () async => UserInfo(userID: userID),
      );
      ApiService().setToken(token);
      userInfo = UserFullInfo.fromJson(user.toJson()).obs;
      _queryMyFullInfo();
      _queryAtAllTag();
      _initTransactionHistory();
    } catch (e, s) {
      Logger.print('e: $e  s:$s');
      await _handleLoginRepeatError(e);

      return Future.error(e, s);
    }
  }

  Future logout() async {
    try {
      final status = await OpenIM.iMManager.getLoginStatus();
      if (status == 1) {
        return true;
      }
      return OpenIM.iMManager.logout();
    } on PlatformException catch (e) {
      if (e.code == '10006') return true;
      rethrow;
    }
  }

  void _queryAtAllTag() async {
    atAllTag = OpenIM.iMManager.conversationManager.atAllTag;
  }

  void _queryMyFullInfo() async {
    final data = await Apis.queryMyFullInfo();
    if (data is UserFullInfo) {
      userInfo.update((val) {
        val?.allowAddFriend = data.allowAddFriend;
        val?.allowBeep = data.allowBeep;
        val?.allowVibration = data.allowVibration;
        val?.nickname = data.nickname;
        val?.faceURL = data.faceURL;
        val?.points = data.points;
        val?.phoneNumber = data.phoneNumber;
        val?.email = data.email;
        val?.birth = data.birth;
        val?.gender = data.gender;
        val?.canSendFreeMsg = data.canSendFreeMsg;
      });
    }
  }

  /// 初始化交易历史记录（包括转账和红包）
  void _initTransactionHistory() async {
    try {
      // 使用新的同步服务
      await TransactionSyncService.to.forceSync();
      Logger.print('初始化交易历史记录完成');
    } catch (e) {
      Logger.print('初始化交易历史记录失败: $e');
    }
  }

  _handleLoginRepeatError(e) async {
    if (e is PlatformException && (e.code == "13002" || e.code == '1507')) {
      await logout();
      await DataSp.removeLoginCertificate();
    }
  }

  /// 显示通话系统通知的实现
  Future<void> _showCallNotificationImpl(String title, String body, String payload) async {
    try {
      Logger.print('[IMController] 准备显示通话通知');
      Logger.print('[IMController] title=$title, body=$body');

      // 获取 AppController
      final appController = Get.find<AppController>();

      // 配置通知
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'call_channel', // 使用独立的通话通道
        'Incoming Call',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        ticker: 'Incoming Call',
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.call, // 标记为通话类型
        fullScreenIntent: true, // 全屏意图，可以在锁屏上显示
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      // 使用时间戳作为通知ID，确保每次都是新通知
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await appController.flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      Logger.print('[IMController] ✅ 通话通知已显示');
    } catch (e, stackTrace) {
      Logger.print('[IMController] ❌ 显示通话通知失败: $e');
      Logger.print('[IMController] 堆栈: $stackTrace');
    }
  }
}
