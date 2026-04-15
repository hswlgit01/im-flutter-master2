import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_logic.dart';

class LoginPage extends StatelessWidget {
  final logic = Get.find<LoginLogic>();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: TouchCloseSoftKeyboard(
        isGradientBg: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              88.verticalSpace,
              // ImageRes.loginLogo.toImage
              //   ..width = 64.w
              //   ..height = 64.h,
              StrRes.welcome.toText..style = Styles.ts_0089FF_17sp_semibold,
              51.verticalSpace,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(children: [
                  _buildInputView(),
                  46.verticalSpace,
                  Obx(() => Button(
                        text: StrRes.login,
                        enabled: logic.enabled.value,
                        onTap: logic.login,
                      )),

                  20.verticalSpace,  // 登录按钮和分隔线之间的间距

                  // 水平分隔线，中间有"或"字
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Color(0xFFE8EAEF),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Text(
                          '或',  // 或文字
                          style: Styles.ts_8E9AB0_12sp,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Color(0xFFE8EAEF),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  20.verticalSpace,  // 分隔线和注册按钮之间的间距

                  // 独立的注册按钮，颜色略有不同
                  Button(
                    text: StrRes.accountPasswordRegister,
                    enabledColor: Color(0xFF66BB6A),  // 适配色系的浅绿色
                    onTap: logic.registerNow,
                  ),
                ]),
              ),
              50.verticalSpace, // 为了保持整体布局的平衡
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    return Container(
      height: 240.h,
      width: 300.w,
      child: Column(
      children: [
        _buildInputView2(LoginType.account),  // 直接显示账号登录的输入框
      ],
    ),
    );
  }

  Widget _buildInputView1(LoginType type) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InputBox.account(
          label: '',
          hintText: type.hintText,
          code: logic.areaCode.value,
          onAreaCode:
              type == LoginType.phone ? logic.openCountryCodePicker : null,
          controller: logic.phoneCtrl,
          focusNode: logic.accountFocus,
          keyBoardType: type == LoginType.phone
              ? TextInputType.phone
              : TextInputType.text,
        ),
        8.verticalSpace,
        Offstage(
          offstage: !logic.isPasswordLogin.value,
          child: InputBox.password(
            label: '',
            hintText: StrRes.plsEnterPassword,
            controller: logic.pwdCtrl,
            focusNode: logic.pwdFocus,
          ),
        ),
        Offstage(
          offstage: logic.isPasswordLogin.value,
          child: InputBox.verificationCode(
            label: StrRes.verificationCode,
            hintText: StrRes.plsEnterVerificationCode,
            controller: logic.verificationCodeCtrl,
            onSendVerificationCode: logic.getVerificationCode,
          ),
        ),
        10.verticalSpace,
        Row(
          children: [
            // 记住密码选项 - 只在密码登录模式下显示
            Obx(() => Offstage(
              offstage: !logic.isPasswordLogin.value,
              child: GestureDetector(
                onTap: logic.toggleRememberPassword,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: logic.rememberPassword.value 
                              ? Styles.c_0089FF 
                              : Styles.c_8E9AB0,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(2.r),
                        color: logic.rememberPassword.value 
                            ? Styles.c_0089FF 
                            : Colors.transparent,
                      ),
                      child: logic.rememberPassword.value
                          ? Icon(
                              Icons.check,
                              size: 12.w,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    8.horizontalSpace,
                    StrRes.rememberPassword.toText
                      ..style = Styles.ts_8E9AB0_12sp,
                  ],
                ),
              ),
            )),
            const Spacer(),
            (logic.isPasswordLogin.value
                    ? StrRes.verificationCodeLogin
                    : StrRes.passwordLogin)
                .toText
              ..style = Styles.ts_0089FF_12sp
              ..onTap = logic.togglePasswordType,
            20.horizontalSpace,
            StrRes.forgetPassword.toText
              ..style = Styles.ts_8E9AB0_12sp
              ..onTap = logic.forgetPassword,
          ],
        ),
      ],
    );
  }

  Widget _buildInputView2(LoginType type) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InputBox.account(
          label: '',
          hintText: type.hintText,
          code: logic.areaCode.value,
          onAreaCode: null,
          controller: logic.phoneCtrl,
          focusNode: logic.accountFocus,
          keyBoardType: TextInputType.text,
        ),
        8.verticalSpace,
        InputBox.password(
          label: '',
          hintText: StrRes.plsEnterPassword,
          controller: logic.pwdCtrl,
          focusNode: logic.pwdFocus,
        ),
        10.verticalSpace,
        Row(
          children: [
            // 记住密码选项
            Obx(() => GestureDetector(
              onTap: logic.toggleRememberPassword,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: logic.rememberPassword.value 
                            ? Styles.c_0089FF 
                            : Styles.c_8E9AB0,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                      color: logic.rememberPassword.value 
                          ? Styles.c_0089FF 
                          : Colors.transparent,
                    ),
                    child: logic.rememberPassword.value
                        ? Icon(
                            Icons.check,
                            size: 12.w,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  8.horizontalSpace,
                  StrRes.rememberPassword.toText
                    ..style = Styles.ts_8E9AB0_12sp,
                ],
              ),
            )),
            const Spacer(),
            StrRes.forgetPassword.toText
              ..style = Styles.ts_8E9AB0_12sp
              ..onTap = _showContactServiceBottomSheet,
          ],
        ),
      ],
    );
  }

  void _showRegisterBottomSheet() {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                logic.operateType = LoginType.email;
                logic.registerNow();
              },
              child: Text('${StrRes.email} ${StrRes.registerNow}'),
            ),
            // CupertinoActionSheetAction(
            //   onPressed: () {
            //     Navigator.pop(context);
            //     logic.operateType = LoginType.phone;
            //     logic.registerNow();
            //   },
            //   child: Text('${StrRes.phoneNumber} ${StrRes.registerNow}'),
            // ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(StrRes.cancel),
          ),
        );
      },
    );
  }

  void _showForgetPasswordBottomSheet() {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                logic.operateType = LoginType.email;
                logic.forgetPassword();
              },
              child: Text(sprintf(StrRes.through, [StrRes.email])),
            ),
            // CupertinoActionSheetAction(
            //   onPressed: () {
            //     Navigator.pop(context);
            //     logic.operateType = LoginType.phone;
            //     logic.forgetPassword();
            //   },
            //   child: Text(sprintf(StrRes.through, [StrRes.phoneNumber])),
            // ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(StrRes.cancel),
          ),
        );
      },
    );
  }

  void _showContactServiceBottomSheet() {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            StrRes.forgetPassword,
            style: Styles.ts_8E9AB0_14sp,
          ),
          message: Text(
            StrRes.forgetPasswordContactService,
            style: Styles.ts_8E9AB0_12sp,
          ),
          actions: [
           
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(StrRes.cancel),
          ),
        );
      },
    );
  }

}
