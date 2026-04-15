import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class SetTransactionPasswordDialog extends StatelessWidget {
  final Future<bool> Function(String password) onConfirm;
  
  const SetTransactionPasswordDialog({
    Key? key,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      titlePadding: EdgeInsets.only(left: 24.w, right: 24.w, top: 24.h),
      contentPadding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
      actionsPadding: EdgeInsets.all(16.w),
      title: Column(
        children: [
          StrRes.walletSetTransactionPassword.toText..style = Styles.ts_0C1C33_17sp_medium,
          8.verticalSpace,
          StrRes.walletPasswordLength.toText..style = Styles.ts_8E9AB0_14sp,
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPasswordField(
            controller: passwordController,
            hintText: StrRes.walletEnterTransactionPassword,
          ),
          16.verticalSpace,
          _buildPasswordField(
            controller: confirmController,
            hintText: StrRes.walletConfirmTransactionPassword,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Get.back(result: false),
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
                  if (passwordController.text.length != 6) {
                    IMViews.showToast(StrRes.walletPasswordLength);
                    return;
                  }
                  if (passwordController.text != confirmController.text) {
                    IMViews.showToast(StrRes.walletPasswordMismatch);
                    return;
                  }
                  
                  final success = await onConfirm(passwordController.text);
                  if (success) {
                    Get.back(result: true);
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Styles.c_F0F2F6,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: Styles.ts_0C1C33_17sp,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Styles.ts_8E9AB0_14sp,
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }
} 