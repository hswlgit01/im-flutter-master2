import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

/// 好友会话创建辅助类
/// 用于确保好友关系建立后会话能够正确创建
class FriendConversationHelper {
  /// 定期检查好友列表，为没有会话的好友创建会话
  static Future<void> ensureConversationsForAllFriends() async {
    try {
      print('[FriendConversationHelper] 开始检查好友会话...');

      // 获取所有好友
      final friends = await OpenIM.iMManager.friendshipManager.getFriendList();
      print('[FriendConversationHelper] 当前好友数量: ${friends.length}');

      // 获取所有会话
      final conversations = await OpenIM.iMManager.conversationManager.getAllConversationList();
      final conversationUserIDs = conversations
          .where((c) => c.conversationType == ConversationType.single)
          .map((c) => c.userID)
          .toSet();

      print('[FriendConversationHelper] 当前单聊会话数量: ${conversationUserIDs.length}');

      // 找出没有会话的好友
      final friendsWithoutConversation = friends.where((friend) {
        return !conversationUserIDs.contains(friend.userID);
      }).toList();

      if (friendsWithoutConversation.isEmpty) {
        print('[FriendConversationHelper] ✅ 所有好友都有会话');
        return;
      }

      print('[FriendConversationHelper] ⚠️ 发现 ${friendsWithoutConversation.length} 个好友没有会话');

      // 为每个没有会话的好友创建会话
      for (var friend in friendsWithoutConversation) {
        try {
          print('[FriendConversationHelper] 为好友创建会话: ${friend.nickname ?? friend.userID}');

          await OpenIM.iMManager.conversationManager.getOneConversation(
            sourceID: friend.userID!,
            sessionType: ConversationType.single,
          );

          print('[FriendConversationHelper] ✅ 会话创建成功: ${friend.userID}');
        } catch (e) {
          print('[FriendConversationHelper] ❌ 会话创建失败: ${friend.userID}, 错误: $e');
        }
      }

      print('[FriendConversationHelper] 检查完成');
    } catch (e, stackTrace) {
      print('[FriendConversationHelper] ❌ 检查过程出错: $e');
      print('[FriendConversationHelper] 堆栈: $stackTrace');
    }
  }

  /// 为特定好友确保会话存在
  static Future<void> ensureConversationForFriend(String friendUserID) async {
    try {
      print('[FriendConversationHelper] 为好友创建会话: $friendUserID');

      final conversation = await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: friendUserID,
        sessionType: ConversationType.single,
      );

      print('[FriendConversationHelper] ✅ 会话已存在或创建成功');
      print('[FriendConversationHelper] conversationID: ${conversation.conversationID}');

      // 验证会话是否在列表中
      final conversations = await OpenIM.iMManager.conversationManager.getAllConversationList();
      final exists = conversations.any((c) => c.userID == friendUserID);

      print('[FriendConversationHelper] 会话在列表中: $exists');

      if (!exists) {
        print('[FriendConversationHelper] ⚠️ 会话未在列表中，尝试刷新...');
        // 等待一下再次检查
        await Future.delayed(Duration(milliseconds: 500));
        final conversationsRetry = await OpenIM.iMManager.conversationManager.getAllConversationList();
        final existsRetry = conversationsRetry.any((c) => c.userID == friendUserID);
        print('[FriendConversationHelper] 重试后会话在列表中: $existsRetry');
      }
    } catch (e, stackTrace) {
      print('[FriendConversationHelper] ❌ 创建会话失败: $e');
      print('[FriendConversationHelper] 堆栈: $stackTrace');
    }
  }
}
