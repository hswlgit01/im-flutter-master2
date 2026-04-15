import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';

class ChatNotificationLogic extends GetxController {
  final imLogic = Get.find<IMController>();

  final nickname = ''.obs;
  late ConversationInfo conversationInfo;
  final messageList = <Message>[].obs;
  final _pageSize = 40;
  bool _isFirstLoad = true;
  final scaleFactor = Config.textScaleFactor.obs;
  ScrollController scrollController = ScrollController();

  String? get userID => conversationInfo.userID;
  ValueKey itemKey(Message message) => ValueKey(message.clientMsgID!);
  static int get _timestamp => DateTime.now().millisecondsSinceEpoch;

  @override
  onInit() {
    _initChatConfig();

    var arguments = Get.arguments;
    conversationInfo = arguments['conversationInfo'];
    nickname.value = conversationInfo.showName ?? '';

    imLogic.onRecvNewMessage = (Message message) async {
      ILogger.d('收到新消息: ${json.encode(message)}');
      if (isCurrentChat(message)) {
        if (message.contentType == MessageType.typing) {
          ILogger.d('忽略输入状态消息');
          return;
        }

        if (!messageList.contains(message)) {
          messageList.add(message);
        }
      }
    };

    super.onInit();
  }

  Future<AdvancedMessage> _fetchHistoryMessages() {
    return OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
      conversationID: conversationInfo.conversationID,
      count: _pageSize,
      startMsg: _isFirstLoad ? null : messageList.firstOrNull,
    );
  }

  void _initChatConfig() async {
    scaleFactor.value = DataSp.getChatFontSizeFactor();
  }

  Message indexOfMessage(int index, {bool calculate = true}) =>
      IMUtils.calChatTimeInterval(
        messageList,
        calculate: calculate,
      ).reversed.elementAt(index);

  Future<bool> onScrollToBottomLoad() async {
    late List<Message> list;
    final result = await _fetchHistoryMessages();
    if ((result.messageList == null || result.messageList!.isEmpty)) {
      return false;
    }
    list = result.messageList!;
    if (_isFirstLoad) {
      _isFirstLoad = false;
      messageList.assignAll(list);

      // 预加载通知账号信息
      _preloadNotificationAccounts();
    } else {
      messageList.insertAll(0, list);

      // 预加载新加载消息中的通知账号信息
      _preloadNotificationAccounts(list);
    }
    return result.isEnd != true;
  }

  /// 预加载通知账号信息
  void _preloadNotificationAccounts([List<Message>? messages]) {
    try {
      final msgs = messages ?? messageList;
      // 获取所有通知消息的发送者ID
      final notificationUserIDs = msgs
        .where((msg) => msg.contentType == MessageType.oaNotification) // 筛选出通知类型的消息
        .map((msg) => msg.sendID)
        .toSet() // 去重
        .toList();

      print('🔍 预加载通知账号信息: ${notificationUserIDs.length}个');

      if (notificationUserIDs.isNotEmpty) {
        try {
          // 预加载通知账号信息
          Get.find<NotificationAccountController>().preloadNotificationAccounts(notificationUserIDs);
        } catch (e) {
          print('❌ 预加载通知账号信息失败: $e');
          ILogger.d('预加载通知账号信息失败: $e');
        }
      }
    } catch (e) {
      print('❌ 预加载通知账号信息失败: $e');
      ILogger.d('预加载通知账号信息失败: $e');
    }
  }

  bool isCurrentChat(Message message) {
    var senderId = message.sendID;
    var receiverId = message.recvID;

    var isCurSingleChat = (senderId == userID ||
        senderId == OpenIM.iMManager.userID && receiverId == userID);

    return isCurSingleChat;
  }

  void onTapMessage(Message message) {
    var content = NotifyContent.fromJson(
        jsonDecode(message.notificationElem?.detail ?? ''));

    if (content.externalUrl != null && content.externalUrl != '') {
      AppNavigator.startWebViewPage(url: content.externalUrl);
    }
  }

  void markMessageAsRead(Message message, bool visible) async {
    if (visible) {
      _markMessageAsRead(message);
    }
  }

  _markMessageAsRead(Message message) async {
    if (!message.isRead! && message.sendID != OpenIM.iMManager.userID) {
      try {
        await OpenIM.iMManager.conversationManager
            .markConversationMessageAsRead(
                conversationID: conversationInfo.conversationID);
      } catch (e) {
        ILogger.d(
            'failed to send group message read receipt： ${message.clientMsgID} ${message.isRead}');
      } finally {
        message.isRead = true;
        message.hasReadTime = _timestamp;
        messageList.refresh();
      }
    }
  }
}
