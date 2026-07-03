import 'dart:async';
import 'dart:convert';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/pages/contacts/group_profile_panel/group_profile_panel_logic.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim/utils/scan.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import '../../../utils/luck_money_status_manager.dart';
import '../../core/api_service.dart' as core;
import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';
import '../contacts/add_by_search/add_by_search_logic.dart';
import '../home/home_logic.dart';

class ConversationLogic extends GetxController {
  final popCtrl = CustomPopupMenuController();
  final list = <ConversationInfo>[].obs;
  final imLogic = Get.find<IMController>();
  final homeLogic = Get.find<HomeLogic>();
  final appLogic = Get.find<AppController>();
  final refreshController = RefreshController();
  final orgController = Get.find<OrgController>();
  final tempDraftText = <String, String>{};
  // dawn 2026-06-16 优化移动端登录速度：会话首屏只拉 50 条，避免账号会话多时登录后长时间同步卡屏。
  static const firstPageSize = 50;
  final pageSize = firstPageSize;

  final imStatus = IMSdkStatus.connectionSucceeded.obs;
  bool reInstall = false;

  final onChangeConversations = <ConversationInfo>[];

  // 好友列表缓存,用于快速检查好友关系
  final _friendUserIDs = <String>{};
  DateTime? _friendListLastUpdate;
  Timer? _friendCheckTimer;

  /// 红包状态缓存（当前用户是否已领取）：会话列表摘要用，避免 latestMsg 未更新时仍显示 [待领取]
  Map<String, String> _redPacketStatusCache = {};

  /// 红包整体状态缓存（无论谁领完，只要红包结束，用于纠正 [待领取]）
  Map<String, String> _packetOverallStatusCache = {};
  final _apiService = core.ApiService();
  final _latestDisplayMsgCache = <String, Message>{};

  // dawn 2026-06-21 新增官方人员标识：单聊会话按需批量查询组织角色并缓存，避免每次构建列表都请求接口。
  final officialUserMap = <String, bool>{}.obs;
  final _officialRoleRequestedAt = <String, DateTime>{};
  static const _officialRoleRefreshInterval = Duration(minutes: 10);

  // dawn 2026-05-25 修复手机端文件消息无列表提示：SDK 弱网/文件消息场景偶发会话 unreadCount 为 0，
  // 但 latestMsg 已经更新；这里给最近收到的对方消息补一个本地未读提示，进入会话或标记已读后清除。
  static const _fallbackUnreadWindow = Duration(minutes: 10);
  final _fallbackUnreadCounts = <String, int>{};
  final _fallbackReadLatestMsgKeys = <String, String>{};
  // dawn 2026-06-29 fallback 已读改为按 seq/sendTime 记录(不依赖会变的 latestMsg key)：
  // latestMsg 被服务端补字段/通话信令/撤回等改变 key 时,旧的精确 key 失配会导致已读后红点又冒出来。
  final _fallbackReadUntilSeq = <String, int>{};
  final _fallbackReadUntilTime = <String, int>{};
  bool _syncingJoinedGroupConversations = false;

  @override
  void onInit() {
    getFirstPage();
    _updateFriendList(); // 初始化好友列表
    // 注意: 暂时保留定时器作为兜底方案,但应该优先解决A收不到通知的问题
    // _startFriendCheckTimer(); // 启动好友列表检查定时器
    imLogic.conversationAddedSubject.listen(onChanged);
    imLogic.conversationChangedSubject.listen(onChanged);
    // 监听好友变化,更新好友列表缓存
    imLogic.friendAddSubject.listen((friend) {
      print('[ConversationLogic] 好友添加: ${friend.userID}');
      _friendUserIDs.add(friend.userID!);
      print('[ConversationLogic] 当前好友数: ${_friendUserIDs.length}');
      // 好友添加后,立即刷新会话列表以显示新好友的会话
      Future.delayed(Duration(milliseconds: 500), () {
        print('[ConversationLogic] 好友添加后延迟刷新会话列表');
        onRefresh();
      });
    });
    imLogic.friendDelSubject.listen((friend) {
      print('[ConversationLogic] 好友删除: ${friend.userID}');
      _friendUserIDs.remove(friend.userID!);
    });
    // 监听群信息变更,主动更新会话列表中的群名称和头像
    imLogic.groupInfoUpdatedSubject.listen((groupInfo) async {
      print(
          '[ConversationLogic] 群信息更新: groupID=${groupInfo.groupID}, 新名称: ${groupInfo.groupName}, status=${groupInfo.status}');

      // 构建会话ID (超级群格式: sg_groupID)
      final conversationID = 'sg_${groupInfo.groupID}';

      // 群被解散 (status == 2): 服务端已不再推送该群的消息，我们这里主动把本地
      // 会话连同历史消息一起删掉。否则即便已经退出该群，非群主成员仍能在聊天
      // 列表里点进去看到全部历史（bug 1 的症状）。服务端的 GetMaxSeq 过滤只防
      // 清缓存后重新拉取，不负责清本地 DB。
      if (groupInfo.status == 2) {
        print('[ConversationLogic] 群已解散,清除本地会话与历史: $conversationID');
        try {
          // Await the SDK deletion before touching the in-memory list so the two
          // stay consistent even if the call throws.
          await OpenIM.iMManager.conversationManager
              .deleteConversationAndDeleteAllMsg(
                  conversationID: conversationID);
        } catch (e, s) {
          print('[ConversationLogic] 删除已解散群会话失败: $e\n$s');
        }
        list.removeWhere((c) => c.conversationID == conversationID);
        return;
      }

      // 查找对应的会话
      final index = list.indexWhere((c) => c.conversationID == conversationID);

      if (index != -1) {
        print('[ConversationLogic] 找到会话,更新显示名称: ${groupInfo.groupName}');
        // 更新会话的显示名称和头像
        final updatedConversation = list[index];
        updatedConversation.showName = groupInfo.groupName;
        updatedConversation.faceURL = groupInfo.faceURL;

        // 触发列表刷新
        list[index] = updatedConversation;
        list.refresh();
      } else {
        print('[ConversationLogic] 未找到会话: $conversationID');
      }
    });
    // dawn 2026-04-26 修复解散群成员侧残留：
    // 仅监听 groupInfoUpdatedSubject status==2 不可靠——SDK 在群被解散时优先
    // 触发 joinedGroupDeletedSubject（自己已被剔出群），groupInfo 后续才同步。
    // 这里加兜底：joinedGroupDeleted 时主动 getGroupsInfo 确认 status==2
    // 才清本地会话，否则只是普通的退群/被踢，按原行为不动。
    // dawn 2026-04-27 codex 回归修复：原版无条件 deleteConversationAndDeleteAllMsg，
    // 在 normal leave/kick 场景会误把不该删的群历史也清掉。增加 status==2 校验。
    imLogic.joinedGroupDeletedSubject.listen((groupInfo) async {
      final groupID = groupInfo.groupID;
      final conversationID = 'sg_$groupID';
      var dismissed = groupInfo.status == 2;
      if (!dismissed) {
        try {
          final fresh = await OpenIM.iMManager.groupManager
              .getGroupsInfo(groupIDList: [groupID]);
          dismissed = fresh.firstOrNull?.status == 2;
        } catch (e, s) {
          // 群已经查不到也视为解散
          print('[ConversationLogic] joinedGroupDeleted 查群信息失败,按解散处理: $e\n$s');
          dismissed = true;
        }
      }
      print(
          '[ConversationLogic] joinedGroupDeleted 清理本地群会话: $conversationID dismissed=$dismissed');
      try {
        await OpenIM.iMManager.conversationManager
            .deleteConversationAndDeleteAllMsg(conversationID: conversationID);
      } catch (e, s) {
        print('[ConversationLogic] joinedGroupDeleted 删除会话失败: $e\n$s');
      }
      list.removeWhere((c) => c.conversationID == conversationID);
    });
    // dawn 2026-06-26 加入群聊后立即在会话列表生成会话：不再等群里有人发消息。
    // 服务端已把建群/入群通知改为持久化(成员能同步到入群事件)，这里收到入群回调即
    // 主动 getOneConversation 建本地会话并插入列表，确保"加入即可见"。
    imLogic.joinedGroupAddedSubject.listen((groupInfo) async {
      final groupID = groupInfo.groupID;
      if (groupID.isEmpty) return;
      try {
        final info = await OpenIM.iMManager.conversationManager
            .getOneConversation(
                sourceID: groupID, sessionType: groupInfo.sessionType);
        _ensureConversationInList(info);
      } catch (e) {
        Logger.print('[ConversationLogic] joinedGroupAdded 建会话失败: $e');
      }
    });
    imLogic.imSdkStatusSubject.listen((value) async {
      final status = value.status;
      final appReInstall = value.reInstall;
      final progress = value.progress;
      imStatus.value = status;

      if (status == IMSdkStatus.syncStart) {
        reInstall = appReInstall;
        // dawn 2026-06-16 优化移动端登录体验：SDK 重建本地库时仍会同步，但不再用全屏“同步中”遮罩阻塞首页。
        Logger.print('[ConversationLogic] SDK 开始同步, reInstall=$reInstall');
      }

      if (status == IMSdkStatus.syncProgress && reInstall) {
        Logger.print('[ConversationLogic] SDK 同步进度: ${progress ?? 0}%');
      } else if (status == IMSdkStatus.syncEnded ||
          status == IMSdkStatus.syncFailed) {
        EasyLoading.dismiss();
        // dawn 2026-05-11 修复手机端弱网私聊无提示：每次同步结束都重拉会话列表，避免 SDK 会话变更事件弱网下丢失。
        if (status == IMSdkStatus.syncEnded) {
          onRefresh();
          unawaited(_syncJoinedGroupConversations());
        } else if (reInstall) {
          onRefresh();
          reInstall = false;
        }
        if (status == IMSdkStatus.syncEnded) {
          reInstall = false;
        }
      }
    });
    super.onInit();
  }

