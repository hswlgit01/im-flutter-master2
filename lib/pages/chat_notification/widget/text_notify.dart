import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class TextNotify extends StatelessWidget {
  final String text;
  final String? externalUrl;

  const TextNotify({
    super.key,
    required this.text,
    this.externalUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          color: (externalUrl == null || externalUrl == "")
              ? Styles.c_0C1C33
              : Styles.c_0089FF,
        ),
      ),
    );
  }
}
