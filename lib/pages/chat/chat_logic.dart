import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chat_bottom_container/panel_container.dart';
import 'package:chat_listview/chat_listview.dart';
import 'package:collection/collection.dart';
import 'package:common_utils/common_utils.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/chat/chat_merge.dart';
import 'package:openim/pages/discover/Live/meeting_view.dart';
import 'package:openim/utils/debug_log_uploader.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/openim_live.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/message_deduplicator.dart'; // 添加消息去重器
import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';
import '../contacts/select_contacts/select_contacts_logic.dart';
import '../conversation/conversation_logic.dart';
import 'group_setup/group_member_list/group_member_list_logic.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/transfer_status_manager.dart';
import '../../../utils/luck_money_status_manager.dart';
import 'widget/emoji_picker.dart';
import '../../core/security_manager.dart';

class ChatListViewController<E> extends CustomChatListViewController<E> {
  ChatListViewController(super.list, {required this.scrollController});

  final AutoScrollController scrollController;
  final RxList<E> _rxList = <E>[].obs;

  RxList<E> get rxList => _rxList;

  clear() {
    super.topList.clear();
    super.bottomList.clear();
    _rxList.clear();
  }

  // 检查是否在滚动视图的底部
  bool _isAtBottom() {
    if (!scrollController.hasClients) return true;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    // 允许一些误差范围（比如50像素），因为用户可能不是完全滚动到底部
    return (maxScroll - currentScroll) < 50;
  }

  refresh() {
    _rxList.refresh(); // 触发UI更新
  }

  @override
  void insertToBottom(E data) {
    super.insertToBottom(data);

    // 只有当用户在底部附近且是新接收的消息时才自动滚动
    // 删除操作或其他批量操作不应该触发自动滚动
    if (_isAtBottom()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          ScrollControllerExt(scrollController).scrollToBottom();
        }
      });
    }
    _rxList.add(data);
  }

  @override
  void insertToTop(E data) {
    super.insertToTop(data);
    _rxList.insert(0, data); // 触发UI更新
  }

  @override
  void insertAllToBottom(Iterable<E> iterable) {
    super.insertAllToBottom(iterable);
    _rxList.addAll(iterable); // 触发UI更新
    // 批量插入时不自动滚动，避免删除消息后意外滚动到底部
  }

  @override
  void insertAllToTop(Iterable<E> iterable) {
    super.insertAllToTop(iterable);
    _rxList.insertAll(0, iterable); // 触发UI更新
  }

  @override
  bool remove(Object? value) {
    if (super.bottomList.contains(value)) {
      _rxList.remove(value); // 触发UI更新
      return super.bottomList.remove(value);
    } else if (super.topList.contains(value)) {
      _rxList.remove(value); // 触发UI更新
      return super.topList.remove(value);
    } else {
      ILogger.w('尝试删除的元素不在列表中: $value');
      return false;
    }
  }

  Future jumpToElement(E data) {
    return scrollController.scrollToIndex(
      list.indexOf(data),
      duration: const Duration(milliseconds: 1),
      preferPosition: AutoScrollPosition.begin,
    );
  }
}

extension ScrollControllerExt on ScrollController {
  /// 滚动到底部
  Future<void> scrollToBottom() async {
    final completer = Completer<void>();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        while (position.pixels != position.maxScrollExtent) {
          jumpTo(position.maxScrollExtent);
          await SchedulerBinding.instance.endOfFrame;
        }
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// 滚动到顶部
  Future<void> scrollToTop() async {
    final completer = Completer<void>();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        while (position.pixels != position.minScrollExtent) {
          jumpTo(position.minScrollExtent);
          await SchedulerBinding.instance.endOfFrame;
        }
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }
}

class ChatLogic extends SuperController with WidgetsBindingObserver {
  final imLogic = Get.find<IMController>();
  final appLogic = Get.find<AppController>();
  final conversationLogic = Get.find<ConversationLogic>();
  final cacheLogic = Get.find<CacheController>();
  final orgController = Get.find<OrgController>();

  final inputCtrl = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = AutoScrollController();
  final isReadyToShow = false.obs;
  final enabledBottomLoad = false.obs;
  final enabledTopLoad = true.obs;
  /// 首次加载时本地无消息（如同步未拉取到该会话），用于展示空状态与重试
  final firstLoadEmpty = false.obs;
  /// 正在执行“重试加载历史”（同步+拉取）时为 true，用于界面显示“正在同步…”
  final retryingLoadHistory = false.obs;
  /// 红包状态缓存（msg_id -> status），会话内从本地恢复后写入，供 item 用 Obx 订阅，避免重启后仍显示待领取
  final redPacketStatusMap = <String, String>{}.obs;
  late final ChatListViewController<Message> customChatListViewController;
  final refreshController = RefreshController();

  // 应用前后台状态
  var _isAppInForeground = true;
  bool playOnce = false; // 点击的当前视频只能播放一次

  /// 语音管理
  late final AudioPlayerManager _audioManager = AudioPlayerManager();

  final forceCloseToolbox = PublishSubject<bool>();
  final toolboxController = ChatBottomPanelContainerController<PanelType>();
  final sendStatusSub = PublishSubject<MsgStreamEv<bool>>();

  late ConversationInfo conversationInfo;
  final GlobalKey scrollViewKey = GlobalKey();
  Message? searchMessage;
  final nickname = ''.obs;
  final faceUrl = ''.obs;
  final isReadNotification = true.obs;
  final notification = "".obs;
  Timer? _debounce;
  // 最近一次向对端上报“正在输入”状态的时间戳（毫秒）
  int _lastTypingNotifyMs = 0;
  final tempMessages = <Message>[]; // 临时存放消息体，例如图片消息
  final scaleFactor = Config.textScaleFactor.obs;
  final background = "".obs;
  final memberUpdateInfoMap = <String, GroupMembersInfo>{};
  final groupMessageReadMembers = <String, List<String>>{};
  final groupMemberRoleLevel = 1.obs;
  GroupInfo? groupInfo;
  GroupMembersInfo? groupMembersInfo;
  List<GroupMembersInfo> ownerAndAdmin = [];

  final quote = Rxn<Message?>(null);

  final isInGroup = true.obs;
  final memberCount = 0.obs;
  final lookMemberInfo = 0.obs;
  final privateMessageList = <Message>[];
  final isInBlacklist = false.obs;

  final announcement = ''.obs;
  late StreamSubscription conversationSub;
  late StreamSubscription newMessageSub;  // 新增：订阅新消息Subject
  late StreamSubscription revokedMessageSub;
  late StreamSubscription memberAddSub;
  late StreamSubscription memberDelSub;
  late StreamSubscription joinedGroupAddedSub;
  late StreamSubscription joinedGroupDeletedSub;
  StreamSubscription? c2cReadReceiptSub;
  late StreamSubscription memberInfoChangedSub;
  late StreamSubscription groupInfoUpdatedSub;
  late StreamSubscription friendInfoChangedSub;
  StreamSubscription? userStatusChangedSub;
  StreamSubscription? selfInfoUpdatedSub;
  var curMsgAtUserInfos = <AtUserInfo>[];
  var _lastCursorIndex = -1;

  late StreamSubscription connectionSub;
  final syncStatus = IMSdkStatus.syncEnded.obs;
  int? lastMinSeq;

  final showCallingMember = false.obs;

  bool _isReceivedMessageWhenSyncing = false;
  bool _isStartSyncing = false;
  bool _isFirstLoad = true;

  final copyTextMap = <String?, String?>{};

  String? groupOwnerID;

  final _pageSize = 20;

  RTCBridge? get rtcBridge => PackageBridge.rtcBridge;

  bool get rtcIsBusy => rtcBridge?.hasConnection == true;

  List<Message> get messageList => customChatListViewController.list;

  String? get userID => conversationInfo.userID;

  String? get groupID => conversationInfo.groupID;

  bool get isSingleChat => null != userID && userID!.trim().isNotEmpty;

  bool get isGroupChat => null != groupID && groupID!.trim().isNotEmpty;

  String? get senderName => isSingleChat
      ? OpenIM.iMManager.userInfo.nickname
      : groupMembersInfo?.nickname;

  bool get isAdmin => groupMemberRoleLevel.value == GroupRoleLevel.admin;

  bool get isOwner => groupMemberRoleLevel.value == GroupRoleLevel.owner;

  bool get isAdminOrOwner => isAdmin || isOwner;

  final isMute = false.obs;
  Timer? _muteTimer;
  /// 仅作兜底：长间隔轮询（秒），0=关闭。实时主要靠 1514/1515 推送 + 收到群通知时防抖拉取，避免高并发下短周期轮询压垮服务端
  static const int _kGroupMutedFallbackPollSeconds = 60;
  Timer? _groupMutedRefreshTimer;
  Timer? _groupInfoDebounceTimer;

  /// 群禁言状态（status == 3），单独提为响应式，方便根据通知/GroupInfo 变更实时刷新 UI
  final _groupMuted = false.obs;
  /// 最近一次由 _queryGroupInfo（服务端）设置禁言状态的时间（ms），用于避免 SDK 推送的过期 GroupInfo 覆盖正确结果
  int? _lastGroupMutedFromServerMs;
  /// 当首次拉取到 status==3 时，延迟再拉一次以绕过 SDK 缓存（仅一次）
  Timer? _groupMutedRetryTimer;
  bool _groupMutedRetryScheduled = false;

  bool get isGroupMute => _groupMuted.value && !isAdminOrOwner;
  bool get enabled => !isMute.value && !isGroupMute;

  String get memberStr {
    var roleLength = isOwner ? 2 : (isAdmin ? 1 : 0);

    var isShow = (lookMemberInfo.value - roleLength) < 2;
    return isSingleChat ? "" : (isShow ? "($memberCount)" : "");
  }

  final unreadCount = 0.obs;
  final inTime = DateTime.now().millisecondsSinceEpoch;

  final directionalUsers = <GroupMembersInfo>[].obs;
  final apiService = core.ApiService();

  final securityManager = SecurityManager();

  bool isCurrentChat(Message message) {
    var senderId = message.sendID;
    var receiverId = message.recvID;
    var groupId = message.groupID;
    var myUserID = OpenIM.iMManager.userID;

    print('========== isCurrentChat 判断 ==========');
    print('[ChatLogic] message.sendID=$senderId');
    print('[ChatLogic] message.recvID=$receiverId');
    print('[ChatLogic] this.userID=$userID');
    print('[ChatLogic] this.conversationInfo.userID=${conversationInfo.userID}');
    print('[ChatLogic] this.conversationInfo.conversationID=${conversationInfo.conversationID}');
    print('[ChatLogic] myUserID=$myUserID');
    print('[ChatLogic] message.isSingleChat=${message.isSingleChat}');
    print('[ChatLogic] this.isSingleChat=$isSingleChat');

    // 修复：使用conversationID来判断消息是否属于当前会话
    // 单聊conversationID格式: si_{userID1}_{userID2}
    // 只要消息的发送者和接收者组合与当前会话匹配即可
    var isCurSingleChat = false;
    if (message.isSingleChat && isSingleChat) {
      // 方案1：检查消息是否涉及当前会话的双方
      // conversationID 包含了双方的 userID
      var conversationID = conversationInfo.conversationID;
      var containsSender = conversationID.contains(senderId ?? '');
      var containsReceiver = conversationID.contains(receiverId ?? '');
      var containsMyID = conversationID.contains(myUserID ?? '');

      // 消息必须涉及我（发送者或接收者之一是我）
      // 且消息的另一方也在conversationID中
      if (senderId == myUserID) {
        // 我发送的消息：接收者必须在conversationID中
        isCurSingleChat = containsReceiver;
      } else if (receiverId == myUserID) {
        // 我接收的消息：发送者必须在conversationID中
        isCurSingleChat = containsSender;
      }

      print('[ChatLogic] conversationID=$conversationID');
      print('[ChatLogic] containsSender=$containsSender');
      print('[ChatLogic] containsReceiver=$containsReceiver');
      print('[ChatLogic] containsMyID=$containsMyID');
    }

    print('[ChatLogic] 条件检查:');
    print('[ChatLogic]   message.isSingleChat=${message.isSingleChat}');
    print('[ChatLogic]   this.isSingleChat=$isSingleChat');
    print('[ChatLogic]   senderId == myUserID: ${senderId == myUserID}');
    print('[ChatLogic]   receiverId == myUserID: ${receiverId == myUserID}');
    print('[ChatLogic] isCurSingleChat=$isCurSingleChat');

    var isCurGroupChat =
        message.isGroupChat && isGroupChat && groupID == groupId;

    final result = isCurSingleChat || isCurGroupChat;
    print('[ChatLogic] isCurrentChat 结果=$result');
    print('========================================');

    return result;
  }

  Future scrollBottom() {
    return ScrollControllerExt(scrollController).scrollToBottom();
  }

  onSeeNewMessage() {
    _clearUnreadCount();
    customChatListViewController.jumpToElement(customChatListViewController.list
        .firstWhere((e) =>
    e.sendID != OpenIM.iMManager.userID &&
        !e.isRead! &&
        isShowReadStatus(e) &&
        e.sendTime! < inTime));
  }

  Future<List<Message>> searchMediaMessage() async {
    final messageList = await OpenIM.iMManager.messageManager
        .searchLocalMessages(
        conversationID: conversationInfo.conversationID,
        messageTypeList: [MessageType.picture, MessageType.video],
        count: 500);
    return messageList.searchResultItems?.first.messageList?.reversed
        .toList() ??
        [];
  }

  @override
  void onReady() {
    _resetGroupAtType();
    appLogic.setActiveConversation(
      conversationInfo.conversationID,
    );
    if (isGroupChat) {
      _groupMutedRetryScheduled = false; // 进入群聊允许一次“status=3 时延迟再拉”
      // dawn 2026-04-26 修复进群即显示"已退出群聊"：
      // joinedGroupDeletedSubject 是 BehaviorSubject，订阅时会回放上一次 leave 事件，
      // 若 groupID 恰好命中（再次被加入同一个群、或 sub 缓存窜场），会把 isInGroup
      // 误置成 false。onReady 主动调 SDK 拿真实成员状态覆盖回去。
      _isJoinedGroup();
      _queryMyGroupMemberInfo();
      _queryGroupInfo();
      _groupMutedRefreshTimer?.cancel();
      if (_kGroupMutedFallbackPollSeconds > 0) {
        _groupMutedRefreshTimer = Timer.periodic(
          Duration(seconds: _kGroupMutedFallbackPollSeconds),
              (_) => _queryGroupInfo(),
        );
      }
    }
    super.onReady();
  }

