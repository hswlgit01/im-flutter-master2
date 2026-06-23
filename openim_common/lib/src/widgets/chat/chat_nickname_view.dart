import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatNicknameView extends StatelessWidget {
  const ChatNicknameView({
    Key? key,
    this.nickname,
    this.timeStr,
    this.isCertified = false,
  }) : super(key: key);
  final String? nickname;
  final String? timeStr;
  final bool isCertified;

  @override
  Widget build(BuildContext context) {
    // dawn 2026-06-23 官方人员标识改版：群聊中管理员/官方昵称红色显示，并在昵称后追加“官方”红色标签（替换原蓝色认证图标）。
    final nicknameStyle = isCertified
        ? Styles.ts_8E9AB0_12sp.copyWith(color: Styles.c_FF381F)
        : Styles.ts_8E9AB0_12sp;
    return RichText(
      text: TextSpan(
        text: '',
        style: Styles.ts_8E9AB0_12sp,
        children: [
          if (null != nickname)
            WidgetSpan(
              child: Container(
                constraints: BoxConstraints(maxWidth: 100.w),
                margin: EdgeInsets.only(right: 6.w),
                child: nickname!.toText
                  ..style = nicknameStyle
                  ..maxLines = 1
                  ..overflow = TextOverflow.ellipsis,
              ),
            ),
          if (isCertified && null != nickname)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Styles.c_FF381F.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '官方',
                    style: TextStyle(
                      color: Styles.c_FF381F,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          TextSpan(text: timeStr),
        ],
      ),
    );
  }
}
