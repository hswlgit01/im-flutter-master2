import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import '../account_register/account_register_logic.dart';
import 'login_logic.dart';

// dawn 2026-06-26 登录/注册页改版(设计稿)：同页 Tab 切换登陆/注册，头部"您好!欢迎来到心享"+心享 logo。
class LoginPage extends StatelessWidget {
  final logic = Get.find<LoginLogic>();
  AccountRegisterLogic get registerLogic => Get.find<AccountRegisterLogic>();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: TouchCloseSoftKeyboard(
        isGradientBg: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                64.verticalSpace,
                _buildHeader(),
                28.verticalSpace,
                _buildTabs(),
                16.verticalSpace,
                Obx(() => logic.authTab.value == 0
                    ? _buildLoginCard()
                    : _buildRegisterCard()),
                30.verticalSpace,
                // dawn 2026-07-04 登录页网络测试：一键测全部线路自动选最快，并保留手动"线路检测"入口。
                Center(
                  child: OutlinedButton.icon(
                    onPressed: logic.autoTestAndSelectFastestLine,
                    icon: Icon(Icons.speed, size: 18.w, color: Styles.c_0089FF),
                    label: Text('网络测试（自动选最快）',
                        style: TextStyle(
                            color: Styles.c_0089FF, fontSize: 14.sp)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(220.w, 40.h),
                      side: BorderSide(color: Styles.c_0089FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r)),
                    ),
                  ),
                ),
                8.verticalSpace,
                // 手动线路检测入口(逐条测速、手动选择切换)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: logic.openLineCheck,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Text('线路检测（手动选择）',
                          style: TextStyle(
                              color: Styles.c_8E9AB0, fontSize: 13.sp)),
                    ),
                  ),
                ),
                20.verticalSpace,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 头部：您好!欢迎来到心享 + 右上心享 logo
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('您好!',
                  style: TextStyle(
                      color: Styles.c_0089FF,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold)),
              6.verticalSpace,
              Text('欢迎来到心享',
                  style: TextStyle(
                      color: Styles.c_0089FF,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ImageRes.loginLogo.toImage
          ..width = 64.w
          ..height = 64.w,
      ],
    );
  }

  // 登陆 / 注册 Tab
  Widget _buildTabs() {
    Widget tab(String text, int index) {
      final active = logic.authTab.value == index;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.authTab.value = index,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                style: TextStyle(
                  color: active ? Styles.c_0C1C33 : Styles.c_8E9AB0,
                  fontSize: 18.sp,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                )),
            6.verticalSpace,
            Container(
              width: 24.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: active ? Styles.c_0089FF : Colors.transparent,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() => Row(
          children: [
            tab('登陆', 0),
            40.horizontalSpace,
            tab('注册', 1),
          ],
        ));
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: child,
    );
  }

  // 登陆表单卡片
  Widget _buildLoginCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputBox.account(
            label: StrRes.account,
            hintText: StrRes.plsEnterAccount,
            code: logic.areaCode.value,
            onAreaCode: null,
            controller: logic.phoneCtrl,
            focusNode: logic.accountFocus,
            keyBoardType: TextInputType.text,
          ),
          16.verticalSpace,
          InputBox.password(
            label: StrRes.password,
            hintText: StrRes.plsEnterPassword,
            controller: logic.pwdCtrl,
            focusNode: logic.pwdFocus,
          ),
          12.verticalSpace,
          Row(
            children: [
              Obx(() => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: logic.toggleRememberPassword,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16.w,
                          height: 16.w,
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
                              ? Icon(Icons.check, size: 12.w, color: Colors.white)
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
                ..onTap = logic.forgetPassword,
            ],
          ),
          28.verticalSpace,
          Obx(() => Button(
                text: StrRes.login,
                enabled: logic.enabled.value,
                onTap: logic.login,
              )),
          16.verticalSpace,
          Center(
            child: RichText(
              text: TextSpan(
                style: Styles.ts_8E9AB0_12sp,
                children: [
                  const TextSpan(text: '登陆及接受'),
                  TextSpan(
                    text: '用户协议及隐私授权',
                    style: Styles.ts_0089FF_12sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 注册表单卡片(复用 AccountRegisterLogic)
  Widget _buildRegisterCard() {
    final r = registerLogic;
    return _card(
      child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputBox(
                label: StrRes.nickname,
                hintText: StrRes.plsEnterYourNickname,
                controller: r.nicknameCtrl,
              ),
              16.verticalSpace,
              InputBox.account(
                label: StrRes.account,
                hintText: StrRes.phoneRegisterHint,
                controller: r.accountCtrl,
                code: r.areaCode.value,
                formatHintText: StrRes.phoneRegisterHint,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                keyBoardType: TextInputType.phone,
              ),
              16.verticalSpace,
              InputBox.password(
                label: StrRes.password,
                hintText: StrRes.loginPwdFormat6t,
                controller: r.pwdCtrl,
                inputFormatters: [IMUtils.getPasswordFormatter()],
              ),
              16.verticalSpace,
              InputBox.password(
                label: StrRes.confirmPassword,
                hintText: StrRes.plsConfirmPasswordAgain,
                controller: r.pwdAgainCtrl,
                inputFormatters: [IMUtils.getPasswordFormatter()],
              ),
              16.verticalSpace,
              InputBox.imageVerificationCode(
                label: StrRes.verificationCode,
                hintText: StrRes.plsEnterVerificationCode,
                controller: r.imageInvitationCodeCtrl,
                onImageVerificationTap: () => r.reGetCaptcha(),
                verificationImage: r.captchaImage.value == ''
                    ? null
                    : Image.memory(_convertBase64ToImage(r.captchaImage.value)),
              ),
              16.verticalSpace,
              InputBox(
                label: StrRes.invitationCode,
                hintText: sprintf(StrRes.plsEnterInvitationCode, ['']),
                controller: r.invitationCodeCtrl,
              ),
              28.verticalSpace,
              Obx(() => Button(
                    text: StrRes.registerNow,
                    enabled: r.enabled.value,
                    onTap: r.nextStep,
                  )),
            ],
          )),
    );
  }

  Uint8List _convertBase64ToImage(String base64String) {
    final String base64Data = base64String.split(',').last;
    return base64.decode(base64Data);
  }
}
