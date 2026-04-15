import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/login/login_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

class AccountRegisterLogic extends GetxController with GetTickerProviderStateMixin {
  final loginController = Get.find<LoginLogic>();
  late Rx<LoginType> operateType;

  late TabController tabController;
  final imLogic = Get.find<IMController>();

  final nicknameCtrl = TextEditingController();
  final accountCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // 专门的邮箱控制器
  final verificationCodeCtrl = TextEditingController(); // 邮箱验证码输入框
  final pwdCtrl = TextEditingController();
  final pwdAgainCtrl = TextEditingController();
  final invitationCodeCtrl = TextEditingController();
  final imageInvitationCodeCtrl = TextEditingController();

  final areaCode = "+86".obs;
  final enabled = false.obs;

  final captchaImage = ''.obs;
  final captchaExpiration = 0.obs;
  final captchaId = ''.obs;

  @override
  void onInit() {
    tabController = TabController(length: 2, vsync: this);
    operateType = loginController.operateType.obs;
    tabController.index = operateType.value == LoginType.email ? 1 : 0;

    nicknameCtrl.addListener(_onChanged);
    accountCtrl.addListener(_onChanged);
    emailCtrl.addListener(_onChanged);
    verificationCodeCtrl.addListener(_onChanged);
    pwdCtrl.addListener(_onChanged);
    pwdAgainCtrl.addListener(_onChanged);
    invitationCodeCtrl.addListener(_onChanged);
    imageInvitationCodeCtrl.addListener(_onChanged);
    tabController.addListener(_onTabChange);
    reGetCaptcha();
    super.onInit();
  }

  @override
  void onClose() {
    tabController.dispose();

    nicknameCtrl.dispose();
    accountCtrl.dispose();
    emailCtrl.dispose();
    verificationCodeCtrl.dispose();
    pwdCtrl.dispose();
    pwdAgainCtrl.dispose();
    invitationCodeCtrl.dispose();
    imageInvitationCodeCtrl.dispose();
    super.onClose();
  }
  _onChanged() {
    if (operateType.value == LoginType.email) {
      // 邮箱注册需要昵称、邮箱、账户、验证码
      enabled.value = nicknameCtrl.text.trim().isNotEmpty &&
          emailCtrl.text.trim().isNotEmpty &&
          accountCtrl.text.trim().isNotEmpty &&
          verificationCodeCtrl.text.trim().isNotEmpty &&
          pwdCtrl.text.trim().isNotEmpty &&
          pwdAgainCtrl.text.trim().isNotEmpty &&
          invitationCodeCtrl.text.trim().isNotEmpty;
    } else {
      // 账户注册需要昵称、账户、图片验证码
      enabled.value = nicknameCtrl.text.trim().isNotEmpty &&
          accountCtrl.text.trim().isNotEmpty &&
          pwdCtrl.text.trim().isNotEmpty &&
          pwdAgainCtrl.text.trim().isNotEmpty &&
          invitationCodeCtrl.text.trim().isNotEmpty &&
          imageInvitationCodeCtrl.text.trim().isNotEmpty;
    }
  }

  void _onTabChange() {
    operateType.value = tabController.index == 0 ? LoginType.account : LoginType.email;
  }

  reGetCaptcha() async {
    captchaImage.value = '';
    final captcha = await Apis.getCaptcha();
    captchaImage.value = captcha.captcha!;
    captchaExpiration.value = captcha.expiration!;
    captchaId.value = captcha.id!;
  }

  // 获取邮箱验证码
  Future<bool> getVerificationCode() async {
    if (operateType.value == LoginType.email) {
      if (!emailCtrl.text.isEmail) {
        IMViews.showToast(StrRes.plsEnterRightEmail);
        return false;
      }
    }

    return LoadingView.singleton.wrap(
      asyncFunction: () => Apis.requestVerificationCode(
        areaCode: areaCode.value,
        phoneNumber: null,
        email: operateType.value == LoginType.email ? emailCtrl.text.trim() : null,
        usedFor: 1,
        invitationCode: invitationCodeCtrl.text.trim(),
      ),
    );
  }

  /// 校验昵称格式：5-20位字符，只允许数字、字母、"-"、"_"
  bool _isValidAccount(String nickname) {
    if (nickname.length < 5 || nickname.length > 20) {
      return false;
    }
    // 只允许数字、字母、"-"、"_"
    final regex = RegExp(r'^[a-zA-Z0-9_-]+$');
    return regex.hasMatch(nickname);
  }
  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    
    // 1. 必须是11位
    if (phone.length != 11) return false;
    
    // 2. 必须是纯数字
    if (!RegExp(r'^\d+$').hasMatch(phone)) return false;
    
