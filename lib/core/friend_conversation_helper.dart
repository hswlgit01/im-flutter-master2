import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

/// Makes sure freshly-imported friends (default friends + invitation-code inviter)
/// actually show up in the chat list right after registration.
///
/// Why this exists: OpenIM's `getOneConversation` creates the local conversation
/// row, but the home chat list in this app surfaces conversations that have a
/// `latestMsg`. A conversation whose row exists but whose last message is empty
/// stays invisible. To make the chat window pop up as the product expects, we
/// drop a local-only greeting via `insertSingleMessageToLocalStorage` so the
/// conversation has something to render in the list preview.
class FriendConversationHelper {
  /// Default local greeting shown as the first line of the conversation.
  /// It is NOT sent to the server; purely a local hint to surface the session.
  static const _greeting = '你们已经成为好友，打个招呼吧～';

  /// Ensure conversations exist (and are visible) for every friend in the
  /// logged-in user's friend list. Safe to call multiple times — friends that
  /// already have a conversation with at least one message are skipped.
  static Future<void> ensureConversationsForAllFriends() async {
    try {
      var friends = await OpenIM.iMManager.friendshipManager.getFriendList();
      for (var i = 0; friends.isEmpty && i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 600));
        friends = await OpenIM.iMManager.friendshipManager.getFriendList();
      }
      if (friends.isEmpty) return;
      for (final f in friends) {
        final uid = f.userID;
        if (uid == null || uid.isEmpty) continue;
        await ensureConversationForFriend(uid);
      }
    } catch (e, s) {
      Logger.print('[FriendConversationHelper] ensureConversationsForAllFriends error: $e\n$s');
    }
  }

  /// Ensure the conversation with [friendUserID] exists AND has a renderable
  /// last message so the chat list shows it.
  static Future<void> ensureConversationForFriend(String friendUserID) async {
    try {
      final selfID = OpenIM.iMManager.userID;
      if (selfID.isEmpty || selfID == friendUserID) return;

      // Create the conversation record (or return the existing one).
      final conversation =
          await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: friendUserID,
        sessionType: ConversationType.single,
      );

      if (_hasLatestMsg(conversation)) {
        // Already has messages, it's visible — don't spam another hint.
        return;
      }

      // Drop a local-only greeting; the SDK persists it but does not send it.
      final hint = await OpenIM.iMManager.messageManager
          .createTextMessage(text: _greeting);
      await OpenIM.iMManager.messageManager.insertSingleMessageToLocalStorage(
        message: hint,
        receiverID: friendUserID,
        senderID: selfID,
      );
    } catch (e, s) {
      Logger.print(
          '[FriendConversationHelper] ensureConversationForFriend($friendUserID) error: $e\n$s');
    }
  }

  static bool _hasLatestMsg(ConversationInfo c) {
    final t = c.latestMsgSendTime ?? 0;
    return t > 0 || c.latestMsg != null;
  }
}
