import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/pages/login/login_logic.dart';
import 'package:openim/widgets/register_page_bg.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';
import 'account_register_logic.dart';

class AccountRegisterView extends StatelessWidget {
  final logic = Get.find<AccountRegisterLogic>();
  AccountRegisterView({super.key});
  @override
  Widget build(BuildContext context) => RegisterBgView(
        backText: TextView(
          data: StrRes.newUserRegister,
          style: Styles.ts_0C1C33_17sp_medium,
        ),
        child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                29.verticalSpace,

                // 昵称输入框 - 邮箱注册和账户注册都需要
                InputBox(
                  key: const Key('nickname_input'),
                  label: StrRes.nickname,
                  hintText: StrRes.plsEnterYourNickname,
                  controller: logic.nicknameCtrl,
                ),
                16.verticalSpace,

                // 邮箱注册时显示邮箱输入框
                if (logic.operateType.value == LoginType.email) ...[
                  InputBox.account(
                    key: const Key('email_input'),
                    label: StrRes.email,
                    hintText: StrRes.plsEnterEmail,
                    controller: logic.emailCtrl,
                    code: logic.areaCode.value,
                    formatHintText: null, // 邮箱输入框不显示格式文案
                  ),
                  16.verticalSpace,
                ],

                InputBox.account(
                  key: const Key('account_input'),
                  label: logic.operateType.value == LoginType.email
                      ? StrRes.account
                      : logic.operateType.value.name,
                  hintText: logic.operateType.value == LoginType.email
                      ? StrRes.plsEnterAccount
                      : logic.operateType.value.hintText,
                  controller: logic.accountCtrl,
                  code: logic.areaCode.value,
                  formatHintText: StrRes.phoneRegisterHint, // 账户输入框显示格式文案
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,  // 只允许输入数字
                    LengthLimitingTextInputFormatter(11),    // 限制11位
                  ],
                  keyBoardType: TextInputType.phone,         // 数字键盘
                ),
                16.verticalSpace,

                // 邮箱注册时显示验证码输入框
                if (logic.operateType.value == LoginType.email) ...[
                  InputBox.verificationCode(
                    key: const Key('email_verification_code_input'),
                    label: StrRes.verificationCode,
                    hintText: StrRes.plsEnterVerificationCode,
                    controller: logic.verificationCodeCtrl,
                    onSendVerificationCode: logic.getVerificationCode,
                  ),
                  16.verticalSpace,
                ],

                InputBox.password(
                  key: const Key('password_input'),
                  label: StrRes.password,
                  hintText: StrRes.plsEnterPassword,
                  controller: logic.pwdCtrl,
                  formatHintText: StrRes.loginPwdFormat6t,
                  inputFormatters: [IMUtils.getPasswordFormatter()],
                ),
                16.verticalSpace,
                InputBox.password(
                  key: const Key('confirm_password_input'),
                  label: StrRes.confirmPassword,
                  hintText: StrRes.plsConfirmPasswordAgain,
                  controller: logic.pwdAgainCtrl,
                  inputFormatters: [IMUtils.getPasswordFormatter()],
                ),
                16.verticalSpace,
                InputBox.imageVerificationCode(
                  key: const Key('image_verification_code_input'),
                  label: StrRes.verificationCode,
                  hintText: StrRes.plsEnterVerificationCode,
                  controller: logic.imageInvitationCodeCtrl,
                  onImageVerificationTap: () => logic.reGetCaptcha(),
                  verificationImage: logic.captchaImage.value == ''
                      ? null
                      : Image.memory(
                          _convertBase64ToImage(logic.captchaImage.value)),
                ),
                16.verticalSpace,
                InputBox(
                  key: const Key('invitation_code_input'),
                  label: StrRes.invitationCode,
                  hintText: sprintf(StrRes.plsEnterInvitationCode, ['']),
                  controller: logic.invitationCodeCtrl,
                ),
                29.verticalSpace,
                Obx(() => Button(
                      text: StrRes.registerNow,
                      enabled: logic.enabled.value,
                      onTap: logic.nextStep,
                    )),
                129.verticalSpace,
              ],
            )),
      );

  Uint8List _convertBase64ToImage(String base64String) {
    // 移除可能的 Base64 前缀（如 "data:image/png;base64,"）
    final String base64Data = base64String.split(',').last;
    return base64.decode(base64Data);
  }
}