  @override
  void onInit() {
    customChatListViewController =
        ChatListViewController([], scrollController: scrollController);
    var arguments = Get.arguments;
    conversationInfo = arguments['conversationInfo'];
    searchMessage = arguments['searchMessage'];
    nickname.value = conversationInfo.showName ?? '';
    faceUrl.value = conversationInfo.faceURL ?? '';
    _initChatConfig();
    _setSdkSyncDataListener();

    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    orgController.refreshRules();

    // 初始化转账状态
    _initTransferStatusAndHistory();
    // 红包状态在 initMessageList 加载完消息后再初始化，见 initMessageList()
    initMessageList();

    conversationSub = imLogic.conversationChangedSubject.listen((value) {
      final obj = value.firstWhereOrNull(
              (e) => e.conversationID == conversationInfo.conversationID);

      if (obj != null) {
        conversationInfo = obj;
        unreadCount.value = customChatListViewController.list.where((e) {
          return e.sendID != OpenIM.iMManager.userID &&
              !e.isRead! &&
              isShowReadStatus(e) &&
              e.sendTime! < inTime;
        }).length;
      }
    });

    print('========================================');
    print('[ChatLogic] onInit: 准备设置消息监听');
    print('[ChatLogic] conversationID=${conversationInfo.conversationID}');
    print('[ChatLogic] conversationInfo.userID=${conversationInfo.userID}');
    print('[ChatLogic] conversationInfo.groupID=${conversationInfo.groupID}');
    print('[ChatLogic] conversationInfo.showName=${conversationInfo.showName}');
    print('[ChatLogic] this.userID=$userID');
    print('[ChatLogic] this.groupID=$groupID');
    print('[ChatLogic] OpenIM.iMManager.userID=${OpenIM.iMManager.userID}');
    print('[ChatLogic] isSingleChat=$isSingleChat');
    print('========================================');

    // 只使用新消息Subject订阅方式，避免双重监听导致重复消息
    newMessageSub = imLogic.newMessageSubject.listen((Message message) async {
      print('[ChatLogic] ✅ newMessageSub收到消息: ${message.contentType}');
      _handleNewMessage(message);
    });

    revokedMessageSub = imLogic.revokedMessageSubject.listen((RevokedInfo value) {
      final updated = _applyRevokedInfo(value);
      if (!updated) {
        Future.microtask(_loadHistoryForSyncEnd);
      }
    });

    // 取消设置直接回调，防止双重监听
    // imLogic.onRecvNewMessage = null; // 无法设为null，这是SDK中定义的回调
    // 为了清晰起见，我们仍然设置回调，但在回调中什么也不做
    imLogic.onRecvNewMessage = (Message message) async {
      print('[ChatLogic] ⚠️ onRecvNewMessage回调收到消息，但已被禁用: ${message.contentType}');
      // 不再调用_handleNewMessage，避免重复处理
    };

    print('[ChatLogic] ✅ 消息监听设置完成');

    // 使用全局已读回执广播订阅，实现实时同步（不覆盖全局回调，避免切会话时丢失）
    c2cReadReceiptSub = imLogic.c2cReadReceiptSubject.listen((List<ReadReceiptInfo> list) {
      try {
        if (list.isNotEmpty) {
          print('[ChatLogic] 📬 已读回执广播: 当前会话userID=$userID, 回执userIDs=${list.map((r) => r.userID).toList()}');
        }
        // dawn 2026-04-27 修已读不更新：和撤回/sending 状态同因——message.isRead
        // 只是被 mutate 在原对象上，customChatListViewController.refresh() 不会让
        // SliverList 现有 item 重建。改成收集 touched clientMsgID 走 _rebuildItemsByClientMsgID
        // 强制 itemBuilder rebuild，已读勾标和阅读时间立刻在气泡边上更新。
        final touched = <String>{};
        var matchedAny = false;
        for (var readInfo in list) {
          if (readInfo.userID != userID) continue;
          matchedAny = true;
          print('[ChatLogic] ✅ 已读回执匹配当前会话, 应用已读 userID=$userID');
          _applyOneReadReceipt(readInfo, touched);
        }
        // dawn 2026-04-27 临时排查：上报每次回执处理结果
        DebugLogUploader.send('read_receipt', {
          'broadcastCount': list.length,
          'currentUserID': userID,
          'matched': matchedAny,
          'touchedCount': touched.length,
          'broadcastUserIDs': list.map((r) => r.userID).toList(),
        });
        if (touched.isNotEmpty) {
          _rebuildItemsByClientMsgID(touched);
        }
      } catch (e) {
        ILogger.d('c2cReadReceiptSubject error: $e');
      }
    });

    joinedGroupAddedSub = imLogic.joinedGroupAddedSubject.listen((event) {
      if (event.groupID == groupID) {
        isInGroup.value = true;
        _queryGroupInfo();
      }
    });

    joinedGroupDeletedSub = imLogic.joinedGroupDeletedSubject.listen((event) {
      if (event.groupID == groupID) {
        isInGroup.value = false;
        inputCtrl.clear();
      }
    });

    memberAddSub = imLogic.memberAddedSubject.listen((info) {
      var groupId = info.groupID;
      if (groupId == groupID) {
        _putMemberInfo([info]);
      }
    });

    memberDelSub = imLogic.memberDeletedSubject.listen((info) {
      if (info.groupID == groupID && info.userID == OpenIM.iMManager.userID) {
        isInGroup.value = false;
        inputCtrl.clear();
      }
    });

    memberInfoChangedSub = imLogic.memberInfoChangedSubject.listen((info) {
      if (info.groupID == groupID) {
        if (info.userID == OpenIM.iMManager.userID) {
          groupMemberRoleLevel.value = info.roleLevel ?? GroupRoleLevel.member;
          groupMembersInfo = info;
          _updateMuteStatus();
        }
        _putMemberInfo([info]);

        final index = ownerAndAdmin
            .indexWhere((element) => element.userID == info.userID);
        if (info.roleLevel == GroupRoleLevel.member) {
          if (index > -1) {
            ownerAndAdmin.removeAt(index);
          }
        } else if (info.roleLevel == GroupRoleLevel.admin ||
            info.roleLevel == GroupRoleLevel.owner) {
          if (index == -1) {
            ownerAndAdmin.add(info);
          } else {
            ownerAndAdmin[index] = info;
          }
        }

        for (var msg in messageList) {
          if (msg.sendID == info.userID) {
            if (msg.isNotificationType) {
              final map = json.decode(msg.notificationElem!.detail!);
              final ntf = GroupNotification.fromJson(map);
              ntf.opUser?.nickname = info.nickname;
              ntf.opUser?.faceURL = info.faceURL;
              msg.notificationElem?.detail = jsonEncode(ntf);
            } else {
              msg.senderFaceUrl = info.faceURL;
              msg.senderNickname = info.nickname;
            }
          }
        }
      }
    });

    groupInfoUpdatedSub = imLogic.groupInfoUpdatedSubject.listen((value) {
      if (groupID == value.groupID) {
        groupInfo = value;
        // 群解散 (status == 2): 清空当前聊天的内存列表，让用户在退出前就看不到
        // 老的历史。conversation_logic 的同名监听会删本地 DB 的会话与消息，
        // 再次进入时从空 DB 载入，符合 bug 1 的期望——对方不应继续看到历史。
        if ((value.status ?? 0) == 2) {
          messageList.clear();
          customChatListViewController.clear();
          update();
          return;
        }
        // 禁言状态以服务端拉取为准：若 3 秒内刚执行过 _queryGroupInfo，不采用 SDK 推送的 status，避免过期缓存覆盖正确结果
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (_lastGroupMutedFromServerMs == null ||
            (nowMs - _lastGroupMutedFromServerMs!) > 3000) {
          _groupMuted.value = (value.status ?? 0) == 3;
        }
        nickname.value = value.groupName ?? '';
        faceUrl.value = value.faceURL ?? '';
        notification.value = value.notification ?? '';
        setIsReadNotification();
        memberCount.value = value.memberCount ?? 0;
        lookMemberInfo.value = value.lookMemberInfo ?? 0;
        // 刷新 UI，使禁言状态 isGroupMute / enabled 及时更新
        update();
      }
    });

    friendInfoChangedSub = imLogic.friendInfoChangedSubject.listen((value) {
      if (userID == value.userID) {
        nickname.value = value.getShowName();
        faceUrl.value = value.faceURL ?? '';

        for (var msg in messageList) {
          if (msg.sendID == value.userID) {
            msg.senderFaceUrl = value.faceURL;
            msg.senderNickname = value.nickname;
          }
        }
      }
    });

    selfInfoUpdatedSub = imLogic.selfInfoUpdatedSubject.listen((value) {
      for (var msg in messageList) {
        if (msg.sendID == value.userID) {
          msg.senderFaceUrl = value.faceURL;
          msg.senderNickname = value.nickname;
        }
      }
    });

    inputCtrl.addListener(() {
      // 记录最近一次光标位置，用于长按头像插入 @ 时复用
      _lastCursorIndex = inputCtrl.selection.start;

      // 仅在群聊中、光标前一个字符为 @ 时触发 @ 成员选择
      atMember();

      // 对“正在输入”状态做简单节流，避免每个字符都发一次 IM 调用
      final now = DateTime.now().millisecondsSinceEpoch;
      const typingIntervalMs = 800; // 800ms 内最多上报一次 focus=true
      if (now - _lastTypingNotifyMs >= typingIntervalMs) {
        _lastTypingNotifyMs = now;
        sendTypingMsg(focus: true);
      }

      // 使用防抖在用户停止输入一段时间后上报 focus=false
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(1.seconds, () {
        sendTypingMsg(focus: false);
      });
    });

    imLogic.onSignalingMessage = (value) {
      if (value.userID == userID) {
        customChatListViewController.insertToBottom(value.message);
        scrollBottom();
      }
    };
    super.onInit();
  }

  bool _applyRevokedInfo(RevokedInfo value) {
    final detail = value.toJson();
    var updated = false;
    final touched = <String>{};
    for (var msg in messageList) {
      if (_matchesRevokedMessage(msg, value) &&
          msg.contentType != MessageType.revokeMessageNotification) {
        updated = true;
        msg.contentType = MessageType.revokeMessageNotification;
        msg.notificationElem = NotificationElem(
          detail: json.encode(_normalizeRevokeDetail(detail, msg)),
        );
        if (msg.clientMsgID != null) touched.add(msg.clientMsgID!);
      }
    }
    // dawn 2026-04-27 临时：每次 _applyRevokedInfo 结束都上报一下命中情况
    DebugLogUploader.send('apply_revoked_info', {
      'targetClientMsgID': value.clientMsgID,
      'matched': updated,
      'touchedCount': touched.length,
      'messageListLen': messageList.length,
    });
    if (updated) {
      // dawn 2026-04-27 修撤回不同步：仅 mutate Message + refresh() 时，由于 SliverList
      // 的既有 item 不会被 markNeedsBuild，bubble 仍显示原文。把 rxList 中对应 index
      // 重新赋同一个引用，触发 GetX list 元素变更事件，强制 itemBuilder rebuild。
      _rebuildItemsByClientMsgID(touched);
      update();
    }
    return updated;
  }

  /// dawn 2026-04-27 撤回 / 状态变更后，把 rxList 中对应 clientMsgID 的元素重新赋值，
  /// 触发 GetX 的索引变更事件，让 SliverChildBuilderDelegate 把对应 item rebuild。
  void _rebuildItemsByClientMsgID(Set<String> clientMsgIDs) {
    if (clientMsgIDs.isEmpty) {
      customChatListViewController.refresh();
      return;
    }
    final rxList = customChatListViewController.rxList;
    var hit = false;
    for (var i = 0; i < rxList.length; i++) {
      final id = rxList[i].clientMsgID;
      if (id != null && clientMsgIDs.contains(id)) {
        rxList[i] = rxList[i];
        hit = true;
      }
    }
    if (!hit) {
      rxList.refresh();
    }
  }

  bool _matchesRevokedMessage(Message msg, RevokedInfo value) {
    final clientMsgID = value.clientMsgID;
    return clientMsgID != null &&
        clientMsgID.isNotEmpty &&
        msg.clientMsgID == clientMsgID;
  }

  String? _stringFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    return value.toString();
  }

