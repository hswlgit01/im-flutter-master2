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
  final pageSize = 400;

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
    imLogic.groupInfoUpdatedSubject.listen((groupInfo) {
      print('[ConversationLogic] 群信息更新: groupID=${groupInfo.groupID}, 新名称: ${groupInfo.groupName}');

      // 构建会话ID (超级群格式: sg_groupID)
      final conversationID = 'sg_${groupInfo.groupID}';

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
    imLogic.imSdkStatusSubject.listen((value) async {
      final status = value.status;
      final appReInstall = value.reInstall;
      final progress = value.progress;
      imStatus.value = status;

      if (status == IMSdkStatus.syncStart) {
        reInstall = appReInstall;
        if (reInstall) {
          EasyLoading.showProgress(0, status: StrRes.synchronizing);
        }
      }

      if (status == IMSdkStatus.syncProgress && reInstall) {
        final p = (progress!).toDouble() / 100.0;

        EasyLoading.showProgress(p,
            status: '${StrRes.synchronizing}(${(p * 100.0).truncate()}%)');
      } else if (status == IMSdkStatus.syncEnded ||
          status == IMSdkStatus.syncFailed) {
        EasyLoading.dismiss();
        if (reInstall) {
          onRefresh();
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
              print('[ConversationLogic] 检查1203会话: userID=${conversation.userID}, isFriend=$isFriend');
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
            print('[ConversationLogic] ✅ 保留群聊会话(即使latestMsg是系统通知) contentType=$contentType');
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

    // Removed unread count fixing logic - backend handles this correctly now

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
          await LuckMoneyStatusManager.getAllLuckMoneyStatuses(userId: OpenIM.iMManager.userID);
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
      final result = await _apiService.transactionCheckCompleted(transaction_id: msgId);
      if (result == null) return;
      final Map<String, dynamic>? respData =
          result is Map<String, dynamic> ? (result['data'] ?? result) as Map<String, dynamic>? : null;
      final received = respData?['received'] == true;
      final completed = respData?['completed'] == true;

      // 当前用户已领取：写入“已领取”缓存
      if (received) {
        _redPacketStatusCache[msgId] = 'completed';
        await LuckMoneyStatusManager.saveLuckMoneyStatus(
            msgId, 'completed', userId: OpenIM.iMManager.userID);
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
        info.unreadCount > 0 &&
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
      list.removeWhere((item) => item.conversationID == info.conversationID);
    }
  }

  String getConversationID(ConversationInfo info) {
    return info.conversationID;
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

  String getContent(ConversationInfo info) {
    try {
      if (null != info.draftText && '' != info.draftText) {
        var map = json.decode(info.draftText!);
        String text = map['text'];
        if (text.isNotEmpty) {
          return text;
        }
      }

      if (null == info.latestMsg) return "";

      // 普通文件
      if (info.latestMsg!.contentType == MessageType.file) {
        final fileElem = info.latestMsg!.fileElem;
        if (fileElem != null && fileElem.fileName != null) {
          return '[${StrRes.file}] ${fileElem.fileName}';
        } else {
          return '[${StrRes.file}]';
        }
      }
      if (info.latestMsg?.contentType == MessageType.card) {
        return '[${StrRes.carte}]';
      }
      // 处理自定义消息
      if (info.latestMsg!.contentType == MessageType.custom) {
        try {
          final data = json.decode(info.latestMsg!.customElem!.data!);
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
            final content = data['content'] ?? '';
            if (content.isNotEmpty) {
              return content;
            }
            return '[恢复消息]';
          } else if (customType == CustomMessageType.call ||
              customType == CustomMessageType.callingInvite ||
              customType == CustomMessageType.callingAccept ||
              customType == CustomMessageType.callingReject ||
              customType == CustomMessageType.callingCancel ||
              customType == CustomMessageType.callingHungup
              ) {
            final type = data['data']?['type'] ?? '';
            if (type == 'video') {
              return '[${StrRes.callVideo}]';
            }
            return '[${StrRes.callVoice}]';
          }
        } catch (e) {
          ILogger.e('解析自定义消息失败: $e');
        }
      }

      final text = IMUtils.parseNtf(info.latestMsg!, isConversation: true);
      if (text != null) return text;
      if (info.isSingleChat ||
          info.latestMsg!.sendID == OpenIM.iMManager.userID ||
          info.conversationType == ConversationType.notification)
        return IMUtils.parseMsg(info.latestMsg!, isConversation: true);

      return "${info.latestMsg!.senderNickname}: ${IMUtils.parseMsg(info.latestMsg!, isConversation: true)} ";
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
    return IMUtils.getChatTimeline(info.latestMsgSendTime!);
  }

  int getUnreadCount(ConversationInfo info) {
    return info.unreadCount;
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
        final friends = await OpenIM.iMManager.friendshipManager.getFriendList();
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

  void _sortConversationList() =>
      OpenIM.iMManager.conversationManager.simpleSort(list);

  Future<void> onRefresh() async {
    late List<ConversationInfo> list;
    try {
      list = await _request();
      this.list.assignAll(list);

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
        .getConversationListSplit(offset: 0, count: 400);

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
            print('[ConversationLogic] getFirstPage: 保留群聊会话(即使latestMsg是系统通知) contentType=$contentType');
            return true;
          }

          // 其他系统通知过滤掉(仅针对单聊会话)
          return false;
        }
      }
      return true;
    }).toList();

    list.assignAll(filteredResult);
    _sortConversationList();
    _loadRedPacketStatusCache();
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

      if (result.length < pageSize) {
        break;
      }
    }
    onChangeConversations.clear();

    return temp;
  }

  bool isValidConversation(ConversationInfo info) {
    return info.isValid;
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

    if (await _jumpOANtf(conversationInfo)) {
      await AppNavigator.startChatNotification(
          conversationInfo: conversationInfo);
      return;
    }

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
