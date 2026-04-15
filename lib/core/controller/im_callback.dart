import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/openim_live.dart';
import 'package:rxdart/rxdart.dart';

import 'app_controller.dart';

enum IMSdkStatus {
  connectionFailed,
  connecting,
  connectionSucceeded,
  syncStart,
  synchronizing,
  syncEnded,
  syncFailed,
  syncProgress,
}

enum KickoffType {
  kickedOffline,
  userTokenInvalid,
  userTokenExpired,
}

mixin IMCallback {
  final initLogic = Get.find<AppController>();

  Function(RevokedInfo info)? onRecvMessageRevoked;

  Function(List<ReadReceiptInfo> list)? onRecvC2CReadReceipt;

  Function(Message msg)? onRecvNewMessage;

  Function(Message msg)? onRecvOfflineMessage;

  // 新增：消息Subject，用于向所有订阅者广播新消息
  final newMessageSubject = PublishSubject<Message>();

  /// 已读回执广播，供各会话页订阅以实现实时已读同步（不依赖当前打开的会话）
  final c2cReadReceiptSubject = PublishSubject<List<ReadReceiptInfo>>();

  /// 待应用的已读回执（key=对方 userID），进入会话时应用并清空，避免切会话时丢失
  final Map<String, List<ReadReceiptInfo>> _pendingC2CReadReceipts = {};

  List<ReadReceiptInfo> getPendingReadReceiptsForUser(String? userID) =>
      List<ReadReceiptInfo>.from(_pendingC2CReadReceipts[userID ?? ''] ?? []);

  void clearPendingReadReceiptsForUser(String? userID) {
    _pendingC2CReadReceipts.remove(userID);
  }

  Function(String msgId, int progress)? onMsgSendProgress;

  Function(BlacklistInfo u)? onBlacklistAdd;

  Function(BlacklistInfo u)? onBlacklistDeleted;

  Function(int current, int size)? onUploadProgress;

  final conversationAddedSubject = BehaviorSubject<List<ConversationInfo>>();

  final conversationChangedSubject = BehaviorSubject<List<ConversationInfo>>();

  final unreadMsgCountEventSubject = PublishSubject<int>();

  final friendApplicationChangedSubject = BehaviorSubject<FriendApplicationInfo>();

  final friendAddSubject = BehaviorSubject<FriendInfo>();

  final friendDelSubject = BehaviorSubject<FriendInfo>();

  final friendInfoChangedSubject = PublishSubject<FriendInfo>();

  final selfInfoUpdatedSubject = BehaviorSubject<UserInfo>();

  final userStatusChangedSubject = BehaviorSubject<UserStatusInfo>();

  final groupInfoUpdatedSubject = BehaviorSubject<GroupInfo>();

  final groupApplicationChangedSubject = BehaviorSubject<GroupApplicationInfo>();

  final initializedSubject = PublishSubject<bool>();

  final memberAddedSubject = BehaviorSubject<GroupMembersInfo>();

  final memberDeletedSubject = BehaviorSubject<GroupMembersInfo>();

  final memberInfoChangedSubject = PublishSubject<GroupMembersInfo>();

  final joinedGroupDeletedSubject = BehaviorSubject<GroupInfo>();

  final joinedGroupAddedSubject = BehaviorSubject<GroupInfo>();

  final onKickedOfflineSubject = PublishSubject<KickoffType>();

  final imSdkStatusSubject = ReplaySubject<({IMSdkStatus status, bool reInstall, int? progress})>();

  final imSdkStatusPublishSubject = PublishSubject<({IMSdkStatus status, bool reInstall, int? progress})>();

  final inputStateChangedSubject = PublishSubject<InputStatusChangedData>();

  void imSdkStatus(IMSdkStatus status, {bool reInstall = false, int? progress}) {
    imSdkStatusSubject.add((status: status, reInstall: reInstall, progress: progress));
    imSdkStatusPublishSubject.add((status: status, reInstall: reInstall, progress: progress));
  }

  void kickedOffline() {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    print('[IMCallback] ⚠️ 被踢下线！kickedOffline回调被触发');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Logger.print('[IMCallback] 被踢下线：kickedOffline');
    onKickedOfflineSubject.add(KickoffType.kickedOffline);
  }

  void userTokenInvalid() {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    print('[IMCallback] ⚠️ Token失效！userTokenInvalid回调被触发');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Logger.print('[IMCallback] Token失效：userTokenInvalid');
    onKickedOfflineSubject.add(KickoffType.userTokenInvalid);
  }

  void selfInfoUpdated(UserInfo u) {
    selfInfoUpdatedSubject.addSafely(u);
  }

  void userStausChanged(UserStatusInfo u) {
    userStatusChangedSubject.addSafely(u);
  }

  void uploadLogsProgress(int current, int size) {
    onUploadProgress?.call(current, size);
  }

  void recvMessageRevoked(RevokedInfo info) {
    onRecvMessageRevoked?.call(info);
  }

  void recvC2CMessageReadReceipt(List<ReadReceiptInfo> list) {
    if (list.isNotEmpty) {
      print('[IMController] 📬 收到已读回执: ${list.length} 条, userIDs=${list.map((r) => r.userID).toList()}, msgIDList长度=${list.map((r) => r.msgIDList?.length ?? 0).toList()}');
    }
    for (var r in list) {
      final key = r.userID ?? '';
      if (key.isEmpty) continue;
      _pendingC2CReadReceipts[key] = [...(_pendingC2CReadReceipts[key] ?? []), r];
    }
    c2cReadReceiptSubject.add(list);
    onRecvC2CReadReceipt?.call(list);
  }

  void recvNewMessage(Message msg) {
    Logger.print('[IMCallback] ===== recvNewMessage START =====');
    Logger.print('[IMCallback] contentType=${msg.contentType}, sendID=${msg.sendID}, recvID=${msg.recvID}');
    Logger.print('[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');

    final currentUserID = OpenIM.iMManager.userID;
    final isSentByMe = msg.sendID == currentUserID;

    print('[IMCallback] 消息接收详情:');
    print('[IMCallback]   currentUserID=$currentUserID');
    print('[IMCallback]   msg.sendID=${msg.sendID}');
    print('[IMCallback]   msg.recvID=${msg.recvID}');
    print('[IMCallback]   isSentByMe=$isSentByMe');

    // 处理通话信令消息 (contentType=110, customType=200-204)
    // 注意：通话信令消息需要特殊处理，不应该被添加到聊天列表
    if (msg.contentType == 110 && msg.customElem != null) {
      try {
        final data = jsonDecode(msg.customElem!.data!);
        final customType = data['customType'];
        Logger.print('[IMCallback] 检测到自定义消息，customType=$customType');

        // 处理通话信令消息（模拟 onRecvOnlineOnlyMessage 的行为）
        if (customType == 200 || customType == 201 || customType == 202 ||
            customType == 203 || customType == 204 || customType == 2005) {
          Logger.print('[IMCallback] ✅ 检测到通话信令消息(customType=$customType)');
          Logger.print('[IMCallback] 准备手动触发通话信令处理...');

          final signaling = SignalingInfo(
              invitation: InvitationInfo.fromJson(data['data']));
          signaling.userID = signaling.invitation?.inviterUserID;

          switch (customType) {
            case 200: // callingInvite
              Logger.print('[IMCallback] 🎯 处理通话邀请信令(callingInvite)');
              (this as dynamic).receiveNewInvitation(signaling);
              break;
            case 201: // callingAccept
              Logger.print('[IMCallback] 处理通话接受信令(callingAccept)');
              (this as dynamic).inviteeAccepted(signaling);
              break;
            case 202: // callingReject
              Logger.print('[IMCallback] 处理通话拒绝信令(callingReject)');
              (this as dynamic).inviteeRejected(signaling);
              break;
            case 203: // callingCancel
              Logger.print('[IMCallback] 处理通话取消信令(callingCancel)');
              (this as dynamic).invitationCancelled(signaling);
              break;
            case 204: // callingHungup
              Logger.print('[IMCallback] 处理通话挂断信令(callingHungup)');
              (this as dynamic).beHangup(signaling);
              break;
            case 2005: // syncCallStatus
              Logger.print('[IMCallback] 处理同步通话状态信令(syncCallStatus)');
              (this as dynamic).syncCall(msg);
              break;
          }

          // 注意：这里不return，让消息继续传递给其他处理器
          // 但在 chat_logic.dart 中会被过滤掉，不会添加到聊天列表
        }
        // 处理通话记录消息 (customType=901)
        else if (customType == 901) {
          print('[IMCallback] 📞 检测到通话记录消息(customType=901)');
          final callData = data['data'];
          final state = callData['state'];
          final type = callData['type'];
          print('[IMCallback] 通话记录: state=$state, type=$type');

          // 如果是取消状态，需要停止响铃并清除来电事件
          if (state == 'cancel' || state == 'beCanceled') {
            print('[IMCallback] 🚫 检测到通话取消记录，调用 handleCallCanceled');

            try {
              // 直接调用 handleCallCanceled 方法
              // 这个方法会停止声音、清除缓存、关闭UI，但不会插入消息记录
              final controller = this as dynamic;
              controller.handleCallCanceled();
              print('[IMCallback] ✅ 已调用 handleCallCanceled');
            } catch (e, stackTrace) {
              print('[IMCallback] ⚠️ 调用 handleCallCanceled 失败: $e');
              print('[IMCallback] 堆栈: $stackTrace');
            }
          }
        }
      } catch (e, stackTrace) {
        Logger.print('[IMCallback] ❌ 处理通话信令消息失败: $e');
        Logger.print('[IMCallback] ❌ 堆栈: $stackTrace');
      }
    }

    // 处理好友申请通知 (contentType=1203)
    // 由于SDK没有正确触发friendListener，我们手动处理
    // 重要：只处理别人发给我的申请，不处理我发出的申请
    if (msg.contentType == 1203) {
      Logger.print('[IMCallback] 检测到好友申请通知(1203)');
      Logger.print('[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        Logger.print('[IMCallback] ✅ 这是别人发给我的好友申请，触发通知');
        _handleFriendApplicationNotification();
        Logger.print('[IMCallback] ✅ 好友申请处理完成');
      } else {
        Logger.print('[IMCallback] ⚠️ 这是我发出的好友申请，不触发通知');
      }
    }
    // 处理好友申请通过通知 (contentType=1201)
    // 当对方通过我的好友申请时，自动发送验证消息并创建会话
    else if (msg.contentType == 1201) {
      print('========== 收到1201通知(好友申请通过) ==========');
      print('[IMCallback] sendID=${msg.sendID}, currentUserID=$currentUserID');
      Logger.print('[IMCallback] 检测到好友申请通过通知(1201)');
      Logger.print('[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 这是对方通过了我的申请');
        Logger.print('[IMCallback] ✅ 对方通过了我的好友申请，准备处理');
        _handleFriendApplicationApproved(msg.sendID!);
        _showFriendApprovedNotification(msg.sendID!);  // 新增：显示通知
      } else {
        print('[IMCallback] ⚠️ 这是我通过的申请,忽略');
        Logger.print('[IMCallback] ⚠️ 这是我通过的好友申请，不需要处理');
      }
    }
    // 处理好友添加成功通知 (contentType=1204)
    else if (msg.contentType == 1204) {
      print('========== 收到1204通知(好友添加成功) ==========');
      Logger.print('[IMCallback] 检测到好友添加成功通知(1204)');
      Logger.print('[IMCallback] sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 好友关系已建立');
        Logger.print('[IMCallback] ✅ 好友关系已建立');
        _showFriendAddedNotification(msg.sendID!);  // 显示通知
      }
    }

    initLogic.showNotification(msg);
    onRecvNewMessage?.call(msg);

    // 通过Subject广播消息，让所有订阅者都能收到
    newMessageSubject.addSafely(msg);

    Logger.print('[IMCallback] ===== recvNewMessage END =====');
  }

  /// 手动处理好友申请通知
  /// 当SDK没有触发friendListener回调时，通过此方法手动刷新好友申请列表
  void _handleFriendApplicationNotification() async {
    try {
      Logger.print('[IMCallback] 🔔 开始处理好友申请通知');
      Logger.print('[IMCallback] 正在获取最新好友申请列表...');
      var list = await OpenIM.iMManager.friendshipManager.getFriendApplicationListAsRecipient();
      Logger.print('[IMCallback] 获取到 ${list.length} 个好友申请');

      if (list.isNotEmpty) {
        // 优先选择“未处理(handleResult == 0)且最新(createTime 最大)”的一条申请
        final pendingList =
            list.where((e) => (e.handleResult ?? 0) == 0).toList();
        final targetList = pendingList.isNotEmpty ? pendingList : list;

        targetList.sort((a, b) {
          final at = a.createTime ?? 0;
          final bt = b.createTime ?? 0;
          if (at > bt) return -1;
          if (at < bt) return 1;
          return 0;
        });

        final latest = targetList.first;
        Logger.print(
            '[IMCallback] 选中的好友申请: fromUserID=${latest.fromUserID}, fromNickname=${latest.fromNickname}, handleResult=${latest.handleResult}, createTime=${latest.createTime}');

        // 触发好友申请变更事件
        friendApplicationChangedSubject.addSafely(latest);
        Logger.print('[IMCallback] ✅ 已触发好友申请变更事件');

        // 播放声音和显示通知
        Logger.print('[IMCallback] 🔔 准备播放声音和显示通知');
        _showFriendApplicationNotification(latest);
        Logger.print('[IMCallback] 🔔 声音和通知处理完成');
      } else {
        Logger.print('[IMCallback] ⚠️ 没有获取到好友申请');
      }
    } catch (e, stackTrace) {
      Logger.print('[IMCallback] ❌ 获取好友申请列表失败: $e');
      Logger.print('[IMCallback] ❌ 堆栈: $stackTrace');
    }
  }

  /// 显示好友申请通知（声音+视觉提示）
  void _showFriendApplicationNotification(FriendApplicationInfo info) {
    try {
      Logger.print('[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');

      // 策略：同时播放声音和显示通知，让系统决定
      // 前台时：系统通知会被忽略，只播放声音
      // 后台时：系统通知会显示

      // 始终播放声音
      initLogic.playMessageSound();
      Logger.print('[IMCallback] 已播放好友申请通知声音');

      // 始终尝试显示系统通知（前台时系统会自动忽略）
      initLogic.showFriendApplicationSystemNotification(info);
      Logger.print('[IMCallback] 已调用系统通知方法');

    } catch (e) {
      Logger.print('[IMCallback] 显示好友申请通知失败: $e');
    }
  }

  /// 处理好友申请通过通知
  /// 当对方通过我的好友申请时,主动创建会话并刷新会话列表
  void _handleFriendApplicationApproved(String friendUserID) async {
    try {
      print('[IMCallback] ===== 好友申请已通过(申请者) =====');
      Logger.print('[IMCallback] ===== 好友申请已通过 =====');
      Logger.print('[IMCallback] friendUserID=$friendUserID');

      // 等待好友关系同步(friendAdded回调会自动更新好友缓存)
      print('[IMCallback] 等待好友关系同步...');
      await Future.delayed(Duration(milliseconds: 1500));

      // 主动创建或获取与新好友的会话
      print('[IMCallback] 主动创建与新好友的会话');
      Logger.print('[IMCallback] 主动创建与新好友的会话: $friendUserID');
      try {
        final conversation = await OpenIM.iMManager.conversationManager.getOneConversation(
          sourceID: friendUserID,
          sessionType: ConversationType.single,
        );
        print('[IMCallback] ✅ 会话已创建: ${conversation.conversationID}');
        Logger.print('[IMCallback] ✅ 会话已创建/获取: ${conversation.conversationID}');

        // 触发新会话添加事件
        conversationAddedSubject.addSafely([conversation]);
        print('[IMCallback] ✅ 已触发 conversationAddedSubject');
        Logger.print('[IMCallback] ✅ 已触发新会话添加事件');
      } catch (e) {
        print('[IMCallback] ❌ 创建会话失败: $e');
        Logger.print('[IMCallback] ❌ 创建会话失败: $e');
      }

      // 同时拉取所有会话作为兜底方案
      print('[IMCallback] 拉取所有会话作为兜底');
      try {
        final conversations = await OpenIM.iMManager.conversationManager.getAllConversationList();
        conversationChangedSubject.addSafely(conversations);
        print('[IMCallback] ✅ 已触发 conversationChangedSubject, 会话数: ${conversations.length}');
        Logger.print('[IMCallback] ✅ 已触发会话列表更新, 会话数: ${conversations.length}');
      } catch (e) {
        print('[IMCallback] ❌ 拉取会话列表失败: $e');
        Logger.print('[IMCallback] ❌ 拉取会话列表失败: $e');
      }

    } catch (e, stackTrace) {
      print('[IMCallback] ❌ 处理好友申请通过失败: $e');
      Logger.print('[IMCallback] ❌ 处理好友申请通过失败: $e');
      Logger.print('[IMCallback] 堆栈: $stackTrace');
    }
  }

  /// 显示好友申请通过通知（声音+视觉提示）
  /// 当对方通过我的好友申请时触发
  void _showFriendApprovedNotification(String friendUserID) async {
    try {
      Logger.print('[IMCallback] 准备显示好友申请通过通知');

      // 始终播放声音
      initLogic.playMessageSound();
      Logger.print('[IMCallback] 已播放好友通过通知声音');

      // 获取好友信息用于通知
      try {
        final friendInfo = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
          userIDList: [friendUserID],
        );

        if (friendInfo.isNotEmpty) {
          final friend = friendInfo.first;

          // 显示系统通知（仅Android后台）
          if (Platform.isAndroid && initLogic.isRunningBackground) {
            await initLogic.showFriendApprovedSystemNotification(friend);
          }

          Logger.print('[IMCallback] ✅ 好友通过通知处理完成: ${friend.nickname}');
        }
      } catch (e) {
        Logger.print('[IMCallback] ⚠️ 获取好友信息失败,仅播放声音: $e');
        // 即使获取失败,也已经播放了声音
      }

    } catch (e) {
      Logger.print('[IMCallback] 显示好友通过通知失败: $e');
    }
  }

  /// 显示好友添加成功通知（声音+视觉提示）
  /// 当成功添加好友后触发(contentType=1204)
  void _showFriendAddedNotification(String friendUserID) async {
    try {
      Logger.print('[IMCallback] 准备显示好友添加成功通知');

      // 始终播放声音
      initLogic.playMessageSound();
      Logger.print('[IMCallback] 已播放好友添加通知声音');

      // 获取好友信息用于通知
      try {
        final friendInfo = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
          userIDList: [friendUserID],
        );

        if (friendInfo.isNotEmpty) {
          final friend = friendInfo.first;

          // 显示系统通知（仅Android后台）
          if (Platform.isAndroid && initLogic.isRunningBackground) {
            await initLogic.showFriendAddedSystemNotification(friend);
          }

          Logger.print('[IMCallback] ✅ 好友添加通知处理完成: ${friend.nickname}');
        }
      } catch (e) {
        Logger.print('[IMCallback] ⚠️ 获取好友信息失败,仅播放声音: $e');
      }

    } catch (e) {
      Logger.print('[IMCallback] 显示好友添加通知失败: $e');
    }
  }

  void recvOfflineMessage(Message msg) {
    print('[IMCallback] ===== recvOfflineMessage START =====');
    print('[IMCallback] contentType=${msg.contentType}, sendID=${msg.sendID}, recvID=${msg.recvID}');
    print('[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');

    final currentUserID = OpenIM.iMManager.userID;
    final isSentByMe = msg.sendID == currentUserID;

    // 处理通话信令消息 (contentType=110, customType=200-204)
    // 注意：通话信令消息需要特殊处理，不应该被添加到聊天列表
    if (msg.contentType == 110 && msg.customElem != null) {
      try {
        final data = jsonDecode(msg.customElem!.data!);
        final customType = data['customType'];
        print('[IMCallback] 检测到离线自定义消息，customType=$customType');

        // 处理通话信令消息
        if (customType == 200 || customType == 201 || customType == 202 ||
            customType == 203 || customType == 204 || customType == 2005) {
          print('[IMCallback] ✅ 检测到离线通话信令消息(customType=$customType)');
          print('[IMCallback] 准备手动触发通话信令处理...');

          final signaling = SignalingInfo(
              invitation: InvitationInfo.fromJson(data['data']));
          signaling.userID = signaling.invitation?.inviterUserID;

          switch (customType) {
            case 200: // callingInvite
              print('[IMCallback] 🎯 处理离线通话邀请信令(callingInvite)');
              (this as dynamic).receiveNewInvitation(signaling);
              break;
            case 201: // callingAccept
              print('[IMCallback] 处理离线通话接受信令(callingAccept)');
              (this as dynamic).inviteeAccepted(signaling);
              break;
            case 202: // callingReject
              print('[IMCallback] 处理离线通话拒绝信令(callingReject)');
              (this as dynamic).inviteeRejected(signaling);
              break;
            case 203: // callingCancel
              print('[IMCallback] 🚫 处理离线通话取消信令(callingCancel)');
              (this as dynamic).invitationCancelled(signaling);
              break;
            case 204: // callingHungup
              print('[IMCallback] 处理离线通话挂断信令(callingHungup)');
              (this as dynamic).beHangup(signaling);
              break;
            case 2005: // syncCallStatus
              print('[IMCallback] 处理离线同步通话状态信令(syncCallStatus)');
              (this as dynamic).syncCall(msg);
              break;
          }

          print('[IMCallback] ✅ 离线通话信令处理完成');
          // 注意：这里不return，让消息继续传递给其他处理器
          // 但在 chat_logic.dart 中会被过滤掉，不会添加到聊天列表
        }
        // 处理通话记录消息 (customType=901)
        else if (customType == 901) {
          print('[IMCallback] 📞 检测到通话记录消息(customType=901)');
          final callData = data['data'];
          final state = callData['state'];
          final type = callData['type'];
          print('[IMCallback] 通话记录: state=$state, type=$type');

          // 如果是取消状态，需要停止响铃并清除来电事件
          if (state == 'cancel' || state == 'beCanceled') {
            print('[IMCallback] 🚫 检测到通话取消记录，调用 handleCallCanceled');

            try {
              // 直接调用 handleCallCanceled 方法
              // 这个方法会停止声音、清除缓存、关闭UI，但不会插入消息记录
              final controller = this as dynamic;
              controller.handleCallCanceled();
              print('[IMCallback] ✅ 已调用 handleCallCanceled');
            } catch (e, stackTrace) {
              print('[IMCallback] ⚠️ 调用 handleCallCanceled 失败: $e');
              print('[IMCallback] 堆栈: $stackTrace');
            }
          }
        }
      } catch (e, stackTrace) {
        print('[IMCallback] ❌ 处理离线通话消息失败: $e');
        print('[IMCallback] ❌ 堆栈: $stackTrace');
      }
    }

    // 处理好友申请通知 (contentType=1203)
    // 由于SDK没有正确触发friendListener，我们手动处理
    // 重要：只处理别人发给我的申请，不处理我发出的申请
    if (msg.contentType == 1203) {
      Logger.print('[IMCallback] 检测到好友申请离线通知(1203)');
      Logger.print('[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        Logger.print('[IMCallback] ✅ 这是别人发给我的好友申请，触发通知');
        _handleFriendApplicationNotification();
        Logger.print('[IMCallback] ✅ 好友申请处理完成');
      } else {
        Logger.print('[IMCallback] ⚠️ 这是我发出的好友申请，不触发通知');
      }
    }
    // 处理好友申请通过通知 (contentType=1201)
    // 当对方通过我的好友申请时，自动发送验证消息并创建会话
    else if (msg.contentType == 1201) {
      print('========== 收到1201离线通知(好友申请通过) ==========');
      print('[IMCallback] sendID=${msg.sendID}, currentUserID=$currentUserID');
      Logger.print('[IMCallback] 检测到好友申请通过离线通知(1201)');
      Logger.print('[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 这是对方通过了我的申请(离线)');
        Logger.print('[IMCallback] ✅ 对方通过了我的好友申请，准备处理');
        _handleFriendApplicationApproved(msg.sendID!);
        _showFriendApprovedNotification(msg.sendID!);  // 新增：显示通知
      } else {
        print('[IMCallback] ⚠️ 这是我通过的申请,忽略(离线)');
        Logger.print('[IMCallback] ⚠️ 这是我通过的好友申请，不需要处理');
      }
    }
    // 处理好友添加成功通知 (contentType=1204)
    else if (msg.contentType == 1204) {
      print('========== 收到1204离线通知(好友添加成功) ==========');
      Logger.print('[IMCallback] 检测到好友添加成功离线通知(1204)');
      Logger.print('[IMCallback] sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 好友关系已建立(离线)');
        Logger.print('[IMCallback] ✅ 好友关系已建立(离线)');
        _showFriendAddedNotification(msg.sendID!);  // 显示通知
      }
    }

    initLogic.showNotification(msg);
    onRecvOfflineMessage?.call(msg);
    Logger.print('[IMCallback] ===== recvOfflineMessage END =====');
  }

  void recvCustomBusinessMessage(String s) {}

  void progressCallback(String msgId, int progress) {
    onMsgSendProgress?.call(msgId, progress);
  }

  void blacklistAdded(BlacklistInfo u) {
    onBlacklistAdd?.call(u);
  }

  void blacklistDeleted(BlacklistInfo u) {
    onBlacklistDeleted?.call(u);
  }

  void friendApplicationAccepted(FriendApplicationInfo u) {
    print('========== friendApplicationAccepted 回调被触发 ==========');
    print('[IMCallback] fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    print('[IMCallback] handleResult=${u.handleResult}');

    Logger.print('[IMCallback] friendApplicationAccepted: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);

    // 确保会话创建
    // fromUserID 是申请发起者，toUserID 是接受者
    final currentUserID = OpenIM.iMManager.userID;
    final friendUserID = (u.fromUserID == currentUserID) ? u.toUserID : u.fromUserID;

    if (friendUserID != null) {
      print('[IMCallback] 准备创建会话: friendUserID=$friendUserID');
      Logger.print('[IMCallback] 好友申请已通过，确保会话创建: friendUserID=$friendUserID');
      _ensureConversationExists(friendUserID);
    }
  }

  void friendApplicationAdded(FriendApplicationInfo u) {
    Logger.print('[IMCallback] friendApplicationAdded: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}, handleMsg=${u.handleMsg}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendApplicationDeleted(FriendApplicationInfo u) {
    Logger.print('[IMCallback] friendApplicationDeleted: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendApplicationRejected(FriendApplicationInfo u) {
    Logger.print('[IMCallback] friendApplicationRejected: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendInfoChanged(FriendInfo u) {
    friendInfoChangedSubject.addSafely(u);
  }

  void friendAdded(FriendInfo u) {
    print('========== friendAdded 回调被触发 ==========');
    print('[IMCallback] userID=${u.userID}, nickname=${u.nickname}');

    Logger.print('[IMCallback] friendAdded: userID=${u.userID}, nickname=${u.nickname}');
    friendAddSubject.addSafely(u);

    // 确保会话存在（对于接受者一方）
    _ensureConversationExists(u.userID!);

    // 延迟刷新会话列表,确保新好友的会话能显示
    Future.delayed(Duration(milliseconds: 1500), () async {
      print('[IMCallback] friendAdded - 延迟刷新会话列表');
      try {
        final conversations = await OpenIM.iMManager.conversationManager.getAllConversationList();
        conversationChangedSubject.addSafely(conversations);
        print('[IMCallback] ✅ 已触发会话列表刷新(friendAdded)');
        Logger.print('[IMCallback] friendAdded后已触发会话列表刷新');
      } catch (e) {
        print('[IMCallback] ❌ 刷新会话列表失败: $e');
      }
    });
  }

  /// 确保会话存在
  /// 当成为好友时，主动创建会话（如果不存在）
  void _ensureConversationExists(String friendUserID) async {
    try {
      Logger.print('[IMCallback] 正在确保会话存在: friendUserID=$friendUserID');

      // 主动创建会话
      final conversation = await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: friendUserID,
        sessionType: ConversationType.single,
      );

      Logger.print('[IMCallback] ✅ 会话已确保存在');
      Logger.print('[IMCallback] conversationID=${conversation.conversationID}');

      // 确认会话在列表中
      final conversations = await OpenIM.iMManager.conversationManager.getAllConversationList();
      final exists = conversations.any((c) => c.userID == friendUserID);
      Logger.print('[IMCallback] 会话在列表中: $exists');

    } catch (e, stackTrace) {
      Logger.print('[IMCallback] 确保会话存在失败: $e');
      Logger.print('[IMCallback] 堆栈: $stackTrace');
    }
  }

  void friendDeleted(FriendInfo u) {
    friendDelSubject.addSafely(u);
  }

  void conversationChanged(List<ConversationInfo> list) {
    conversationChangedSubject.addSafely(list);
  }

  void newConversation(List<ConversationInfo> list) {
    conversationAddedSubject.addSafely(list);
  }

  void groupApplicationAccepted(GroupApplicationInfo info) {
    groupApplicationChangedSubject.add(info);
  }

  void groupApplicationAdded(GroupApplicationInfo info) {
    groupApplicationChangedSubject.add(info);
  }

  void groupApplicationDeleted(GroupApplicationInfo info) {
    groupApplicationChangedSubject.add(info);
  }

  void groupApplicationRejected(GroupApplicationInfo info) {
    groupApplicationChangedSubject.add(info);
  }

  void groupInfoChanged(GroupInfo info) {
    groupInfoUpdatedSubject.addSafely(info);
  }

  void groupMemberAdded(GroupMembersInfo info) {
    memberAddedSubject.add(info);
  }

  void groupMemberDeleted(GroupMembersInfo info) {
    memberDeletedSubject.add(info);
  }

  void groupMemberInfoChanged(GroupMembersInfo info) {
    memberInfoChangedSubject.add(info);
  }

  void joinedGroupAdded(GroupInfo info) {
    joinedGroupAddedSubject.add(info);
  }

  void joinedGroupDeleted(GroupInfo info) {
    joinedGroupDeletedSubject.add(info);
  }

  void totalUnreadMsgCountChanged(int count) {
    print('[IMCallback] SDK上报总未读数: $count');

    // 直接使用SDK上报的值，无需前端修正
    // 后端已通过Options机制正确设置IsUnreadCount=false来排除不应计数的消息
    initLogic.showBadge(count);
    unreadMsgCountEventSubject.addSafely(count);
  }

  void inputStateChanged(InputStatusChangedData status) {
    inputStateChangedSubject.addSafely(status);
  }

  void close() {
    initializedSubject.close();
    friendApplicationChangedSubject.close();
    friendAddSubject.close();
    friendDelSubject.close();
    friendInfoChangedSubject.close();
    selfInfoUpdatedSubject.close();
    groupInfoUpdatedSubject.close();
    conversationAddedSubject.close();
    conversationChangedSubject.close();
    memberAddedSubject.close();
    memberDeletedSubject.close();
    memberInfoChangedSubject.close();
    onKickedOfflineSubject.close();
    groupApplicationChangedSubject.close();
    imSdkStatusSubject.close();
    imSdkStatusPublishSubject.close();
    joinedGroupDeletedSubject.close();
    joinedGroupAddedSubject.close();
  }
}
