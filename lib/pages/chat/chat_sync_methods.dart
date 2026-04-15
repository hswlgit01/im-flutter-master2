import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'chat_logic.dart';

/// 聊天页面同步方法扩展
/// 用于修复前后台切换时消息刷新问题
extension ChatSyncMethods on ChatLogic {
  /// 同步并刷新消息
  /// 在应用从后台恢复时调用，确保显示最新消息
  Future<void> syncAndRefreshMessages() async {
    try {
      Logger.print('[ChatLogic] 开始同步会话消息');

      // 延迟执行，确保 UI 完全恢复
      await Future.delayed(Duration(milliseconds: 300));

      // 从服务器拉取最新消息
      final result = await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationInfo.conversationID,
        startMsg: null,
        count: 50,
      );

      if (result.messageList != null && result.messageList!.isNotEmpty) {
        Logger.print('[ChatLogic] 获取到 ${result.messageList!.length} 条最新消息');

        // 添加不在本地列表中的消息，过滤通话信令消息
        for (var newMsg in result.messageList!) {
          if (isCallSignalingMessage(newMsg)) {
            Logger.print('[ChatLogic] ⚠️ 历史消息中跳过通话信令消息');
            continue;
          }

          if (!messageList.contains(newMsg)) {
            customChatListViewController.insertToBottom(newMsg);
          }
        }
      }

      // 刷新UI
      customChatListViewController.refresh();
      update();

      // 滚动到底部
      if (scrollController.hasClients) {
        ScrollControllerExt(scrollController).scrollToBottom();
      }

      // 标记未读消息为已读
      await _markUnreadMessagesAsRead();
    } catch (e) {
      Logger.print('[ChatLogic] 同步消息时出错: $e');
      // 确保UI能够刷新，即使出错
      customChatListViewController.refresh();
    }
  }

  /// 标记未读消息为已读
  Future<void> _markUnreadMessagesAsRead() async {
    try {
      final unreadMsgs = messageList.where((m) =>
        !m.isRead! && m.sendID != OpenIM.iMManager.userID
      ).toList();

      if (unreadMsgs.isNotEmpty) {
        final msgIds = unreadMsgs.map((m) => m.clientMsgID!).toList();
        await OpenIM.iMManager.messageManager.markMessagesAsReadByMsgID(
          conversationID: conversationInfo.conversationID,
          messageIDList: msgIds
        );
      }
    } catch (e) {
      // 忽略标记已读失败
      Logger.print('[ChatLogic] 标记消息已读失败: $e');
    }
  }

  /// 检查消息是否为通话信令消息
  bool isCallSignalingMessage(Message msg) {
    if (msg.contentType == 110 && msg.customElem != null) {
      try {
        final data = json.decode(msg.customElem!.data!);
        final customType = data['customType'];

        // 通话信令消息类型为 200-204 和 2005
        if (customType == 200 || customType == 201 || customType == 202 ||
            customType == 203 || customType == 204 || customType == 2005) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}