import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart' hide ApiService;

import '../../core/controller/im_controller.dart';
import '../../utils/log_util.dart';
import '../../routes/app_navigator.dart';
import '../conversation/conversation_logic.dart';
import '../../core/security_manager.dart';

enum LoginType {
  email(0),
  phone(2),
  account(1);

  final int rawValue;

  const LoginType(this.rawValue);

  static LoginType fromRawValue(int rawValue) {
    return values.firstWhere((e) => e.rawValue == rawValue);
  }
}

extension LoginTypeExt on LoginType {
  String get name {
    switch (this) {
      case LoginType.phone:
        return StrRes.phoneNumber;
      case LoginType.email:
        return StrRes.email;
      case LoginType.account:
        return StrRes.account;
    }
  }

  String get hintText {
    switch (this) {
      case LoginType.phone:
        return StrRes.plsEnterPhoneNumber;
      case LoginType.email:
        return StrRes.plsEnterEmail;
      case LoginType.account:
        return StrRes.plsEnterAccount;
    }
  }

  String get exclusiveName {
    switch (this) {
      case LoginType.phone:
        return StrRes.email;
      case LoginType.email:
        return StrRes.phoneNumber;
      case LoginType.account:
        return StrRes.account;
    }
  }
}

class LoginLogic extends GetxController with GetTickerProviderStateMixin {
  final imLogic = Get.find<IMController>();
  final phoneCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final verificationCodeCtrl = TextEditingController();
  final obscureText = true.obs;
  final enabled = false.obs;
  final areaCode = "+86".obs;
  final isPasswordLogin = true.obs;
  final loginType = LoginType.account.obs;
  final rememberPassword = false.obs;
  String? get email =>
      loginType.value == LoginType.email ? phoneCtrl.text.trim() : null;
  String? get phone =>
      loginType.value == LoginType.phone ? phoneCtrl.text.trim() : null;
  String? get account =>
      loginType.value == LoginType.account ? phoneCtrl.text.trim() : null;
  LoginType operateType = LoginType.account;

  FocusNode? accountFocus = FocusNode();
  FocusNode? pwdFocus = FocusNode();

  late TabController tabController;

    List<Widget> get tabs => LoginType.values
      .where((item) => item == LoginType.account)
      .map((e) => Tab(
            child: Text(
              e.name,
            ),
          ))
          .toList();

  _initData() async {
    var map = DataSp.getLoginAccount();
    if (map is Map) {
      String? phoneNumber = map["phoneNumber"];
      String? areaCode = map["areaCode"];

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        phoneCtrl.text = phoneNumber;
      }
      if (areaCode != null && areaCode.isNotEmpty) {
        this.areaCode.value = areaCode;
      }
    }

    // 初始化记住密码功能
    rememberPassword.value = DataSp.getRememberPassword();
    if (rememberPassword.value) {
      final rememberedAccount = DataSp.getRememberedAccount();
      final rememberedPassword = DataSp.getRememberedPassword();
      final rememberedLoginType = DataSp.getRememberedLoginType();
      
      if (rememberedAccount != null && rememberedAccount.isNotEmpty) {
        phoneCtrl.text = rememberedAccount;
      }
      if (rememberedPassword != null && rememberedPassword.isNotEmpty) {
        pwdCtrl.text = rememberedPassword;
      }
      if (rememberedLoginType != null) {
        final savedLoginType = LoginType.fromRawValue(rememberedLoginType);
        if (savedLoginType == LoginType.account) {
          loginType.value = savedLoginType;
          operateType = savedLoginType;
        }
      }
      
      // 自动填充后手动触发登录按钮状态检查
      _onChanged();
    }

    // 如果没有记住的登录类型，则使用默认的登录类型设置
    if (!rememberPassword.value || DataSp.getRememberedLoginType() == null) {
      //loginType.value = LoginType.fromRawValue(DataSp.getLoginType());
      //operateType = loginType.value;
      loginType.value = LoginType.account;  // 强制设置为账号登录
      operateType = LoginType.account;
      // 如果保存的是手机号登录，默认设置为邮箱登录
      if (loginType.value == LoginType.phone) {
        loginType.value = LoginType.email;
        operateType = loginType.value;
      }
    }
    