    // 3. 必须符合中国手机号格式：1开头，第二位是3-9
    final phoneRegExp = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegExp.hasMatch(phone);
  }
  bool _checkingInput() {
    if (nicknameCtrl.text.trim().isEmpty) {
      IMViews.showToast(StrRes.plsEnterYourNickname);
      return false;
    }
    
    if (operateType.value == LoginType.email) {
      // 邮箱注册验证
      if (emailCtrl.text.trim().isEmpty) {
        IMViews.showToast(StrRes.plsEnterRightEmail);
        return false;
      }
      if (!emailCtrl.text.isEmail) {
        IMViews.showToast(StrRes.plsEnterRightEmail);
        return false;
      }
      if (accountCtrl.text.trim().isEmpty) {
        IMViews.showToast(StrRes.plsEnterRightAccount);
        return false;
      }
      if (!_isValidPhone(accountCtrl.text.trim())) {
        IMViews.showToast(StrRes.plsEnterRightPhone);
        return false;
      }
      if (verificationCodeCtrl.text.trim().isEmpty) {
        IMViews.showToast(StrRes.plsEnterVerificationCode);
        return false;
      }
    } else {
      // 账户注册验证
      if (accountCtrl.text.trim().isEmpty) {
        IMViews.showToast(StrRes.plsEnterRightAccount);
        return false;
      }
      if (!_isValidPhone(accountCtrl.text.trim())) {
        IMViews.showToast(StrRes.plsEnterRightPhone);
        return false;
      }
    }
    
    if (!IMUtils.isValidPassword(pwdCtrl.text)) {
      IMViews.showToast(StrRes.wrongPasswordFormat);
      return false;
    } else if (pwdCtrl.text != pwdAgainCtrl.text) {
      IMViews.showToast(StrRes.twicePwdNoSame);
      return false;
    }
    if (invitationCodeCtrl.text.trim().isEmpty) {
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
    LoadingView.singleton.wrap(asyncFunction: () async {
      try {
        dynamic data;
        
        if (operateType.value == LoginType.email) {
          // 邮箱注册
          data = await Apis.userRegister(
            nickname: nicknameCtrl.text.trim(),
            account: accountCtrl.text.trim(),
            areaCode: areaCode.value,
            phoneNumber: null,
            email: emailCtrl.text.trim(),
            password: pwdCtrl.text.trim(),
            verificationCode: verificationCodeCtrl.text.trim(),
            invitationCode: invitationCodeCtrl.text.trim(),
            orgInvitationCode: invitationCodeCtrl.text.trim(),
          );
        } else {
          // 账户注册
          String mobileDeviceIdentifier = await IMUtils.getDeviceId();
          data = await Apis.userAcountRegister(
            nickname: nicknameCtrl.text.trim(),
            account: accountCtrl.text.trim(),
            password: pwdCtrl.text.trim(),
            orgInvitationCode: invitationCodeCtrl.text.trim(),
            captchaId: captchaId.value,
            captchaAnswer: imageInvitationCodeCtrl.text.trim(),
            deviceCode: mobileDeviceIdentifier,
          );
        }
        
        if (null == IMUtils.emptyStrToNull(data.imToken) ||
            null == IMUtils.emptyStrToNull(data.chatToken)) {
          AppNavigator.startLogin();
          return;
        }
        
        final accountInfo = {
          "areaCode": areaCode.value, 
          "phoneNumber": null, 
          'email': operateType.value == LoginType.email ? emailCtrl.text.trim() : null,
          'account': accountCtrl.text.trim(),
        };
        
        await DataSp.putLoginCertificate(LoginCertificate(
          userID: data.userId,
          imToken: data.imToken,
          chatToken: data.chatToken,
        ));
        await DataSp.putLoginAccount(accountInfo);
        DataSp.putLoginType(operateType.value == LoginType.email ? 0 : 1);
        DataSp.putOrgId(data.organizationId);
        await imLogic.login(data.userId, data.imToken);
        PushController.login(data.userId);

        Get.find<CacheController>().resetCache();
        Get.find<OrgController>().refreshOrg();
        Get.lazyPut<WalletController>(() => WalletController());

        if (data.inviteUserId != null && data.inviteUserId!.isNotEmpty) {
          OpenIM.iMManager.friendshipManager.addFriend(userID: data.inviteUserId!);
        }
        AppNavigator.startMain();
      } catch (e) {
        final t = e as (int, String?);
        final errCode = t.$1;
        if (errCode != 10091) {
          reGetCaptcha();
        } else {
          return Future.error(e);
        }
      }
    });
  }
}
