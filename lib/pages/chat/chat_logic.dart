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
import '../../utils/file_upload_helper.dart';
import '../../utils/log_util.dart' as app_log;
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

  Set<String> _messageKeys(Object? data) {
    if (data is! Message) return {};

    final keys = <String>{};
    final serverMsgID = data.serverMsgID;
    if (serverMsgID != null && serverMsgID.isNotEmpty) {
      keys.add('server:$serverMsgID');
    }

    final seq = data.seq;
    final groupID = data.groupID;
    if (seq != null && seq > 0 && groupID != null && groupID.isNotEmpty) {
      keys.add('seq:g:$groupID:$seq');
    }

    final sendID = data.sendID;
    final recvID = data.recvID;
    if (seq != null &&
        seq > 0 &&
        sendID != null &&
        sendID.isNotEmpty &&
        recvID != null &&
        recvID.isNotEmpty) {
      keys.add('seq:p:$sendID:$recvID:$seq');
    }

    final clientMsgID = data.clientMsgID;
    if (clientMsgID != null && clientMsgID.isNotEmpty) {
      keys.add('client:$clientMsgID');
    }

    final sendTime = data.sendTime;
    if (sendTime != null && sendTime > 0) {
      keys.add(
        'time:${data.sessionType}:${data.contentType}:$sendID:$recvID:$groupID:$sendTime:${_messagePayload(data)}',
      );
    }
    return keys;
  }

  String _messagePayload(Message message) {
    if (message.textElem?.content != null) {
      return message.textElem!.content!;
    }
    if (message.customElem?.data != null) {
      return message.customElem!.data!;
    }
    if (message.notificationElem?.detail != null) {
      return message.notificationElem!.detail!;
    }
    return '';
  }

  Set<String> _existingMessageKeys() => list.expand(_messageKeys).toSet();

  bool _hasExistingMessage(E data) {
    final keys = _messageKeys(data);
    if (keys.isEmpty) return false;
    return keys.any(_existingMessageKeys().contains);
  }

  List<E> _dedupeMessages(Iterable<E> iterable) {
    final keys = _existingMessageKeys();
    final result = <E>[];
    for (final item in iterable) {
      final itemKeys = _messageKeys(item);
      final duplicateKey = itemKeys.firstWhereOrNull(keys.contains);
      if (duplicateKey != null) {
        ILogger.w('[ChatList] skip duplicate message: $duplicateKey');
        continue;
      }
      keys.addAll(itemKeys);
      result.add(item);
    }
    return result;
  }

  @override
  void insertToBottom(E data) {
    if (_hasExistingMessage(data)) {
      return;
    }
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
    if (_hasExistingMessage(data)) {
      return;
    }
    super.insertToTop(data);
    _rxList.insert(0, data); // 触发UI更新
  }

  @override
  void insertAllToBottom(Iterable<E> iterable) {
    final deduped = _dedupeMessages(iterable);
    if (deduped.isEmpty) return;
    super.insertAllToBottom(deduped);
    _rxList.addAll(deduped); // 触发UI更新
    // 批量插入时不自动滚动，避免删除消息后意外滚动到底部
  }

  @override
  void insertAllToTop(Iterable<E> iterable) {
    final deduped = _dedupeMessages(iterable);
    if (deduped.isEmpty) return;
    super.insertAllToTop(deduped);
    _rxList.insertAll(0, deduped); // 触发UI更新
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
  final lastLoginTimeText = ''.obs;
  final peerTitleCertified = false.obs;
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
  // dawn 2026-06-29 持久记录每条消息已知的最早(真实)sendTime：同步竞态下新消息回调批量
  // 同步可能把旧消息时间打成当前时间，历史拉取则为真实时间。记录最早值并在重建时回填，
  // 确保只要见过真实时间一次，之后任何刷新都不会把旧消息显示成今天。
  final _earliestSendTimeById = <String, int>{};
  final groupMessageReadMembers = <String, List<String>>{};
  final groupMemberRoleLevel = 1.obs;
  GroupInfo? groupInfo;
  GroupMembersInfo? groupMembersInfo;
  List<GroupMembersInfo> ownerAndAdmin = [];

  final quote = Rxn<Message?>(null);

  final isInGroup = true.obs;
  bool _closingInvalidGroupConversation = false;
  final memberCount = 0.obs;
  final lookMemberInfo = 0.obs;
  final privateMessageList = <Message>[];
  final isInBlacklist = false.obs;

  final announcement = ''.obs;
  late StreamSubscription conversationSub;
  late StreamSubscription newMessageSub; // 新增：订阅新消息Subject
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
  // dawn 2026-06-14 优化大群历史加载：首屏固定最近50条，上滑历史最多展示最新消息往前5小时。
  static const int _initialHistoryPageSize = 50;
  static const Duration _groupHistoryWindow = Duration(hours: 5);
  bool _groupHistoryReachTimeLimit = false;
  int? _groupHistoryCutoffMs;
  // dawn 2026-06-18 修复3万人群消息不同步：限制当前群服务端最新页补拉频率。
  bool _syncingLatestGroupPage = false;
  int _lastLatestGroupPageSyncMs = 0;
  Timer? _latestGroupPageSyncTimer;
  bool _latestGroupPageSyncEnabled = false;
  int _latestGroupPageIdleRounds = 0;
  final _serverPulledMessageKeys = <String>{};
  // dawn 2026-06-18 修复3万人群消息不同步：当前打开的大群低频补拉服务端最新页，
  // 避免弱网或压测直写消息没有实时推送时，两台手机长期停在不同 seq。
  static const int _largeGroupLatestSyncThreshold = 1000;
  static const int _largeGroupLatestSyncFastSeconds = 5;
  static const int _largeGroupLatestSyncNormalSeconds = 30;
  static const int _largeGroupLatestSyncIdleSeconds = 60;
  static const int _largeGroupLatestSyncIdleThreshold = 3;
  // dawn 2026-06-21 新增官方人员标识：聊天页按消息发送人懒加载组织角色，避免大群一次性查全员。
  final officialMessageUserMap = <String, bool>{}.obs;
  // dawn 2026-06-26 官方账号(超管/后台管理员/群管理员，不含团队长)：用于"官方账号撤回不提示"。
  final officialAccountUserMap = <String, bool>{};
  final _pendingRevokeDetails = <Map<String, dynamic>>[];

  // dawn 2026-07-06 收紧"撤回【别人】消息"权限：修复"群里普通成员(业务员)也能撤群主/官方消息"。
  // 现在撤别人的消息需满足其一：① 本群【群主/群管理员】(群角色)；② 组织【超管/后台管理员】(全局审计)。
  // 业务员(GroupManager)若在本群只是普通成员，则不能撤别人的（自己的消息仍始终可撤，走 SDK）。
  // 服务端 /third_admin/message/revoke 同步按此判权（业务员改用本人 IM token 交由 IM 核心按群角色校验）。
  bool get canRevokeMessages => isAdminOrOwner || orgController.isOrgSuperAdmin;
  final _officialMessageRoleRequestedAt = <String, DateTime>{};
  static const _officialRoleRefreshInterval = Duration(minutes: 10);

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

  Future<void> _loadPeerLastLoginTime() async {
    final peerUserID = userID;
    if (peerUserID == null || peerUserID.isEmpty) {
      lastLoginTimeText.value = '';
      peerTitleCertified.value = false;
      return;
    }

    // dawn 2026-07-04 单聊头部改为展示"最近操作时间"(客户端打开APP上报)，不再用最近登录时间。
    lastLoginTimeText.value = '最近操作：加载中';
    try {
      final users = await Apis.getUserFullInfo(userIDList: [peerUserID]);
      final user = users?.firstOrNull;
      peerTitleCertified.value = _isOfficialOrgRole(user?.orgRole);
      // 优先用最近操作时间；无操作记录时回退到最近登录时间，避免空白。
      final ts = (user?.lastOperationTime != null && user!.lastOperationTime! > 0)
          ? user.lastOperationTime
          : user?.lastLoginTime;
      if (ts == null || ts <= 0) {
        lastLoginTimeText.value = '最近操作：暂无记录';
        return;
      }
      final tsMs = ts < 10000000000 ? ts * 1000 : ts;
      final text = DateUtil.formatDateMs(tsMs, format: 'yyyy-MM-dd HH:mm');
      lastLoginTimeText.value = '最近操作：$text';
    } catch (e) {
      ILogger.d('[ChatLogic] 加载最近操作时间失败: $e');
      lastLoginTimeText.value = '最近操作：暂无记录';
      peerTitleCertified.value = false;
    }
  }

  bool get isAdmin => groupMemberRoleLevel.value == GroupRoleLevel.admin;

  bool get isOwner => groupMemberRoleLevel.value == GroupRoleLevel.owner;

  bool get isAdminOrOwner => isAdmin || isOwner;

  String _normalizeOfficialRole(String? role) {
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
    final normalized = _normalizeOfficialRole(role).toLowerCase();
    return normalized == 'groupmanager';
  }

  // 组织后台"管理员"(GroupManager)：用于官方标识和管理员撤回静默。
  bool _isOfficialAccountRole(String? role) {
    return _isOfficialOrgRole(role);
  }

  bool _isAdminUserForRevoke(String? userID) {
    if (userID == null || userID.isEmpty) return false;
    if (userID == OpenIM.iMManager.userID) {
      return orgController.canRevokeMessage;
    }
    return officialMessageUserMap[userID] == true;
  }

  Future<void> _ensureAdminRoleForRevoke(String? userID) async {
    if (userID == null || userID.isEmpty) return;
    if (userID == OpenIM.iMManager.userID) return;
    if (officialMessageUserMap.containsKey(userID)) return;
    try {
      final users = await Apis.getUserFullInfo(userIDList: [userID]);
      final user = users?.firstOrNull;
      officialMessageUserMap[userID] = _isOfficialOrgRole(user?.orgRole);
      officialAccountUserMap[userID] = _isOfficialAccountRole(user?.orgRole);
      officialMessageUserMap.refresh();
    } catch (e) {
      ILogger.d('[ChatLogic] 加载撤回人管理员角色失败: $e');
    }
  }

  // dawn 2026-06-26 判断某 userID 是否为【本群】群主/群管理员(官方)。单聊恒 false。
  bool _isGroupOwnerOrAdmin(String? userID) {
    if (userID == null || userID.isEmpty || !isGroupChat) return false;
    if (userID == OpenIM.iMManager.userID) {
      final lv = groupMemberRoleLevel.value;
      return lv == GroupRoleLevel.owner || lv == GroupRoleLevel.admin;
    }
    if (ownerAndAdmin.any((e) => e.userID == userID)) return true;
    final lv = memberUpdateInfoMap[userID]?.roleLevel;
    return lv == GroupRoleLevel.owner || lv == GroupRoleLevel.admin;
  }

  // dawn 2026-07-04 修复"普通群成员也显示官方"：官方标识只看【本群群角色】(群主/群管理员)，
  // 不用组织角色。合并客户分支把它改回了组织角色(GroupManager)，导致组织GroupManager当普通群成员时
  // 也被标官方。撤回权限仍用组织角色，两套角色分开。
  bool isOfficialMessageSender(Message message) =>
      _isGroupOwnerOrAdmin(message.sendID);

  Future<void> _loadOfficialRolesForMessages(Iterable<Message> messages) async {
    final now = DateTime.now();
    final userIDs = messages
        .map((message) => message.sendID)
        .whereType<String>()
        .where((userID) => userID.isNotEmpty)
        .where((userID) {
          final requestedAt = _officialMessageRoleRequestedAt[userID];
          return requestedAt == null ||
              now.difference(requestedAt) > _officialRoleRefreshInterval;
        })
        .toSet()
        .toList();
    if (userIDs.isEmpty) return;

    for (final userID in userIDs) {
      _officialMessageRoleRequestedAt[userID] = now;
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
        if (officialMessageUserMap[userID] != official) {
          officialMessageUserMap[userID] = official;
          changed = true;
        }
        // 记录"官方账号"(不含团队长)用于撤回静默
        officialAccountUserMap[userID] = _isOfficialAccountRole(user.orgRole);
      }
      if (changed) {
        officialMessageUserMap.refresh();
        _refreshRevokeSilentFlagsForLoadedRoles();
      }
    } catch (e) {
      ILogger.d('[ChatLogic] 加载官方人员标识失败: $e');
    }
  }

  void _refreshRevokeSilentFlagsForLoadedRoles() {
    final touched = <String>{};
    for (final msg in messageList) {
      if (msg.contentType != MessageType.revokeMessageNotification) continue;
      final detail = msg.notificationElem?.detail;
      if (detail == null || detail.isEmpty) continue;
      try {
        final decoded = _decodeRevokeDetail(detail);
        final revokerID = _stringFromMap(decoded, 'revokerID') ??
            _stringFromMap(decoded, 'revokerUserID');
        if (!_isAdminUserForRevoke(revokerID) ||
            decoded['officialSilent'] == true) {
          continue;
        }
        decoded['officialSilent'] = true;
        msg.notificationElem = NotificationElem(detail: json.encode(decoded));
        if (msg.clientMsgID != null) touched.add(msg.clientMsgID!);
      } catch (_) {}
    }
    if (touched.isNotEmpty) {
      _rebuildItemsByClientMsgID(touched);
      update();
    }
  }

  Future<void> _prepareRevokeSilentFlagsForMessages(
    List<Message> messages,
  ) async {
    final revokerIDs = <String>{};
    for (final msg in messages) {
      if (msg.contentType != MessageType.revokeMessageNotification) continue;
      final detail = msg.notificationElem?.detail;
      if (detail == null || detail.isEmpty) continue;
      try {
        final decoded = _decodeRevokeDetail(detail);
        final revokerID = _stringFromMap(decoded, 'revokerID') ??
            _stringFromMap(decoded, 'revokerUserID');
        if (revokerID != null &&
            revokerID.isNotEmpty &&
            !officialMessageUserMap.containsKey(revokerID)) {
          revokerIDs.add(revokerID);
        }
      } catch (_) {}
    }
    if (revokerIDs.isNotEmpty) {
      await Future.wait(revokerIDs.map(_ensureAdminRoleForRevoke));
    }

    for (final msg in messages) {
      if (msg.contentType != MessageType.revokeMessageNotification) continue;
      final detail = msg.notificationElem?.detail;
      if (detail == null || detail.isEmpty) continue;
      try {
        final decoded = _decodeRevokeDetail(detail);
        final revokerID = _stringFromMap(decoded, 'revokerID') ??
            _stringFromMap(decoded, 'revokerUserID');
        if (_isAdminUserForRevoke(revokerID) &&
            decoded['officialSilent'] != true) {
          decoded['officialSilent'] = true;
          msg.notificationElem = NotificationElem(detail: json.encode(decoded));
        }
      } catch (_) {}
    }
  }

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
    print(
        '[ChatLogic] this.conversationInfo.userID=${conversationInfo.userID}');
    print(
        '[ChatLogic] this.conversationInfo.conversationID=${conversationInfo.conversationID}');
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
            e.isRead != true &&
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
    // dawn 2026-04-27 临时排查：进入会话即上报一次，确认 zz1 这台手机的上报
    // 通路是否通，以及它的版本是否真是 0.8.8。
    DebugLogUploader.send('chat_opened', {
      'me': OpenIM.iMManager.userID,
      'peerUserID': userID,
      'peerGroupID': groupID,
      'conversationID': conversationInfo.conversationID,
      'apkVersion': '0.9.1',
    });
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
      unawaited(_syncLatestGroupPageFromServer(reason: 'ready'));
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
    if (isSingleChat) {
      unawaited(_loadPeerLastLoginTime());
    }
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
              e.isRead != true &&
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
    print('[ChatLogic] OpenIM.c.userID=${OpenIM.iMManager.userID}');
    print('[ChatLogic] isSingleChat=$isSingleChat');
    print('========================================');

    // 只使用新消息Subject订阅方式，避免双重监听导致重复消息
    newMessageSub = imLogic.newMessageSubject.listen((Message message) async {
      print('[ChatLogic] ✅ newMessageSub收到消息: ${message.contentType}');
      _handleNewMessage(message);
    });

    revokedMessageSub =
        imLogic.revokedMessageSubject.listen((RevokedInfo value) async {
      final detail = value.toJson();
      final revokerID =
          (detail['revokerID'] ?? detail['revokerUserID'])?.toString();
      await _ensureAdminRoleForRevoke(revokerID);
      final updated = _applyRevokedInfo(value);
      if (!updated) {
        Future.microtask(_loadHistoryForSyncEnd);
      }
    });

    // dawn 2026-06-18 修复3万人群消息不同步：恢复当前聊天页直接回调兜底。
    // SDK 会先触发 onRecvNewMessage 再广播 newMessageSubject，_handleNewMessage
    // 内部已有 MessageDeduplicator 去重，避免弱网/大群下只依赖全局广播导致当前会话漏消息。
    // dawn 2026-07-04 改用多监听器注册(以 this 为 owner)，避免被通知页覆盖导致聊天页实时收不到消息。
    imLogic.addRecvNewMessageListener(this, (Message message) async {
      print('[ChatLogic] ✅ onRecvNewMessage兜底收到消息: ${message.contentType}');
      _handleNewMessage(message);
    });

    print('[ChatLogic] ✅ 消息监听设置完成');

    // 使用全局已读回执广播订阅，实现实时同步（不覆盖全局回调，避免切会话时丢失）
    c2cReadReceiptSub =
        imLogic.c2cReadReceiptSubject.listen((List<ReadReceiptInfo> list) {
      try {
        if (list.isNotEmpty) {
          print(
              '[ChatLogic] 📬 已读回执广播: 当前会话userID=$userID, 回执userIDs=${list.map((r) => r.userID).toList()}');
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
        _closeInvalidGroupConversation('joinedGroupDeleted');
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
        _closeInvalidGroupConversation('memberDeleted');
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
        _ensureLatestGroupPageSyncTimer(reason: 'groupInfoUpdated');
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
        final normalized = _normalizeRevokeDetail(detail, msg);
        msg.notificationElem = NotificationElem(
          detail: json.encode(normalized),
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
    } else {
      _rememberPendingRevoke(detail);
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
    final sourceNickname =
        _stringFromMap(detail, 'sourceMessageSenderNickname') ??
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
    final normalized = <String, dynamic>{
      'revokerID': revokerID ?? sourceSendID ?? OpenIM.iMManager.userID,
      'revokerRole': _intFromMap(detail, 'revokerRole') ?? 0,
      'clientMsgID':
          _revokeTargetClientMsgID(detail) ?? sourceMessage.clientMsgID,
      'revokerNickname': revokerNickname ?? '',
      'revokeTime':
          _intFromMap(detail, 'revokeTime') ?? sourceMessage.sendTime ?? 0,
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
    if (_isAdminUserForRevoke(normalized['revokerID']?.toString())) {
      normalized['officialSilent'] = true;
    }
    return normalized;
  }

  void _rememberPendingRevoke(Map<String, dynamic> detail) {
    final target = _revokeTargetClientMsgID(detail);
    final srcID = _stringFromMap(detail, 'sourceMessageSendID');
    final srcTime = _intFromMap(detail, 'sourceMessageSendTime');
    if ((target == null || target.isEmpty) &&
        (srcID == null || srcTime == null)) {
      return;
    }
    final key = target?.isNotEmpty == true ? target! : '$srcID|$srcTime';
    final exists = _pendingRevokeDetails.any((item) {
      final itemTarget = _revokeTargetClientMsgID(item);
      final itemKey = itemTarget?.isNotEmpty == true
          ? itemTarget!
          : '${_stringFromMap(item, 'sourceMessageSendID')}|${_intFromMap(item, 'sourceMessageSendTime')}';
      return itemKey == key;
    });
    if (!exists) {
      _pendingRevokeDetails.add(Map<String, dynamic>.from(detail));
    }
  }

  void _applyPendingRevokeDetails() {
    if (_pendingRevokeDetails.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingRevokeDetails);
    for (final detail in pending) {
      final applied = _applyRevokeDetail(detail, keepPendingOnMiss: false);
      if (applied) {
        _pendingRevokeDetails.remove(detail);
      }
    }
  }

  bool _applyRevokeDetail(
    Map<String, dynamic> detail, {
    bool keepPendingOnMiss = true,
  }) {
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
      final byID =
          targetClientMsgID != null && msg.clientMsgID == targetClientMsgID;
      final byPair = srcID != null &&
          srcTime != null &&
          msg.sendID == srcID &&
          msg.sendTime == srcTime;
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
    } else if (keepPendingOnMiss) {
      _rememberPendingRevoke(detail);
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
  Future<bool> _applyRevokeNotificationMessage(Message message) async {
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
      final decodedDetail = _decodeRevokeDetail(detail);
      final revokerID = _stringFromMap(decodedDetail, 'revokerID') ??
          _stringFromMap(decodedDetail, 'revokerUserID');
      await _ensureAdminRoleForRevoke(revokerID);
      final ok = _applyRevokeDetail(decodedDetail);
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
    // dawn 2026-07-04 修复"收不到别人发的消息(要退出重进)"：本方法只用于把【自己发送】的
    // SDK 回显合并进乐观插入的那一条(去重发送圈)。若对【所有】消息做稳定key合并，别人发来的
    // 新消息一旦命中(seq/clientMsgID 巧合等)就会被当作重复跳过插入 → 群里收不到别人的消息。
    // 因此只对"我发的"消息尝试合并；别人的消息一律返回 false，交给调用方正常插入。
    if (newMsg.sendID != OpenIM.iMManager.userID) {
      return false;
    }
    // dawn 2026-06-30 改用稳定 key(serverMsgID/seq/clientMsgID)匹配：SDK 同步会重写
    // clientMsgID，仅按 clientMsgID 匹配会把同步副本当成新消息追加，且发送圈清不掉。
    final keys = _sendStatusKeys(newMsg);
    if (keys.isEmpty) {
      return false;
    }
    final index =
        messageList.indexWhere((msg) => _hasAnySendStatusKey(msg, keys));
    if (index < 0) {
      return false;
    }
    final oldMsg = messageList[index];
    // Always sync the server-assigned fields back into the optimistic copy.
    oldMsg.seq = newMsg.seq ?? oldMsg.seq;
    oldMsg.serverMsgID = newMsg.serverMsgID ?? oldMsg.serverMsgID;
    // succeeded 不被同步副本的 sending 覆盖。
    oldMsg.status = _mergeSendStatus(oldMsg.status, newMsg.status);
    // dawn 2026-06-29 保留更早(真实)的 sendTime：同步竞态下 newMsg 可能携带"当前时间"
    // (批量同步被打成今天)，取两者中更早的非零值，避免旧消息显示成今天。
    final oldT = oldMsg.sendTime ?? 0;
    final newT = newMsg.sendTime ?? 0;
    if (oldT <= 0) {
      oldMsg.sendTime = newMsg.sendTime;
    } else if (newT > 0 && newT < oldT) {
      oldMsg.sendTime = newT;
    }
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
    if (isGroupChat) {
      final currentGroupID = groupID ?? '';
      if (currentGroupID.isNotEmpty) {
        list = list.where((msg) {
          final msgGroupID = msg.groupID ?? '';
          return msgGroupID.isEmpty || msgGroupID == currentGroupID;
        }).toList();
      }
    }
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
      if (m.contentType == MessageType.revokeMessageNotification)
        revokeCount++;
      else
        textCount++;
    }
    byIdContentType.forEach((id, types) {
      if (types.contains(MessageType.revokeMessageNotification) &&
          types.length > 1) {
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
            .notificationElem
            ?.detail,
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
    final revokes =
        <String, Map<String, dynamic>>{}; // target clientMsgID -> detail
    final revokeBySender =
        <String, Map<String, dynamic>>{}; // "sendID|sendTime" -> detail
    final standaloneRevokeRows =
        <String>{}; // clientMsgIDs of the notif rows themselves
    for (final m in list) {
      if (m.contentType == MessageType.revokeMessageNotification) {
        final detail = m.notificationElem?.detail;
        if (detail == null || detail.isEmpty) {
          ILogger.w(
              '[ChatLogic] revoke notification with empty detail: clientMsgID=${m.clientMsgID}');
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
          if (srcID != null &&
              srcID.isNotEmpty &&
              srcTime != null &&
              srcTime > 0) {
            revokeBySender['$srcID|$srcTime'] = info;
          }
          if (!hasTarget && (srcID == null || srcTime == null)) {
            ILogger.w(
                '[ChatLogic] revoke detail missing target: detail=$detail');
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
          if (self != null &&
              self.isNotEmpty &&
              self != target &&
              (hasTarget || (srcID != null && srcTime != null))) {
            standaloneRevokeRows.add(self);
          }
        } catch (e) {
          ILogger.w(
              '[ChatLogic] revoke detail decode failed: $e detail=$detail');
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

  /// dawn 2026-06-29 时间回填稳定 key：SDK 写本地库会重写 clientMsgID，但 serverMsgID/seq 稳定。
  /// 优先 serverMsgID，其次群聊 seq，最后 clientMsgID。
  String? _effectiveTimeKey(Message m) {
    final sid = m.serverMsgID;
    if (sid != null && sid.isNotEmpty) return 's:$sid';
    final seq = m.seq ?? 0;
    if (isGroupChat && seq > 0) return 'q:$seq';
    final cid = m.clientMsgID;
    if (cid != null && cid.isNotEmpty) return 'c:$cid';
    return null;
  }

  /// dawn 2026-06-30 发送状态匹配稳定 key 集合：SDK 同步会重写 clientMsgID，仅按 clientMsgID
  /// 匹配会漏掉同步副本。这里返回一条消息的全部可用标识(serverMsgID/群 seq/clientMsgID)，
  /// 任一命中即视为同一条，确保"清发送圈"能命中列表里被重写过的副本。
  Set<String> _sendStatusKeys(Message m) {
    final keys = <String>{};
    final sid = m.serverMsgID;
    if (sid != null && sid.isNotEmpty) keys.add('s:$sid');
    final seq = m.seq ?? 0;
    if (isGroupChat && seq > 0) keys.add('q:$seq');
    final cid = m.clientMsgID;
    if (cid != null && cid.isNotEmpty) keys.add('c:$cid');
    return keys;
  }

  bool _hasAnySendStatusKey(Message m, Set<String> keys) {
    final sid = m.serverMsgID;
    if (sid != null && sid.isNotEmpty && keys.contains('s:$sid')) return true;
    final seq = m.seq ?? 0;
    if (isGroupChat && seq > 0 && keys.contains('q:$seq')) return true;
    final cid = m.clientMsgID;
    if (cid != null && cid.isNotEmpty && keys.contains('c:$cid')) return true;
    return false;
  }

  /// 合并发送状态：succeeded 最高(不被 sending 覆盖)，其次 failed，否则取已知值。
  int _mergeSendStatus(int? oldStatus, int? newStatus) {
    final o = oldStatus ?? MessageStatus.sending;
    final n = newStatus ?? o;
    if (o == MessageStatus.succeeded || n == MessageStatus.succeeded) {
      return MessageStatus.succeeded;
    }
    if (o == MessageStatus.failed || n == MessageStatus.failed) {
      return MessageStatus.failed;
    }
    return n;
  }

  /// 按 sendTime 升序排序，保证列表为「旧→新」避免 API 返回顺序不一致导致错乱
  List<Message> _sortMessagesBySendTimeAsc(List<Message> messages) {
    // dawn 2026-06-29 修复"旧消息时间显示成今天"：同步竞态下同一条消息可能同时存在
    // 历史拉取(真实 sendTime)与新消息回调(批量同步被打成当前时间)两份。按 clientMsgID
    // 去重并保留/回填更早(真实)的 sendTime，避免显示成加载时刻。
    final byId = <String, Message>{};
    final noId = <Message>[];
    for (final m in messages) {
      // 用稳定 key(serverMsgID/seq)记录并回填真实最早 sendTime,跨多次重建生效。
      // SDK 写本地库会重写 clientMsgID,故时间 map 不能用 clientMsgID 当 key。
      final tkey = _effectiveTimeKey(m);
      if (tkey != null) {
        final t = m.sendTime ?? 0;
        final rec = _earliestSendTimeById[tkey];
        if (t > 0 && (rec == null || t < rec)) {
          _earliestSendTimeById[tkey] = t;
        }
        final best = _earliestSendTimeById[tkey];
        if (best != null && best > 0 && best < (m.sendTime ?? 0)) {
          m.sendTime = best;
        }
      }
      // 去重:按 clientMsgID 折叠重复,保留 seq 更大(信息更全)的一份。
      final id = m.clientMsgID;
      if (id == null || id.isEmpty) {
        noId.add(m);
        continue;
      }
      final exist = byId[id];
      if (exist == null || (m.seq ?? 0) >= (exist.seq ?? 0)) {
        byId[id] = m;
      }
    }
    final list = <Message>[...byId.values, ...noId];
    // dawn 2026-06-18 修复3万人群消息不同步：群聊优先按服务端 seq 排序。
    // 压测并发发送时 sendTime 可能相近或乱序，seq 才是多端一致的消息顺序。
    list.sort((a, b) {
      if (isGroupChat) {
        final aSeq = a.seq ?? 0;
        final bSeq = b.seq ?? 0;
        if (aSeq > 0 && bSeq > 0 && aSeq != bSeq) {
          return aSeq.compareTo(bSeq);
        }
      }
      return (a.sendTime ?? 0).compareTo(b.sendTime ?? 0);
    });
    return list;
  }

  int _messageTimeMs(Message message) =>
      message.sendTime ?? message.createTime ?? 0;

  void _ensureGroupHistoryCutoff(List<Message> messages) {
    if (searchMessage != null ||
        !isGroupChat ||
        _groupHistoryCutoffMs != null) {
      return;
    }
    // dawn 2026-07-04 cutoff 锚点 clamp 到当前时间附近：若某条消息 sendTime 被污染成未来时间，
    // 会把 cutoff 抬得过高，导致刚收到的新消息(time≈现在)被 5 小时窗口过滤掉而收不到。
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAnchor = now + const Duration(minutes: 5).inMilliseconds;
    var latest = 0;
    for (final message in messages) {
      var time = _messageTimeMs(message);
      if (time <= 0) continue;
      if (time > maxAnchor) time = now;
      if (time > latest) latest = time;
    }
    if (latest > 0) {
      _groupHistoryCutoffMs = latest - _groupHistoryWindow.inMilliseconds;
    }
  }

  List<Message> _applyGroupHistoryWindow(List<Message> messages) {
    if (searchMessage != null || !isGroupChat || messages.isEmpty) {
      return messages;
    }
    _ensureGroupHistoryCutoff(messages);
    final cutoff = _groupHistoryCutoffMs;
    if (cutoff == null) return messages;

    final filtered = messages.where((message) {
      final time = _messageTimeMs(message);
      return time == 0 || time >= cutoff;
    }).toList();
    if (filtered.length < messages.length) {
      _groupHistoryReachTimeLimit = true;
      // dawn 2026-06-30 触达 5 小时上限后立即关闭顶部加载,任何重建路径都停止上滑拉取。
      enabledTopLoad.value = false;
    }
    return filtered;
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
    if (isGroupChat &&
        message.isSingleChat &&
        message.contentType == MessageType.text) {
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
                final contentMap =
                    json.decode(rawContent) as Map<String, dynamic>?;
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
    if (isGroupChat && message.isGroupChat && message.groupID == groupID) {
      // 当前群有实时消息到达时，临时唤醒一次补拉，补齐同一时间窗口内可能漏推的相邻消息。
      _triggerLatestGroupPageSync(reason: 'recvGroupMessage');
    }

    if (isCurrentChat(message)) {
      print('[ChatLogic] ✅ 消息属于当前聊天，准备处理');
      // dawn 2026-06-21 新增官方人员标识：实时新消息到达时补拉发送人的组织角色。
      unawaited(_loadOfficialRolesForMessages([message]));
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
        final updated = await _applyRevokeNotificationMessage(message);
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
        if (isGroupChat) {
          // dawn 2026-06-18 修复3万人群消息不同步：实时消息插入后按 seq 规整顺序。
          // dawn 2026-06-30 可见列表重建统一套群聊 5 小时窗口；真实新消息 time>=cutoff 不会被删,
          // 否则同步/实时重建会把昨天>5h 的旧消息又灌回列表(codex 协同定位)。
          final fullList = _applyGroupHistoryWindow(
            _sortMessagesBySendTimeAsc(_filterMessagesForChat(messageList)),
          );
          customChatListViewController.clear();
          customChatListViewController.insertAllToBottom(fullList);
          _syncRxListWithMessageList();
          customChatListViewController.refresh();
        }
        _applyPendingRevokeDetails();

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

        final displayMessages = [
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(topMessageRes.messageList ?? [])),
          searchMessage!,
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(bottomMessageRes.messageList ?? []))
        ];
        await _prepareRevokeSilentFlagsForMessages(displayMessages);
        customChatListViewController.insertAllToBottom(displayMessages);
      } else {
        enabledBottomLoad.value = true;
        final topDisplayMessages = [
          ..._sortMessagesBySendTimeAsc(
              _filterMessagesForChat(topMessageRes.messageList ?? [])),
          searchMessage!
        ];
        final bottomDisplayMessages = _sortMessagesBySendTimeAsc(
            _filterMessagesForChat(bottomMessageRes.messageList ?? []));
        await _prepareRevokeSilentFlagsForMessages([
          ...topDisplayMessages,
          ...bottomDisplayMessages,
        ]);
        customChatListViewController.insertAllToTop(topDisplayMessages);
        customChatListViewController.insertAllToBottom(bottomDisplayMessages);
      }
    }
    // 非搜索：仅拉一页（本地或群聊服务端最近一页），上滑时 onScrollToTopLoad 再按需拉更早历史
    // dawn 2026-06-29 首屏也消费返回值同步顶部加载开关：小群/一屏装得下时返回 false → 关闭顶部加载，
    // 否则列表组件内部 _topHasMore 永远为 true 导致顶部一直转圈。(codex 协同定位)
    final hasMoreTop = await onScrollToTopLoad();
    enabledTopLoad.value = hasMoreTop;
    // 客户端(dev-20260630)：首屏后补齐撤回详情。
    _applyPendingRevokeDetails();
    // dawn 2026-06-21 新增官方人员标识：首屏消息渲染后异步补全认证图标，不阻塞进会话。
    unawaited(_loadOfficialRolesForMessages(messageList));
    unawaited(_syncLatestGroupPageFromServer(reason: 'init'));

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

  Future sendTextMsg(value, {required List<Uint8List> images}) async {
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

    final rawContent = IMUtils.safeTrim(inputCtrl.text);
    var ids = _extractIds(rawContent);
    ids = ids.toSet().toList();
    if (rawContent.isEmpty) {
      return;
    }
    // dawn 2026-05-15 修复手机端发送方敏感词未脱敏：创建本地消息前先替换文本内容。
    final content = await apiService.maskSensitiveWords(rawContent);

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
    if (rawContent.contains('已成功收款')) {
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
    // dawn 2026-05-22 修复手机端视频发送失败：视频也走业务分片上传后创建URL消息，绕开SDK本地视频解析/上传异常。
    var message = await _createUploadedVideoMessage(
      videoPath: file!.path,
      fileName: _fileNameFromPath(file.path),
      fileSize: await file.length(),
      mimeType: mimeType,
      duration: duration,
      snapshotPath: snapshotPath,
    );

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
    // dawn 2026-05-15 修复手机端转发备注敏感词未脱敏：备注文本同普通消息一样先本地替换。
    final filteredContent = await apiService.maskSensitiveWords(content);
    final message = await OpenIM.iMManager.messageManager.createTextMessage(
      text: filteredContent,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }

  String _fileExtension(String fileName, String fallback) {
    final index = fileName.lastIndexOf('.');
    if (index >= 0 && index < fileName.length - 1) {
      return fileName.substring(index + 1).toLowerCase();
    }
    return fallback;
  }

  Future<Message> _createUploadedVideoMessage({
    required String videoPath,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required int duration,
    String? snapshotPath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final videoUrl = await FileUploadHelper.uploadVideo(
      videoPath: videoPath,
      customFileName: '${timestamp}_$fileName',
      progressTitle: StrRes.sendingFile,
      progressMessage: StrRes.sendingFile,
    );
    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception('视频上传未返回URL');
    }

    File snapshotFile;
    final candidateSnapshot = snapshotPath != null && snapshotPath.isNotEmpty
        ? File(snapshotPath)
        : null;
    if (candidateSnapshot != null && await candidateSnapshot.exists()) {
      snapshotFile = candidateSnapshot;
    } else {
      snapshotFile = await IMUtils.getVideoThumbnail(File(videoPath));
    }

    final snapshotSize = await snapshotFile.length();
    final snapshotUrl = await FileUploadHelper.uploadImage(
      imagePath: snapshotFile.path,
      customFileName: '${timestamp}_${fileName}_snapshot.png',
      showProgress: false,
    );
    if (snapshotUrl == null || snapshotUrl.isEmpty) {
      throw Exception('视频封面上传未返回URL');
    }

    return OpenIM.iMManager.messageManager.createVideoMessageByURL(
      videoElem: VideoElem(
        videoUUID: '${timestamp}_$fileName',
        videoUrl: videoUrl,
        videoType:
            mimeType.isNotEmpty ? mimeType : _fileExtension(fileName, 'mp4'),
        videoSize: fileSize,
        duration: duration,
        snapshotUUID: '${timestamp}_${fileName}_snapshot',
        snapshotUrl: snapshotUrl,
        snapshotSize: snapshotSize,
        snapshotWidth: 1,
        snapshotHeight: 1,
      ),
    );
  }

  Future<Message> _createUploadedFileMessage({
    required String filePath,
    required String fileName,
    required int fileSize,
  }) async {
    final uuid = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final uploadedUrl = await FileUploadHelper.uploadFile(
      filePath: filePath,
      customFileName: uuid,
      progressTitle: StrRes.sendingFile,
      progressMessage: StrRes.sendingFile,
    );
    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      throw Exception('文件上传未返回URL');
    }
    // dawn 2026-05-22 修复手机端视频文件发送失败：文件选择器入口统一创建普通文件URL消息，避免SDK视频消息contentType=104发送失败。
    return OpenIM.iMManager.messageManager.createFileMessageByURL(
      fileElem: FileElem(
        filePath: filePath,
        uuid: uuid,
        sourceUrl: uploadedUrl,
        fileName: fileName,
        fileSize: fileSize,
      ),
    );
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

  Future<void> _maskSensitiveMessage(Message message) async {
    // dawn 2026-05-15 修复手机端自己消息仍显示原词：所有发送入口入本地列表前统一脱敏。
    if (message.contentType == MessageType.text) {
      final content = message.textElem?.content;
      if (content != null && content.isNotEmpty) {
        message.textElem?.content =
            await apiService.maskSensitiveWords(content);
      }
    } else if (message.contentType == MessageType.atText) {
      final content = message.atTextElem?.text;
      if (content != null && content.isNotEmpty) {
        message.atTextElem?.text = await apiService.maskSensitiveWords(content);
      }
    } else if (message.contentType == MessageType.quote) {
      final content = message.quoteElem?.text;
      if (content != null && content.isNotEmpty) {
        message.quoteElem?.text = await apiService.maskSensitiveWords(content);
      }
    }
  }

  Future _sendMessage(
    Message message, {
    String? userId,
    String? groupId,
    bool addToUI = true,
  }) async {
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

    await _maskSensitiveMessage(message);

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
    final targetGroupID = useOuterValue ? groupId : groupID;

    // dawn 2026-06-23 修复超大群(如3万人)发送后小圈圈不消失：
    // 正常/慢速发送仍走 then/catchError 正常更新（不打断，弱网慢发也能正确收尾）；
    // 另起一个兜底定时器，专治超大群扇出下 SDK 发送完成回调悬挂（既不 then 也不 catch）的情况——
    // 8 秒后若该消息仍停在“发送中”，就用本地真实状态对账：本地已存为成功(有 serverMsgID)→ 清圈，
    // 本地失败→ 标失败，其余保持现状（不误伤正常发送、不误判）。
    if (!useOuterValue) {
      // dawn 2026-06-30 不再只看"原始 message 对象"状态(它可能已被 _sendSucceeded 改成 succeeded，
      // 而页面渲染的是另一份卡 sending 的同步副本)，改为扫描当前可见列表里所有"我发的、仍 sending、
      // 已超时"的消息做对账，避免副本永久转圈。
      Future.delayed(const Duration(seconds: 8), () {
        _reconcileTimedOutVisibleSendingMessages();
      });
    }
    return OpenIM.iMManager.messageManager
        .sendMessage(
          message: message,
          userID: recvUserID,
          groupID: targetGroupID,
          offlinePushInfo: Config.offlinePushInfo,
        )
        .then((value) => _sendSucceeded(message, value))
        .catchError(
            (error, _) => _senFailed(message, groupId, userId, error, _))
        .whenComplete(() => _completed());
  }

  /// dawn 2026-06-30 扫描当前可见列表里"我发的、本会话、仍 sending、已超时(>=8s)"的消息逐条对账。
  void _reconcileTimedOutVisibleSendingMessages() {
    final myID = OpenIM.iMManager.userID;
    if (myID.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeoutMs = const Duration(seconds: 8).inMilliseconds;
    final candidates = customChatListViewController.list.where((m) {
      if (m.status != MessageStatus.sending) return false;
      if (m.sendID != myID) return false;
      if (isGroupChat && m.groupID != groupID) return false;
      final t = m.sendTime ?? m.createTime ?? 0;
      return t > 0 && now - t >= timeoutMs;
    }).toList();
    for (final m in candidates) {
      unawaited(_reconcileSendStatus(m, false));
    }
  }

  /// dawn 2026-06-23 发送超时对账：用 SDK 本地存储里的真实状态决定 UI 是“成功”还是“失败”，避免大群下永久转圈或误判。
  Future<void> _reconcileSendStatus(Message message, bool useOuterValue) async {
    final clientMsgID = message.clientMsgID;
    if (clientMsgID == null || clientMsgID.isEmpty) return;
    // 仅对“当前会话”的发送做对账（转圈出现在当前聊天页）；转发到其它会话不在本页展示，跳过。
    if (useOuterValue) return;
    try {
      final result = await OpenIM.iMManager.messageManager.findMessageList(
        searchParams: [
          SearchParams(
            conversationID: conversationInfo.conversationID,
            clientMsgIDList: [clientMsgID],
          ),
        ],
      );
      final items = [
        ...?result.findResultItems,
        ...?result.searchResultItems,
      ];
      Message? stored;
      for (final item in items) {
        stored = item.messageList
            ?.firstWhereOrNull((e) => e.clientMsgID == clientMsgID);
        if (stored != null) break;
      }
      if (stored != null && stored.status == MessageStatus.failed) {
        // 仅当 SDK 明确判定失败时才标失败
        _markSendStatusOnList(message, MessageStatus.failed, stored: stored);
      } else {
        // 成功(有 serverMsgID) 或 仍“发送中”/查不到 → 一律乐观钉成功、清掉转圈。
        // 超大群(如3万人)下 SDK 自身也常拿不到发送 ACK、本地状态停在 sending，但消息其实已发出;
        // 真正的硬失败 SDK 会很快走 catchError 标失败(8 秒前),不会落到这里。
        _markSendStatusOnList(message, MessageStatus.succeeded, stored: stored);
      }
    } catch (e) {
      app_log.LogUtil.e('ChatLogic', '发送超时对账查询失败,乐观清圈: clientMsgID=$clientMsgID', e);
      _markSendStatusOnList(message, MessageStatus.succeeded);
    }
  }

  /// dawn 2026-06-23 关键:超大群同步会把 bottomList 里那条消息换成“仍 sending”的新实例，
  /// 只改最初的 message 对象 / rxList 无法清掉页面里的转圈。这里直接定位当前渲染列表(top+bottom)
  /// 里所有同 clientMsgID 的实例改其 status，再走 _rebuildItemsByClientMsgID + refresh 强制重建，
  /// 确保留在页面时转圈也立即消失。
  void _markSendStatusOnList(Message target, int status, {Message? stored}) {
    // dawn 2026-06-30 用稳定 key(serverMsgID/seq/clientMsgID)并集匹配，命中列表里所有同一条
    // 消息的实例(含 SDK 同步重写过 clientMsgID 的副本)，否则发送圈清不掉。
    final keys = <String>{
      ..._sendStatusKeys(target),
      if (stored != null) ..._sendStatusKeys(stored),
    };
    if (keys.isEmpty) return;

    final touched = <String>{};
    for (final m in customChatListViewController.list) {
      if (m.sendID != OpenIM.iMManager.userID) continue;
      if (!_hasAnySendStatusKey(m, keys)) continue;
      m.status = status;
      if (stored != null && status == MessageStatus.succeeded) {
        final sid = stored.serverMsgID;
        if ((m.serverMsgID == null || m.serverMsgID!.isEmpty) &&
            sid != null &&
            sid.isNotEmpty) {
          m.serverMsgID = sid;
        }
        final seq = stored.seq ?? 0;
        if ((m.seq ?? 0) <= 0 && seq > 0) {
          m.seq = seq;
        }
      }
      final cid = m.clientMsgID;
      if (cid != null && cid.isNotEmpty) touched.add(cid);
    }

    target.status = status;

    if (touched.isEmpty) return;
    _rebuildItemsByClientMsgID(touched);
    customChatListViewController.refresh();
    for (final id in touched) {
      sendStatusSub.addSafely(
          MsgStreamEv<bool>(id: id, value: status != MessageStatus.failed));
    }
  }

  void _sendSucceeded(Message oldMsg, Message newMsg) {
    oldMsg.update(newMsg);
    // dawn 2026-06-30 发送成功统一走 _markSendStatusOnList：按 serverMsgID/seq/clientMsgID 稳定 key
    // 命中列表里所有副本(含同步重写过 clientMsgID 的那份)钉成 succeeded + 回填 serverMsgID/seq，
    // 再强制重建，确保小圈圈消失。newMsg 携带 SDK 回显的 serverMsgID/seq/原 clientMsgID。
    oldMsg.status = MessageStatus.succeeded;
    _markSendStatusOnList(oldMsg, MessageStatus.succeeded, stored: newMsg);
  }

  void _senFailed(
      Message message, String? groupId, String? userId, error, stack) async {
    // dawn 2026-05-22 修复手机端发送失败难排查：记录SDK真实错误，App退出后可在后台App日志查看。
    app_log.LogUtil.e(
      'ChatLogic',
      '消息发送失败: contentType=${message.contentType}, clientMsgID=${message.clientMsgID}, groupID=${groupId ?? groupID}, userID=${userId ?? userID}',
      error,
      stack is StackTrace ? stack : null,
    );
    // dawn 2026-06-30 失败也走稳定 key 命中可见副本，确保标红/可重发对页面真正渲染的实例生效。
    _markSendStatusOnList(message, MessageStatus.failed);
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

    if (message.isRead != true && message.sendID != OpenIM.iMManager.userID) {
      try {
        message.isRead = true;
        print(
            '[ChatLogic] 📤 上报已读(单条) conversationID=${conversationInfo.conversationID} clientMsgID=${message.clientMsgID}');
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
    // dawn 2026-06-23 修复进群聊已读后会话列表仍显示未读数：无条件上报会话已读，
    // 不再用快照 conversationInfo.unreadCount>0 做门槛(快照可能过期导致漏报)。markConversationMessageAsRead 幂等，已读再调无害。
    OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
        conversationID: conversationInfo.conversationID);
    // dawn 2026-06-29 同步清掉会话列表本地补充未读(fallback)，记录已读水位线，
    // 否则 SDK unreadCount=0 时本地补的红点"1"在标记已读后不会消失。
    conversationLogic.markFallbackRead(conversationInfo.conversationID);
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
                    // dawn 2026-05-21 修复上传文件限制：视频上传上限调整为200MB。
                    const maxVideoSize = 200 * 1024 * 1024;
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
    newMessageSub.cancel(); // 取消新消息订阅
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
    imLogic.removeRecvNewMessageListener(this);
    imLogic.onSignalingMessage = null;

    _muteTimer?.cancel();
    _groupMutedRefreshTimer?.cancel();
    _groupInfoDebounceTimer?.cancel();
    _groupMutedRetryTimer?.cancel();
    _stopLatestGroupPageSyncTimer();

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
      _stopLatestGroupPageSyncTimer();
    } else if (wasInBackground) {
      // 从后台返回前台：恢复会话并同步消息
      appLogic.setActiveConversation(conversationInfo.conversationID);
      _ensureLatestGroupPageSyncTimer(reason: 'resume');

      // 延迟执行，确保 UI 完全恢复
      Future.delayed(Duration(milliseconds: 300), () async {
        try {
          // 从服务器拉取最新消息
          final result = await OpenIM.iMManager.messageManager
              .getAdvancedHistoryMessageList(
            conversationID: conversationInfo.conversationID,
            startMsg: null,
            count: 50,
          );

          if (result.messageList != null && result.messageList!.isNotEmpty) {
            await _mergeHistoryMessages(result.messageList!);
          } else {
            // 即使没有新消息，也对当前列表做一次排序，保证顺序一致
            final fullList = messageList;
            if (fullList.isNotEmpty) {
              // dawn 2026-06-30 恢复重建同样套 5 小时窗口,避免保留已污染的超窗旧消息。
              final sortedFull =
                  _applyGroupHistoryWindow(_sortMessagesBySendTimeAsc(fullList));
              customChatListViewController.clear();
              customChatListViewController.insertAllToBottom(sortedFull);
            }
            _syncRxListWithMessageList();
            customChatListViewController.refresh();
            update();
          }
          if (isGroupChat) {
            // dawn 2026-06-18 修复3万人群消息不同步：从后台回前台时不能只读 SDK 本地库，
            // 大群还要对服务端最新 seq 做一次补偿拉取。
            await _syncLatestGroupPageFromServer(reason: 'resume');
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
          final unreadMsgs = messageList
              .where((m) =>
                  m.isRead != true && m.sendID != OpenIM.iMManager.userID)
              .toList();

          if (unreadMsgs.isNotEmpty) {
            final msgIds = unreadMsgs.map((m) => m.clientMsgID!).toList();
            print(
                '[ChatLogic] 📤 上报已读(批量) conversationID=${conversationInfo.conversationID} count=${msgIds.length}');
            await OpenIM.iMManager.messageManager.markMessagesAsReadByMsgID(
                conversationID: conversationInfo.conversationID,
                messageIDList: msgIds);
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
      // dawn 2026-06-26 群主/群管理员名单加载完后刷新列表，让已渲染消息的"官方"红标补显。
      customChatListViewController.refresh();
      update();
    } catch (e) {
      if (_handleGroupDismissedError(e)) return;
      rethrow;
    }
  }

  void _isJoinedGroup() async {
    if (!isGroupChat) {
      return;
    }
    final joined = await OpenIM.iMManager.groupManager.isJoinedGroup(
      groupID: groupID!,
    );
    if (joined) {
      isInGroup.value = true;
      _queryGroupInfo();
      _queryOwnerAndAdmin();
      return;
    }
    // dawn 2026-07-06 修复"被邀请入群后点进去立即被弹出、会话还被删"：
    // isJoinedGroup 读的是 SDK 本地缓存，刚被邀请/入群的成员本地成员缓存可能尚未同步，
    // 会误判"未入群"。原逻辑据此直接 deleteConversationAndDeleteAllMsg + Get.back()（破坏性）。
    // 现改为：进入群聊时本地一次判定 false 不再销毁会话，也不把 isInGroup 置 false（保持乐观，
    // 等 joinedGroupAddedSubject 同步补偿）。真正的退群/被踢由 joinedGroupDeletedSubject /
    // memberDeletedSubject 事件权威关闭；群已解散由 _queryGroupInfo 的 _handleGroupDismissedError 处理。
    _queryGroupInfo();
    _queryOwnerAndAdmin();
  }

  Future<void> _closeInvalidGroupConversation(String reason) async {
    if (!isGroupChat || _closingInvalidGroupConversation) return;
    _closingInvalidGroupConversation = true;
    final conversationID = conversationInfo.conversationID;
    inputCtrl.clear();
    try {
      if (conversationID.isNotEmpty) {
        await OpenIM.iMManager.conversationManager
            .deleteConversationAndDeleteAllMsg(conversationID: conversationID);
      }
    } catch (e) {
      ILogger.d('[ChatLogic] 清理已退出群会话失败: $reason, $e');
    }
    if (!isClosed && Get.currentRoute.isNotEmpty) {
      Get.back();
    }
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
      _ensureLatestGroupPageSyncTimer(reason: 'queryGroupInfo');
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
      if (latest == null || (msg.sendTime ?? 0) > (latest.sendTime ?? 0)) {
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
      final hasProtection =
          await core.ApiService().checkUserHasProtection(userID!);
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
          unawaited(_syncLatestGroupPageFromServer(reason: 'syncEnded'));
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
  Future<Message?> _insertServerMsgToLocal(
      Map<String, dynamic> raw, String groupID) async {
    if (!_serverRawBelongsToGroup(raw, groupID)) {
      ILogger.w(
          '[群聊补拉] 跳过非当前群消息 expected=$groupID rawGroupID=${raw['groupID']} recvID=${raw['recvID']} clientMsgID=${raw['clientMsgID']}');
      return null;
    }

    final msg = _messageFromServerRaw(raw, groupID);
    if (msg == null) return null;
    if (!_messageBelongsToCurrentConversation(msg)) {
      ILogger.w(
          '[群聊补拉] 跳过非当前会话消息 currentGroupID=${this.groupID} msgGroupID=${msg.groupID} clientMsgID=${msg.clientMsgID}');
      return null;
    }
    if (_hasServerPulledMessage(msg)) {
      return null;
    }
    final sendID = raw['sendID'] as String? ?? '';
    // dawn 2026-06-29 修复大群补拉历史消息时间变今天：SDK insertGroupMessageToLocalStorage
    // 会用"当前时间"覆盖 sendTime 且【重写 clientMsgID】(该方法本用于插入新本地消息)，导致
    // 后续 getAdvancedHistoryMessageList 读回今天、且 clientMsgID 已变。这里用稳定 key
    // (serverMsgID/seq，SDK 不改、群排序也靠 seq)记录服务端 raw 的真实 sendTime，
    // 排序重建时回填，保证旧消息显示真实日期。(codex 协同排查确认根因)
    final key = _effectiveTimeKey(msg);
    final realT = msg.sendTime ?? 0;
    if (key != null && realT > 0) {
      final rec = _earliestSendTimeById[key];
      if (rec == null || realT < rec) {
        _earliestSendTimeById[key] = realT;
      }
    }
    try {
      await OpenIM.iMManager.messageManager.insertGroupMessageToLocalStorage(
        message: msg,
        groupID: groupID,
        senderID: sendID,
      );
    } catch (e) {
      // dawn 2026-06-18 修复3万人群消息不同步：服务端补拉到的消息即使写 SDK 本地缓存失败，
      // 也先返回给当前 UI 合并展示；下次进入仍会再次从服务端补偿。
      ILogger.d('_insertServerMsgToLocal parse/insert error: $e');
    }
    _rememberServerPulledMessage(msg);
    return msg;
  }

  bool _serverRawBelongsToGroup(
      Map<String, dynamic> raw, String expectedGroupID) {
    final rawGroupID = raw['groupID']?.toString() ?? '';
    final recvID = raw['recvID']?.toString() ?? '';
    if (expectedGroupID.isEmpty) return true;
    if (rawGroupID.isNotEmpty && rawGroupID != expectedGroupID) return false;
    if (rawGroupID.isEmpty && recvID.isNotEmpty && recvID != expectedGroupID) {
      return false;
    }
    return true;
  }

  bool _messageBelongsToCurrentConversation(Message msg) {
    if (!isGroupChat) return true;
    final currentGroupID = groupID ?? '';
    final msgGroupID = msg.groupID ?? '';
    if (currentGroupID.isEmpty || msgGroupID.isEmpty) return true;
    return msgGroupID == currentGroupID;
  }

  bool _hasServerPulledMessage(Message msg) {
    final keys = customChatListViewController._messageKeys(msg);
    if (keys.isEmpty) return false;
    return keys.any(_serverPulledMessageKeys.contains) ||
        customChatListViewController._hasExistingMessage(msg);
  }

  void _rememberServerPulledMessage(Message msg) {
    _serverPulledMessageKeys
        .addAll(customChatListViewController._messageKeys(msg));
  }

  // dawn 2026-06-18 修复3万人群消息不同步：复用服务端消息转换结果，补拉后可直接合并到 UI。
  Message? _messageFromServerRaw(
      Map<String, dynamic> raw, String expectedGroupID) {
    final sendID = raw['sendID'] as String? ?? '';
    final contentType = raw['contentType'] as int? ?? 0;
    final content = raw['content'];
    String? contentStr;
    if (content != null && content is String) {
      contentStr = content;
      if (content.length > 0 &&
          content.length % 4 == 0 &&
          RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(content)) {
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
      'groupID': raw['groupID'] ?? expectedGroupID,
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
      return Message.fromJson(map);
    } catch (e) {
      ILogger.d('_messageFromServerRaw parse error: $e sendID=$sendID');
      return null;
    }
  }

  /// 群聊：从服务端按 seq 分段拉取历史并写入本地。返回 (插入条数, 服务端是否已到顶 isEnd)
  /// [endSeq] 为 null 表示「首屏只拉最近一页」：用大 end 让服务端返回最后 count 条，不先请求 getNewestSeq，加快进群展示
  Future<(int, bool)> _pullGroupHistoryFromServer({
    required String conversationID,
    required String groupID,
    int? endSeq,
    int count = 20,
    List<Message>? insertedMessages,
  }) async {
    final userID = OpenIM.iMManager.userID;
    if (userID == null || userID.isEmpty) return (0, true);

    // 群聊历史消息存储在 sg_groupID，若 conversationID 为 n_groupID 则转换为 sg_
    var chatConversationID = conversationID;
    if (conversationID.startsWith('n_') && groupID.isNotEmpty) {
      chatConversationID = 'sg_$groupID';
      ILogger.d(
          '[群聊上翻] conversationID $conversationID 转为 chatConversationID $chatConversationID');
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

    ILogger.d(
        '[群聊上翻] pullMessageBySeqs conv=$chatConversationID groupID=$groupID begin=$begin end=$end');

    final resp = await Apis.pullMessageBySeqs(
      userID: userID,
      seqRanges: [
        {
          'conversationID': chatConversationID,
          'begin': begin,
          'end': end,
          'num': count
        }
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
      ILogger.d(
          '[群聊上翻] msgsMap 中无 conv=$chatConversationID 的 key，resp.keys=${resp.keys}');
      return (0, true);
    }
    final list = (pullMsgs['Msgs'] ?? pullMsgs['msgs']) as List<dynamic>?;
    final isEnd =
        pullMsgs['isEnd'] as bool? ?? pullMsgs['IsEnd'] as bool? ?? true;
    if (list == null || list.isEmpty) {
      ILogger.d('[群聊上翻] list 为空 isEnd=$isEnd');
      return (0, isEnd);
    }

    int inserted = 0;
    int skipped = 0;
    for (final e in list) {
      final m =
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      if ((m['clientMsgID'] ?? m['sendID']) == null) {
        skipped++;
        continue;
      }
      final msg = await _insertServerMsgToLocal(m, groupID);
      if (msg == null) {
        skipped++;
        continue;
      }
      insertedMessages?.add(msg);
      inserted++;
    }

    ILogger.d(
        '[群聊上翻] inserted=$inserted skipped=$skipped isEnd=$isEnd listLen=${list.length}');

    // 若本批全是占位/已删除消息(inserted=0)，即使 isEnd=false 也当作已到底，避免无限循环请求
    if (inserted == 0 && skipped > 0) {
      return (0, true);
    }
    return (inserted, isEnd);
  }

  void _ensureLatestGroupPageSyncTimer({required String reason}) {
    if (!_shouldRunLatestGroupPageSync) return;
    _latestGroupPageSyncEnabled = true;
    if (_latestGroupPageSyncTimer != null || _syncingLatestGroupPage) return;

    // 只对当前打开的大群启用补偿轮询；每轮结束后按是否有新消息自适应退避。
    unawaited(_syncLatestGroupPageFromServer(
      reason: reason,
      scheduleNext: true,
    ));
  }

  bool get _shouldRunLatestGroupPageSync =>
      isGroupChat &&
      _isAppInForeground &&
      memberCount.value >= _largeGroupLatestSyncThreshold &&
      (conversationInfo.groupID ?? '').isNotEmpty;

  void _stopLatestGroupPageSyncTimer() {
    _latestGroupPageSyncEnabled = false;
    _latestGroupPageSyncTimer?.cancel();
    _latestGroupPageSyncTimer = null;
  }

  void _triggerLatestGroupPageSync({required String reason}) {
    if (!_shouldRunLatestGroupPageSync) return;
    _latestGroupPageSyncEnabled = true;
    _latestGroupPageIdleRounds = 0;
    _latestGroupPageSyncTimer?.cancel();
    _latestGroupPageSyncTimer = null;
    unawaited(_syncLatestGroupPageFromServer(
      reason: reason,
      scheduleNext: true,
    ));
  }

  void _scheduleNextLatestGroupPageSync({required bool hadNewMessages}) {
    if (!_latestGroupPageSyncEnabled || !_shouldRunLatestGroupPageSync) {
      _stopLatestGroupPageSyncTimer();
      return;
    }

    if (hadNewMessages) {
      _latestGroupPageIdleRounds = 0;
    } else {
      _latestGroupPageIdleRounds++;
    }

    final seconds = hadNewMessages
        ? _largeGroupLatestSyncFastSeconds
        : (_latestGroupPageIdleRounds >= _largeGroupLatestSyncIdleThreshold
            ? _largeGroupLatestSyncIdleSeconds
            : _largeGroupLatestSyncNormalSeconds);

    _latestGroupPageSyncTimer?.cancel();
    _latestGroupPageSyncTimer = Timer(Duration(seconds: seconds), () {
      _latestGroupPageSyncTimer = null;
      if (!_latestGroupPageSyncEnabled || !_shouldRunLatestGroupPageSync) {
        _stopLatestGroupPageSyncTimer();
        return;
      }
      unawaited(_syncLatestGroupPageFromServer(
        reason: 'largeGroupTimer',
        scheduleNext: true,
      ));
    });
  }

  Future<void> _syncLatestGroupPageFromServer({
    required String reason,
    bool scheduleNext = false,
  }) async {
    if (searchMessage != null || !isGroupChat || _syncingLatestGroupPage) {
      if (scheduleNext) {
        _scheduleNextLatestGroupPageSync(hadNewMessages: false);
      }
      return;
    }
    final currentGroupID = conversationInfo.groupID ?? '';
    if (currentGroupID.isEmpty) {
      if (scheduleNext) {
        _scheduleNextLatestGroupPageSync(hadNewMessages: false);
      }
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLatestGroupPageSyncMs < 2000) {
      if (scheduleNext) {
        _scheduleNextLatestGroupPageSync(hadNewMessages: false);
      }
      return;
    }

    _syncingLatestGroupPage = true;
    _lastLatestGroupPageSyncMs = now;
    var inserted = 0;
    try {
      final latestMessages = <Message>[];
      // dawn 2026-06-18 修复3万人群消息不同步：当前群进入/同步结束后主动补服务端最新一页。
      // 只读 SDK 本地缓存时，弱网或超大群偶发停在旧 seq；直接补拉服务端最新 50 条并合并到 UI。
      final (insertedCount, _) = await _pullGroupHistoryFromServer(
        conversationID: conversationInfo.conversationID,
        groupID: currentGroupID,
        endSeq: null,
        count: _initialHistoryPageSize,
        insertedMessages: latestMessages,
      );
      inserted = insertedCount;
      if (latestMessages.isNotEmpty) {
        await _mergeHistoryMessages(latestMessages);
      } else if (inserted > 0) {
        final result =
            await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
          conversationID: conversationInfo.conversationID,
          count: _initialHistoryPageSize,
          startMsg: null,
        );
        if (result.messageList != null && result.messageList!.isNotEmpty) {
          await _mergeHistoryMessages(result.messageList!);
        }
      }
      ILogger.d(
          '[群聊最新补拉] reason=$reason inserted=$inserted merged=${latestMessages.length}');
    } catch (e) {
      ILogger.w('[群聊最新补拉] reason=$reason error=$e');
    } finally {
      _syncingLatestGroupPage = false;
      if (scheduleNext) {
        _scheduleNextLatestGroupPageSync(hadNewMessages: inserted > 0);
      }
    }
  }

  Future<AdvancedMessage> _fetchHistoryMessages(Message? startMsg) async {
    // dawn 2026-06-14 优化大群首屏：长时间未读也只取最近50条，避免进群一次性拉大量历史消息。
    final pageSize = _isFirstLoad && searchMessage == null
        ? _initialHistoryPageSize
        : _pageSize;
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
      if (nextResult.messageList == null || nextResult.messageList!.isEmpty)
        break;
      list = [...list, ...nextResult.messageList!];
      filteredList = _sortMessagesBySendTimeAsc(_filterMessagesForChat(list));
      result = nextResult;
      iterations++;
    }

    customChatListViewController.insertAllToBottom(filteredList);
    return result.isEnd != true;
  }

  Future<bool> onScrollToTopLoad() async {
    // dawn 2026-06-29 群聊到 5 小时窗口上限即停止上拉:关闭顶部加载,避免一直转圈("滑到头不再拉")。
    if (searchMessage == null && _groupHistoryReachTimeLimit) {
      enabledTopLoad.value = false;
      return false;
    }
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
        count: _isFirstLoad ? _initialHistoryPageSize : _pageSize,
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
      // dawn 2026-06-29 已无更早历史:关闭顶部加载,停止转圈。
      enabledTopLoad.value = false;
      return false;
    }
    firstLoadEmpty.value = false;
    var list = result.messageList!;

    // 过滤通话信令及群通知消息，并按 sendTime 升序保证顺序一致
    _ensureGroupHistoryCutoff(list);
    var filteredList = _applyGroupHistoryWindow(
      _sortMessagesBySendTimeAsc(_filterMessagesForChat(list)),
    );

    // 首次加载时若本页全是群通知等被过滤消息，则继续向后拉取直到有可展示消息或到末尾，避免群聊只显示“空+一直转圈”
    const int maxIterations = 10;
    int iterations = 0;
    while (searchMessage == null &&
        _isFirstLoad &&
        filteredList.isEmpty &&
        !_groupHistoryReachTimeLimit &&
        list.isNotEmpty &&
        result.isEnd != true &&
        iterations < maxIterations) {
      final nextResult = await _fetchHistoryMessages(list.last);
      if (nextResult.messageList == null || nextResult.messageList!.isEmpty)
        break;
      list = [...list, ...nextResult.messageList!];
      _ensureGroupHistoryCutoff(list);
      filteredList = _applyGroupHistoryWindow(
        _sortMessagesBySendTimeAsc(_filterMessagesForChat(list)),
      );
      result = nextResult;
      iterations++;
    }

    if (filteredList.isEmpty && _groupHistoryReachTimeLimit) {
      // dawn 2026-06-29 过滤后无可展示(已达 5 小时窗口):关闭顶部加载,停止转圈。
      enabledTopLoad.value = false;
      return false;
    }

    await _prepareRevokeSilentFlagsForMessages(filteredList);

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
    // dawn 2026-06-21 新增官方人员标识：上滑历史消息时只补拉本页出现的发送人角色。
    unawaited(_loadOfficialRolesForMessages(filteredList));

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
    // dawn 2026-06-29 修复小群/一屏装得下时顶部一直转圈:首屏由 init 调用,其返回值不被
    // 列表组件捕获,_topHasMore 维持初始 true,无法上滑就永远转圈。这里到末页即直接关闭
    // enabledTopLoad,无需用户上滑也能收起顶部加载。
    final reachedEnd = didServerPull ? serverPulledIsEnd : (result.isEnd == true);
    if (reachedEnd) {
      enabledTopLoad.value = false;
    }
    // dawn 2026-06-30 本页过滤后触达 5 小时上限：关闭顶部加载并告知列表已无更早可展示。
    if (_groupHistoryReachTimeLimit) {
      enabledTopLoad.value = false;
      return false;
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

          final userStatus = allLuckyMoneyStatuses[luckyMoneyId] ?? 'pending';
          final packetStatus = allPacketStatuses[luckyMoneyId] ?? 'pending';

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
      final List<Message> candidates = luckyMoneyMessages.where((msg) {
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
      }).toList();

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

          final result = await apiService.transactionCheckCompleted(
              transaction_id: luckyMoneyId);
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
            await LuckMoneyStatusManager.saveLuckMoneyStatus(
                luckyMoneyId, 'completed',
                userId: OpenIM.iMManager.userID);
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
    await _mergeHistoryMessages(result.messageList!);
  }

  Future<void> _mergeHistoryMessages(List<Message> messages) async {
    // dawn 2026-06-30 同步/补拉进来的消息也套 5 小时窗口,不把超窗旧消息合并进可见列表。
    final incoming = _applyGroupHistoryWindow(
      _sortMessagesBySendTimeAsc(_filterMessagesForChat(messages)),
    );
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

    // dawn 2026-06-30 同步/恢复/补偿拉取后重建的是可见列表,也必须套群聊 5 小时窗口。
    final fullList = _applyGroupHistoryWindow(
      _sortMessagesBySendTimeAsc(_filterMessagesForChat(messageList)),
    );
    // 客户端(dev-20260630)：重建后为撤回消息准备静默标记。
    await _prepareRevokeSilentFlagsForMessages(fullList);
    customChatListViewController.clear();
    customChatListViewController.insertAllToBottom(fullList);
    _syncRxListWithMessageList();
    customChatListViewController.refresh();
    _applyPendingRevokeDetails();
    // dawn 2026-06-21 新增官方人员标识：历史合并后补全新增发送人的认证状态。
    unawaited(_loadOfficialRolesForMessages(fullList));
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
      await OpenIM.iMManager.conversationManager
          // dawn 2026-06-16 优化移动端空历史重试速度：触发同步只需补刷首屏会话，不再拉 400 条。
          .getConversationListSplit(offset: 0, count: 50);
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
            final userStatus = allLuckyMoneyStatuses[luckyMoneyId] ?? 'pending';
            // 2. 红包整体是否已结束（即使当前用户未领取）
            final packetStatus = allPacketStatuses[luckyMoneyId] ?? 'pending';

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

          final result = await apiService.transactionCheckCompleted(
              transaction_id: luckyMoneyId);
          final Map<String, dynamic>? respData = result == null
              ? null
              : ((result as Map<String, dynamic>)['data'] ?? result)
                  as Map<String, dynamic>?;
          final received = respData?['received'] == true;

          if (received) {
            redPacketStatusMap[luckyMoneyId] = 'completed';
            luckyMoneyData['isReceived'] = true;
            luckyMoneyData['status'] = 'completed';
            msg.customElem!.data = json.encode(data);
            await LuckMoneyStatusManager.saveLuckMoneyStatus(
                luckyMoneyId, 'completed',
                userId: OpenIM.iMManager.userID);
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
      LuckMoneyStatusManager.saveLuckMoneyStatus(luckMoneyId, status,
          userId: OpenIM.iMManager.userID);

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
                final List<dynamic> list =
                    List<dynamic>.from(luckMoneyData['receivers'] as List);
                const int kMaxReceiversInMessage = 50;
                msgLuckMoneyData['receivers'] =
                    list.length > kMaxReceiversInMessage
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
          // dawn 2026-05-21 修复上传文件限制：文件上传上限调整为200MB。
          final fileSize = file.size;
          const maxFileSize = 200 * 1024 * 1024; // 200MB

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
              // dawn 2026-05-22 修复手机端视频文件发送失败：文件入口选择的视频按文件消息发送，不走contentType=104视频消息。
              message = await _createUploadedFileMessage(
                filePath: file.path!,
                fileName: file.name,
                fileSize: fileSize,
              );
            } else {
              // dawn 2026-05-22 修复手机端大文件发送失败：普通文件先走业务分片上传，再用URL消息发送，避免SDK内部上传失败只返回泛化错误。
              message = await _createUploadedFileMessage(
                filePath: file.path!,
                fileName: file.name,
                fileSize: fileSize,
              );
            }

            // 发送消息
            await _sendMessage(message);
            IMViews.showToast(StrRes.sendFileSuccess);
          } catch (e, s) {
            app_log.LogUtil.e(
              'ChatLogic',
              '发送文件失败: file=${file.name}, size=${file.size}',
              e,
              s,
            );
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

  final GlobalKey<ChatInputBoxState> chatInputKey =
      GlobalKey<ChatInputBoxState>();

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
        // dawn 2026-07-04 修复"撤不回自己的消息"：合并客户分支后 canRevokeMessages 只剩管理员，
        // 连撤自己的消息都被拦。自己的消息始终可撤(走 SDK)；撤【别人】的消息才需要管理员权限(走审计接口)。
        final isOwnMessage = message.sendID == OpenIM.iMManager.userID;
        if (!isOwnMessage && !canRevokeMessages) {
          IMViews.showToast(StrRes.revokeFailed);
          break;
        }
        try {
          if (isOwnMessage) {
            await OpenIM.iMManager.messageManager.revokeMessage(
              conversationID: conversationInfo.conversationID,
              clientMsgID: message.clientMsgID!,
            );
          } else {
            final seq = message.seq;
            if (seq == null || seq <= 0) {
              IMViews.showToast(StrRes.revokeFailed);
              break;
            }
            await Apis.revokeChatMessage(
              conversationID: conversationInfo.conversationID,
              seq: seq,
              userID: OpenIM.iMManager.userID,
            );
          }
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
