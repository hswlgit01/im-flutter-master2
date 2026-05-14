import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/debug_log_uploader.dart';
import 'controller/app_controller.dart';
import 'friend_conversation_helper.dart';

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

  /// 撤回事件广播，避免单个页面回调被切换会话覆盖导致双方/多端状态不同步。
  final revokedMessageSubject = PublishSubject<RevokedInfo>();

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

  final friendApplicationChangedSubject =
      BehaviorSubject<FriendApplicationInfo>();

  final friendAddSubject = BehaviorSubject<FriendInfo>();

  final friendDelSubject = BehaviorSubject<FriendInfo>();

  final friendInfoChangedSubject = PublishSubject<FriendInfo>();

  final selfInfoUpdatedSubject = BehaviorSubject<UserInfo>();

  final userStatusChangedSubject = BehaviorSubject<UserStatusInfo>();

  final groupInfoUpdatedSubject = BehaviorSubject<GroupInfo>();

  final groupApplicationChangedSubject =
      BehaviorSubject<GroupApplicationInfo>();

  final initializedSubject = PublishSubject<bool>();

  final Map<String, int> _conversationEnsureMarks = {};

  final Map<String, int> _friendRelationshipNotifyMarks = {};

  bool _markRecent(Map<String, int> marks, String key, {int windowMs = 5000}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = marks[key];
    if (last != null && now - last < windowMs) {
      return false;
    }
    marks[key] = now;
    Future.delayed(Duration(milliseconds: windowMs), () {
      if (marks[key] == now) {
        marks.remove(key);
      }
    });
    return true;
  }

  final memberAddedSubject = BehaviorSubject<GroupMembersInfo>();

  final memberDeletedSubject = BehaviorSubject<GroupMembersInfo>();

  final memberInfoChangedSubject = PublishSubject<GroupMembersInfo>();

  final joinedGroupDeletedSubject = BehaviorSubject<GroupInfo>();

  final joinedGroupAddedSubject = BehaviorSubject<GroupInfo>();

  final onKickedOfflineSubject = PublishSubject<KickoffType>();

  final imSdkStatusSubject =
      ReplaySubject<({IMSdkStatus status, bool reInstall, int? progress})>();

  final imSdkStatusPublishSubject =
      PublishSubject<({IMSdkStatus status, bool reInstall, int? progress})>();

  final inputStateChangedSubject = PublishSubject<InputStatusChangedData>();

  Timer? _conversationReconcileTimer;
  final Map<String, String> _promptedConversationMessageKeys = {};
  int? _lastTotalUnreadCount;

  void imSdkStatus(IMSdkStatus status,
      {bool reInstall = false, int? progress}) {
    imSdkStatusSubject
        .add((status: status, reInstall: reInstall, progress: progress));
    imSdkStatusPublishSubject
        .add((status: status, reInstall: reInstall, progress: progress));
    // dawn 2026-05-11 修复手机端弱网私聊无提示：同步完成后主动补刷会话/未读并释放同步期间缓存的提示。
    if (status == IMSdkStatus.syncEnded) {
      Future.microtask(() async {
        await refreshConversationSnapshot(reason: 'sync_ended');
        await initLogic.flushPendingMessagePrompts();
      });
    }
  }

  void scheduleConversationReconcile(String reason,
      {Duration delay = const Duration(milliseconds: 800)}) {
    _conversationReconcileTimer?.cancel();
    _conversationReconcileTimer = Timer(delay, () {
      unawaited(refreshConversationSnapshot(reason: reason));
    });
  }

  Future<void> refreshConversationSnapshot({String reason = 'manual'}) async {
    try {
      final conversations = await OpenIM.iMManager.conversationManager
          .getConversationListSplit(offset: 0, count: 400);
      conversationChangedSubject.addSafely(conversations);
      _promptLatestMessagesFromConversations(conversations, reason);
      Logger.print(
          '[IMCallback] 已补刷会话列表($reason), count=${conversations.length}');
    } catch (e, s) {
      Logger.print('[IMCallback] 补刷会话列表失败($reason): $e\n$s');
    }

    try {
      final rawCount =
          await OpenIM.iMManager.conversationManager.getTotalUnreadMsgCount();
      final count = rawCount is int
          ? rawCount
          : int.tryParse(rawCount?.toString() ?? '') ?? 0;
      totalUnreadMsgCountChanged(count);
      Logger.print('[IMCallback] 已补刷总未读($reason): $count');
    } catch (e, s) {
      Logger.print('[IMCallback] 补刷总未读失败($reason): $e\n$s');
    }
  }

  String _messagePromptKey(Message message) {
    final serverMsgID = message.serverMsgID;
    if (serverMsgID != null && serverMsgID.isNotEmpty) {
      return 'server:$serverMsgID';
    }
    final clientMsgID = message.clientMsgID;
    if (clientMsgID != null && clientMsgID.isNotEmpty) {
      return 'client:$clientMsgID';
    }
    return [
      'fallback',
      message.sessionType,
      message.sendID,
      message.recvID,
      message.groupID,
      message.seq,
      message.sendTime,
      message.contentType,
    ].join(':');
  }

  void _markPromptedMessage(Message message) {
    final messageKey = _messagePromptKey(message);
    if (message.sessionType == ConversationType.single) {
      // dawn 2026-05-12 修复手机端弱网私聊无提示：单聊 conversationID 双方顺序不固定，两个方向都标记避免重复提示。
      _promptedConversationMessageKeys[
          'si_${message.sendID}_${message.recvID}'] = messageKey;
      _promptedConversationMessageKeys[
          'si_${message.recvID}_${message.sendID}'] = messageKey;
      return;
    }
    _promptedConversationMessageKeys['sg_${message.groupID}'] = messageKey;
  }

  bool _isRecentEnoughForPrompt(Message message) {
    final sendTime = message.sendTime;
    if (sendTime == null || sendTime <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - sendTime).abs() <= const Duration(minutes: 10).inMilliseconds;
  }

  void _promptLatestMessagesFromConversations(
      List<ConversationInfo> list, String reason) {
    // dawn 2026-05-12 修复手机端弱网私聊无提示：SDK 只回调会话/未读时，用会话 latestMsg 兜底触发一次提示。
    final shouldPrompt = reason == 'conversation_changed' ||
        reason == 'new_conversation' ||
        reason == 'total_unread_changed';
    if (!shouldPrompt) return;

    for (final conversation in list) {
      final latestMsg = conversation.latestMsg;
      if (latestMsg == null ||
          conversation.unreadCount <= 0 ||
          latestMsg.sendID == OpenIM.iMManager.userID ||
          !_isRecentEnoughForPrompt(latestMsg)) {
        continue;
      }

      final conversationID = conversation.conversationID;
      final messageKey = _messagePromptKey(latestMsg);
      if (_promptedConversationMessageKeys[conversationID] == messageKey) {
        continue;
      }

      _promptedConversationMessageKeys[conversationID] = messageKey;
      unawaited(initLogic.showNotification(latestMsg));
    }
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
    // dawn 2026-04-27 临时排查：SDK 调到 Dart 入口立即上报，确认 server 是否
    // 把撤回通知投递到了 zz1 那台手机。
    DebugLogUploader.send('sdk_recv_message_revoked', {
      'targetClientMsgID': info.clientMsgID,
      'revokerID': info.revokerID,
      'sourceMessageSendID': info.sourceMessageSendID,
    });
    onRecvMessageRevoked?.call(info);
    revokedMessageSubject.addSafely(info);
  }

  void recvC2CMessageReadReceipt(List<ReadReceiptInfo> list) {
    if (list.isNotEmpty) {
      print(
          '[IMController] 📬 收到已读回执: ${list.length} 条, userIDs=${list.map((r) => r.userID).toList()}, msgIDList长度=${list.map((r) => r.msgIDList?.length ?? 0).toList()}');
    }
    // dawn 2026-04-27 临时排查：SDK 已读回调入口上报
    DebugLogUploader.send('sdk_recv_c2c_read_receipt', {
      'count': list.length,
      'userIDs': list.map((r) => r.userID).toList(),
    });
    for (var r in list) {
      final key = r.userID ?? '';
      if (key.isEmpty) continue;
      _pendingC2CReadReceipts[key] = [
        ...(_pendingC2CReadReceipts[key] ?? []),
        r
      ];
    }
    c2cReadReceiptSubject.add(list);
    onRecvC2CReadReceipt?.call(list);
  }

  void recvNewMessage(Message msg) {
    Logger.print('[IMCallback] ===== recvNewMessage START =====');
    Logger.print(
        '[IMCallback] contentType=${msg.contentType}, sendID=${msg.sendID}, recvID=${msg.recvID}');
    Logger.print(
        '[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');
    // dawn 2026-04-27 临时排查：SDK 给 Dart 的新消息入口上报，重点关注 2101
    DebugLogUploader.send('sdk_recv_new_msg', {
      'contentType': msg.contentType,
      'clientMsgID': msg.clientMsgID,
      'sendID': msg.sendID,
      'recvID': msg.recvID,
    });

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
        if (customType == 200 ||
            customType == 201 ||
            customType == 202 ||
            customType == 203 ||
            customType == 204 ||
            customType == 2005) {
          Logger.print('[IMCallback] ✅ 检测到通话信令消息(customType=$customType)');
          Logger.print('[IMCallback] 准备手动触发通话信令处理...');

          final signaling =
              SignalingInfo(invitation: InvitationInfo.fromJson(data['data']));
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
      Logger.print(
          '[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        Logger.print('[IMCallback] ✅ 这是别人发给我的好友申请，触发通知');
        _scheduleFriendApplicationRefresh();
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
      Logger.print(
          '[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 这是对方通过了我的申请');
        Logger.print('[IMCallback] ✅ 对方通过了我的好友申请，准备处理');
        _handleFriendApplicationApproved(msg.sendID!);
        _showFriendApprovedNotification(msg.sendID!); // 新增：显示通知
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
        _ensureConversationExists(msg.sendID!);
        _showFriendAddedNotification(msg.sendID!); // 显示通知
      }
    }
    // dawn 2026-05-14 修复群通知无红点：SDK 群申请 listener 偶发不回调时，按协议通知手动刷新群申请列表。
    else if (msg.contentType == 1503 ||
        msg.contentType == 1505 ||
        msg.contentType == 1506) {
      Logger.print('[IMCallback] 检测到群申请通知(${msg.contentType})');
      if (!isSentByMe) {
        _scheduleGroupApplicationRefresh();
      }
    }

    initLogic.showNotification(msg);
    _markPromptedMessage(msg);
    onRecvNewMessage?.call(msg);

    // 通过Subject广播消息，让所有订阅者都能收到
    newMessageSubject.addSafely(msg);
    // dawn 2026-05-11 修复手机端弱网会话不提示：SDK 会话变更回调丢失时，收到消息后兜底补刷列表/未读。
    scheduleConversationReconcile('recv_new_message');

    Logger.print('[IMCallback] ===== recvNewMessage END =====');
  }

  /// 手动处理好友申请通知
  /// 当SDK没有触发friendListener回调时，通过此方法手动刷新好友申请列表
  void _scheduleFriendApplicationRefresh() {
    _handleFriendApplicationNotification();
    // dawn 2026-05-14 修复新好友提示延迟：通知可能先于本地申请列表落盘，延迟补刷避免红点漏掉。
    Future.delayed(const Duration(milliseconds: 800),
        _handleFriendApplicationNotification);
    Future.delayed(
        const Duration(seconds: 2), _handleFriendApplicationNotification);
  }

  void _handleFriendApplicationNotification() async {
    try {
      Logger.print('[IMCallback] 🔔 开始处理好友申请通知');
      Logger.print('[IMCallback] 正在获取最新好友申请列表...');
      var list = await OpenIM.iMManager.friendshipManager
          .getFriendApplicationListAsRecipient();
      Logger.print('[IMCallback] 获取到 ${list.length} 个好友申请');

      if (list.isNotEmpty) {
        Logger.print(
            '[IMCallback] 好友申请详情: fromUserID=${list.first.fromUserID}, fromNickname=${list.first.fromNickname}');

        // 触发好友申请变更事件
        friendApplicationChangedSubject.addSafely(list.first);
        Logger.print('[IMCallback] ✅ 已触发好友申请变更事件');

        // 播放声音和显示通知
        Logger.print('[IMCallback] 🔔 准备播放声音和显示通知');
        _showFriendApplicationNotification(list.first);
        Logger.print('[IMCallback] 🔔 声音和通知处理完成');
      } else {
        Logger.print('[IMCallback] ⚠️ 没有获取到好友申请');
      }
    } catch (e, stackTrace) {
      Logger.print('[IMCallback] ❌ 获取好友申请列表失败: $e');
      Logger.print('[IMCallback] ❌ 堆栈: $stackTrace');
    }
  }

  void _scheduleGroupApplicationRefresh() {
    _handleGroupApplicationNotification();
    // dawn 2026-05-14 修复群通知提示延迟：协议通知到达后延迟补刷，覆盖 SDK 列表同步慢的情况。
    Future.delayed(
        const Duration(milliseconds: 800), _handleGroupApplicationNotification);
    Future.delayed(
        const Duration(seconds: 2), _handleGroupApplicationNotification);
  }

  void _handleGroupApplicationNotification() async {
    try {
      Logger.print('[IMCallback] 🔔 开始处理群申请通知');
      final list = await OpenIM.iMManager.groupManager
          .getGroupApplicationListAsRecipient();
      Logger.print('[IMCallback] 获取到 ${list.length} 个群申请');
      if (list.isNotEmpty) {
        groupApplicationChangedSubject.addSafely(list.first);
        Logger.print('[IMCallback] ✅ 已触发群申请变更事件');
      }
    } catch (e, stackTrace) {
      Logger.print('[IMCallback] ❌ 获取群申请列表失败: $e');
      Logger.print('[IMCallback] ❌ 堆栈: $stackTrace');
    }
  }

  /// 显示好友申请通知（声音+视觉提示）
  void _showFriendApplicationNotification(FriendApplicationInfo info) {
    try {
      Logger.print(
          '[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');

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
        await FriendConversationHelper.ensureConversationForFriend(
            friendUserID);
        final conversation =
            await OpenIM.iMManager.conversationManager.getOneConversation(
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
        final conversations =
            await OpenIM.iMManager.conversationManager.getAllConversationList();
        conversationChangedSubject.addSafely(conversations);
        print(
            '[IMCallback] ✅ 已触发 conversationChangedSubject, 会话数: ${conversations.length}');
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
      if (!_markRecent(_friendRelationshipNotifyMarks, friendUserID)) {
        Logger.print('[IMCallback] 跳过重复好友关系通知: $friendUserID');
        return;
      }
      Logger.print('[IMCallback] 准备显示好友申请通过通知');

      // 始终播放声音
      initLogic.playMessageSound();
      Logger.print('[IMCallback] 已播放好友通过通知声音');

      // 获取好友信息用于通知
      try {
        final friendInfo =
            await OpenIM.iMManager.friendshipManager.getFriendsInfo(
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
      if (!_markRecent(_friendRelationshipNotifyMarks, friendUserID)) {
        Logger.print('[IMCallback] 跳过重复好友关系通知: $friendUserID');
        return;
      }
      Logger.print('[IMCallback] 准备显示好友添加成功通知');

      // 始终播放声音
      initLogic.playMessageSound();
      Logger.print('[IMCallback] 已播放好友添加通知声音');

      // 获取好友信息用于通知
      try {
        final friendInfo =
            await OpenIM.iMManager.friendshipManager.getFriendsInfo(
          userIDList: [friendUserID],
        );

        if (friendInfo.isNotEmpty) {
          final friend = friendInfo.first;

          // 显示系统通知（仅Android后台）
          if (Platform.isAndroid && initLogic.isRunningBackground) {
            await initLogic.showFriendAddedSystemNotification(friend);
          }

          // dawn 2026-04-26 修复邀请人看不到新好友：
          // SDK 的 friendAdded 回调在邀请码注册场景不一定触发，主动把 1204 推到
          // friendAddSubject，让 friend_list_logic 的 _addFriend 也能收到，
          // 邀请人 zz 列表里立刻出现 zz5。
          friendAddSubject.addSafely(friend);
          Logger.print(
              '[IMCallback] ✅ 已主动推送 friendAddSubject: ${friend.nickname}');

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
    print(
        '[IMCallback] contentType=${msg.contentType}, sendID=${msg.sendID}, recvID=${msg.recvID}');
    print('[IMCallback] isRunningBackground=${initLogic.isRunningBackground}');
    // dawn 2026-04-27 临时排查：离线消息入口也打上报
    DebugLogUploader.send('sdk_recv_offline_msg', {
      'contentType': msg.contentType,
      'clientMsgID': msg.clientMsgID,
      'sendID': msg.sendID,
      'recvID': msg.recvID,
    });

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
        if (customType == 200 ||
            customType == 201 ||
            customType == 202 ||
            customType == 203 ||
            customType == 204 ||
            customType == 2005) {
          print('[IMCallback] ✅ 检测到离线通话信令消息(customType=$customType)');
          print('[IMCallback] 准备手动触发通话信令处理...');

          final signaling =
              SignalingInfo(invitation: InvitationInfo.fromJson(data['data']));
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
      Logger.print(
          '[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        Logger.print('[IMCallback] ✅ 这是别人发给我的好友申请，触发通知');
        _scheduleFriendApplicationRefresh();
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
      Logger.print(
          '[IMCallback] currentUserID=$currentUserID, sendID=${msg.sendID}, isSentByMe=$isSentByMe');

      if (!isSentByMe) {
        print('[IMCallback] ✅ 这是对方通过了我的申请(离线)');
        Logger.print('[IMCallback] ✅ 对方通过了我的好友申请，准备处理');
        _handleFriendApplicationApproved(msg.sendID!);
        _showFriendApprovedNotification(msg.sendID!); // 新增：显示通知
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
        _ensureConversationExists(msg.sendID!);
        _showFriendAddedNotification(msg.sendID!); // 显示通知
      }
    }
    // dawn 2026-05-14 修复离线群通知无红点：离线同步的群申请协议通知也触发群申请列表补刷。
    else if (msg.contentType == 1503 ||
        msg.contentType == 1505 ||
        msg.contentType == 1506) {
      Logger.print('[IMCallback] 检测到群申请离线通知(${msg.contentType})');
      if (!isSentByMe) {
        _scheduleGroupApplicationRefresh();
      }
    }

    initLogic.showNotification(msg);
    _markPromptedMessage(msg);
    onRecvOfflineMessage?.call(msg);
    // dawn 2026-05-11 修复手机端离线/弱网消息进库但页面无感知：离线消息也广播给当前聊天页并补刷会话。
    newMessageSubject.addSafely(msg);
    scheduleConversationReconcile('recv_offline_message');
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

    Logger.print(
        '[IMCallback] friendApplicationAccepted: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);

    // 确保会话创建
    // fromUserID 是申请发起者，toUserID 是接受者
    final currentUserID = OpenIM.iMManager.userID;
    final friendUserID =
        (u.fromUserID == currentUserID) ? u.toUserID : u.fromUserID;

    if (friendUserID != null) {
      print('[IMCallback] 准备创建会话: friendUserID=$friendUserID');
      Logger.print('[IMCallback] 好友申请已通过，确保会话创建: friendUserID=$friendUserID');
      _ensureConversationExists(friendUserID);
    }
  }

  void friendApplicationAdded(FriendApplicationInfo u) {
    Logger.print(
        '[IMCallback] friendApplicationAdded: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}, handleMsg=${u.handleMsg}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendApplicationDeleted(FriendApplicationInfo u) {
    Logger.print(
        '[IMCallback] friendApplicationDeleted: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendApplicationRejected(FriendApplicationInfo u) {
    Logger.print(
        '[IMCallback] friendApplicationRejected: fromUserID=${u.fromUserID}, toUserID=${u.toUserID}');
    friendApplicationChangedSubject.addSafely(u);
  }

  void friendInfoChanged(FriendInfo u) {
    friendInfoChangedSubject.addSafely(u);
  }

  void friendAdded(FriendInfo u) {
    print('========== friendAdded 回调被触发 ==========');
    print('[IMCallback] userID=${u.userID}, nickname=${u.nickname}');

    Logger.print(
        '[IMCallback] friendAdded: userID=${u.userID}, nickname=${u.nickname}');
    friendAddSubject.addSafely(u);

    // 确保会话存在且在聊天列表可见（默认好友/邀请人自动互加也走这里）
    _ensureConversationExists(u.userID!);

    // 延迟刷新会话列表,确保新好友的会话能显示
    Future.delayed(Duration(milliseconds: 1500), () async {
      print('[IMCallback] friendAdded - 延迟刷新会话列表');
      try {
        final conversations =
            await OpenIM.iMManager.conversationManager.getAllConversationList();
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
    if (!_markRecent(_conversationEnsureMarks, friendUserID)) {
      Logger.print('[IMCallback] 跳过重复会话确保任务: friendUserID=$friendUserID');
      return;
    }
    try {
      Logger.print('[IMCallback] 正在确保会话存在: friendUserID=$friendUserID');

      await FriendConversationHelper.ensureConversationForFriend(friendUserID);
      final conversation =
          await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: friendUserID,
        sessionType: ConversationType.single,
      );

      Logger.print('[IMCallback] ✅ 会话已确保存在');
      Logger.print(
          '[IMCallback] conversationID=${conversation.conversationID}');

      // 确认会话在列表中
      final conversations =
          await OpenIM.iMManager.conversationManager.getAllConversationList();
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
    _promptLatestMessagesFromConversations(list, 'conversation_changed');
    conversationChangedSubject.addSafely(list);
  }

  void newConversation(List<ConversationInfo> list) {
    _promptLatestMessagesFromConversations(list, 'new_conversation');
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
    final previous = _lastTotalUnreadCount;
    _lastTotalUnreadCount = count;

    // 直接使用SDK上报的值，无需前端修正
    // 后端已通过Options机制正确设置IsUnreadCount=false来排除不应计数的消息
    initLogic.showBadge(count);
    unreadMsgCountEventSubject.addSafely(count);
    if (previous != null && count > previous) {
      // dawn 2026-05-12 修复手机端弱网私聊无提示：未读数增加但消息回调缺失时，补拉会话 latestMsg 触发提示。
      scheduleConversationReconcile('total_unread_changed',
          delay: const Duration(milliseconds: 500));
    }
  }

  void inputStateChanged(InputStatusChangedData status) {
    inputStateChangedSubject.addSafely(status);
  }

  void close() {
    _conversationReconcileTimer?.cancel();
    _promptedConversationMessageKeys.clear();
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
