import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/login/login_logic.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import '../../../core/controller/im_controller.dart';
import '../../../routes/app_navigator.dart';

class SetPasswordLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final nicknameCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final pwdAgainCtrl = TextEditingController();
  final invitationCodeCtrl = TextEditingController();
  final enabled = false.obs;
  String? phoneNumber;
  String? email;
  late String areaCode;
  late int usedFor;
  late String verificationCode;
  String? invitationCode;

  @override
  void onClose() {
    nicknameCtrl.dispose();
    pwdCtrl.dispose();
    pwdAgainCtrl.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    phoneNumber = Get.arguments['phoneNumber'];
    email = Get.arguments['email'];
    areaCode = Get.arguments['areaCode'];
    usedFor = Get.arguments['usedFor'];
    verificationCode = Get.arguments['verificationCode'];
    invitationCode = Get.arguments['invitationCode'];
    nicknameCtrl.addListener(_onChanged);
    pwdCtrl.addListener(_onChanged);
    pwdAgainCtrl.addListener(_onChanged);
    super.onInit();
  }

  _onChanged() {
    enabled.value =
        nicknameCtrl.text.trim().isNotEmpty && pwdCtrl.text.trim().isNotEmpty && pwdAgainCtrl.text.trim().isNotEmpty;
  }

  bool _checkingInput() {
    if (nicknameCtrl.text.trim().isEmpty) {
      IMViews.showToast(StrRes.plsEnterYourNickname);
      return false;
    }
    if (!IMUtils.isValidPassword(pwdCtrl.text)) {
      IMViews.showToast(StrRes.wrongPasswordFormat);
      return false;
    } else if (pwdCtrl.text != pwdAgainCtrl.text) {
      IMViews.showToast(StrRes.twicePwdNoSame);
      return false;
    }
    if ( invitationCodeCtrl.text.trim().isEmpty) {
      IMViews.showToast(sprintf(StrRes.plsEnterInvitationCode, ['']));
      return false;
    }
    return true;
  }

  void nextStep() {
    if (_checkingInput()) {
      register();
    }
  }

  void register() async {
    final operateType = Get.find<LoginLogic>().operateType;
    await LoadingView.singleton.wrap(asyncFunction: () async {
      final data = await Apis.userRegister(
        nickname: nicknameCtrl.text.trim(),
        account: nicknameCtrl.text.trim(),
        areaCode: areaCode,
        phoneNumber: operateType == LoginType.phone ? phoneNumber : null,
        email: email,
        password: pwdCtrl.text,
        verificationCode: verificationCode,
        invitationCode: invitationCode,
        orgInvitationCode: invitationCodeCtrl.text.trim(),
      );
      if (null == IMUtils.emptyStrToNull(data.imToken) || null == IMUtils.emptyStrToNull(data.chatToken)) {
        AppNavigator.startLogin();
        return;
      }
      final account = {"areaCode": areaCode, "phoneNumber": phoneNumber, 'email': email};
      await DataSp.putLoginCertificate(LoginCertificate(
        userID: data.userId,
        imToken: data.imToken,
        chatToken: data.chatToken,
      ));
      await DataSp.putLoginAccount(account);
      DataSp.putLoginType(email != null ? 1 : 0);
      DataSp.putOrgId(data.organizationId);
      await imLogic.login(data.userId, data.imToken);
      PushController.login(data.userId);

      Get.find<CacheController>().resetCache();
      Get.find<OrgController>().refreshOrg();
      Get.lazyPut<WalletController>(() => WalletController());

      if (data.inviteUserId != null && data.inviteUserId!.isNotEmpty) {
        OpenIM.iMManager.friendshipManager.addFriend(userID: data.inviteUserId!);
      }
    });
    AppNavigator.startMain();
  }
}