  @override
  void onClose() {
    list.clear();
    reInstall = false;
    _friendCheckTimer?.cancel();
    super.onClose();
  }

  // Removed _isCallSignalingMessage and _fixUnreadCount methods
  // Backend now handles unread count correctly via Options mechanism

  String? _latestMessageKey(ConversationInfo info) {
    final msg = info.latestMsg;
    if (msg == null) return null;
    final msgID =
        msg.serverMsgID?.isNotEmpty == true ? msg.serverMsgID : msg.clientMsgID;
    return [
      msgID ?? '',
      msg.sendID ?? '',
      msg.recvID ?? '',
      msg.groupID ?? '',
      msg.sendTime ?? 0,
      msg.contentType ?? 0,
    ].join('|');
  }

  bool _shouldFallbackUnread(ConversationInfo info) {
    final msg = info.latestMsg;
    if (msg == null || info.unreadCount > 0) return false;
    if (msg.sendID == OpenIM.iMManager.userID) return false;
    if ((info.recvMsgOpt ?? 0) != 0) return false;

    // dawn 2026-06-29 优先用 seq/sendTime 判断是否已读：进入会话标记已读后,服务端可能给 latestMsg
    // 补字段/改 clientMsgID 使精确 key 失配,从而红点又冒出来；改成"已读到的 seq/时间 之内都算已读"。
    final id = info.conversationID;
    final seq = msg.seq ?? 0;
    final readSeq = _fallbackReadUntilSeq[id] ?? 0;
    if (seq > 0 && readSeq > 0 && seq <= readSeq) return false;
    final readTime = _fallbackReadUntilTime[id] ?? 0;
    final msgTime = msg.sendTime ?? info.latestMsgSendTime ?? 0;
    if (msgTime > 0 && readTime > 0 && msgTime <= readTime) return false;

    final key = _latestMessageKey(info);
    if (key == null || _fallbackReadLatestMsgKeys[id] == key) {
      return false;
    }

    if (msgTime <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - msgTime).abs() <= _fallbackUnreadWindow.inMilliseconds;
  }

  // dawn 2026-06-29 供聊天页标记已读时调用：以当前 latestMsg 的 seq/sendTime 为已读水位线。
  void markFallbackRead(String conversationID) {
    final info =
        list.firstWhereOrNull((e) => e.conversationID == conversationID);
    if (info != null) {
      _markFallbackUnreadRead(info);
    } else {
      // 列表里暂时找不到(刚进会话/未同步)，仍清掉补充计数，避免残留红点。
      _fallbackUnreadCounts.remove(conversationID);
    }
  }