  int? _intFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _revokeTargetClientMsgID(Map<String, dynamic> detail) {
    // dawn 2026-04-27 增强：原版只看 clientMsgID/client_msg_id；不同 SDK / 序列化
    // 路径里也可能用 sourceClientMsgID / sourceMessageClientMsgID / clientMessageID
    // / msgID 等命名。多挂几个备胎，命中一个就行。
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

  Map<String, dynamic> _decodeRevokeDetail(String detail) {
    final decoded = json.decode(detail);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    ILogger.d('revoke notification detail is not a map: $detail');
    return <String, dynamic>{};
  }

  String _cachedNicknameForUser(String? userID) {
    if (userID == null || userID.isEmpty) return '';
    if (userID == OpenIM.iMManager.userID) {
      return OpenIM.iMManager.userInfo.nickname ?? '';
    }
    if (isSingleChat && userID == conversationInfo.userID) {
      return conversationInfo.showName ?? nickname.value;
    }
    final member = memberUpdateInfoMap[userID] ??
        ownerAndAdmin.firstWhereOrNull((member) => member.userID == userID);
    return member?.nickname ?? '';
  }

  Map<String, dynamic> _normalizeRevokeDetail(
    Map<String, dynamic> detail,
    Message sourceMessage,
  ) {
    final revokerID = _stringFromMap(detail, 'revokerID') ??
        _stringFromMap(detail, 'revokerUserID');
    final sourceSendID =
        _stringFromMap(detail, 'sourceMessageSendID') ?? sourceMessage.sendID;
    final sourceNickname = _stringFromMap(detail, 'sourceMessageSenderNickname') ??
        sourceMessage.senderNickname ??
        '';
    var revokerNickname = _stringFromMap(detail, 'revokerNickname');
    if ((revokerNickname == null || revokerNickname.isEmpty) &&
        revokerID != null &&
        revokerID == sourceSendID) {
      revokerNickname = sourceNickname;
    } else if ((revokerNickname == null || revokerNickname.isEmpty) &&
        revokerID == OpenIM.iMManager.userID) {
      revokerNickname = OpenIM.iMManager.userInfo.nickname ?? '';
    } else if (revokerNickname == null || revokerNickname.isEmpty) {
      revokerNickname = _cachedNicknameForUser(revokerID);
    }
    return <String, dynamic>{
      'revokerID': revokerID ?? sourceSendID ?? OpenIM.iMManager.userID,
      'revokerRole': _intFromMap(detail, 'revokerRole') ?? 0,
      'clientMsgID':
          _revokeTargetClientMsgID(detail) ?? sourceMessage.clientMsgID,
      'revokerNickname': revokerNickname ?? '',
      'revokeTime': _intFromMap(detail, 'revokeTime') ??
          sourceMessage.sendTime ??
          0,
      'sourceMessageSendTime': _intFromMap(detail, 'sourceMessageSendTime') ??
          sourceMessage.sendTime ??
          0,
      'sourceMessageSendID': sourceSendID ?? '',
      'sourceMessageSenderNickname': sourceNickname,
      'sessionType': _intFromMap(detail, 'sessionType') ??
          _intFromMap(detail, 'sesstionType') ??
          sourceMessage.sessionType ??
          0,
      'seq': _intFromMap(detail, 'seq') ?? sourceMessage.seq ?? 0,
      'ex': _stringFromMap(detail, 'ex') ?? sourceMessage.ex ?? '',
    };
  }

  bool _applyRevokeDetail(Map<String, dynamic> detail) {
    final targetClientMsgID = _revokeTargetClientMsgID(detail);
    // dawn 2026-04-27 增强：clientMsgID 命中不到时，按 sourceMessageSendID +
    // sourceMessageSendTime 双键再扫一遍，应对 SDK 偶尔不带回 clientMsgID 的情况。
    final srcID = _stringFromMap(detail, 'sourceMessageSendID');
    final srcTime = _intFromMap(detail, 'sourceMessageSendTime');
    if (targetClientMsgID == null && (srcID == null || srcTime == null)) {
      ILogger.w('[ChatLogic] _applyRevokeDetail: 无法定位目标消息 detail=$detail');
      DebugLogUploader.send('apply_revoke_no_locator', {
        'detail': detail,
      });
      return false;
    }
    var updated = false;
    final touched = <String>{};
    for (final msg in messageList) {
      final byID = targetClientMsgID != null && msg.clientMsgID == targetClientMsgID;
      final byPair = srcID != null && srcTime != null &&
          msg.sendID == srcID && msg.sendTime == srcTime;
      if (!byID && !byPair) continue;
      if (msg.contentType == MessageType.revokeMessageNotification) continue;
      updated = true;
      msg.contentType = MessageType.revokeMessageNotification;
      msg.notificationElem = NotificationElem(
        detail: json.encode(_normalizeRevokeDetail(detail, msg)),
      );
      if (msg.clientMsgID != null) touched.add(msg.clientMsgID!);
    }
    if (updated) {
      _rebuildItemsByClientMsgID(touched);
      update();
    }
    return updated;
  }

  /// Called when a revoke event arrives as a regular notification message (the
  /// "ReliableNotificationMsg" path on the server). The message's own
  /// clientMsgID is brand new — the original revoked clientMsgID is inside
  /// notificationElem.detail. We apply the revoke to the original message and
  /// return true so the caller skips inserting the bare notification row,
  /// otherwise the receiver would see both the revoked placeholder AND the
  /// original message still sitting there.
  bool _applyRevokeNotificationMessage(Message message) {
    final detail = message.notificationElem?.detail;
    if (detail == null || detail.isEmpty) {
      // dawn 2026-04-27 临时：跟踪 newMessage 路径上的 2101 处理
      DebugLogUploader.send('apply_notif_msg', {
        'reason': 'detail_empty',
        'notificationClientMsgID': message.clientMsgID,
      });
      return false;
    }
    try {
      final ok = _applyRevokeDetail(_decodeRevokeDetail(detail));
      DebugLogUploader.send('apply_notif_msg', {
        'reason': ok ? 'ok' : 'no_match',
        'notificationClientMsgID': message.clientMsgID,
        'rawDetailString': detail,
        'messageListLen': messageList.length,
      });
      return ok;
    } catch (e, s) {
      ILogger.d('parse revoke notification failed: $e\n$s');
      DebugLogUploader.send('apply_notif_msg', {
        'reason': 'exception',
        'err': e.toString(),
        'rawDetailString': detail,
      });
      return false;
    }
  }

  /// 如果 [newMsg] 对应的 clientMsgID 已经存在于列表里（说明是乐观发送后 SDK 回
  /// 显的同一条），就把服务端赋值的字段（seq/serverMsgID/status 等）写回旧对象
  /// 并返回 true 让调用方跳过再次 insert，避免出现「发送方自己看到两条一模一样
  /// 的消息」这种幻影。
  bool _mergeSyncedMessage(Message newMsg) {
    final clientMsgID = newMsg.clientMsgID;
    if (clientMsgID == null || clientMsgID.isEmpty) {
      return false;
    }
    final index = messageList.indexWhere((msg) => msg.clientMsgID == clientMsgID);
    if (index < 0) {
      return false;
    }
    final oldMsg = messageList[index];
    // Always sync the server-assigned fields back into the optimistic copy.
    oldMsg.seq = newMsg.seq ?? oldMsg.seq;
    oldMsg.serverMsgID = newMsg.serverMsgID ?? oldMsg.serverMsgID;
    oldMsg.status = newMsg.status ?? oldMsg.status;
    // Keep the optimistic sendTime if we already have one. Overwriting with the
    // server value can cause the bubble to jump order when server-time drifts
    // from the local clock by a few hundred ms.
    oldMsg.sendTime ??= newMsg.sendTime;
    if (newMsg.contentType == MessageType.revokeMessageNotification) {
      oldMsg.contentType = MessageType.revokeMessageNotification;
      oldMsg.notificationElem = newMsg.notificationElem;
    }
    return true;
  }

  // 检查是否为通话信令消息（需要过滤）
  bool _isCallSignalingMessage(Message msg) {
    if (msg.contentType == MessageType.custom && msg.customElem != null) {
      final raw = msg.customElem?.data;
      if (raw == null || raw.isEmpty) {
        return false;
      }
      try {
        final decoded = json.decode(raw);
        if (decoded is! Map<String, dynamic>) return false;
        final customType = decoded['customType'];

        // 通话信令消息(200-204)和同步消息(2005)需要被过滤
        return customType == CustomMessageType.callingInvite ||
            customType == CustomMessageType.callingAccept ||
            customType == CustomMessageType.callingReject ||
            customType == CustomMessageType.callingCancel ||
            customType == CustomMessageType.callingHungup ||
            customType == CustomMessageType.syncCallStatus;
      } catch (e) {
        print('[ChatLogic] ❌ 解析自定义消息失败: $e');
      }
    }
    return false;
  }

  // 过滤消息列表，移除通话信令消息
  List<Message> _filterCallSignalingMessages(List<Message> messages) {
    return messages.where((msg) => !_isCallSignalingMessage(msg)).toList();
  }

  /// 过滤后用于聊天列表展示的消息：去掉通话信令；群聊时去掉群通知类消息
  List<Message> _filterMessagesForChat(List<Message> messages) {
    var list = _filterCallSignalingMessages(messages);
    // dawn 2026-04-27 临时调查：每次进入 fold 都统计一下 list 形态，看是否有
    // 同 clientMsgID 同时出现 text 和 2101 的真实证据；以及 fold 跑完最后剩多少条。
    var revokeCount = 0;
    var textCount = 0;
    final sameIdConflict = <String>[];
    final byIdContentType = <String, Set<int>>{};
    for (final m in list) {
      final id = m.clientMsgID ?? '';
      if (id.isEmpty) continue;
      byIdContentType.putIfAbsent(id, () => <int>{}).add(m.contentType ?? 0);
      if (m.contentType == MessageType.revokeMessageNotification) revokeCount++;
      else textCount++;
    }
    byIdContentType.forEach((id, types) {
      if (types.contains(MessageType.revokeMessageNotification) && types.length > 1) {
        sameIdConflict.add(id);
      }
    });
    if (revokeCount > 0) {
      DebugLogUploader.send('filter_input_summary', {
        'inListLen': list.length,
        'revokeCount': revokeCount,
        'textCount': textCount,
        'sameIdConflict': sameIdConflict,
        'firstRevokeRawDetail': list
            .firstWhere(
                (m) => m.contentType == MessageType.revokeMessageNotification,
                orElse: () => Message())
            .notificationElem?.detail,
      });
    }

    // Fold standalone revoke-notification rows into their target messages. The
    // server now sends revoke events as queueable messages (ReliableNotificationMsg)
    // — without this, on receiver-side history load you'd see both the original
    // AND a separate "xxx 撤回了一条消息" line, OR in group chat the revoke would
    // be dropped by the notification filter and the original would stay as if
    // nothing happened (bug 3 symptom).
    // dawn 2026-04-27 增强：原版仅按 detail.clientMsgID 匹配；用户截图显示接收方
    // 仍出现 "原文 + 撤回提示" 并存，说明部分 SDK 给的 detail 字段名/结构在我们的
    // 取值里命中不了。增加：a) 多个备用字段名；b) sourceMessageSendID +
    // sourceMessageSendTime 双键回退；c) 命中失败时打 ILogger.w 把 detail 摆出
    // 来，便于下个 build 用户回报时排查。
    final revokes = <String, Map<String, dynamic>>{}; // target clientMsgID -> detail
    final revokeBySender = <String, Map<String, dynamic>>{}; // "sendID|sendTime" -> detail
    final standaloneRevokeRows = <String>{}; // clientMsgIDs of the notif rows themselves
    for (final m in list) {
      if (m.contentType == MessageType.revokeMessageNotification) {
        final detail = m.notificationElem?.detail;
        if (detail == null || detail.isEmpty) {
          ILogger.w('[ChatLogic] revoke notification with empty detail: clientMsgID=${m.clientMsgID}');
          DebugLogUploader.send('revoke_empty_detail', {
            'clientMsgID': m.clientMsgID,
            'sendID': m.sendID,
            'sendTime': m.sendTime,
          });
          continue;
        }
        try {
          final info = _decodeRevokeDetail(detail);
          final target = _revokeTargetClientMsgID(info);
          // dawn 2026-04-27 移除 `target != m.clientMsgID`：从 /debug/log 上报数据
          // 看到 SDK 的 2101 通知消息复用原文 clientMsgID（in-place mutation 语义）。
          // 真实 bug 场景是 list 里同 clientMsgID 同时出现 (text 旧的内存残留) 和
          // (2101 重新加载的)，此时旧逻辑 target==self 会跳过 fold 导致两条并存。
          // 现改为只要 target 有值就建立索引；后面再做"同 clientMsgID 去重保 2101"。
          final hasTarget = target != null && target.isNotEmpty;
          if (hasTarget) {
            revokes[target] = info;
          }
          // 兜底：sourceMessageSendID + sourceMessageSendTime 也做一份索引
          final srcID = _stringFromMap(info, 'sourceMessageSendID');
          final srcTime = _intFromMap(info, 'sourceMessageSendTime');
          if (srcID != null && srcID.isNotEmpty && srcTime != null && srcTime > 0) {
            revokeBySender['$srcID|$srcTime'] = info;
          }
          if (!hasTarget && (srcID == null || srcTime == null)) {
            ILogger.w('[ChatLogic] revoke detail missing target: detail=$detail');
            DebugLogUploader.send('revoke_no_target', {
              'notificationClientMsgID': m.clientMsgID,
              'detail': info,
              'rawDetailString': detail,
            });
          }
          // standaloneRevokeRows 只收 self != target 的真"独立通知"。in-place
          // mutation 那条 (self == target) 不能加进去，否则它会被自己的 target
          // 索引覆盖、被剔除掉。
          final self = m.clientMsgID;
          if (self != null && self.isNotEmpty && self != target &&
              (hasTarget || (srcID != null && srcTime != null))) {
            standaloneRevokeRows.add(self);
          }
        } catch (e) {
          ILogger.w('[ChatLogic] revoke detail decode failed: $e detail=$detail');
          DebugLogUploader.send('revoke_decode_failed', {
            'err': e.toString(),
            'rawDetailString': detail,
          });
        }
      }
    }
    if (revokes.isNotEmpty || revokeBySender.isNotEmpty) {
      for (final m in list) {
        if (m.contentType == MessageType.revokeMessageNotification) continue;
        var info = revokes[m.clientMsgID];
        if (info == null) {
          // 按发送者+sendTime 兜底匹配
          final sendID = m.sendID;
          final sendTime = m.sendTime;
          if (sendID != null && sendTime != null) {
            info = revokeBySender['$sendID|$sendTime'];
          }
        }
        if (info != null) {
          m.contentType = MessageType.revokeMessageNotification;
          m.notificationElem = NotificationElem(
            detail: json.encode(_normalizeRevokeDetail(info, m)),
          );
        }
      }
    }
    if (standaloneRevokeRows.isNotEmpty) {
      list = list
          .where((m) => !standaloneRevokeRows.contains(m.clientMsgID))
          .toList();
    }

    // dawn 2026-04-27 同 clientMsgID 去重，保留 2101 那条：
    // 真实 bug 场景下 list 里会同时存在 (X, text 旧的内存残留) 和 (X, 2101
    // 后来加载的)，此时上一阶段的 fold 已经把 X 这一条按需 mutate 成了 2101，
    // 但 list 里仍可能残留另一条同 ID 的 text，因此再做一次"同 clientMsgID
    // 优先保 2101"的去重，确保 UI 不会同时画原文和撤回提示。
    {
      final byID = <String, Message>{};
      for (final m in list) {
        final id = m.clientMsgID;
        if (id == null || id.isEmpty) continue;
        final existing = byID[id];
        if (existing == null) {
          byID[id] = m;
        } else {
          final existingIsRevoke =
              existing.contentType == MessageType.revokeMessageNotification;
          final mIsRevoke =
              m.contentType == MessageType.revokeMessageNotification;
          if (mIsRevoke && !existingIsRevoke) {
            byID[id] = m;
          }
        }
      }
      list = list.where((m) {
        final id = m.clientMsgID;
        if (id == null || id.isEmpty) return true; // 没 ID 的不参与去重
        return identical(byID[id], m);
      }).toList();
    }

    if (isGroupChat) {
      // Keep revoke placeholders visible (they are the mutated originals);
      // strip everything else above the notification range.
      list = list
          .where((msg) =>
              !isNotificationType(msg) ||
              msg.contentType == MessageType.revokeMessageNotification)
          .toList();
    }
    return list;
  }

  /// 按 sendTime 升序排序，保证列表为「旧→新」避免 API 返回顺序不一致导致错乱
  List<Message> _sortMessagesBySendTimeAsc(List<Message> messages) {
    final list = List<Message>.from(messages);
    list.sort((a, b) => (a.sendTime ?? 0).compareTo(b.sendTime ?? 0));
    return list;
  }

  // 处理新消息的统一方法
  void _handleNewMessage(Message message) async {
    print('========== _handleNewMessage 被调用 ==========');
    print('[ChatLogic] message.clientMsgID=${message.clientMsgID}');
    print('[ChatLogic] message.contentType=${message.contentType}');
    print('[ChatLogic] message.sendID=${message.sendID}');
    print('[ChatLogic] message.recvID=${message.recvID}');

    // 使用消息去重器检查此消息是否已处理过
    if (!await MessageDeduplicator.instance.shouldProcessMessage(message)) {
      print('[ChatLogic] ⚠️ 消息已处理过，跳过重复消息: ${message.clientMsgID}');
      return; // 跳过已处理过的消息
    }

    // 拦截红包领取通知（单聊消息），如果是当前群组的红包通知，则转换为群组系统消息显示
    if (isGroupChat && message.isSingleChat && message.contentType == MessageType.text) {
      try {
        if (message.ex != null && message.ex!.isNotEmpty) {
          final extraData = json.decode(message.ex!);
          // 检查是否为红包领取通知且目标群ID匹配当前群ID
          if (extraData['type'] == 'red_packet_claimed' &&
              extraData['target_id'] == groupID) {

            print('[ChatLogic] 🧧 拦截到红包领取通知，转换为群消息显示');

            // 解析原始内容（SDK Message 无 content，文本在 textElem.content）
            String notificationContent = "红包领取通知";
            try {
              final rawContent = message.textElem?.content ?? '';
              if (rawContent.isNotEmpty) {
                final contentMap = json.decode(rawContent) as Map<String, dynamic>?;
                if (contentMap != null && contentMap['content'] != null) {
                  notificationContent = contentMap['content'] as String;
                }
              }
            } catch (e) {
              notificationContent = message.textElem?.content ?? "红包领取通知";
            }

            // 修改消息属性使其被 isCurrentChat 识别为当前群消息
            message.sessionType = ConversationType.group;
            message.groupID = groupID;
            message.contentType = MessageType.custom;

            // 构造 CustomElem 以便 UI 正确渲染为系统通知 (CustomMessageType.recover)
            message.customElem = CustomElem(
              data: json.encode({
                "customType": CustomMessageType.recover,
                "content": notificationContent,
                "viewType": CustomMessageType.recover,
              }),
              extension: '',
              description: '系统通知',
            );

            print('[ChatLogic] ✅ 红包通知转换完成: $notificationContent');
          }
        }
      } catch (e) {
        print('[ChatLogic] ❌ 处理红包通知失败: $e');
      }
    }

    // 处理群禁言/取消禁言系统通知，实时更新本地群禁言状态（以推送为准，优先于 getGroupsInfo 缓存）
    if (isGroupChat &&
        message.isGroupChat &&
        message.groupID == groupID &&
        (message.contentType == MessageType.groupMutedNotification ||
            message.contentType == MessageType.groupCancelMutedNotification)) {
      _groupMuted.value =
          message.contentType == MessageType.groupMutedNotification;
      _lastGroupMutedFromServerMs = DateTime.now().millisecondsSinceEpoch;
      _groupMutedRetryTimer?.cancel(); // 已收到推送，无需再延迟重试
      update();
    }
    // 收到本群任意通知类消息时防抖拉取群信息，服务端推送未达时也能通过拉取实现实时同步
    if (isGroupChat &&
        message.isGroupChat &&
        message.groupID == groupID &&
        isNotificationType(message)) {
      _scheduleGroupInfoRefresh();
    }

    if (isCurrentChat(message)) {
      print('[ChatLogic] ✅ 消息属于当前聊天，准备处理');
      if (message.contentType == MessageType.typing) {
        return;
      }

      // 过滤音视频通话信令消息，这些消息应该由 onRecvOnlineOnlyMessage 或 recvNewMessage 的信令处理器处理
      if (_isCallSignalingMessage(message)) {
        print('[ChatLogic] ⚠️ 收到通话信令消息，跳过添加到聊天列表');
        return;
      }

      // Revoke notifications arrive here now that the server uses ReliableNotificationMsg
      // (see pkg/notification/msg.go). Apply the revoke to the matching original
      // message in the list and stop — we don't want to insert a separate
      // "你撤回了一条消息" row alongside the still-visible original.
      if (message.contentType == MessageType.revokeMessageNotification) {
        // dawn 2026-04-27 临时：标记 newMessage 路径上 2101 进入处理
        DebugLogUploader.send('newmsg_2101_received', {
          'clientMsgID': message.clientMsgID,
          'sendID': message.sendID,
          'recvID': message.recvID,
          'currentChatUserID': userID,
          'isCurrent': isCurrentChat(message),
        });
        final updated = _applyRevokeNotificationMessage(message);
        if (!updated) {
          Future.microtask(_loadHistoryForSyncEnd);
        }
        return;
      }

      // 过滤群通知类消息（入群、退群、邀请、群资料变更、禁言通知等），不展示在聊天列表中
      if (isGroupChat && isNotificationType(message)) {
        print('[ChatLogic] ⚠️ 群通知消息已过滤，不加入列表: ${message.contentType}');
        return;
      }

      // Dedupe by clientMsgID: the optimistic send path inserted the message object
      // earlier. The SDK returns a brand-new Message instance via onRecvNewMessage
      // for the server echo, so `List.contains` (identity) misses it and we insert
      // the same logical message twice. _mergeSyncedMessage syncs the server-side
      // fields into the existing row and returns true so we skip the duplicate.
      if (_mergeSyncedMessage(message)) {
        // dawn 2026-04-27 修撤回/状态不刷新：和 _sendSucceeded 同样的逻辑——
        // 仅 refresh() 不一定触发 SliverList item 重建。把对应 clientMsgID 的
        // rxList 元素重新赋值，强制 itemBuilder rebuild，保证 status/contentType
        // 等字段变化能在 bubble 里立刻反映出来。
        final id = message.clientMsgID;
        if (id != null) {
          _rebuildItemsByClientMsgID({id});
        } else {
          customChatListViewController.refresh();
        }
      } else {
        _isReceivedMessageWhenSyncing = true;
        customChatListViewController.insertToBottom(message);

        // 处理自定义消息（转账消息和红包消息）
        if (message.contentType == MessageType.custom &&
            message.customElem != null) {
          final data = json.decode(message.customElem!.data!);
          ILogger.d('自定义消息数据: $data');

          // 处理转账消息
          if (data['customType'] == CustomMessageType.transfer) {
            final transferData = data['data'];
            final transferId = transferData['msg_id'];
            final isReceived = transferData['isReceived'] ?? false;
            final status = transferData['status'] ?? 'pending';

            ILogger.d(
                '收到转账消息,ID: $transferId, 状态: $status, 是否已收款: $isReceived');

            // 更新全局状态
            TransferStatusManager.saveTransferStatus(transferId, status);

            // 更新消息列表中的状态
            for (var msg in messageList) {
              if (msg.contentType == MessageType.custom) {
                final msgData = json.decode(msg.customElem!.data!);
                if (msgData['customType'] == CustomMessageType.transfer) {
                  final msgTransferData = msgData['data'];
                  if (msgTransferData['msg_id'] == transferId) {
                    msgTransferData['isReceived'] = isReceived;
                    msgTransferData['status'] = status;
                    ILogger.d('更新消息状态: $transferId -> $status');
                    customChatListViewController.refresh();
                    break;
                  }
                }
              }
            }
          }
          // 处理红包消息
          else if (data['customType'] == CustomMessageType.luckMoney) {
            _handleLuckyMoneyStatusUpdate(data);
          } else {
            ILogger.d('其他类型的自定义消息,类型: ${data['customType']}');
          }
        } else {
          ILogger.d('非自定义消息,类型: ${message.contentType}');
        }
      }
    } else {
      ILogger.d('消息不属于当前聊天,忽略处理');
    }
  }

  initMessageList() async {
    if (searchMessage != null) {
      final topMessageRes = await _fetchHistoryMessages(searchMessage);
      final bottomMessageRes =
      await _fetchReverseHistoryMessages(searchMessage);
      if (topMessageRes.isEnd == true) {
        enabledTopLoad.value = false;
      }
      if (bottomMessageRes.isEnd == true) {
        enabledBottomLoad.value = false;

        customChatListViewController.insertAllToBottom([
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(topMessageRes.messageList ?? [])),
          searchMessage!,
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(bottomMessageRes.messageList ?? []))
        ]);
      } else {
        enabledBottomLoad.value = true;
        customChatListViewController.insertAllToTop([
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(topMessageRes.messageList ?? [])),
          searchMessage!
        ]);
        customChatListViewController.insertAllToBottom(
            _sortMessagesBySendTimeAsc(
                _filterMessagesForChat(bottomMessageRes.messageList ?? []))
        );
      }
    }
    // 非搜索：仅拉一页（本地或群聊服务端最近一页），上滑时 onScrollToTopLoad 再按需拉更早历史
    await onScrollToTopLoad();

    // 第一阶段：先让消息尽快显示出来，再做红包/转账等较重的状态初始化，避免首屏白屏时间过长
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (searchMessage != null) {
        await customChatListViewController.jumpToElement(searchMessage!);
      } else {
        await scrollBottom();
      }
      isReadyToShow.value = true;
    });

    // 第二阶段：在后台补全红包状态（本地+服务端校准），不阻塞首屏展示
    Future.microtask(() async {
      await _initLuckMoneyStatusFromLocal();
    });
  }

  Future chatSetup() => isSingleChat
      ? AppNavigator.startChatSetup(conversationInfo: conversationInfo)
      : AppNavigator.startGroupChatSetup(conversationInfo: conversationInfo);

  void _putMemberInfo(List<GroupMembersInfo>? list) {
    list?.forEach((member) {
      memberUpdateInfoMap[member.userID!] = member;
    });

    customChatListViewController.refresh();
  }

  List<String> _extractIds(String text) {
    RegExp regExp = RegExp(r'@(\S+)');
    return regExp.allMatches(text).map((match) => match.group(1)!).toList();
  }

  Future sendTextMsg(value, { required List<Uint8List> images }) async {
    try {
      if (images.isNotEmpty) {
        // 如果有图片，先发送图片消息
        for (var image in images) {
          final file = await IMUtils.compressImageAndGetFileFromBytes(image);
          if (file != null) {
            var message = await OpenIM.iMManager.messageManager
                .createImageMessageFromFullPath(imagePath: file.path);
            _sendMessage(message);
          }
        }
      }
    } catch (e) {
      ILogger.e('发送图片消息失败: $e');
    }

    var content = IMUtils.safeTrim(inputCtrl.text);
    var ids = _extractIds(content);
    ids = ids.toSet().toList();
    if (content.isEmpty) {
      return;
    }

    Message message;

    List<AtUserInfo> curMsgAtUserInfosTemp = [];
    List<String> atUserIds = [];
    if (isGroupChat) {
      for (var item in curMsgAtUserInfos) {
        if (ids.contains(item.atUserID)) {
          curMsgAtUserInfosTemp.add(AtUserInfo(
              atUserID: item.atUserID,
              groupNickname: item.groupNickname ?? item.atUserID));
          atUserIds.add(item.atUserID!);
        }
      }
    }

    if (curMsgAtUserInfosTemp.isNotEmpty) {
      message = await OpenIM.iMManager.messageManager.createTextAtMessage(
        text: content,
        atUserIDList: atUserIds,
        atUserInfoList: curMsgAtUserInfosTemp,
      );
    } else if (quote.value != null) {
      message = await OpenIM.iMManager.messageManager.createQuoteMessage(
        text: content,
        quoteMsg: quote.value!,
      );
      quote.value = null;
    } else {
      var messageText = content;
      message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: messageText,
      );
    }

    // 发送消息
    await _sendMessage(message);

    // 如果包含"已成功收款"关键词，可能是收款成功的通知，尝试刷新相关的转账消息
    if (content.contains('已成功收款')) {
      // 检查是否有需要更新的转账消息
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // 尝试从消息列表中找出最近的转账消息
          for (int i = messageList.length - 1;
          i >= 0 && i >= messageList.length - 10;
          i--) {
            final msg = messageList[i];

            // 检查是否为转账消息
            if (msg.contentType == MessageType.custom) {
              try {
                final data = jsonDecode(msg.customElem?.data ?? '{}');

                if (data['viewType'] == 'transfer') {
                  final transferId = data['msg_id'] as String?;

                  if (transferId != null) {
                    // 查看是否已存在于完成状态中
                    // TransferStatusManager.getTransferStatus(transferId).then((completedStatus) {
                    //   if (completedStatus != null &&
                    //       completedStatus.toLowerCase() == 'completed') {
                    //     ILogger.d('找到相关的转账消息，触发更新: $transferId');

                    //     // 刷新消息列表
                    //     messageList.refresh();
                    //     ILogger.d('消息列表更新完成');
                    //   }
                    // });
                    break;
                  }
                }
              } catch (e) {
                ILogger.d('解析消息数据失败: $e');
              }
            }
          }
        } catch (e) {
          ILogger.d('检查转账消息状态失败: $e');
        }
      });
    } else {
      ILogger.d('非收款成功消息,不处理转账状态更新');
    }
  }

  Future sendPicture({required String path, bool sendNow = true}) async {
    final file = await IMUtils.compressImageAndGetFile(File(path));

    var message =
    await OpenIM.iMManager.messageManager.createImageMessageFromFullPath(
      imagePath: file!.path,
    );

    if (sendNow) {
      return _sendMessage(message);
    } else {
      customChatListViewController.insertToBottom(message);
      tempMessages.add(message);
    }
  }

  Future sendVideo(
      {required String path,
        bool sendNow = true,
        required String mimeType,
        required int duration,
        required String snapshotPath}) async {
    final file = await IMUtils.compressVideoAndGetFile(File(path));
    var message = await OpenIM.iMManager.messageManager
        .createVideoMessageFromFullPath(
        videoPath: file!.path,
        videoType: mimeType,
        duration: duration,
        snapshotPath: snapshotPath);

    if (sendNow) {
      return _sendMessage(message);
    } else {
      customChatListViewController.insertToBottom(message);
      tempMessages.add(message);
    }
  }

  sendForwardRemarkMsg(
      String content, {
        String? userId,
        String? groupId,
      }) async {
    final message = await OpenIM.iMManager.messageManager.createTextMessage(
      text: content,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  sendForwardMsg(
      Message originalMessage, {
        String? userId,
        String? groupId,
      }) async {
    var message = await OpenIM.iMManager.messageManager.createForwardMessage(
      message: originalMessage,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  void sendTypingMsg({bool focus = false}) async {
    if (isSingleChat) {
      OpenIM.iMManager.conversationManager.changeInputStates(
          conversationID: conversationInfo.conversationID, focus: focus);
    }
  }

  void atMember() {
    // 只在群聊中处理 @ 成员
    if (!isGroupChat) return;

    final currentText = inputCtrl.text;
    final selection = inputCtrl.selection;

    // 仅在光标是折叠状态（没有选中文本）时处理
    if (!selection.isCollapsed) return;

    final cursor = selection.start;
    // 光标位置非法或在第 0 位，不可能有“光标前一个字符是 @”
    if (cursor <= 0 || cursor > currentText.length) return;

    // 当且仅当“光标前一个字符是 @”时触发成员选择
    if (currentText[cursor - 1] == '@') {
      _mention(cursor - 1);
    }
  }

  _mention(int postion) async {
    final List<GroupMembersInfo> list = await AppNavigator.startGroupMemberList(
      groupInfo: groupInfo!,
      opType: GroupMemberOpType.at,
    );
    var oldStr = inputCtrl.text;
    var appendStr = "";

    for (var member in list) {
      // 判断curMsgAtUserInfos是否包含member，以userID对比
      if (!curMsgAtUserInfos.any((info) => info.atUserID == member.userID)) {
        curMsgAtUserInfos.add(AtUserInfo(
            groupNickname: member.nickname, atUserID: member.userID));
      }
      var at = '@${member.userID} ';
      appendStr += at;
    }
    // oldStr将i处字符串替换为appendStr且设置光标位置
    var start = oldStr.substring(0, postion);
    var end = oldStr.substring(postion + 1);
    inputCtrl.text = '$start$appendStr$end';
    inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: '$start$appendStr'.length),
    );
  }

  void sendCarte({
    required String userID,
    String? nickname,
    String? faceURL,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createCardMessage(
      userID: userID,
      nickname: nickname!,
      faceURL: faceURL,
    );
    _sendMessage(message);
  }

  void sendCustomMsg({
    required String data,
    required String extension,
    required String description,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createCustomMessage(
      data: data,
      extension: extension,
      description: description,
    );
    _sendMessage(message);
  }

  Future _sendMessage(
      Message message, {
        String? userId,
        String? groupId,
        bool addToUI = true,
      }) {
    // 群聊场景下，在本地先做禁言/全员禁言前置校验，避免发出无效请求：
    // - isMute.value 为 true：当前用户已被单独禁言
    // - isGroupMute 为 true：已开启全员禁言（管理员/群主除外）
    if (isGroupChat && !enabled) {
      if (isGroupMute) {
        IMViews.showToast(StrRes.groupMuted);
      } else if (isMute.value) {
        IMViews.showToast(StrRes.youMuted);
      }
      return Future.value();
    }

    userId = IMUtils.emptyStrToNull(userId);
    groupId = IMUtils.emptyStrToNull(groupId);
    if (null == userId && null == groupId ||
        userId == userID && userId != null ||
        groupId == groupID && groupId != null) {
      if (addToUI) {
        customChatListViewController.insertToBottom(message);
        scrollBottom();
      }
    }
    _reset(message);
    bool useOuterValue = null != userId || null != groupId;

    final recvUserID = useOuterValue ? userId : userID;
    message.recvID = recvUserID;

    return OpenIM.iMManager.messageManager
        .sendMessage(
      message: message,
      userID: recvUserID,
      groupID: useOuterValue ? groupId : groupID,
      offlinePushInfo: Config.offlinePushInfo,
    )
        .then((value) => _sendSucceeded(message, value))
        .catchError(
            (error, _) => _senFailed(message, groupId, userId, error, _))
        .whenComplete(() => _completed());
  }

  void _sendSucceeded(Message oldMsg, Message newMsg) {
    oldMsg.update(newMsg);
    // dawn 2026-04-27 修发送成功小圈圈不消失：
    // 1) Message.update 只在 newMsg.status 非 null 时才覆盖；为了兜底 SDK 偶发
    //    回 null 的情况，手动把 status 钉死成 succeeded（2）。
    // 2) 仅 mutate Message + RxList.refresh() 在某些场景下 SliverList 不会让
    //    既有 item 的 State.build 重跑（CustomChatListView 是 StatefulWidget，
    //    didUpdateWidget 不自动触发 setState），导致小圈圈视图保留。把 rxList
    //    里对应 index 重新赋值，触发 GetX 的 element 变化事件，让 itemBuilder
    //    被强制 rebuild。
    oldMsg.status = MessageStatus.succeeded;
    final rxList = customChatListViewController.rxList;
    final idx = rxList.indexWhere((m) => m.clientMsgID == oldMsg.clientMsgID);
    if (idx >= 0) {
      rxList[idx] = oldMsg;
    } else {
      rxList.refresh();
    }
    sendStatusSub.addSafely(MsgStreamEv<bool>(
      id: oldMsg.clientMsgID!,
      value: true,
    ));
  }

  void _senFailed(
      Message message, String? groupId, String? userId, error, stack) async {
    message.status = MessageStatus.failed;
    sendStatusSub.addSafely(MsgStreamEv<bool>(
      id: message.clientMsgID!,
      value: false,
    ));
    if (error is PlatformException) {
      int code = int.tryParse(error.code) ?? 0;
      // 群聊发送失败且服务端返回 1204：表示群已解散/不可用，给出明确提示并退出当前会话
      if (isGroupChat && code == 1204) {
        IMViews.showToast(StrRes.groupDisbanded);
        Get.back();
        return;
      }
      if (isSingleChat) {
        int? customType;
        if (code == SDKErrorCode.hasBeenBlocked) {
          customType = CustomMessageType.blockedByFriend;
        } else if (code == SDKErrorCode.notFriend) {
          customType = CustomMessageType.deletedByFriend;
        }
        if (null != customType) {
          final hintMessage = (await OpenIM.iMManager.messageManager
              .createFailedHintMessage(type: customType))
            ..status = 2
            ..isRead = true;
          if (userId != null) {
            if (userId == userID) {
              customChatListViewController.insertToBottom(hintMessage);
            }
          } else {
            customChatListViewController.insertToBottom(hintMessage);
          }
          OpenIM.iMManager.messageManager.insertSingleMessageToLocalStorage(
            message: hintMessage,
            receiverID: userId ?? userID,
            senderID: OpenIM.iMManager.userID,
          );
        }
      } else {
        if ((code == SDKErrorCode.userIsNotInGroup ||
            code == SDKErrorCode.groupDisbanded) &&
            null == groupId) {
          final status = groupInfo?.status;
          final hintMessage = (await OpenIM.iMManager.messageManager
              .createFailedHintMessage(
              type: status == 2
                  ? CustomMessageType.groupDisbanded
                  : CustomMessageType.removedFromGroup))
            ..status = 2
            ..isRead = true;
          customChatListViewController.insertToBottom(hintMessage);
          OpenIM.iMManager.messageManager.insertGroupMessageToLocalStorage(
            message: hintMessage,
            groupID: groupID,
            senderID: OpenIM.iMManager.userID,
          );
        }
      }
    }
  }

  void _reset(Message message) {
    if (message.contentType == MessageType.text ||
        message.contentType == MessageType.quote ||
        message.contentType == MessageType.atText) {
      inputCtrl.clear();
      chatInputKey.currentState?.clearPasteImages();
    }
  }

  void _completed() {
    // 只在必要时刷新，避免发送消息后的闪烁
    customChatListViewController.refresh();
  }

  void markMessageAsRead(Message message, bool visible) async {
    if (visible && isShowReadStatus(message) && isSingleChat) {
      _markMessageAsRead(message);
    }
  }

  bool isShowReadStatus(Message message) {
    if (message.contentType! < 1000) {
      var data = IMUtils.parseCustomMessage(message);
      if (null != data &&
          (data['viewType'] == CustomMessageType.call ||
              data['viewType'] == CustomMessageType.luckMoney ||
              data['viewType'] == CustomMessageType.transfer)) {
        return false;
      }
      return true;
    }
    return false;
  }

  _markMessageAsRead(Message message) async {
    // 单聊为实时已读尽量上报；群聊仍仅在前台时上报
    if (!isSingleChat && !_isAppInForeground) return;

    if (!message.isRead! && message.sendID != OpenIM.iMManager.userID) {
      try {
        message.isRead = true;
        print('[ChatLogic] 📤 上报已读(单条) conversationID=${conversationInfo.conversationID} clientMsgID=${message.clientMsgID}');
        await OpenIM.iMManager.messageManager.markMessagesAsReadByMsgID(
            conversationID: conversationInfo.conversationID,
            messageIDList: [message.clientMsgID!]);
      } catch (e) {
        ILogger.d(
            'failed to send group message read receipt： ${message.clientMsgID} ${message.isRead}');
      } finally {
        message.isRead = true;
        message.hasReadTime = _timestamp;
        customChatListViewController.refresh();
      }
    }
  }

  /// 应用一条已读回执到当前 messageList（支持 msgIDList 为 clientMsgID 或 seq）
  /// 单聊且无 msgIDList 时：将本会话内自己发出的全部消息标为已读，保证双方已读状态一致刷新
  /// dawn 2026-04-27 加 touched 出参：把被改的 clientMsgID 收集起来供调用方走
  /// _rebuildItemsByClientMsgID，否则 SliverList item 不会因为 isRead 变化重建。
  void _applyOneReadReceipt(ReadReceiptInfo readInfo, [Set<String>? touched]) {
    final msgIDs = readInfo.msgIDList;
    var anyUpdated = false;
    if (msgIDs != null && msgIDs.isNotEmpty) {
      for (var e in messageList) {
        final byClientMsgID = msgIDs.contains(e.clientMsgID);
        final bySeq = e.seq != null && msgIDs.contains(e.seq.toString());
        if (byClientMsgID || bySeq) {
          e.isRead = true;
          e.hasReadTime = _timestamp;
          anyUpdated = true;
          if (touched != null && e.clientMsgID != null) {
            touched.add(e.clientMsgID!);
          }
        }
      }
    }
    // 单聊兜底：无 msgIDList 时（服务端常只下 hasReadSeq），将本会话内自己发的所有消息标为已读，实现整屏已读同步
    if (!anyUpdated && isSingleChat) {
      for (var e in messageList) {
        if (e.sendID == OpenIM.iMManager.userID && e.isRead != true) {
          e.isRead = true;
          e.hasReadTime = _timestamp;
          if (touched != null && e.clientMsgID != null) {
            touched.add(e.clientMsgID!);
          }
        }
      }
    }
  }

  /// 进入会话时应用之前收到的待处理已读回执，实现跨会话实时同步
  void _applyPendingReadReceipts() {
    if (!isSingleChat || userID == null) return;
    final pending = imLogic.getPendingReadReceiptsForUser(userID);
    if (pending.isEmpty) return;
    // dawn 2026-04-27 同因修复：refresh() 不会让 SliverList item 重建，改成
    // 收集 touched 走 _rebuildItemsByClientMsgID。
    final touched = <String>{};
    for (var readInfo in pending) _applyOneReadReceipt(readInfo, touched);
    imLogic.clearPendingReadReceiptsForUser(userID);
    if (touched.isNotEmpty) {
      _rebuildItemsByClientMsgID(touched);
    }
  }

  _clearUnreadCount() {
    // OpenIM.CustomElem({})
    if (conversationInfo.unreadCount > 0) {
      print('[ChatLogic] 📤 上报已读(会话) conversationID=${conversationInfo.conversationID} unreadCount=${conversationInfo.unreadCount}');
      OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
          conversationID: conversationInfo.conversationID);
    }
  }

  void closeToolbox() {
    forceCloseToolbox.addSafely(true);
  }

  void onTapLuckMoney(BuildContext context) async {
    final walletController = Get.find<WalletController>();
    walletController.checkWalletetActivated(() {
      AppNavigator.startLuckMoney(conversationInfo, groupInfo);
    });
  }

  void onTapEmoji(BuildContext context) async {
    // 打开表情包选择器
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => EmojiPicker(
        onEmojiSelected: (emoji) {
          Navigator.pop(context, emoji);
        },
      ),
    );

    if (result != null) {
      // 将 result 转换为 JSON 字符串
      Message message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: result['emoji'],
      );

      _sendMessage(message);
    }
  }

  /// 发送语音
  onSondVoice(int duration, String path) async {
    var message = await OpenIM.iMManager.messageManager
        .createSoundMessageFromFullPath(soundPath: path, duration: duration);
    await _sendMessage(message);
  }

  /// 名片
  void onTapCarte() async {
    var result = await AppNavigator.startSelectContacts(action: SelAction.card);
    if (null != result) {
      var userID = IMUtils.convertCheckedToUserID(result);
      // 处理 UserInfo 对象
      if (userID != null && userID != "") {
        UserInfo? userinfo;
        if (result is ConversationInfo) {
          userinfo = UserInfo(
              userID: result.userID,
              nickname: result.showName,
              faceURL: result.faceURL);
        } else {
          userinfo = UserInfo.fromJson(result.toJson());
        }
        sendCarte(
          userID: userinfo.userID!,
          nickname: userinfo.nickname,
          faceURL: userinfo.faceURL,
        );
      } else {
        Message? message;
        if (result is GroupInfo) {
          message = await IMUtils.createGroupCardMessage(
              groupID: result.groupID,
              groupName: result.groupName ?? "",
              groupAvatar: result.faceURL ?? "");
        }
        if (result is ConversationInfo) {
          message = await IMUtils.createGroupCardMessage(
              groupID: result.groupID!,
              groupName: result.showName ?? "",
              groupAvatar: result.faceURL ?? "");
        }
        if (message != null) {
          _sendMessage(message);
        }
      }
    }
  }

  /// 外部可能调用
  sendMessage(Message message) {
    _sendMessage(message);
  }

  void onTapAlbum() async {
    // 多重权限检查策略
    // bool hasPermission = await _checkPhotoPermission();

    // if (!hasPermission) {
    //   // 显示权限说明并提供备选方案
    //   await _showPermissionOptions();
    //   return;
    // }

    try {
      // 使用AssetPicker选择图片
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
          Get.context!,
          pickerConfig: AssetPickerConfig(
              sortPathsByModifiedDate: true,
              filterOptions: PMFilter.defaultValue(containsPathModified: true),
              selectPredicate: (_, entity, isSelected) async {
                // 检查文件大小
                final file = await entity.file;
                if (file != null) {
                  final fileSizeBytes = file.lengthSync();

                  if (entity.type == AssetType.image) {
                    // 图片大小限制 5MB
                    const maxImageSize = 5 * 1024 * 1024;
                    if (fileSizeBytes > maxImageSize) {
                      IMViews.showToast(StrRes.imageSizeLimit);
                      return false;
                    }

                    if (await allowSendImageType(entity)) {
                      return true;
                    }
                    IMViews.showToast(StrRes.supportsTypeHint);
                    return false;
                  }

                  if (entity.type == AssetType.video) {
                    // 视频大小限制 50MB
                    const maxVideoSize = 50 * 1024 * 1024;
                    if (fileSizeBytes > maxVideoSize) {
                      IMViews.showToast(StrRes.videoSizeLimit);
                      return false;
                    }

                    if (entity.videoDuration >
                        const Duration(seconds: 5 * 60)) {
                      IMViews.showToast(sprintf(StrRes.selectVideoLimit, [5]) +
                          StrRes.minute);
                      return false;
                    }
                  }
                }

                return true;
              }));

      if (assets != null && assets.isNotEmpty) {
        for (var asset in assets) {
          await _handleAssets(asset, sendNow: false);
        }

        for (var msg in tempMessages) {
          await _sendMessage(msg, addToUI: false);
        }

        tempMessages.clear();
      }
    } catch (e) {
      print('AssetPicker失败: $e');
      // 降级到FilePicker
      await _useFilePicker();
    }
  }

  /// 检查相册权限
  Future<bool> _checkPhotoPermission() async {
    try {
      // 1. 检查基础权限
      final basicStatus = await Permission.photos.status;
      if (basicStatus.isGranted || basicStatus.isLimited) {
        return true;
      }

      // 2. 请求权限
      final requestResult = await Permission.photos.request();
      if (requestResult.isGranted || requestResult.isLimited) {
        return true;
      }

      // 3. 检查PhotoManager权限
      final pmStatus = await PhotoManager.getPermissionState(
          requestOption: const PermissionRequestOption());
      if (pmStatus.isAuth || pmStatus.hasAccess) {
        return true;
      }

      // 4. 尝试PhotoManager请求
      final pmResult = await PhotoManager.requestPermissionExtend();
      return pmResult.isAuth || pmResult.hasAccess;
    } catch (e) {
      print('权限检查失败: $e');
      return false;
    }
  }

  /// 显示权限选项
  Future<void> _showPermissionOptions() async {
    final result = await Get.dialog(
      AlertDialog(
        title: Text('需要相册权限'),
        content: Text('无法访问相册，请选择：\n1. 去设置开启权限\n2. 使用文件选择器\n3. 直接拍照'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'settings'),
            child: Text('去设置'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'file'),
            child: Text('文件选择'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'camera'),
            child: Text('拍照'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text('取消'),
          ),
        ],
      ),
    );

    switch (result) {
      case 'settings':
        await openAppSettings();
        break;
      case 'file':
        await _useFilePicker();
        break;
      case 'camera':
        await _useCamera();
        break;
    }
  }

  /// 使用文件选择器
  Future<void> _useFilePicker() async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.media,
        allowMultiple: true,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final fileName = file.name.toLowerCase();
            if (fileName.endsWith('.jpg') ||
                fileName.endsWith('.jpeg') ||
                fileName.endsWith('.png') ||
                fileName.endsWith('.gif')) {
              await sendPicture(path: file.path!, sendNow: false);
            } else if (fileName.endsWith('.mp4') ||
                fileName.endsWith('.mov') ||
                fileName.endsWith('.avi')) {
              await sendVideo(
                path: file.path!,
                sendNow: false,
                mimeType: 'video/mp4',
                duration: 0,
                snapshotPath: file.path!,
              );
            }
          }
        }

        // 发送暂存的消息
        for (var msg in tempMessages) {
          await _sendMessage(msg, addToUI: false);
        }
        tempMessages.clear();
      }
    } catch (e) {
      print('文件选择失败: $e');
      IMViews.showToast('文件选择失败');
    }
  }

  /// 使用相机
  Future<void> _useCamera() async {
    try {
      Permissions.camera(() async {
        // 简化的相机调用，使用image_picker
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.camera);

        if (image != null) {
          await sendPicture(path: image.path, sendNow: true);
        }
      });
    } catch (e) {
      print('相机拍照失败: $e');
      IMViews.showToast('拍照失败');
    }
  }

  Future<bool> allowSendImageType(AssetEntity entity) async {
    final mimeType = await entity.mimeTypeAsync;

    return IMUtils.allowImageType(mimeType);
  }

  Future _handleAssets(AssetEntity? asset, {bool sendNow = true}) async {
    if (null != asset) {
      final originalFile = await asset.file;
      final originalPath = originalFile!.path;
      var path = originalPath.toLowerCase().endsWith('.gif')
          ? originalPath
          : originalFile.path;
      switch (asset.type) {
        case AssetType.image:
          await sendPicture(path: path, sendNow: sendNow);
          break;
        case AssetType.video:
          final thumb =
          await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
          if (thumb != null) {
            final file = await IMUtils.saveThumbToFile(thumb, asset.id);
            await sendVideo(
              path: path,
              sendNow: sendNow,
              mimeType: asset.mimeType!,
              duration: asset.videoDuration.inSeconds,
              snapshotPath: file.path,
            );
          }

          break;
        default:
          break;
      }
      if (Platform.isIOS) {
        originalFile.deleteSync();
      }
    }
  }

  void onTapDirectionalMessage() async {
    if (null != groupInfo) {
      final list = await AppNavigator.startGroupMemberList(
        groupInfo: groupInfo!,
        opType: GroupMemberOpType.call,
      );
      if (list is List<GroupMembersInfo>) {
        directionalUsers.assignAll(list);
      }
    }
  }

  TextSpan? directionalText() {
    if (directionalUsers.isNotEmpty) {
      final temp = <TextSpan>[];

      for (var e in directionalUsers) {
        final r = TextSpan(
          text: '${e.nickname ?? ''} ${directionalUsers.last == e ? '' : ','} ',
          style: Styles.ts_0089FF_14sp,
        );

        temp.add(r);
      }

      return TextSpan(
        text: '${StrRes.directedTo}:',
        style: Styles.ts_8E9AB0_14sp,
        children: temp,
      );
    }

    return null;
  }

  void onClearDirectional() {
    directionalUsers.clear();
  }

  /// 群聊天长按头像为@用户
  void onLongPressLeftAvatar(Message message) {
    var msg = message;
    if (isGroupChat) {
      var uid = msg.sendID!;
      var uname = msg.senderNickname;
      if (!curMsgAtUserInfos.any((info) => info.atUserID == uid)) {
        curMsgAtUserInfos.add(AtUserInfo(groupNickname: uname, atUserID: uid));
      }

      // 在光标出插入内容
      // 先保存光标前和后内容
      var cursor = inputCtrl.selection.base.offset;
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
        cursor = _lastCursorIndex;
      }
      if (cursor < 0) cursor = 0;
      // 光标前面的内容
      var start = inputCtrl.text.substring(0, cursor);
      // 光标后面的内容
      var end = inputCtrl.text.substring(cursor);
      var at = ' @$uid ';
      inputCtrl.text = '$start$at$end';
      inputCtrl.selection = TextSelection.collapsed(offset: '$start$at'.length);
      // inputCtrl.selection = TextSelection.fromPosition(TextPosition(
      //   offset: '$start$at'.length,
      // ));
      _lastCursorIndex = inputCtrl.selection.start;
    }
  }

  // 检查是否是直播分享
  bool _isLiveStreamLink(String text) {
    // 检查是否包含直播分享标识（支持中英文）
    return (text.contains('🎥Live Stream:') && text.contains('Room ID:')) ||
        (text.contains('🎥直播分享:') && text.contains('房间ID:'));
  }

  // 从分享文本解析出房间ID
  String? _extractRoomIdFromUrl(String text) {
    try {
      // 使用正则表达式提取房间ID（支持中英文）
      final RegExp roomIdRegex =
      RegExp(r'(?:Room ID|房间ID):\s*([a-zA-Z0-9_-]+)');
      final match = roomIdRegex.firstMatch(text);
      if (match != null) {
        String roomId = match.group(1)!;
        ILogger.d('解析到直播房间ID: $roomId');
        return roomId;
      }
    } catch (e) {
      ILogger.e('解析直播分享出错: $e');
    }
    return null;
  }

  // 处理直播分享
  void _handleLiveStreamLink(String text) {
    String? roomId = _extractRoomIdFromUrl(text);

    if (roomId != null && roomId.isNotEmpty) {
      // 弹出确认对话框
      Get.dialog(
        CustomDialog(
          title: StrRes.joinMeeting,
          content: sprintf(StrRes.joinMeetingContent, [roomId]),
          rightText: StrRes.joinIn,
          leftText: StrRes.cancel,
        ),
      ).then((value) {
        if (value == true) {
          // 调用API获取连接参数后进入会议页面
          _joinStreamByRoomId(roomId);
        }
      });
    }
  }

  // 通过API获取会议连接信息并进入会议
  Future<void> _joinStreamByRoomId(String roomId) async {
    // 显示加载对话框
    Get.dialog(
      Dialog(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16.0),
              Text(StrRes.connecting),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final result = await apiService.joinStream(
        roomName: roomId, // 房间名字
      );

      // 关闭加载对话框
      Get.back();

      if (result != null) {
        final connectionDetails = result['connection_details'];
        final token = connectionDetails['token'];
        final wsUrl = connectionDetails['ws_url'];

        Get.off(
              () => MeetingPage(),
          arguments: {
            'wsUrl': wsUrl,
            'token': token,
          },
          // 设置导航选项禁用侧滑手势返回
          transition: Transition.rightToLeft,
          popGesture: false, // 禁用侧滑返回手势
        );
      } else {
        throw Exception('加入直播失败');
      }
    } catch (e) {
      // 确保关闭加载对话框
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      // IMViews.showToast('加入会议失败');
    }
  }

  void parseClickEvent(Message msg) async {
    if (msg.contentType == MessageType.custom) {
      var data = msg.customElem?.data;
      if (data != null) {
        var map = json.decode(data);
        var customType = map['customType'];

        if (CustomMessageType.call == customType && !isInBlacklist.value) {
          // 处理通话类型
        }
      }
      return;
    } else if (msg.contentType == MessageType.card) {
      // 使用 cardElem 属性获取名片信息
      if (msg.cardElem != null) {
        // 创建 UserInfo 对象
        UserInfo userInfo = UserInfo()
          ..userID = msg.cardElem!.userID
          ..nickname = msg.cardElem!.nickname
          ..faceURL = msg.cardElem!.faceURL;

        // 跳转到用户信息页面
        viewUserInfo(userInfo, isCard: true);
      }
    } else if (msg.contentType == MessageType.text) {
      // 检查文本消息中是否包含直播分享
      final text = msg.textElem?.content ?? '';

      // 检查是否包含直播分享
      if (_isLiveStreamLink(text)) {
        _handleLiveStreamLink(text);
        return;
      }
    } else if (msg.contentType == MessageType.voice) {
      _audioManager.play(msg);
    } else if (msg.contentType == MessageType.merger) {
      Get.to(ChatMerge(message: msg));
    } else if (msg.contentType ==
        MessageType.groupInfoSetAnnouncementNotification) {
      toNotivication();
    }
    IMUtils.parseClickEvent(
      msg,
      onViewUserInfo: (userInfo) {
        viewUserInfo(userInfo, isCard: msg.isCardType);
      },
    );
  }

  void clickLinkText(url, type) async {
    // 检查是否是直播分享
    if (_isLiveStreamLink(url)) {
      _handleLiveStreamLink(url);
      return;
    }

    // 如果不是直播分享或解析失败，使用默认处理方式
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void onTapLeftAvatar(Message message) {
    viewUserInfo(UserInfo()
      ..userID = message.sendID
      ..nickname = message.senderNickname
      ..faceURL = message.senderFaceUrl);
  }

  void onTapRightAvatar() {
    viewUserInfo(OpenIM.iMManager.userInfo);
  }

  void viewUserInfo(UserInfo userInfo, {bool isCard = false}) {
    if (isGroupChat && !isCard) {
      var isShow = false;
      if (isOwner) {
        // 群主总是可以查看成员资料
        isShow = true;
      } else if (isAdmin) {
        // 管理员根据 lookMemberInfo 级别判断
        isShow = lookMemberInfo < 3; // 3 时不允许管理员查看
      } else {
        // 普通成员根据 lookMemberInfo 级别判断
        isShow = lookMemberInfo.value == 0; // 只有 0 时允许普通成员查看
      }
      if (isShow) {
        AppNavigator.startUserProfilePane(
          userID: userInfo.userID!,
          nickname: userInfo.nickname,
          faceURL: userInfo.faceURL,
          groupID: groupID,
          offAllWhenDelFriend: isSingleChat,
        );
      }
    } else {
      AppNavigator.startUserProfilePane(
        userID: userInfo.userID!,
        nickname: userInfo.nickname,
        faceURL: userInfo.faceURL,
        groupID: groupID,
        offAllWhenDelFriend: isSingleChat,
        forceCanAdd: isCard,
      );
    }
  }

  exit() async {
    if (isMultiSelectMode.value) {
      toggleMultiSelectMode();
    } else {
      Get.back();
    }

    return true;
  }

  Message indexOfMessage(int index, {bool calculate = true}) =>
      IMUtils.calChatTimeInterval(
        messageList,
        calculate: calculate,
      ).reversed.elementAt(index);

  ValueKey itemKey(Message message) => ValueKey(message.clientMsgID!);

  @override
  void onClose() {
    sendTypingMsg();
    _clearUnreadCount();
    inputCtrl.dispose();
    focusNode.dispose();
    forceCloseToolbox.close();
    conversationSub.cancel();
    newMessageSub.cancel();  // 取消新消息订阅
    revokedMessageSub.cancel();
    sendStatusSub.close();
    memberAddSub.cancel();
    memberDelSub.cancel();
    memberInfoChangedSub.cancel();
    groupInfoUpdatedSub.cancel();
    friendInfoChangedSub.cancel();
    userStatusChangedSub?.cancel();
    selfInfoUpdatedSub?.cancel();
    joinedGroupAddedSub.cancel();
    joinedGroupDeletedSub.cancel();
    c2cReadReceiptSub?.cancel();
    connectionSub.cancel();

    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);

    // 清理消息回调，避免内存泄漏和回调混乱（已读回执改由 c2cReadReceiptSubject 订阅，此处不再覆盖全局回调）
    imLogic.onRecvNewMessage = null;
    imLogic.onSignalingMessage = null;

    _muteTimer?.cancel();
    _groupMutedRefreshTimer?.cancel();
    _groupInfoDebounceTimer?.cancel();
    _groupMutedRetryTimer?.cancel();

    _debounce?.cancel();
    GetTags.destroyChatTag();
    appLogic.clearActiveConversation();

    // 输出去重器状态
    MessageDeduplicator.instance.logStatus();

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final wasInBackground = !_isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (!_isAppInForeground) {
      // 切换到后台：清除活跃会话，启用推送通知
      appLogic.clearActiveConversation();
    } else if (wasInBackground) {
      // 从后台返回前台：恢复会话并同步消息
      appLogic.setActiveConversation(conversationInfo.conversationID);

      // 延迟执行，确保 UI 完全恢复
      Future.delayed(Duration(milliseconds: 300), () async {
        try {
          // 从服务器拉取最新消息
          final result = await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
            conversationID: conversationInfo.conversationID,
            startMsg: null,
            count: 50,
          );

          if (result.messageList != null && result.messageList!.isNotEmpty) {
            _mergeHistoryMessages(result.messageList!);
          } else {
            // 即使没有新消息，也对当前列表做一次排序，保证顺序一致
            final fullList = messageList;
            if (fullList.isNotEmpty) {
              final sortedFull = _sortMessagesBySendTimeAsc(fullList);
              customChatListViewController.clear();
              customChatListViewController.insertAllToBottom(sortedFull);
            }
            _syncRxListWithMessageList();
            customChatListViewController.refresh();
            update();
          }
        } catch (e) {
          customChatListViewController.refresh();
        }

        // 滚动到底部
        if (scrollController.hasClients) {
          ScrollControllerExt(scrollController).scrollToBottom();
        }

        _applyPendingReadReceipts();
        _clearUnreadCount();
        // 标记未读消息为已读
        try {
          final unreadMsgs = messageList.where((m) =>
          !m.isRead! && m.sendID != OpenIM.iMManager.userID
          ).toList();

          if (unreadMsgs.isNotEmpty) {
            final msgIds = unreadMsgs.map((m) => m.clientMsgID!).toList();
            print('[ChatLogic] 📤 上报已读(批量) conversationID=${conversationInfo.conversationID} count=${msgIds.length}');
            await OpenIM.iMManager.messageManager.markMessagesAsReadByMsgID(
                conversationID: conversationInfo.conversationID,
                messageIDList: msgIds
            );
          }
        } catch (e) {
          // 忽略标记已读失败
        }
      });
    }
  }

  /// 同步 rxList 与 messageList，确保 UI 能看到所有消息
  void _syncRxListWithMessageList() {
    final rxList = customChatListViewController.rxList;
    final currentList = messageList;

    if (rxList.length != currentList.length) {
      rxList.clear();
      rxList.addAll(currentList);
    } else {
      rxList.refresh();
    }
  }

  String? getShowTime(Message message) {
    if (message.exMap['showTime'] == true) {
      return IMUtils.getChatTimeline(message.sendTime!);
    }
    return null;
  }

  void clearAllMessage() {
    customChatListViewController.clear();
  }

  void _initChatConfig() async {
    scaleFactor.value = DataSp.getChatFontSizeFactor();
    var path = DataSp.getChatBackground(otherId) ?? '';
    if (path.isNotEmpty && (await File(path).exists())) {
      background.value = path;
    }
  }

  String get otherId => isSingleChat ? userID! : groupID!;

  void failedResend(Message message) {
    if (message.status == MessageStatus.sending) {
      return;
    }
    sendStatusSub.addSafely(MsgStreamEv<bool>(
      id: message.clientMsgID!,
      value: true,
    ));

    _sendMessage(message..status = MessageStatus.sending, addToUI: false);
  }

  static int get _timestamp => DateTime.now().millisecondsSinceEpoch;

  void destroyMsg() {
    for (var message in privateMessageList) {
      OpenIM.iMManager.messageManager.deleteMessageFromLocalAndSvr(
        conversationID: conversationInfo.conversationID,
        clientMsgID: message.clientMsgID!,
      );
    }
  }

  /// 群已解散错误码（服务端 DismissedAlreadyError）
  static const int _groupDismissedErrorCode = 1204;

  bool _handleGroupDismissedError(dynamic e) {
    final code = e is PlatformException ? int.tryParse(e.code) : null;
    if (code == _groupDismissedErrorCode) {
      IMViews.showToast(StrRes.groupDisbanded);
      Get.back();
      return true;
    }
    return false;
  }

  Future _queryMyGroupMemberInfo() async {
    if (!isGroupChat) {
      return;
    }
    try {
      var list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
        groupID: groupID!,
        userIDList: [OpenIM.iMManager.userID],
      );
      groupMembersInfo = list.firstOrNull;
      groupMemberRoleLevel.value =
          groupMembersInfo?.roleLevel ?? GroupRoleLevel.member;
      _updateMuteStatus();
      if (null != groupMembersInfo) {
        memberUpdateInfoMap[OpenIM.iMManager.userID] = groupMembersInfo!;
      }
    } catch (e) {
      if (_handleGroupDismissedError(e)) return;
      rethrow;
    }
  }

  Future _queryOwnerAndAdmin() async {
    if (!isGroupChat) return;
    try {
      ownerAndAdmin = await OpenIM.iMManager.groupManager
          .getGroupMemberList(groupID: groupID!, filter: 5, count: 20);
    } catch (e) {
      if (_handleGroupDismissedError(e)) return;
      rethrow;
    }
  }

  void _isJoinedGroup() async {
    if (!isGroupChat) {
      return;
    }
    isInGroup.value = await OpenIM.iMManager.groupManager.isJoinedGroup(
      groupID: groupID!,
    );
    if (!isInGroup.value) {
      return;
    }
    _queryGroupInfo();
    _queryOwnerAndAdmin();
  }

  void _queryGroupInfo() async {
    if (!isGroupChat) {
      return;
    }
    try {
      var list = await OpenIM.iMManager.groupManager.getGroupsInfo(
        groupIDList: [groupID!],
      );
      groupInfo = list.firstOrNull;
      final status = groupInfo?.status ?? 0;
      final isMuted = status == 3;
      _groupMuted.value = isMuted;
      _lastGroupMutedFromServerMs = DateTime.now().millisecondsSinceEpoch;
      notification.value = groupInfo?.notification ?? '';
      setIsReadNotification();
      groupOwnerID = groupInfo?.ownerUserID;
      if (null != groupInfo?.memberCount) {
        memberCount.value = groupInfo!.memberCount!;
        lookMemberInfo.value = groupInfo!.lookMemberInfo!;
      }
      _queryMyGroupMemberInfo();
      update();
      // 若本次拿到的是“已禁言”(3)，可能是 SDK 缓存；1.5s 后再拉一次以尽量拿到服务端最新状态（仅一次）
      if (isMuted && !_groupMutedRetryScheduled) {
        _groupMutedRetryScheduled = true;
        _groupMutedRetryTimer?.cancel();
        _groupMutedRetryTimer = Timer(const Duration(milliseconds: 1500), () {
          _queryGroupInfo();
        });
      }
    } catch (e) {
      if (_handleGroupDismissedError(e)) return;
      rethrow;
    }
  }

  /// 收到群内通知类消息时，防抖拉取一次群信息（含禁言状态），实现实时同步
  void _scheduleGroupInfoRefresh() {
    if (!isGroupChat) return;
    _groupInfoDebounceTimer?.cancel();
    _groupInfoDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _queryGroupInfo();
    });
  }

  /// 从当前会话消息列表中同步群禁言状态（历史中的 1514/1515），作为 1514/1515 未实时推送时的兜底
  void _syncGroupMutedFromMessageList() {
    if (!isGroupChat || groupID == null) return;
    final list = customChatListViewController.list;
    Message? latest;
    for (final msg in list) {
      if (msg.groupID != groupID) continue;
      if (msg.contentType != MessageType.groupMutedNotification &&
          msg.contentType != MessageType.groupCancelMutedNotification) continue;
      if (latest == null ||
          (msg.sendTime ?? 0) > (latest.sendTime ?? 0)) {
        latest = msg;
      }
    }
    if (latest != null) {
      _groupMuted.value =
          latest.contentType == MessageType.groupMutedNotification;
      update();
    }
  }

  bool get havePermissionMute =>
      isGroupChat &&
          (groupInfo?.ownerUserID ==
              OpenIM.iMManager
                  .userID /*||
          groupMembersInfo?.roleLevel == 2*/
          );

  bool isNotificationType(Message message) => message.contentType! >= 1000;

  Map<String, String> getAtMapping(Message message) {
    return {};
  }

  void _checkInBlacklist() async {
    if (userID != null) {
      var list = await OpenIM.iMManager.friendshipManager.getBlacklist();
      var user = list.firstWhereOrNull((e) => e.userID == userID);
      isInBlacklist.value = user != null;
    }
  }

  bool isExceed24H(Message message) {
    int milliseconds = message.sendTime!;
    return !DateUtil.isToday(milliseconds);
  }

  String? getNewestNickname(Message message) {
    if (isSingleChat) null;

    return message.senderNickname;
  }

  /// 设置已读通知状态
  setIsReadNotification() async {
    if (isGroupChat) {
      final prefs = await SharedPreferences.getInstance();
      // 读取旧的已读通知时间
      final key = 'old_read_notification_time_${groupID!}';
      final oldTime = prefs.getInt(key) ?? 0;
      final newTime = groupInfo?.notificationUpdateTime ?? 0;
      isReadNotification.value = oldTime >= newTime;
      return;
    }
    isReadNotification.value = false;
  }

  toNotivication() {
    if (isGroupChat) {
      AppNavigator.startGroupAc(groupInfo: groupInfo!);
    }
  }

  setAcReadTime() async {
    if (isGroupChat) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'old_read_notification_time_${groupID!}';
      final oldTime = prefs.getInt(key) ?? 0;
      prefs.setInt(key, max(groupInfo?.notificationUpdateTime ?? 0, oldTime));
      isReadNotification.value = true;
    }
  }

  String? getNewestFaceURL(Message message) {
    return message.senderFaceUrl;
  }

  bool get isInvalidGroup => !isInGroup.value && isGroupChat;

  void _resetGroupAtType() {
    if (conversationInfo.groupAtType != GroupAtType.atNormal) {
      OpenIM.iMManager.conversationManager.resetConversationGroupAtType(
        conversationID: conversationInfo.conversationID,
      );
    }
  }

  WillPopCallback? willPop() {
    return null;
  }

  void call() async {
    if (rtcIsBusy) {
      IMViews.showToast(StrRes.callingBusy);
      return;
    }

    // 检查对方是否拥有官方账号保护权限
    if (isSingleChat && userID != null) {
      final hasProtection = await core.ApiService().checkUserHasProtection(userID!);
      if (hasProtection) {
        IMViews.showToast('此用户为官方客服，暂不支持通话');
        return;
      }
    }

    IMViews.openIMCallSheet(nickname.value, (index) {
      imLogic.call(
        callObj: CallObj.single,
        callType: index == 0 ? CallType.audio : CallType.video,
        inviteeUserIDList: [if (isSingleChat) userID!],
      );
    });
  }

  String get markText {
    String? phoneNumber = imLogic.userInfo.value.phoneNumber;
    if (phoneNumber != null) {
      int start = phoneNumber.length > 4 ? phoneNumber.length - 4 : 0;
      final sub = phoneNumber.substring(start);
      return "${OpenIM.iMManager.userInfo.nickname!}$sub";
    }
    return OpenIM.iMManager.userInfo.nickname ?? '';
  }

  bool isFailedHintMessage(Message message) {
    if (message.contentType == MessageType.custom) {
      var data = message.customElem!.data;
      var map = json.decode(data!);
      var customType = map['customType'];
      return customType == CustomMessageType.deletedByFriend ||
          customType == CustomMessageType.blockedByFriend;
    }
    return false;
  }

  void sendFriendVerification() =>
      AppNavigator.startSendVerificationApplication(userID: userID);

  void _setSdkSyncDataListener() {
    connectionSub = imLogic.imSdkStatusPublishSubject.listen((value) {
      syncStatus.value = value.status;
      if (value.status == IMSdkStatus.syncStart) {
        _isStartSyncing = true;
      } else if (value.status == IMSdkStatus.syncEnded) {
        if (/*_isReceivedMessageWhenSyncing &&*/ _isStartSyncing) {
          _isReceivedMessageWhenSyncing = false;
          _isStartSyncing = false;
          _isFirstLoad = true;
          _loadHistoryForSyncEnd();
        }
      } else if (value.status == IMSdkStatus.syncFailed) {
        _isReceivedMessageWhenSyncing = false;
        _isStartSyncing = false;
      }
    });
  }

  bool get isSyncFailed => syncStatus.value == IMSdkStatus.syncFailed;

  String? get syncStatusStr {
    switch (syncStatus.value) {
      case IMSdkStatus.syncStart:
      case IMSdkStatus.synchronizing:
        return StrRes.synchronizing;
      case IMSdkStatus.syncFailed:
        return StrRes.syncFailed;
      default:
        return null;
    }
  }

  bool showBubbleBg(Message message) {
    return !isNotificationType(message) && !isFailedHintMessage(message);
  }

  /// 将服务端 PullMessageBySeqs 返回的单条 MsgData（Map）转为 SDK Message 并写入本地
  Future<void> _insertServerMsgToLocal(Map<String, dynamic> raw, String groupID) async {
    final sendID = raw['sendID'] as String? ?? '';
    final contentType = raw['contentType'] as int? ?? 0;
    final content = raw['content'];
    String? contentStr;
    if (content != null && content is String) {
      contentStr = content;
      if (content.length > 0 && content.length % 4 == 0 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(content)) {
        try {
          contentStr = utf8.decode(base64Decode(content));
          // 服务端文本消息 content 常为 JSON 如 {"content":"xxx"}，提取 content 字段
          if (contentStr.startsWith('{')) {
            final decoded = jsonDecode(contentStr) as Map<String, dynamic>?;
            contentStr = decoded?['content']?.toString();
          }
        } catch (_) {}
      }
    }
    final map = <String, dynamic>{
      'clientMsgID': raw['clientMsgID'],
      'serverMsgID': raw['serverMsgID'],
      'createTime': raw['createTime'],
      'sendTime': raw['sendTime'],
      'sendID': raw['sendID'],
      'recvID': raw['recvID'],
      'msgFrom': raw['msgFrom'],
      'contentType': contentType,
      'senderPlatformID': raw['senderPlatformID'],
      'senderNickname': raw['senderNickname'],
      'senderFaceUrl': raw['senderFaceURL'],
      'groupID': raw['groupID'],
      'seq': raw['seq'],
      'isRead': raw['isRead'],
      'status': raw['status'] ?? 2,
      'sessionType': raw['sessionType'],
    };
    if (contentType == 101 && contentStr != null && contentStr.isNotEmpty) {
      map['textElem'] = {'content': contentStr};
    }
    if (raw['offlinePushInfo'] != null) {
      map['offlinePush'] = raw['offlinePushInfo'];
    }
    if (raw['ex'] != null) map['ex'] = raw['ex'];
    if (raw['attachedInfo'] != null) map['attachedInfo'] = raw['attachedInfo'];
    try {
      final msg = Message.fromJson(map);
      await OpenIM.iMManager.messageManager.insertGroupMessageToLocalStorage(
        message: msg,
        groupID: groupID,
        senderID: sendID,
      );
    } catch (e) {
      ILogger.d('_insertServerMsgToLocal parse/insert error: $e');
    }
  }

  /// 群聊：从服务端按 seq 分段拉取历史并写入本地。返回 (插入条数, 服务端是否已到顶 isEnd)
  /// [endSeq] 为 null 表示「首屏只拉最近一页」：用大 end 让服务端返回最后 count 条，不先请求 getNewestSeq，加快进群展示
  Future<(int, bool)> _pullGroupHistoryFromServer({
    required String conversationID,
    required String groupID,
    int? endSeq,
    int count = 20,
  }) async {
    final userID = OpenIM.iMManager.userID;
    if (userID == null || userID.isEmpty) return (0, true);

    // 群聊历史消息存储在 sg_groupID，若 conversationID 为 n_groupID 则转换为 sg_
    var chatConversationID = conversationID;
    if (conversationID.startsWith('n_') && groupID.isNotEmpty) {
      chatConversationID = 'sg_$groupID';
      ILogger.d('[群聊上翻] conversationID $conversationID 转为 chatConversationID $chatConversationID');
    }

    int begin;
    int end;
    if (endSeq == null || endSeq < 1) {
      begin = 1;
      end = 2147483647;
    } else {
      end = endSeq;
      begin = max(1, end - count + 1);
    }

    ILogger.d('[群聊上翻] pullMessageBySeqs conv=$chatConversationID groupID=$groupID begin=$begin end=$end');

    final resp = await Apis.pullMessageBySeqs(
      userID: userID,
      seqRanges: [
        {'conversationID': chatConversationID, 'begin': begin, 'end': end, 'num': count}
      ],
      order: 1,
    );

    if (resp == null) {
      ILogger.w('[群聊上翻] pullMessageBySeqs 返回 null');
      return (0, true);
    }
    final msgsMap = resp['msgs'] as Map<String, dynamic>?;
    final pullMsgs = msgsMap?[chatConversationID];
    if (pullMsgs == null) {
      ILogger.d('[群聊上翻] msgsMap 中无 conv=$chatConversationID 的 key，resp.keys=${resp.keys}');
      return (0, true);
    }
    final list = (pullMsgs['Msgs'] ?? pullMsgs['msgs']) as List<dynamic>?;
    final isEnd = pullMsgs['isEnd'] as bool? ?? pullMsgs['IsEnd'] as bool? ?? true;
    if (list == null || list.isEmpty) {
      ILogger.d('[群聊上翻] list 为空 isEnd=$isEnd');
      return (0, isEnd);
    }

    int inserted = 0;
    int skipped = 0;
    for (final e in list) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      if ((m['clientMsgID'] ?? m['sendID']) == null) {
        skipped++;
        continue;
      }
      await _insertServerMsgToLocal(m, groupID);
      inserted++;
    }

    ILogger.d('[群聊上翻] inserted=$inserted skipped=$skipped isEnd=$isEnd listLen=${list.length}');

    // 若本批全是占位/已删除消息(inserted=0)，即使 isEnd=false 也当作已到底，避免无限循环请求
    if (inserted == 0 && skipped > 0) {
      return (0, true);
    }
    return (inserted, isEnd);
  }

  Future<AdvancedMessage> _fetchHistoryMessages(Message? startMsg) {
    // 首次进入会话时,未读很多会导致一次性拉取过多历史消息,影响进入速度。
    // 这里为 pageSize 设置一个合理上限,保证首屏加载更快,更多历史由用户上滑按需加载。
    var pageSize = _isFirstLoad
        ? max(conversationInfo.unreadCount + 1, _pageSize)
        : _pageSize;
    const int kMaxFirstPageSize = 100;
    if (pageSize > kMaxFirstPageSize) {
      pageSize = kMaxFirstPageSize;
    }
    return OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
      conversationID: conversationInfo.conversationID,
      count: pageSize,
      startMsg: startMsg,
    );
  }

  Future<AdvancedMessage> _fetchReverseHistoryMessages(Message? startMsg) {
    return OpenIM.iMManager.messageManager.getAdvancedHistoryMessageListReverse(
      conversationID: conversationInfo.conversationID,
      count: _pageSize,
      startMsg: startMsg,
    );
  }

  Future<bool> onScrollToBottomLoad() async {
    final startMsg = customChatListViewController.list.lastOrNull;

    var result = await _fetchReverseHistoryMessages(startMsg);
    if (result.messageList == null || result.messageList!.isEmpty) {
      return false;
    }
    var list = result.messageList!;

    // 过滤通话信令及群通知消息，并按 sendTime 升序保证顺序一致
    var filteredList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(list));

    // 若本页全是群通知等被过滤消息，继续拉取直到有可展示消息或到末尾，避免一直转圈
    const int maxIterations = 10;
    int iterations = 0;
    while (filteredList.isEmpty &&
        list.isNotEmpty &&
        result.isEnd != true &&
        iterations < maxIterations) {
      final nextResult = await _fetchReverseHistoryMessages(list.last);
      if (nextResult.messageList == null ||
          nextResult.messageList!.isEmpty) break;
      list = [...list, ...nextResult.messageList!];
      filteredList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(list));
      result = nextResult;
      iterations++;
    }

    customChatListViewController.insertAllToBottom(filteredList);
    return result.isEnd != true;
  }

  Future<bool> onScrollToTopLoad() async {
    Message? startMsg = customChatListViewController.list.firstOrNull;
    var result = await _fetchHistoryMessages(startMsg);
    bool serverPulledIsEnd = true;
    bool didServerPull = false;
    if (searchMessage == null &&
        isGroupChat &&
        (result.messageList == null || result.messageList!.isEmpty)) {
      final conversationID = conversationInfo.conversationID;
      final groupID = conversationInfo.groupID ?? '';
      final endSeq = startMsg?.seq != null ? (startMsg!.seq! - 1) : null;
      final oldFirst = startMsg;
      final (inserted, isEnd) = await _pullGroupHistoryFromServer(
        conversationID: conversationID,
        groupID: groupID,
        endSeq: endSeq,
        count: _pageSize,
      );
      serverPulledIsEnd = isEnd;
      didServerPull = true;
      if (inserted > 0) {
        result = await _fetchHistoryMessages(oldFirst);
      }
    }
    if (searchMessage == null &&
        (result.messageList == null || result.messageList!.isEmpty)) {
      if (_isFirstLoad) {
        firstLoadEmpty.value = true;
        _getGroupInfoAfterLoadMessage();
        _clearUnreadCount();
        _isFirstLoad = false;
      }
      return false;
    }
    firstLoadEmpty.value = false;
    var list = result.messageList!;

    // 过滤通话信令及群通知消息，并按 sendTime 升序保证顺序一致
    var filteredList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(list));

    // 首次加载时若本页全是群通知等被过滤消息，则继续向后拉取直到有可展示消息或到末尾，避免群聊只显示“空+一直转圈”
    const int maxIterations = 10;
    int iterations = 0;
    while (searchMessage == null &&
        _isFirstLoad &&
        filteredList.isEmpty &&
        list.isNotEmpty &&
        result.isEnd != true &&
        iterations < maxIterations) {
      final nextResult = await _fetchHistoryMessages(list.last);
      if (nextResult.messageList == null ||
          nextResult.messageList!.isEmpty) break;
      list = [...list, ...nextResult.messageList!];
      filteredList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(list));
      result = nextResult;
      iterations++;
    }

    if (searchMessage == null && _isFirstLoad) {
      customChatListViewController.insertAllToBottom(filteredList);
    } else {
      customChatListViewController.insertAllToTop(filteredList);
    }

    // 非首次加载(用户上拉查看更多历史消息)时,对新加载的一页消息增量补全红包状态,
    // 避免历史里已领取/已领完的红包仍显示待领取。
    if (!_isFirstLoad && filteredList.isNotEmpty) {
      // 增量处理这一页消息中的红包状态(本地+最近少量服务端校准),不改变消息顺序
      unawaited(_initLuckMoneyStatusForMessages(filteredList));
    }

    if (_isFirstLoad) {
      _getGroupInfoAfterLoadMessage();
      _applyPendingReadReceipts();
      _clearUnreadCount();
      _isFirstLoad = false;
      if (searchMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final RenderBox box =
          scrollViewKey.currentContext!.findRenderObject() as RenderBox;
          final scrollViewHeight = box.size.height;
          scrollController.jumpTo((scrollViewHeight ?? 0) * -1);
        });
      }
    }
    if (didServerPull) return !serverPulledIsEnd;
    return result.isEnd != true;
  }

  /// 增量补全一批消息中的红包状态(用于上拉加载更多历史消息时),
  /// 逻辑与 _initLuckMoneyStatusFromLocal 保持一致,但作用范围仅限传入 messages。
  Future<void> _initLuckMoneyStatusForMessages(List<Message> messages) async {
    try {
      final luckyMoneyMessages = messages
          .where((msg) =>
      msg.contentType == MessageType.custom &&
          msg.customElem != null &&
          msg.customElem!.data != null)
          .toList();
      if (luckyMoneyMessages.isEmpty) return;

      final allLuckyMoneyStatuses =
      await LuckMoneyStatusManager.getAllLuckMoneyStatuses(
          userId: OpenIM.iMManager.userID);
      final allPacketStatuses =
      await LuckMoneyStatusManager.getAllPacketStatuses();

      // 先用本地状态更新这一批消息
      for (final msg in luckyMoneyMessages) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] != CustomMessageType.luckMoney) continue;
          final luckyMoneyData = data['data'];
          if (luckyMoneyData == null) continue;

          final luckyMoneyId = luckyMoneyData['msg_id'];
          if (luckyMoneyId == null || luckyMoneyId.isEmpty) continue;

          final userStatus =
              allLuckyMoneyStatuses[luckyMoneyId] ?? 'pending';
          final packetStatus =
              allPacketStatuses[luckyMoneyId] ?? 'pending';

          bool isReceived = false;
          String finalStatus = 'pending';

          if (userStatus == 'completed') {
            isReceived = true;
            finalStatus = 'completed';
          } else if (packetStatus == 'completed') {
            isReceived = false;
            finalStatus = 'completed';
          } else {
            finalStatus = userStatus;
          }

          luckyMoneyData['isReceived'] = isReceived;
          luckyMoneyData['status'] = finalStatus;
          msg.customElem!.data = json.encode(data);
        } catch (e) {
          ILogger.e('增量解析红包消息数据失败: $e');
        }
      }

      // 对这一页中本地仍为 pending 的少量红包做一次服务端校准
      final apiService = core.ApiService();
      const int kMaxServerCheckCount = 10;
      final List<Message> candidates = luckyMoneyMessages
          .where((msg) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] != CustomMessageType.luckMoney) {
            return false;
          }
          final luckyMoneyData = data['data'];
          if (luckyMoneyData == null) return false;
          final luckyMoneyId = luckyMoneyData['msg_id'] as String?;
          if (luckyMoneyId == null || luckyMoneyId.isEmpty) return false;
          return allLuckyMoneyStatuses[luckyMoneyId] != 'completed';
        } catch (_) {
          return false;
        }
      })
          .toList();

      if (candidates.isEmpty) return;

      final Iterable<Message> toCheck = candidates.length > kMaxServerCheckCount
          ? candidates.sublist(0, kMaxServerCheckCount)
          : candidates;

      for (final msg in toCheck) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] != CustomMessageType.luckMoney) continue;
          final luckyMoneyData = data['data'];
          if (luckyMoneyData == null) continue;
          final luckyMoneyId = luckyMoneyData['msg_id'] as String?;
          if (luckyMoneyId == null || luckyMoneyId.isEmpty) continue;

          final result =
          await apiService.transactionCheckCompleted(transaction_id: luckyMoneyId);
          final Map<String, dynamic>? respData = result == null
              ? null
              : ((result as Map<String, dynamic>)['data'] ?? result)
          as Map<String, dynamic>?;
          final received = respData?['received'] == true;
          final completed = respData?['completed'] == true;

          if (received) {
            redPacketStatusMap[luckyMoneyId] = 'completed';
            luckyMoneyData['isReceived'] = true;
            luckyMoneyData['status'] = 'completed';
            msg.customElem!.data = json.encode(data);
            await LuckMoneyStatusManager.saveLuckMoneyStatus(luckyMoneyId,
                'completed', userId: OpenIM.iMManager.userID);
          } else if (completed) {
            // 红包整体已结束但当前用户未领取：仅更新视觉状态与整体状态缓存
            luckyMoneyData['isReceived'] = false;
            luckyMoneyData['status'] = 'completed';
            msg.customElem!.data = json.encode(data);
            await LuckMoneyStatusManager.savePacketStatus(
                luckyMoneyId, 'completed');
          }
        } catch (e) {
          ILogger.d('增量拉取红包服务端状态失败: $e');
        }
      }
      redPacketStatusMap.refresh();
      customChatListViewController.refresh();
    } catch (e) {
      ILogger.e('增量初始化红包状态失败: $e');
    }
  }

  Future<void> _loadHistoryForSyncEnd() async {
    final result =
    await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
      conversationID: conversationInfo.conversationID,
      count: messageList.length < _pageSize ? _pageSize : messageList.length,
      startMsg: null,
    );
    if (result.messageList == null || result.messageList!.isEmpty) return;
    _mergeHistoryMessages(result.messageList!);
  }

  void _mergeHistoryMessages(List<Message> messages) {
    final incoming = _sortMessagesBySendTimeAsc(_filterMessagesForChat(messages));
    final existingIds =
        messageList.map((m) => m.clientMsgID).whereType<String>().toSet();

    for (final newMsg in incoming) {
      if (_mergeSyncedMessage(newMsg)) {
        final clientMsgID = newMsg.clientMsgID;
        if (clientMsgID != null && clientMsgID.isNotEmpty) {
          existingIds.add(clientMsgID);
        }
        continue;
      }

      final clientMsgID = newMsg.clientMsgID;
      if (clientMsgID == null || clientMsgID.isEmpty) {
        customChatListViewController.insertToBottom(newMsg);
        continue;
      }
      if (!existingIds.contains(clientMsgID)) {
        customChatListViewController.insertToBottom(newMsg);
        existingIds.add(clientMsgID);
      }
    }

    final fullList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(messageList));
    customChatListViewController.clear();
    customChatListViewController.insertAllToBottom(fullList);
    _syncRxListWithMessageList();
    customChatListViewController.refresh();
    update();
  }

  void _getGroupInfoAfterLoadMessage() {
    if (isGroupChat && ownerAndAdmin.isEmpty) {
      _isJoinedGroup();
    } else {
      _checkInBlacklist();
    }
  }

  /// 首次加载为空时（本地无该会话消息）可调用：先触发会话列表拉取以促发同步，再重新拉取历史
  Future<void> retryLoadHistory() async {
    if (retryingLoadHistory.value) return;
    retryingLoadHistory.value = true;
    firstLoadEmpty.value = false;
    _isFirstLoad = true;
    try {
      await OpenIM.iMManager.conversationManager.getConversationListSplit(offset: 0, count: 400);
      await Future.delayed(const Duration(milliseconds: 1800));
      await onScrollToTopLoad();
    } catch (_) {}
    retryingLoadHistory.value = false;
  }

  recommendFriendCarte(UserInfo userInfo) async {
    final result = await AppNavigator.startSelectContacts(
      action: SelAction.recommend,
      ex: '[${StrRes.carte}]${userInfo.nickname}',
    );
    if (null != result) {
      final customEx = result['customEx'];
      final checkedList = result['checkedList'];
      for (var info in checkedList) {
        final userID = IMUtils.convertCheckedToUserID(info);
        final groupID = IMUtils.convertCheckedToGroupID(info);
        if (customEx is String && customEx.isNotEmpty) {
          _sendMessage(
            await OpenIM.iMManager.messageManager.createTextMessage(
              text: customEx,
            ),
            userId: userID,
            groupId: groupID,
          );
        }
        _sendMessage(
          await OpenIM.iMManager.messageManager.createCardMessage(
            userID: userInfo.userID!,
            nickname: userInfo.nickname!,
            faceURL: userInfo.faceURL,
          ),
          userId: userID,
          groupId: groupID,
        );
      }
    }
  }

  @override
  void onDetached() {}

  @override
  void onHidden() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {
    _loadHistoryForSyncEnd();
    // 从群管理/其他页返回时刷新群信息，确保禁言状态等与服务器一致
    if (isGroupChat && groupID != null) {
      _queryGroupInfo();
    }
  }

  /// 初始化转账状态
  Future<void> _initTransferStatusAndHistory() async {
    try {
      // 获取历史消息中的转账消息
      final transferMessages = messageList
          .where((msg) =>
      msg.contentType == MessageType.custom &&
          msg.customElem != null &&
          msg.customElem!.data != null)
          .toList();

      // 从本地存储获取转账状态
      for (final msg in transferMessages) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] == CustomMessageType.transfer) {
            final transferData = data['data'];
            final transferId = transferData['msg_id'];

            // 从本地存储获取转账状态
            final status =
            await TransferStatusManager.getTransferStatus(transferId);
            final isReceived = status == 'completed';

            // 更新消息状态
            transferData['isReceived'] = isReceived;
            transferData['status'] = status;
          }
        } catch (e) {
          ILogger.d('解析消息数据失败: $e');
        }
      }

      // 刷新消息列表以更新状态
      customChatListViewController.refresh();
    } catch (e) {
      ILogger.d('初始化转账状态失败: $e');
    }
  }

  /// 初始化红包状态
  Future<void> _initLuckMoneyStatusFromLocal() async {
    try {
      // 获取历史消息中的红包消息
      final luckyMoneyMessages = messageList
          .where((msg) =>
      msg.contentType == MessageType.custom &&
          msg.customElem != null &&
          msg.customElem!.data != null)
          .toList();

      if (luckyMoneyMessages.isEmpty) {
        return;
      }

      // 批量获取红包状态（按当前用户过滤）+ 红包整体结束状态，避免多次读取本地存储
      final allLuckyMoneyStatuses =
      await LuckMoneyStatusManager.getAllLuckMoneyStatuses(
          userId: OpenIM.iMManager.userID);
      final allPacketStatuses =
      await LuckMoneyStatusManager.getAllPacketStatuses();

      // 写入响应式缓存（当前用户是否已领取），供 ChatLuckMoneyItemView 的 Obx 订阅，
      // 确保重启进入会话后 UI 能刷新为已领取
      redPacketStatusMap.value = Map.from(allLuckyMoneyStatuses);

      // 1）先用本地存储更新消息与 map
      for (final msg in luckyMoneyMessages) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] == CustomMessageType.luckMoney) {
            final luckyMoneyData = data['data'];
            if (luckyMoneyData == null) continue;

            final luckyMoneyId = luckyMoneyData['msg_id'];
            if (luckyMoneyId == null || luckyMoneyId.isEmpty) continue;

            // 1. 当前用户是否已领取
            final userStatus =
                allLuckyMoneyStatuses[luckyMoneyId] ?? 'pending';
            // 2. 红包整体是否已结束（即使当前用户未领取）
            final packetStatus =
                allPacketStatuses[luckyMoneyId] ?? 'pending';

            bool isReceived = false;
            String finalStatus = 'pending';

            if (userStatus == 'completed') {
              // 自己已领取：既是已领又已结束
              isReceived = true;
              finalStatus = 'completed';
            } else if (packetStatus == 'completed') {
              // 红包整体已结束但当前用户未领取：显示“已抢完/已结束”的视觉状态，
              // 但不标记 isReceived，避免误以为自己抢到
              isReceived = false;
              finalStatus = 'completed';
            } else {
              // 其它情况维持原始 pending/expired 等状态
              finalStatus = userStatus;
            }

            luckyMoneyData['isReceived'] = isReceived;
            luckyMoneyData['status'] = finalStatus;
            msg.customElem!.data = json.encode(data);
          }
        } catch (e) {
          ILogger.e('解析红包消息数据失败: $e');
          // 解析失败仅记录日志,避免删除消息导致会话出现断层或顺序错乱
        }
      }

      // 2）以服务端为准：对「最近少量、且本地仍为 pending 的红包」请求 check_completed，
      //    若当前用户已领取则覆盖为已领取（解决本地未持久化或丢失），避免对大量历史红包逐个发起网络请求。
      final apiService = core.ApiService();
      const int kMaxServerCheckCount = 20;
      // 只针对最近 N 条红包做服务端校准,减少进入会话时的网络压力
      final Iterable<Message> recentLuckyMessages =
      luckyMoneyMessages.length > kMaxServerCheckCount
          ? luckyMoneyMessages
          .sublist(luckyMoneyMessages.length - kMaxServerCheckCount)
          : luckyMoneyMessages;

      for (final msg in recentLuckyMessages) {
        try {
          final data = json.decode(msg.customElem!.data!);
          if (data['customType'] != CustomMessageType.luckMoney) continue;
          final luckyMoneyData = data['data'];
          if (luckyMoneyData == null) continue;

          final luckyMoneyId = luckyMoneyData['msg_id'] as String?;
          if (luckyMoneyId == null || luckyMoneyId.isEmpty) continue;

          // 若本地已是 completed, 无需再向服务端校准
          if (allLuckyMoneyStatuses[luckyMoneyId] == 'completed') {
            continue;
          }

          final result = await apiService.transactionCheckCompleted(transaction_id: luckyMoneyId);
          final Map<String, dynamic>? respData = result == null
              ? null
              : ((result as Map<String, dynamic>)['data'] ?? result) as Map<String, dynamic>?;
          final received = respData?['received'] == true;

          if (received) {
            redPacketStatusMap[luckyMoneyId] = 'completed';
            luckyMoneyData['isReceived'] = true;
            luckyMoneyData['status'] = 'completed';
            msg.customElem!.data = json.encode(data);
            await LuckMoneyStatusManager.saveLuckMoneyStatus(luckyMoneyId, 'completed', userId: OpenIM.iMManager.userID);
          }
        } catch (e) {
          ILogger.d('拉取红包服务端状态失败: $e');
        }
      }
      redPacketStatusMap.refresh();

      // 定期清理过期红包记录
      LuckMoneyStatusManager.cleanupExpiredRecords();

      // 刷新消息列表以更新状态；下一帧再刷新一次，确保列表用到最新 message 与 redPacketStatusMap
      customChatListViewController.refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        customChatListViewController.refresh();
      });
    } catch (e) {
      ILogger.e('初始化红包状态失败: $e');
    }
  }

  /// 处理红包状态更新
  /// 接收到红包消息时调用
  void _handleLuckyMoneyStatusUpdate(Map<String, dynamic> data) {
    try {
      if (data['customType'] != CustomMessageType.luckMoney) return;

      final luckMoneyData = data['data'];
      if (luckMoneyData == null) return;

      final luckMoneyId = luckMoneyData['msg_id'];
      if (luckMoneyId == null || luckMoneyId.isEmpty) return;

      final isReceived = luckMoneyData['isReceived'] ?? false;
      final status = luckMoneyData['status'] ?? 'pending';

      // 更新全局状态
      LuckMoneyStatusManager.saveLuckMoneyStatus(luckMoneyId, status, userId: OpenIM.iMManager.userID);

      // 更新消息列表中的状态
      _updateLuckyMoneyInMessageList(luckMoneyId, luckMoneyData);
    } catch (e) {
      ILogger.d('处理红包状态更新失败: $e');
    }
  }

  /// 更新消息列表中的红包状态
  void _updateLuckyMoneyInMessageList(
      String luckMoneyId, Map<String, dynamic> luckMoneyData) {
    for (var i = 0; i < messageList.length; i++) {
      var msg = messageList[i];
      if (msg.contentType == MessageType.custom) {
        try {
          final msgData = json.decode(msg.customElem!.data!);
          if (msgData['customType'] == CustomMessageType.luckMoney) {
            final msgLuckMoneyData = msgData['data'];
            if (msgLuckMoneyData == null) continue;

            if (msgLuckMoneyData['msg_id'] == luckMoneyId) {
              // 更新红包状态
              msgLuckMoneyData['isReceived'] =
                  luckMoneyData['isReceived'] ?? false;
              msgLuckMoneyData['status'] = luckMoneyData['status'] ?? 'pending';

              // 如果有领取金额，也更新
              if (luckMoneyData['received_amount'] != null) {
                msgLuckMoneyData['received_amount'] =
                luckMoneyData['received_amount'];
              }

              // 更新领取计数
              if (luckMoneyData['received_count'] != null) {
                msgLuckMoneyData['received_count'] =
                luckMoneyData['received_count'];
              }

              // 更新领取记录：仅保留最近 N 条，避免 5000 人群等场景下消息体过大导致 websocket 断连
              if (luckMoneyData['receivers'] != null) {
                final List<dynamic> list = List<dynamic>.from(luckMoneyData['receivers'] as List);
                const int kMaxReceiversInMessage = 50;
                msgLuckMoneyData['receivers'] = list.length > kMaxReceiversInMessage
                    ? list.sublist(list.length - kMaxReceiversInMessage)
                    : list;
              }

              // 创建新消息对象以强制刷新列表
              var updatedMsg = Message.fromJson(msg.toJson());
              messageList[i] = updatedMsg;
              customChatListViewController.refresh();
              break;
            }
          }
        } catch (e) {
          ILogger.d('解析红包消息数据失败: $e');
        }
      }
    }
  }

  void onTapFile(BuildContext context) async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // 检查文件大小限制 20MB
          final fileSize = file.size;
          const maxFileSize = 20 * 1024 * 1024; // 20MB

          if (fileSize > maxFileSize) {
            IMViews.showToast(StrRes.fileSizeLimit);
            return;
          }

          IMViews.showToast(StrRes.sendingFile);

          try {
            Message message;

            // 判断文件类型
            final fileName = file.name.toLowerCase();
            final isImage = fileName.endsWith('.jpg') ||
                fileName.endsWith('.jpeg') ||
                fileName.endsWith('.png') ||
                fileName.endsWith('.gif');
            final isVideo = fileName.endsWith('.mp4') ||
                fileName.endsWith('.mov') ||
                fileName.endsWith('.avi');

            if (isImage) {
              // 发送图片消息
              message = await OpenIM.iMManager.messageManager
                  .createImageMessageFromFullPath(
                imagePath: file.path!,
              );
            } else if (isVideo) {
              // 发送视频消息
              message = await OpenIM.iMManager.messageManager
                  .createVideoMessageFromFullPath(
                videoPath: file.path!,
                videoType: file.extension ?? 'mp4',
                duration: 0, // 视频时长，如果需要可以添加获取视频时长的逻辑
                snapshotPath: file.path!, // 暂时使用视频文件路径作为缩略图路径
              );
            } else {
              // 发送普通文件消息
              message = await OpenIM.iMManager.messageManager
                  .createFileMessageFromFullPath(
                filePath: file.path!,
                fileName: file.name,
              );
            }

            // 发送消息
            await _sendMessage(message);
            IMViews.showToast(StrRes.sendFileSuccess);
          } catch (e) {
            ILogger.d('发送文件失败: $e');
            IMViews.showToast(StrRes.sendFileFailed);
          }
        }
      }
    } catch (e) {
      ILogger.d('选择文件失败: $e');
      IMViews.showToast(StrRes.selectFileFailed);
    }
  }

  final isMultiSelectMode = false.obs;
  final selectedMessages = <Message>[].obs;

  final GlobalKey<ChatInputBoxState> chatInputKey = GlobalKey<ChatInputBoxState>();

  void toggleMultiSelectMode() {
    isMultiSelectMode.value = !isMultiSelectMode.value;
    if (!isMultiSelectMode.value) {
      selectedMessages.clear();
    }
  }

  void selectMessage(Message message) {
    final index = selectedMessages
        .indexWhere((m) => m.clientMsgID == message.clientMsgID);
    if (index == -1) {
      selectedMessages.add(message);
      print(
          'DEBUG: 选择消息 ${message.clientMsgID}, 当前选中数量: ${selectedMessages.length}');
    } else {
      selectedMessages.removeAt(index);
      print(
          'DEBUG: 取消选择消息 ${message.clientMsgID}, 当前选中数量: ${selectedMessages.length}');
    }
  }

  Future<Uint8List?> getImageDataFromMessage(Message message) async {
    if (message.isPictureType) {
      // 首先尝试从本地源文件获取
      if (message.pictureElem?.sourcePath != null &&
          await File(message.pictureElem!.sourcePath!).exists()) {
        return await File(message.pictureElem!.sourcePath!).readAsBytes();
      }
      // 尝试从缓存获取
      File? file;
      String? imageUrl;

      if (IMUtils.isNotNullEmptyStr(
          message.pictureElem?.snapshotPicture?.url)) {
        final url = message.pictureElem!.snapshotPicture!.url!
            .adjustThumbnailAbsoluteString(960);
        file = await getCachedImageFile(UrlConverter.convertMediaUrl(url));
        file ??= await getCachedImageFile(url);
        imageUrl ??= UrlConverter.convertMediaUrl(url);
      }
      if (IMUtils.isNotNullEmptyStr(message.pictureElem?.bigPicture?.url) &&
          file == null) {
        final url = message.pictureElem!.bigPicture!.url!;
        file = await getCachedImageFile(UrlConverter.convertMediaUrl(url));
        file ??= await getCachedImageFile(url);
      }

      if (file != null && await file.exists()) {
        return await file.readAsBytes();
      }

      // 如果缓存中也没有，尝试从网络下载
      if (imageUrl != null) {
        try {
          final dio = Dio();
          final response = await dio.get<List<int>>(
            imageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.statusCode == 200 && response.data != null) {
            return Uint8List.fromList(response.data!);
          }
        } catch (e) {
          ILogger.e('从网络下载图片失败: $e');
        }
      }
    }
    return null;
  }

  void performMessageAction(
      MessageOperationType messageOperationType, Message message) async {
    switch (messageOperationType) {
      case MessageOperationType.copy:
        if (message.isTextType) {
          await Clipboard.setData(
            ClipboardData(text: message.textElem?.content ?? ""),
          );
          IMViews.showToast(StrRes.copySuccessfully);
        }
        if (message.contentType == MessageType.atText) {
          await Clipboard.setData(
            ClipboardData(text: IMUtils.parseMsg(message)),
          );
          IMViews.showToast(StrRes.copySuccessfully);
        }
        if (message.contentType == MessageType.merger) {
          await Clipboard.setData(
            ClipboardData(text: message.mergeElem?.title ?? ''),
          );
          IMViews.showToast(StrRes.copySuccessfully);
        }
        if (message.contentType == MessageType.quote) {
          await Clipboard.setData(
            ClipboardData(text: message.quoteElem?.text ?? ''),
          );
          IMViews.showToast(StrRes.copySuccessfully);
        }
        if (message.isPictureType) {
          final data = await getImageDataFromMessage(message);
          try {
            await Pasteboard.writeImage(data);
            IMViews.showToast(StrRes.copySuccessfully);
          } catch (e) {
            print('Failed to copy image: $e');
          }
        }
        break;
      case MessageOperationType.delete:
        focusNode.unfocus();
        await OpenIM.iMManager.messageManager.deleteMessageFromLocalStorage(
          conversationID: conversationInfo.conversationID,
          clientMsgID: message.clientMsgID!,
        );
        customChatListViewController.remove(message);
        break;
      case MessageOperationType.forward:
        final result =
            await AppNavigator.startSelectContacts(action: SelAction.forward);
        if (result != null && result is Map && result['checkedList'] != null) {
          final checkedList = result['checkedList'];
          for (final item in checkedList) {
            final userID = IMUtils.convertCheckedToUserID(item);
            final groupID = IMUtils.convertCheckedToGroupID(item);
            if (userID != null && userID.isNotEmpty) {
              sendForwardMsg(message, userId: userID);
            } else if (groupID != null && groupID.isNotEmpty) {
              sendForwardMsg(message, groupId: groupID);
            }
          }
          IMViews.showToast(StrRes.sent);
        }
        break;
      case MessageOperationType.quote:
        quote.value = message;
        // 避免页面滚动到顶部后，回复消息，输入框聚焦失败
        // todo: 这里的延时可能会影响性能，后续可以考虑优化
        await Future.delayed(const Duration(milliseconds: 100));
        focusNode.requestFocus();
        break;
      case MessageOperationType.revoke:
        focusNode.unfocus();
        try {
          await OpenIM.iMManager.messageManager.revokeMessage(
            conversationID: conversationInfo.conversationID,
            clientMsgID: message.clientMsgID!,
          );
          _applyRevokeDetail(<String, dynamic>{
            'revokerID': OpenIM.iMManager.userID,
            'clientMsgID': message.clientMsgID,
            'revokerNickname': OpenIM.iMManager.userInfo.nickname,
            'revokeTime': DateTime.now().millisecondsSinceEpoch,
            'sourceMessageSendTime': message.sendTime,
            'sourceMessageSendID': message.sendID,
            'sourceMessageSenderNickname': message.senderNickname,
            'sessionType': message.sessionType,
            'seq': message.seq,
            'ex': message.ex,
          });
        } catch (e) {
          IMViews.showToast(StrRes.revokeFailed);
        }
        break;
      case MessageOperationType.multi:
        toggleMultiSelectMode();
        selectMessage(message);
      default:
        break;
    }
  }

  setMergeMessage() async {
    final result =
        await AppNavigator.startSelectContacts(action: SelAction.forward);
    selectedMessages.sort((a, b) => a.sendTime!.compareTo(b.sendTime!));
    if (result != null && result is Map && result['checkedList'] != null) {
      final checkedList = result['checkedList'];
      final title = isGroupChat
          ? StrRes.globalSearchChatHistory
          : sprintf(StrRes.chatHistoryBetween, [senderName, nickname.value]);
      final summaryList = List.generate(selectedMessages.length, (index) {
        final message = selectedMessages[index];
        return "${message.senderNickname}: ${IMUtils.parseMsg(message)}";
      });
      for (final item in checkedList) {
        final userID = IMUtils.convertCheckedToUserID(item);
        final groupID = IMUtils.convertCheckedToGroupID(item);

        final message = await OpenIM.iMManager.messageManager
            .createMergerMessage(
                messageList: selectedMessages,
                title: title,
                summaryList: summaryList);
        if (userID != null && userID.isNotEmpty) {
          _sendMessage(message, userId: userID);
        } else if (groupID != null && groupID.isNotEmpty) {
          _sendMessage(message, groupId: groupID);
        }
      }
      isMultiSelectMode.value = false;
      IMViews.showToast(StrRes.sent);
    }
  }

  /// 批量删除消息
  batchDelMessages() async {
    focusNode.unfocus();

    // 执行删除操作
    for (Message message in selectedMessages) {
      await OpenIM.iMManager.messageManager.deleteMessageFromLocalStorage(
        conversationID: conversationInfo.conversationID,
        clientMsgID: message.clientMsgID!,
      );
      customChatListViewController.remove(message);
    }

    // 清空选中状态并退出多选模式
    selectedMessages.clear();
    isMultiSelectMode.value = false;
  }

  void _updateMuteStatus() {
    _muteTimer?.cancel();
    final muteEndTime = groupMembersInfo?.muteEndTime ?? 0;

    if (muteEndTime <= 0) {
      isMute.value = false;
      return;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime < muteEndTime) {
      isMute.value = true;

      final duration = Duration(milliseconds: muteEndTime - currentTime);
      _muteTimer = Timer(duration, () {
        isMute.value = false;
      });
    } else {
      isMute.value = false;
    }
  }

  void preDownloadAudio(Message message) {
    if (message.isVoiceType) {
      _audioManager.preDownload(message);
    }
  }
}
