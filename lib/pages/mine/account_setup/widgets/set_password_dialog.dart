import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class SetPasswordDialog extends StatelessWidget {
  final Future<bool> Function(String password, String newPassword) onConfirm;

  const SetPasswordDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    final oldPasswordFocusNode = FocusNode();
    final passwordFocusNode = FocusNode();
    final confirmFocusNode = FocusNode();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      titlePadding: EdgeInsets.only(left: 24.w, right: 24.w, top: 24.h),
      contentPadding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
      actionsPadding: EdgeInsets.all(16.w),
      title: Column(
        children: [
          StrRes.changePassword.toText..style = Styles.ts_0C1C33_17sp_medium,
          8.verticalSpace,
          StrRes.loginPwdFormat.toText..style = Styles.ts_8E9AB0_14sp,
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPasswordField(
            controller: oldPasswordController,
            focusNode: oldPasswordFocusNode,
            hintText: StrRes.plsEnterOldPwd,
          ),
          16.verticalSpace,
          _buildPasswordField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            hintText: StrRes.plsEnterNewPwd,
          ),
          16.verticalSpace,
          _buildPasswordField(
            controller: confirmController,
            focusNode: confirmFocusNode,
            hintText: StrRes.plsConfirmNewPwd,
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
                child: StrRes.walletCancel.toText
                  ..style = Styles.ts_0C1C33_17sp,
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: TextButton(
                onPressed: () async {
                  if (!IMUtils.isValidPassword(oldPasswordController.text)) {
                    IMViews.showToast(StrRes.wrongPasswordFormat);
                    oldPasswordFocusNode.requestFocus();
                    return;
                  }
                  if (!IMUtils.isValidPassword(passwordController.text)) {
                    IMViews.showToast(StrRes.wrongPasswordFormat);
                    passwordFocusNode.requestFocus();
                    return;
                  }
                  if (!IMUtils.isValidPassword(confirmController.text)) {
                    IMViews.showToast(StrRes.wrongPasswordFormat);
                    confirmFocusNode.requestFocus();
                    return;
                  }
                  if (passwordController.text != confirmController.text) {
                    IMViews.showToast(StrRes.twicePwdNoSame);
                    confirmFocusNode.requestFocus();
                    return;
                  }
                  if (oldPasswordController.text == passwordController.text) {
                    IMViews.showToast(StrRes.newPwdSameAsOld);
                    passwordFocusNode.requestFocus();
                    return;
                  }

                  final success =
                      await onConfirm.call(oldPasswordController.text, passwordController.text);
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
                child: StrRes.walletConfirm.toText
                  ..style = Styles.ts_FFFFFF_17sp,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Styles.c_F0F2F6,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.visiblePassword,
        maxLength: 20,
        style: Styles.ts_0C1C33_17sp,
        inputFormatters: [IMUtils.getPasswordFormatter()],
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Styles.ts_8E9AB0_14sp,
          counterText: '',
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }
}