  void _syncFallbackUnreadCounts(
    Iterable<ConversationInfo> conversations, {
    bool pruneMissing = false,
  }) {
    final seen = <String>{};
    for (final info in conversations) {
      seen.add(info.conversationID);
      if (info.unreadCount > 0) {
        _fallbackUnreadCounts.remove(info.conversationID);
      } else if (_shouldFallbackUnread(info)) {
        _fallbackUnreadCounts[info.conversationID] = 1;
      } else {
        _fallbackUnreadCounts.remove(info.conversationID);
      }
    }
    if (pruneMissing) {
      _fallbackUnreadCounts.removeWhere((id, _) => !seen.contains(id));
      _fallbackReadLatestMsgKeys.removeWhere((id, _) => !seen.contains(id));
      _fallbackReadUntilSeq.removeWhere((id, _) => !seen.contains(id));
      _fallbackReadUntilTime.removeWhere((id, _) => !seen.contains(id));
    }
  }

  void _markFallbackUnreadRead(ConversationInfo info) {
    final id = info.conversationID;
    final key = _latestMessageKey(info);
    if (key != null) {
      _fallbackReadLatestMsgKeys[id] = key;
    }
    // dawn 2026-06-29 记录已读水位线(seq + sendTime)，取较大值，避免乱序消息把水位线拉低。
    final msg = info.latestMsg;
    final seq = msg?.seq ?? 0;
    if (seq > 0) {
      _fallbackReadUntilSeq[id] = (_fallbackReadUntilSeq[id] ?? 0) < seq
          ? seq
          : _fallbackReadUntilSeq[id]!;
    }
    final time = msg?.sendTime ?? info.latestMsgSendTime ?? 0;
    if (time > 0) {
      _fallbackReadUntilTime[id] = (_fallbackReadUntilTime[id] ?? 0) < time
          ? time
          : _fallbackReadUntilTime[id]!;
    }
    if (_fallbackUnreadCounts.remove(id) != null) {
      list.refresh();
    }
  }

  void onChanged(List<ConversationInfo> newList) async {
    print('[ConversationLogic] onChanged 被调用, 会话数: ${newList.length}');

    // 过滤掉系统通知类型的会话，但保留好友相关通知
    final filteredList = newList.where((conversation) {
      final latestMsg = conversation.latestMsg;
      if (latestMsg != null) {
        final contentType = latestMsg.contentType ?? 0;

        // 保留以下通知类型的会话：
        // 1400: OA通知
        // 1201: 好友申请通过通知
        // 1204: 好友添加通知
        final allowedNotificationTypes = [1400, 1201, 1204];

        if (contentType >= 1000 && contentType < 2000) {
          // 如果是允许的通知类型，保留会话
          if (allowedNotificationTypes.contains(contentType)) {
            print('[ConversationLogic] ✅ 保留好友通知会话 contentType=$contentType');
            return true;
          }

          // 特殊处理: 如果是1203好友申请通知,检查是否已经是好友
          // 如果已经是好友,说明申请已通过,保留会话;否则过滤掉
          if (contentType == 1203) {
            // 检查是否是单聊且对方已经是好友
            if (conversation.isSingleChat && conversation.userID != null) {
              final isFriend = _checkIsFriend(conversation.userID!);
              print(
                  '[ConversationLogic] 检查1203会话: userID=${conversation.userID}, isFriend=$isFriend');
              if (isFriend) {
                print('[ConversationLogic] ✅ 保留1203会话(已是好友)');
                return true; // 已是好友,显示会话
              } else {
                print('[ConversationLogic] ❌ 过滤1203会话(还不是好友)');
              }
            }
          }

          // ⚠️ 重要修复: 群聊会话即使最后一条消息是系统通知也要保留
          // 例如: 1520是群名修改通知,不应该导致整个群聊会话被过滤掉
          if (!conversation.isSingleChat) {
            print(
                '[ConversationLogic] ✅ 保留群聊会话(即使latestMsg是系统通知) contentType=$contentType');
            return true;
          }

          // 其他系统通知过滤掉(仅针对单聊会话)
          print('[ConversationLogic] ❌ 过滤单聊系统通知会话 contentType=$contentType');
          return false;
        }
      }
      return true; // 显示在列表中
    }).toList();

    print('[ConversationLogic] 过滤后会话数: ${filteredList.length}');

    _syncFallbackUnreadCounts(filteredList);
    // dawn 2026-06-21 新增官方人员标识：会话变更后异步补全单聊对象认证状态。
    unawaited(_loadOfficialRolesForConversations(filteredList));
    unawaited(_refreshLatestDisplayMessages(filteredList));

    if (reInstall) {
      onChangeConversations.addAll(filteredList);
    }
    for (var newValue in filteredList) {
      list.removeWhere((e) => e.conversationID == newValue.conversationID);
    }

    if (filteredList.length > pageSize) {
      final tempList = filteredList;

      while (true) {
        final temp = tempList.sublist(0, pageSize);
        list.insertAll(0, temp);
        _sortConversationList();

        if (tempList.length <= pageSize) {
          break;
        }

        tempList.removeRange(0, pageSize);
      }
    } else {
      list.insertAll(0, filteredList);
      _sortConversationList();
    }
    _loadRedPacketStatusCache();
  }

  /// 加载红包已领状态缓存，用于会话列表摘要显示 [已领取] / [待领取]（领取成功后可由 chat 页调用以刷新列表摘要）
  Future<void> loadRedPacketStatusCache() async {
    try {
      _redPacketStatusCache =
          await LuckMoneyStatusManager.getAllLuckMoneyStatuses(
              userId: OpenIM.iMManager.userID);
      _packetOverallStatusCache =
          await LuckMoneyStatusManager.getAllPacketStatuses();
      list.refresh();
    } catch (e) {
      ILogger.e('加载红包状态缓存失败: $e');
    }
  }

  Future<void> _loadRedPacketStatusCache() => loadRedPacketStatusCache();

  /// 若本地缓存无红包状态，则以服务端为准补齐（避免重装或本地被清理后会话列表仍显示[待领取]）
  void _ensureRedPacketStatusFromServer(String msgId) async {
    if (_redPacketStatusCache.containsKey(msgId)) return;
    try {
      final result =
          await _apiService.transactionCheckCompleted(transaction_id: msgId);
      if (result == null) return;
      final Map<String, dynamic>? respData = result is Map<String, dynamic>
          ? (result['data'] ?? result) as Map<String, dynamic>?
          : null;
      final received = respData?['received'] == true;
      final completed = respData?['completed'] == true;

      // 当前用户已领取：写入“已领取”缓存
      if (received) {
        _redPacketStatusCache[msgId] = 'completed';
        await LuckMoneyStatusManager.saveLuckMoneyStatus(msgId, 'completed',
            userId: OpenIM.iMManager.userID);
      }

      // 无论是谁领完，只要红包整体已结束，就写入整体状态缓存，纠正会话预览中的 [待领取]
      if (completed) {
        _packetOverallStatusCache[msgId] = 'completed';
        await LuckMoneyStatusManager.savePacketStatus(msgId, 'completed');
      }

      if (received || completed) {
        list.refresh();
      }
    } catch (e) {
      ILogger.e('从服务端补齐红包状态失败: $e');
    }
  }

