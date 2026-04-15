import 'package:flutter/widgets.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/widgets/chat/mention_text.dart';

class ChatAtView extends StatelessWidget {
  final Message message;
  final Function(String id)? onMentionTap;
  const ChatAtView({super.key, required this.message, this.onMentionTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: MentionText(
        text: message.atTextElem?.text ?? "",
        style: Styles.ts_0C1C33_17sp,
        mentionStyle: Styles.ts_0089FF_17sp_semibold,
        formatText: (mentionStr) {
          String id = mentionStr.replaceAll(RegExp(r'@'), '');
          if (id == 'AtAllTag') {
            return "@${StrRes.everyone}";
          }

          final info = message.atTextElem?.atUsersInfo
              ?.where((user) => user.atUserID == id);
          if (info != null && info.isNotEmpty) {
            return "@${info.first.groupNickname}";
          }
          return mentionStr;
        },
        onMentionTap: (mentionStr) {
          String id = mentionStr.replaceAll(RegExp(r'@'), '');
          if (id != 'AtAllTag') {
            onMentionTap?.call(id);
          }
        },
      ),
    );
  }
}
