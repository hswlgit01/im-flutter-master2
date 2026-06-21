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
                  ..style = Styles.ts_8E9AB0_12sp
                  ..maxLines = 1
                  ..overflow = TextOverflow.ellipsis,
              ),
            ),
          if (isCertified && null != nickname)
            // dawn 2026-06-21 新增官方人员标识：聊天昵称后追加认证图标。
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: Icon(
                  Icons.verified,
                  size: 12.w,
                  color: Styles.c_0089FF,
                ),
              ),
            ),
          TextSpan(text: timeStr),
        ],
      ),
    );
  }
}