  void promptSoundOrNotification(ConversationInfo info) {
    if (imLogic.userInfo.value.globalRecvMsgOpt == 0 &&
        info.recvMsgOpt == 0 &&
        getUnreadCount(info) > 0 &&
        info.latestMsg?.sendID != OpenIM.iMManager.userID) {
      appLogic.promptSoundOrNotification(info.latestMsg!);
    }
  }

  /// 设置会话置顶
  void setPinnedConversation(ConversationInfo info, bool isPinned) async {
    if (isPinned == info.isPinned) {
      return;
    }
    await OpenIM.iMManager.conversationManager.setConversation(
        info.conversationID, ConversationReq(isPinned: isPinned));
  }

  /// 设为已读
  setReadConversation(ConversationInfo info) async {
    _markFallbackUnreadRead(info);
    await OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
      conversationID: info.conversationID,
    );
  }

  /// 删除会话
  void removeConversation(ConversationInfo info) async {
    final confirm =
        await Get.dialog(CustomDialog(title: StrRes.deleteChatWarning));
    if (confirm == true) {
      await OpenIM.iMManager.conversationManager
          .deleteConversationAndDeleteAllMsg(
              conversationID: info.conversationID);
      _fallbackUnreadCounts.remove(info.conversationID);
      _fallbackReadLatestMsgKeys.remove(info.conversationID);
      list.removeWhere((item) => item.conversationID == info.conversationID);
    }
  }

  String getConversationID(ConversationInfo info) {
    return info.conversationID;
  }

  bool _latestMsgBelongsToConversation(ConversationInfo info) {
    final msg = info.latestMsg;
    if (msg == null) return true;
    if (info.isGroupChat) {
      final conversationGroupID = info.groupID ?? '';
      final msgGroupID = msg.groupID ?? '';
      if (conversationGroupID.isNotEmpty &&
          msgGroupID.isNotEmpty &&
          conversationGroupID != msgGroupID) {
        return false;
      }
    }
    return true;
  }

  bool _messageBelongsToConversation(ConversationInfo info, Message msg) {
    if (info.isGroupChat) {
      final conversationGroupID = info.groupID ?? '';
      final msgGroupID = msg.groupID ?? '';
      if (conversationGroupID.isNotEmpty &&
          msgGroupID.isNotEmpty &&
          conversationGroupID != msgGroupID) {
        return false;
      }
    }
    return true;
  }

  bool _isPreviewableMessage(Message msg) {
    final contentType = msg.contentType ?? 0;
    if (contentType == 0) return false;
    if (contentType == MessageType.revokeMessageNotification &&
        _isSilentRevokeMessage(msg)) {
      return false;
    }
    if (contentType >= 1000 &&
        contentType < 2000 &&
        contentType != MessageType.revokeMessageNotification) {
      return false;
    }
    return true;
  }

  bool _isSilentRevokeMessage(Message msg) {
    final detail = msg.notificationElem?.detail;
    if (detail == null || detail.isEmpty) return false;
    try {
      final decoded = json.decode(detail);
      if (decoded is Map) {
        return decoded['officialSilent'] == true;
      }
    } catch (_) {}
    return false;
  }

  String? _stringFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  int? _intFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _decodeRevokeDetail(Message msg) {
    final detail = msg.notificationElem?.detail;
    if (detail == null || detail.isEmpty) return null;
    try {
      final decoded = json.decode(detail);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String? _revokeTargetClientMsgID(Map<String, dynamic> detail) {
    final clientMsgID = _stringFromMap(detail, 'clientMsgID') ??
        _stringFromMap(detail, 'client_msg_id') ??
        _stringFromMap(detail, 'sourceClientMsgID') ??
        _stringFromMap(detail, 'sourceMessageClientMsgID') ??
        _stringFromMap(detail, 'sourceMessageId') ??
        _stringFromMap(detail, 'clientMessageID') ??
        _stringFromMap(detail, 'msgID') ??
        _stringFromMap(detail, 'messageID');
    return clientMsgID == null || clientMsgID.isEmpty ? null : clientMsgID;
  }

  String? _revokeSourceKey(Map<String, dynamic> detail) {
    final sourceID = _stringFromMap(detail, 'sourceMessageSendID');
    final sourceTime = _intFromMap(detail, 'sourceMessageSendTime');
    if (sourceID == null || sourceID.isEmpty || sourceTime == null) {
      return null;
    }
    return '$sourceID|$sourceTime';
  }

  String? _messageSourceKey(Message msg) {
    final sendID = msg.sendID;
    final sendTime = msg.sendTime;
    if (sendID == null || sendID.isEmpty || sendTime == null) return null;
    return '$sendID|$sendTime';
  }

  List<Message> _previewableHistoryMessages(
    ConversationInfo info,
    List<Message> rawMessages,
  ) {
    final scoped = rawMessages
        .where((msg) => _messageBelongsToConversation(info, msg))
        .toList();
    final revokedClientMsgIDs = <String>{};
    final revokedSourceKeys = <String>{};

    for (final msg in scoped) {
      if (msg.contentType != MessageType.revokeMessageNotification) continue;
      final detail = _decodeRevokeDetail(msg);
      if (detail == null) continue;
      final target = _revokeTargetClientMsgID(detail);
      if (target != null && target.isNotEmpty) {
        revokedClientMsgIDs.add(target);
      }
      final sourceKey = _revokeSourceKey(detail);
      if (sourceKey != null) {
        revokedSourceKeys.add(sourceKey);
      }
    }

    return scoped.where((msg) {
      if (msg.contentType != MessageType.revokeMessageNotification) {
        final clientMsgID = msg.clientMsgID;
        if (clientMsgID != null && revokedClientMsgIDs.contains(clientMsgID)) {
          return false;
        }
        final sourceKey = _messageSourceKey(msg);
        if (sourceKey != null && revokedSourceKeys.contains(sourceKey)) {
          return false;
        }
      }
      return _isPreviewableMessage(msg);
    }).toList();
  }

  int _compareMessageOrder(Message a, Message b) {
    final aSeq = a.seq ?? 0;
    final bSeq = b.seq ?? 0;
    if (aSeq > 0 && bSeq > 0 && aSeq != bSeq) {
      return aSeq.compareTo(bSeq);
    }
    return (a.sendTime ?? a.createTime ?? 0)
        .compareTo(b.sendTime ?? b.createTime ?? 0);
  }

  Message? _effectiveLatestMsg(ConversationInfo info) {
    final cached = _latestDisplayMsgCache[info.conversationID];
    if (cached != null) return cached;
    final latest = info.latestMsg;
    if (latest != null && !_isPreviewableMessage(latest)) return null;
    return latest;
  }

  bool _isSamePreviewMessage(Message? a, Message? b) {
    if (a == null || b == null) return a == b;
    final aID = a.clientMsgID ?? a.serverMsgID ?? '';
    final bID = b.clientMsgID ?? b.serverMsgID ?? '';
    if (aID.isNotEmpty || bID.isNotEmpty) return aID == bID;
    return _compareMessageOrder(a, b) == 0 &&
        a.contentType == b.contentType &&
        a.sendID == b.sendID;
  }

  Future<void> _refreshLatestDisplayMessages(
      Iterable<ConversationInfo> conversations) async {
    final targets = conversations
        .where((info) => info.isGroupChat && info.conversationID.isNotEmpty)
        .toList();
    if (targets.isEmpty) return;

    var changed = false;
    for (final info in targets) {
      try {
        final result =
            await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
          conversationID: info.conversationID,
          count: 50,
          startMsg: null,
        );
        final messages =
            _previewableHistoryMessages(info, result.messageList ?? []);
        if (messages.isEmpty) {
          if (_latestDisplayMsgCache.remove(info.conversationID) != null) {
            changed = true;
          }
          continue;
        }
        messages.sort(_compareMessageOrder);
        final latest = messages.last;

        final currentCached = _latestDisplayMsgCache[info.conversationID];
        if (!_isSamePreviewMessage(currentCached, latest)) {
          _latestDisplayMsgCache[info.conversationID] = latest;
          changed = true;
        }
      } catch (e) {
        Logger.print('[ConversationLogic] 刷新本地最新摘要失败: $e');
      }
    }
    if (changed) {
      _sortConversationList();
      list.refresh();
    }
  }

  String? getPrefixTag(ConversationInfo info) {
    if (info.groupAtType == GroupAtType.groupNotification) {
      return '[${StrRes.groupAc}]';
    } else if (info.groupAtType == GroupAtType.atAll) {
      return '[@${StrRes.everyone}]';
    } else if (info.groupAtType == GroupAtType.atAllAtMe) {
      return '[${StrRes.someoneMentionYou}]';
    } else if (info.groupAtType == GroupAtType.atMe) {
      return '[${StrRes.someoneMentionYou}]';
    }
    return null;
  }

  // dawn 2026-05-15 修复手机端会话列表摘要显示暂不支持：未知自定义消息尽量提取真实文案。
  Map<String, dynamic>? _decodeJsonMap(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  String? _readCustomPreviewText(dynamic payload) {
    if (payload is String) {
      final nested = _decodeJsonMap(payload);
      if (nested != null) {
        return _readCustomPreviewText(nested);
      }
      final text = payload.trim();
      if (text.isNotEmpty && !text.startsWith('{') && !text.startsWith('[')) {
        return text;
      }
      return null;
    }

    if (payload is! Map) return null;
    final map = Map<String, dynamic>.from(payload);
    for (final key in ['content', 'text', 'remark', 'msg', 'title']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return _readCustomPreviewText(map['data']);
  }

  String? _getCustomMessagePreview(Message message) {
    final rawData = message.customElem?.data;
    if (rawData == null || rawData.isEmpty) return null;

    final payload = _decodeJsonMap(rawData);
    final preview = _readCustomPreviewText(payload ?? rawData);
    if (preview != null && preview.isNotEmpty) return preview;

    final parsed = IMUtils.parseCustomMessage(message);
    if (parsed is Map) {
      final content = parsed['content']?.toString().trim();
      if (content != null &&
          content.isNotEmpty &&
          content != StrRes.unsupportedMessage &&
          content != '[${StrRes.unsupportedMessage}]') {
        return content;
      }
    }
    return null;
  }

  String _maskPreviewText(String text) =>
      _apiService.maskSensitiveWordsFromCache(text);

  String _formatLatestMsgPreview(
      ConversationInfo info, Message latestMsg, String content) {
    final preview = _maskPreviewText(content);
    if (info.isSingleChat ||
        latestMsg.sendID == OpenIM.iMManager.userID ||
        info.conversationType == ConversationType.notification) {
      return preview;
    }
    return "${latestMsg.senderNickname ?? ''}: $preview ";
  }

  String getContent(ConversationInfo info) {
    try {
      if (null != info.draftText && '' != info.draftText) {
        var map = json.decode(info.draftText!);
        String text = map['text'];
        if (text.isNotEmpty) {
          return text;
        }
      }

      final latestMsg = _effectiveLatestMsg(info);
      if (latestMsg == null) return "";
      if (!_messageBelongsToConversation(info, latestMsg)) return "";

      // 普通文件
      if (latestMsg.contentType == MessageType.file) {
        final fileElem = latestMsg.fileElem;
        if (fileElem != null && fileElem.fileName != null) {
          return '[${StrRes.file}] ${fileElem.fileName}';
        } else {
          return '[${StrRes.file}]';
        }
      }
      if (latestMsg.contentType == MessageType.card) {
        return '[${StrRes.carte}]';
      }
      // 处理自定义消息
      if (latestMsg.contentType == MessageType.custom) {
        try {
          final data = json.decode(latestMsg.customElem!.data!);
          final customType = data['customType'];

          // 处理转账消息
          if (customType == CustomMessageType.transfer) {
            final transferData = data['data'];
            final status = transferData['status'] ?? 'pending';
            final isReceived = transferData['isReceived'] ?? false;

            if (isReceived) {
              return '[${StrRes.received}]';
            } else if (status == 'pending') {
              return '[${StrRes.pendingPayment}]';
            } else {
              return '[${StrRes.transfer}]';
            }
          }

          // 处理红包消息（优先用本地缓存：当前用户是否已领取 + 红包是否整体已结束）
          else if (customType == CustomMessageType.luckMoney) {
            final luckMoneyData = data['data'];
            final msgId = luckMoneyData?['msg_id'] as String?;
            final cacheStatus =
                msgId != null ? _redPacketStatusCache[msgId] : null;
            final overallStatus =
                msgId != null ? _packetOverallStatusCache[msgId] : null;

            // 若本地缓存中无状态或仍为待领取，尝试异步向服务端确认（只查一次），
            // 查到“我已领取”或“红包已结束”后刷新列表，避免长时间显示 [待领取]
            if (msgId != null &&
                (cacheStatus == null || cacheStatus == 'pending') &&
                (overallStatus == null || overallStatus == 'pending')) {
              _ensureRedPacketStatusFromServer(msgId);
            }
            // 当前用户已领取：优先显示 [已领取]
            if (cacheStatus == 'completed') {
              return '[${StrRes.claimed}]';
            }

            // 红包整体已结束但当前用户未领取：不再误显示 [待领取]，退化为通用 [红包] 提示
            if (overallStatus == 'completed') {
              return '[${StrRes.redPacket}]';
            }

            final status = luckMoneyData['status'] ?? 'pending';
            final isReceived = luckMoneyData['isReceived'] ?? false;
            if (isReceived) {
              return '[${StrRes.claimed}]';
            } else if (status == 'pending') {
              return '[${StrRes.toBeClaimed}]';
            } else {
              return '[${StrRes.redPacket}]';
            }
          }
          // 处理恢复消息
          else if (customType == CustomMessageType.recover) {
            final content = data['content']?.toString() ??
                _readCustomPreviewText(data) ??
                '';
            if (content.isNotEmpty) {
              return _maskPreviewText(content);
            }
            return '[恢复消息]';
          } else if (customType == CustomMessageType.call ||
              customType == CustomMessageType.callingInvite ||
              customType == CustomMessageType.callingAccept ||
              customType == CustomMessageType.callingReject ||
              customType == CustomMessageType.callingCancel ||
              customType == CustomMessageType.callingHungup) {
            final type = data['data']?['type'] ?? '';
            if (type == 'video') {
              return '[${StrRes.callVideo}]';
            }
            return '[${StrRes.callVoice}]';
          }
          final customPreview = _getCustomMessagePreview(latestMsg);
          if (customPreview != null && customPreview.isNotEmpty) {
            return _formatLatestMsgPreview(info, latestMsg, customPreview);
          }
        } catch (e) {
          ILogger.e('解析自定义消息失败: $e');
          final customPreview = _getCustomMessagePreview(latestMsg);
          if (customPreview != null && customPreview.isNotEmpty) {
            return _formatLatestMsgPreview(info, latestMsg, customPreview);
          }
        }
      }

      final text = IMUtils.parseNtf(latestMsg, isConversation: true);
      if (text != null) return text;
      if (info.isSingleChat ||
          latestMsg.sendID == OpenIM.iMManager.userID ||
          info.conversationType == ConversationType.notification) {
        return _maskPreviewText(
            IMUtils.parseMsg(latestMsg, isConversation: true));
      }

      return "${latestMsg.senderNickname}: ${_maskPreviewText(IMUtils.parseMsg(latestMsg, isConversation: true))} ";
    } catch (e, s) {
      Logger.print('------e:$e s:$s');
    }
    return '[${StrRes.unsupportedMessage}]';
  }

  String? getAvatar(ConversationInfo info) {
    return info.faceURL;
  }

  bool isGroupChat(ConversationInfo info) {
    return info.isGroupChat;
  }

  String getShowName(ConversationInfo info) {
    if (info.showName == null || info.showName.isBlank!) {
      return info.userID!;
    }
    return info.showName!;
  }

  String getTime(ConversationInfo info) {
    final latestMsg = _effectiveLatestMsg(info);
    if (latestMsg == null || !_messageBelongsToConversation(info, latestMsg)) {
      return "";
    }
    final time =
        latestMsg.sendTime ?? latestMsg.createTime ?? info.latestMsgSendTime;
    if (time == null || time <= 0) return "";
    return IMUtils.getChatTimeline(time);
  }

  int getUnreadCount(ConversationInfo info) {
    if (info.unreadCount > 0) return info.unreadCount;
    return _fallbackUnreadCounts[info.conversationID] ?? 0;
  }

  bool existUnreadMsg(ConversationInfo info) {
    return getUnreadCount(info) > 0;
  }

  bool isUserGroup(int index) => list.elementAt(index).isGroupChat;

  /// 更新好友列表缓存
  void _updateFriendList() async {
    try {
      print('[ConversationLogic] 开始更新好友列表...');
      final friends = await OpenIM.iMManager.friendshipManager.getFriendList();
      _friendUserIDs.clear();
      for (var friend in friends) {
        if (friend.userID != null) {
          _friendUserIDs.add(friend.userID!);
        }
      }
      _friendListLastUpdate = DateTime.now();
      print('[ConversationLogic] 好友列表更新完成, 共${_friendUserIDs.length}个好友');
      print('[ConversationLogic] 好友IDs: $_friendUserIDs');
    } catch (e) {
      print('[ConversationLogic] ❌ 更新好友列表失败: $e');
      Logger.print('[ConversationLogic] 更新好友列表失败: $e');
    }
  }

  /// 检查是否是好友
  bool _checkIsFriend(String userID) {
    // 如果缓存超过30秒,刷新一次
    if (_friendListLastUpdate == null ||
        DateTime.now().difference(_friendListLastUpdate!).inSeconds > 30) {
      _updateFriendList();
    }
    return _friendUserIDs.contains(userID);
  }

  /// 启动好友列表检查定时器
  /// 每5秒检查一次好友列表是否有变化,如果有新好友则刷新会话列表
  void _startFriendCheckTimer() {
    print('[ConversationLogic] 启动好友列表检查定时器');
    _friendCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final friends =
            await OpenIM.iMManager.friendshipManager.getFriendList();
        final newFriendIDs = friends.map((f) => f.userID!).toSet();

        // 检查是否有新好友
        final addedFriends = newFriendIDs.difference(_friendUserIDs);
        if (addedFriends.isNotEmpty) {
          print('[ConversationLogic] 🔔 检测到新好友: $addedFriends');
          _friendUserIDs.addAll(addedFriends);
          _friendListLastUpdate = DateTime.now();

          // 有新好友,刷新会话列表
          print('[ConversationLogic] 刷新会话列表以显示新好友');
          onRefresh();
        }
      } catch (e) {
        print('[ConversationLogic] 检查好友列表失败: $e');
      }
    });
  }

  String? get imSdkStatus {
    switch (imStatus.value) {
      case IMSdkStatus.syncStart:
      case IMSdkStatus.synchronizing:
      case IMSdkStatus.syncProgress:
        return StrRes.synchronizing;
      case IMSdkStatus.syncFailed:
        return StrRes.syncFailed;
      case IMSdkStatus.connecting:
        return StrRes.connecting;
      case IMSdkStatus.connectionFailed:
        return StrRes.connecting;
      // return StrRes.connectionFailed;
      case IMSdkStatus.connectionSucceeded:
      case IMSdkStatus.syncEnded:
        return null;
    }
  }

  bool get isFailedSdkStatus =>
      // imStatus.value == IMSdkStatus.connectionFailed ||
      imStatus.value == IMSdkStatus.syncFailed;

  int _conversationSortTime(ConversationInfo info) {
    final cached = _latestDisplayMsgCache[info.conversationID];
    if (cached != null) {
      return cached.sendTime ??
          cached.createTime ??
          info.latestMsgSendTime ??
          0;
    }
    return info.latestMsgSendTime ?? 0;
  }

  void _sortConversationList() {
    OpenIM.iMManager.conversationManager.simpleSort(list);
    list.sort((a, b) {
      final pinnedA = a.isPinned == true;
      final pinnedB = b.isPinned == true;
      if (pinnedA != pinnedB) return pinnedA ? -1 : 1;
      return _conversationSortTime(b).compareTo(_conversationSortTime(a));
    });
  }

  Future<void> onRefresh() async {
    late List<ConversationInfo> list;
    try {
      list = await _request();
      _syncFallbackUnreadCounts(list, pruneMissing: true);
      this.list.assignAll(list);
      // dawn 2026-06-21 新增官方人员标识：刷新会话列表后补拉单聊角色。
      unawaited(_loadOfficialRolesForConversations(list));
      unawaited(_refreshLatestDisplayMessages(list));
      unawaited(_syncJoinedGroupConversations());

      if (list.isEmpty || list.length < pageSize) {
        refreshController.loadNoData();
      } else {
        refreshController.loadComplete();
      }
    } finally {
      refreshController.refreshCompleted();
    }
  }

  /// 同步失败时点击重试：刷新会话列表（SDK 无“重新同步”接口，仅能重新拉取本地/服务端会话）
  void onRetrySync() async {
    if (imStatus.value != IMSdkStatus.syncFailed) return;
    try {
      EasyLoading.show(status: StrRes.synchronizing);
      await onRefresh();
      EasyLoading.dismiss();
      EasyLoading.showSuccess(StrRes.success);
    } catch (e) {
      Logger.print('重试同步失败: $e');
      EasyLoading.dismiss();
      EasyLoading.showError(StrRes.syncFailed);
    }
  }

  static Future<List<ConversationInfo>> getConversationFirstPage() async {
    final result = await OpenIM.iMManager.conversationManager
        .getConversationListSplit(offset: 0, count: firstPageSize);

    return result;
  }

  void getFirstPage() async {
    final result = homeLogic.conversationsAtFirstPage;

    // 过滤掉系统通知类型的会话，但保留好友相关通知
    final filteredResult = result.where((conversation) {
      final latestMsg = conversation.latestMsg;
      if (latestMsg != null) {
        final contentType = latestMsg.contentType ?? 0;

        // 保留以下通知类型的会话：
        // 1400: OA通知
        // 1201: 好友申请通过通知
        // 1204: 好友添加通知
        final allowedNotificationTypes = [1400, 1201, 1204];

        if (contentType >= 1000 && contentType < 2000) {
          // 如果是允许的通知类型，保留会话
          if (allowedNotificationTypes.contains(contentType)) {
            return true;
          }

          // ⚠️ 重要修复: 群聊会话即使最后一条消息是系统通知也要保留
          // 例如: 1520是群名修改通知,不应该导致整个群聊会话被过滤掉
          if (!conversation.isSingleChat) {
            print(
                '[ConversationLogic] getFirstPage: 保留群聊会话(即使latestMsg是系统通知) contentType=$contentType');
            return true;
          }

          // 其他系统通知过滤掉(仅针对单聊会话)
          return false;
        }
      }
      return true;
    }).toList();

    _syncFallbackUnreadCounts(filteredResult, pruneMissing: true);
    list.assignAll(filteredResult);
    _sortConversationList();
    _loadRedPacketStatusCache();
    // dawn 2026-06-21 新增官方人员标识：首屏会话加载后补全认证图标。
    unawaited(_loadOfficialRolesForConversations(filteredResult));
    unawaited(_refreshLatestDisplayMessages(filteredResult));
    unawaited(_syncJoinedGroupConversations());
  }

  String _normalizeOrgRole(String? role) {
    final text = role?.trim() ?? '';
    if (text.isEmpty) return '';
    const aliases = {
      '管理员': 'GroupManager',
      '组织管理员': 'GroupManager',
      '后台管理员': 'BackendAdmin',
      '超级管理员': 'SuperAdmin',
      '团队长': 'TermManager',
    };
    return aliases[text] ?? text;
  }

  bool _isOfficialOrgRole(String? role) {
    final normalized = _normalizeOrgRole(role).toLowerCase();
    return normalized == 'groupmanager';
  }

  bool isOfficialConversation(ConversationInfo info) {
    // dawn 2026-06-23 修复群聊会话整行 99955 红色溢出：调用处用 Obx 包裹，Obx 的 builder 必须访问到可观察对象。
    // 群聊原本在首行直接 return，不会读取 officialUserMap(RxMap)，导致 Obx 抛 “improper use of GetX”，
    // Flutter 用 ErrorWidget 兜底，而 RenderErrorBox 在无约束空间下默认尺寸为 100000×100000，撑爆整行。
    // 这里无条件先读一次 RxMap，使群聊也建立响应式依赖，再按原逻辑判断。
    final isOfficial = officialUserMap[info.userID] ?? false;
    if (!info.isSingleChat || info.userID == null) return false;
    return isOfficial;
  }

  Future<void> _loadOfficialRolesForConversations(
      Iterable<ConversationInfo> conversations) async {
    final now = DateTime.now();
    final userIDs = conversations
        .where(
            (info) => info.isSingleChat && (info.userID?.isNotEmpty ?? false))
        .map((info) => info.userID!)
        .where((userID) {
          final requestedAt = _officialRoleRequestedAt[userID];
          return requestedAt == null ||
              now.difference(requestedAt) > _officialRoleRefreshInterval;
        })
        .toSet()
        .toList();
    if (userIDs.isEmpty) return;

    for (final userID in userIDs) {
      _officialRoleRequestedAt[userID] = now;
    }

    try {
      final users = await Apis.getUserFullInfo(
        userIDList: userIDs,
        showNumber: userIDs.length,
      );
      if (users == null) return;
      var changed = false;
      for (final user in users) {
        final userID = user.userID;
        if (userID == null || userID.isEmpty) continue;
        final official = _isOfficialOrgRole(user.orgRole);
        if (officialUserMap[userID] != official) {
          officialUserMap[userID] = official;
          changed = true;
        }
      }
      if (changed) {
        officialUserMap.refresh();
      }
    } catch (e) {
      Logger.print('[ConversationLogic] 加载官方人员标识失败: $e');
    }
  }

  void clearConversations() {
    list.clear();
  }

  _request() async {
    final temp = <ConversationInfo>[];

    while (true) {
      var result =
          await OpenIM.iMManager.conversationManager.getConversationListSplit(
        offset: temp.length,
        count: pageSize,
      );
      if (onChangeConversations.isNotEmpty) {
        final bSet = Set.from(onChangeConversations);

        Logger.print(
            'replace conversation: [${onChangeConversations.length}], $bSet');

        for (int i = 0; i < result.length; i++) {
          final info = result[i];

          if (bSet.contains(info)) {
            result[i] =
                onChangeConversations[onChangeConversations.indexOf(info)];
          }
        }
      }
      temp.addAll(result);

      if (result.length < pageSize || temp.length >= pageSize) {
        break;
      }
    }
    onChangeConversations.clear();

    return temp;
  }

  Future<void> _syncJoinedGroupConversations() async {
    if (_syncingJoinedGroupConversations) return;
    _syncingJoinedGroupConversations = true;
    try {
      const count = 200;
      var offset = 0;
      var changed = false;
      final joinedConversationIDs = <String>{};
      while (true) {
        final groups = await OpenIM.iMManager.groupManager
            .getJoinedGroupListPage(offset: offset, count: count);
        if (groups.isEmpty) break;

        final existingIDs = list.map((e) => e.conversationID).toSet();
        for (final group in groups) {
          final groupID = group.groupID;
          if (groupID.isEmpty) continue;
          final conversationID = 'sg_$groupID';
          joinedConversationIDs.add(conversationID);
          if (existingIDs.contains(conversationID)) continue;

          try {
            final conversation =
                await OpenIM.iMManager.conversationManager.getOneConversation(
              sourceID: groupID,
              sessionType: group.sessionType,
            );
            if (conversation.conversationID.isEmpty) continue;
            conversation.showName ??= group.groupName;
            conversation.faceURL ??= group.faceURL;
            list.add(conversation);
            existingIDs.add(conversation.conversationID);
            changed = true;
          } catch (e) {
            Logger.print(
                '[ConversationLogic] 补齐已加入群会话失败: groupID=$groupID, err=$e');
          }
        }

        if (groups.length < count) break;
        offset += groups.length;
      }

      final staleGroupConversations = list
          .where((info) =>
              info.isGroupChat &&
              info.conversationID.isNotEmpty &&
              !joinedConversationIDs.contains(info.conversationID))
          .toList();
      for (final info in staleGroupConversations) {
        try {
          await OpenIM.iMManager.conversationManager
              .deleteConversationAndDeleteAllMsg(
                  conversationID: info.conversationID);
        } catch (e) {
          Logger.print(
              '[ConversationLogic] 清理未加入群会话失败: ${info.conversationID}, err=$e');
        }
        list.removeWhere((e) => e.conversationID == info.conversationID);
        changed = true;
      }

      if (changed) {
        _sortConversationList();
        list.refresh();
      }
    } catch (e) {
      Logger.print('[ConversationLogic] 同步已加入群会话失败: $e');
    } finally {
      _syncingJoinedGroupConversations = false;
    }
  }

  bool isValidConversation(ConversationInfo info) {
    return info.isValid;
  }

  // dawn 2026-06-23 建群后/首次进入会话时，确保该会话已存在于列表中（避免依赖 SDK 回调时序）。
  void _ensureConversationInList(ConversationInfo info) {
    if (info.conversationID.isEmpty) return;
    final exists = list.any((e) => e.conversationID == info.conversationID);
    if (exists) return;
    list.insert(0, info);
    _sortConversationList();
  }

  static Future<ConversationInfo> _createConversation({
    required String sourceID,
    required int sessionType,
  }) =>
      LoadingView.singleton.wrap(
          asyncFunction: () =>
              OpenIM.iMManager.conversationManager.getOneConversation(
                sourceID: sourceID,
                sessionType: sessionType,
              ));

  Future<bool> _jumpOANtf(ConversationInfo info) async {
    if (info.conversationType == ConversationType.notification) {
      return true;
    }
    return false;
  }

  void toChat({
    bool offUntilHome = true,
    String? userID,
    String? groupID,
    String? nickname,
    String? faceURL,
    int? sessionType,
    ConversationInfo? conversationInfo,
    Message? searchMessage,
  }) async {
    conversationInfo ??= await _createConversation(
      sourceID: userID ?? groupID!,
      sessionType: userID == null ? sessionType! : ConversationType.single,
    );

    // dawn 2026-06-23 修复建群后会话列表不生成：进入会话时主动把会话补进列表，
    // 不再完全依赖 SDK 的 onNewConversation 回调（新建群/首次单聊回调可能不触发）。
    _ensureConversationInList(conversationInfo);

    if (await _jumpOANtf(conversationInfo)) {
      _markFallbackUnreadRead(conversationInfo);
      await AppNavigator.startChatNotification(
          conversationInfo: conversationInfo);
      return;
    }

    _markFallbackUnreadRead(conversationInfo);
    await AppNavigator.startChat(
      offUntilHome: offUntilHome,
      draftText: conversationInfo.draftText,
      conversationInfo: conversationInfo,
      searchMessage: searchMessage,
    );

    bool equal(e) => e.conversationID == conversationInfo?.conversationID;

    var groupAtType = list.firstWhereOrNull(equal)?.groupAtType;
    if (groupAtType != GroupAtType.atNormal) {
      OpenIM.iMManager.conversationManager.resetConversationGroupAtType(
        conversationID: conversationInfo.conversationID,
      );
    }
  }

  addFriend() =>
      AppNavigator.startAddContactsBySearch(searchType: SearchType.user);

  createGroup() => AppNavigator.startCreateGroup(
      defaultCheckedList: [OpenIM.iMManager.userInfo]);

  scan() {
    ScanUtil.scan();
  }

  addGroup() =>
      AppNavigator.startAddContactsBySearch(searchType: SearchType.group);

  void globalSearch() => AppNavigator.startGlobalSearch();

  toSearch() {
    AppNavigator.startSearch();
  }
}
