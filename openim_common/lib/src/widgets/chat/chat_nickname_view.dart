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
    // 官方人员仅追加标签，昵称保持普通颜色。
    final nicknameStyle = Styles.ts_0C1C33_12sp;
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
