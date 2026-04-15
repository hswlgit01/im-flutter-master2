import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

enum PasswordVeifyBackType {
  cancel,
  success
}

class PasswordVerifyDialog extends StatelessWidget {
  final String title;
  final Future<bool> Function(String password) onConfirm;
  
  const PasswordVerifyDialog({
    Key? key,
    required this.title,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final passwordController = TextEditingController();
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      titlePadding: EdgeInsets.only(left: 24.w, right: 24.w, top: 24.h),
      contentPadding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
      actionsPadding: EdgeInsets.all(16.w),
      title: Column(
        children: [
          title.toText..style = Styles.ts_0C1C33_17sp_medium,
          8.verticalSpace,
          StrRes.walletEnterPassword.toText..style = Styles.ts_8E9AB0_14sp,
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Styles.c_F0F2F6,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              style: Styles.ts_0C1C33_17sp,
              decoration: InputDecoration(
                hintText: StrRes.walletEnterPassword,
                hintStyle: Styles.ts_8E9AB0_14sp,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Get.back(result: PasswordVeifyBackType.cancel),
                style: TextButton.styleFrom(
                  backgroundColor: Styles.c_F0F2F6,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                child: StrRes.walletCancel.toText..style = Styles.ts_0C1C33_17sp,
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: TextButton(
                onPressed: () async {
                  if (passwordController.text.isEmpty) {
                    IMViews.showToast(StrRes.walletEnterPassword);
                    return;
                  }
                  
                  final success = await onConfirm(passwordController.text);
                  if (success) {
                    Get.back(result: PasswordVeifyBackType.success);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Styles.c_0089FF,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                child: StrRes.walletConfirm.toText..style = Styles.ts_FFFFFF_17sp,
              ),
            ),
          ],
        ),
      ],
    );
  }
} 