    // 将rawValue映射到实际的tab索引（排除手机号）
    final availableTypes = LoginType.values.where((item) => item == LoginType.account).toList();
    final tabIndex = availableTypes.indexOf(loginType.value);
    tabController.index = tabIndex;
  }

  @override
  void onClose() {
    phoneCtrl.dispose();
    pwdCtrl.dispose();
    verificationCodeCtrl.dispose();
    tabController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    tabController = TabController(length: 2, vsync: this);
    _initData();
    phoneCtrl.addListener(_onChanged);
    pwdCtrl.addListener(_onChanged);
    verificationCodeCtrl.addListener(_onChanged);
    super.onInit();
  }

  _onChanged() {
    if (loginType.value == LoginType.account) {
      enabled.value =
          phoneCtrl.text.trim().isNotEmpty && pwdCtrl.text.trim().isNotEmpty;
    } else {
      enabled.value = isPasswordLogin.value &&
              phoneCtrl.text.trim().isNotEmpty &&
              pwdCtrl.text.trim().isNotEmpty ||
          !isPasswordLogin.value &&
              phoneCtrl.text.trim().isNotEmpty &&
              verificationCodeCtrl.text.trim().isNotEmpty;
    }
  }

  login() {
    DataSp.putLoginType(loginType.value.rawValue);
    
    // 处理记住密码
    if (rememberPassword.value) {
      DataSp.putRememberPassword(true);
      DataSp.putRememberedAccount(phoneCtrl.text.trim());
      DataSp.putRememberedPassword(pwdCtrl.text.trim());
      DataSp.putRememberedLoginType(loginType.value.rawValue);
    } else {
      DataSp.clearRememberedCredentials();
    }
    
    LoadingView.singleton.wrap(asyncFunction: () async {
      var suc = await _login();
      if (suc) {
        final result = await ConversationLogic.getConversationFirstPage();

        Get.find<CacheController>().resetCache();
        Get.find<OrgController>().refreshOrg();
        Get.lazyPut<WalletController>(() => WalletController());
        AppNavigator.startMain(conversations: result);
      }
    });
  }

  Future<bool> _login() async {
    try {
      if (loginType.value == LoginType.phone) {
        if (phone?.isNotEmpty == true &&
            !IMUtils.isMobile(areaCode.value, phoneCtrl.text)) {
          IMViews.showToast(StrRes.plsEnterRightPhone);
          return false;
        }
      } else if (loginType.value == LoginType.email) {
        if (email?.isNotEmpty == true && !phoneCtrl.text.isEmail) {
          IMViews.showToast(StrRes.plsEnterRightEmail);
          return false;
        }
      } else if (loginType.value == LoginType.account) {
        if (this.account?.isNotEmpty != true) {
          IMViews.showToast(StrRes.plsEnterRightAccount);
          return false;
        }
      }
      final password = IMUtils.emptyStrToNull(pwdCtrl.text.trim());
      final code = IMUtils.emptyStrToNull(verificationCodeCtrl.text.trim());
      final data = await Apis.login(
        areaCode: areaCode.value,
        phoneNumber: phone,
        account: this.account,
        email: email,
        password: isPasswordLogin.value ? password : null,
        verificationCode: isPasswordLogin.value ? null : code,
      );
      final account = {
        "areaCode": areaCode.value,
        "phoneNumber": phoneCtrl.text,
        'loginType': loginType.value.rawValue,
      };
      await DataSp.putLoginCertificate(data);
      await DataSp.putLoginAccount(account);
      final allOrgRes = await Apis.getSelfAllOrg();
      if (allOrgRes.total == 0) {
        IMViews.showToast(StrRes.noOrg);
        return false;
      }
      DataSp.putOrgId(allOrgRes.data?.firstOrNull?.organizationId ?? "");
      final changeOrgData = await Apis.changeOrgUser(allOrgRes.data?.firstOrNull?.organizationId ?? "");
      data.imToken = changeOrgData.imToken!;
      data.userID = changeOrgData.imServerUserId!;
      await DataSp.putLoginCertificate(data);
      await imLogic.login(data.userID, data.imToken);

      // 登录成功后初始化安全服务
      final securityInitResult = await _initSecurityService();
      if (!securityInitResult) {
        await imLogic.logout();
        await DataSp.removeLoginCertificate();
        IMViews.showToast('安全服务初始化失败，请重试登录');
        return false;
      }

      PushController.login(
        data.userID,
        onTokenRefresh: (token) {
          OpenIM.iMManager.updateFcmToken(
              fcmToken: token,
              expireTime: DateTime.now()
                  .add(Duration(days: 90))
                  .millisecondsSinceEpoch);
        },
      );
      return true;
    } catch (e, s) {
      ILogger.d('login e: $e $s');
    }
    return false;
  }

  /// 初始化安全服务
  /// 返回初始化是否成功
  Future<bool> _initSecurityService() async {
    try {
      final securityManager = SecurityManager();

      // 如果已经初始化，直接返回成功
      if (securityManager.isInitialized) {
        return true;
      }

      // 尝试从本地恢复密钥
      final restored = await securityManager.checkAndRestoreKeys();
      if (restored) {
        return true;
      }

      // 如果恢复失败，尝试重新初始化
      final result = await securityManager.initAfterLogin();
      if (result) {
        return true;
      }

      return false;
    } catch (e) {
      LogUtil.e('LoginLogic', '安全服务初始化异常: $e');
      return false;
    }
  }

  void togglePasswordType() {
    isPasswordLogin.value = !isPasswordLogin.value;
  }

  void toggleLoginType() {
    if (loginType.value == LoginType.phone) {
      loginType.value = LoginType.email;
    } else {
      loginType.value = LoginType.phone;
    }

    phoneCtrl.text = '';
  }

  Future<bool> getVerificationCode() async {
    if (phone?.isNotEmpty == true &&
        !IMUtils.isMobile(areaCode.value, phoneCtrl.text)) {
      IMViews.showToast(StrRes.plsEnterRightPhone);
      return false;
    }

    if (email?.isNotEmpty == true && !phoneCtrl.text.isEmail) {
      IMViews.showToast(StrRes.plsEnterRightEmail);
      return false;
    }

    return sendVerificationCode();
  }

  Future<bool> sendVerificationCode() => LoadingView.singleton.wrap(
      asyncFunction: () => Apis.requestVerificationCode(
            areaCode: areaCode.value,
            phoneNumber: phone,
            email: email,
            usedFor: 3,
          ));

  void openCountryCodePicker() async {
    String? code = await IMViews.showCountryCodePicker();
    if (null != code) areaCode.value = code;
  }

  void registerNow() => AppNavigator.startAccountRegister();

  void forgetPassword() => AppNavigator.startForgetPassword();

  /// 切换记住密码状态
  void toggleRememberPassword() {
    rememberPassword.value = !rememberPassword.value;
    if (!rememberPassword.value) {
      // 如果取消记住密码，清除已保存的凭据
      DataSp.clearRememberedCredentials();
    }
  }

  /// 根据当前登录类型自动填充记住的账号密码
  void autoFillRememberedCredentials() {
    if (rememberPassword.value) {
      final rememberedAccount = DataSp.getRememberedAccount();
      final rememberedPassword = DataSp.getRememberedPassword();
      final rememberedLoginType = DataSp.getRememberedLoginType();
      
      // 只有在记住的登录类型与当前登录类型匹配时才自动填充
      if (rememberedLoginType != null && 
          rememberedLoginType == loginType.value.rawValue) {
        if (rememberedAccount != null && rememberedAccount.isNotEmpty) {
          phoneCtrl.text = rememberedAccount;
        }
        if (rememberedPassword != null && rememberedPassword.isNotEmpty) {
          pwdCtrl.text = rememberedPassword;
        }
        // 自动填充后手动触发登录按钮状态检查
        _onChanged();
      }
    }
  }
}
