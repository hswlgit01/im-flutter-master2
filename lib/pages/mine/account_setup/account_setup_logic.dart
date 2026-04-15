import 'package:flutter/cupertino.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/mine/account_setup/widgets/set_password_dialog.dart';
import 'package:openim/utils/cache_clear_util.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim/utils/user_util.dart';
import 'package:openim_common/openim_common.dart' hide DataSp;
import '../../../routes/app_navigator.dart';
import '../../wallet/widgets/set_transaction_password_dialog.dart';
import '../../../core/data_sp.dart' as app_sp;
import '../../../core/controller/im_controller.dart';
import '../../../core/security_service.dart';
import '../../../core/security_manager.dart';
import '../../../core/api_service.dart';
import '../../../utils/log_util.dart';
import '../../../core/api_service.dart' as app_api;

class AccountSetupLogic extends GetxController {
  static const String TAG = "AccountSetupLogic";

  // IM控制器
  final _imController = Get.find<IMController>();
  final curLanguage = "".obs;
  final hasPaymentPassword = false.obs;
  final isBiometricEnabled = false.obs;

  // 安全服务
  final _securityService = SecurityService();
  final _securityManager = SecurityManager();
  final _apiService = app_api.ApiService();

  static const String _biometricKey = 'biometric_enabled';

  @override
  void onInit() {
    super.onInit();
    _queryMyFullInfo();
    checkPaymentPassword();
    _loadBiometricState();
  }

  @override
  void onReady() async {
    _updateLanguage();
    // 初始化安全服务
    await _initSecurityService();
    // 确保安全服务已初始化
    if (!_securityManager.isInitialized) {
      LogUtil.e(TAG, '安全服务初始化失败');
      return;
    }
    super.onReady();
  }

  void _queryMyFullInfo() async {
    final data = await LoadingView.singleton.wrap(
      asyncFunction: () => Apis.queryMyFullInfo(),
    );
    if (data is UserFullInfo) {
      final userInfo = UserFullInfo.fromJson(data.toJson());
      _imController.userInfo.update((val) {
        val?.allowAddFriend = userInfo.allowAddFriend;
        val?.allowBeep = userInfo.allowBeep;
        val?.allowVibration = userInfo.allowVibration;
      });
    }
  }

  void checkPaymentPassword() async {
    // TODO: 从后端检查是否设置过支付密码
    hasPaymentPassword.value = await app_sp.DataSp.getWalletStatus();
  }

  /// 初始化安全服务
  Future<void> _initSecurityService() async {
    try {
      // 检查是否已初始化
      if (!_securityManager.isInitialized) {
        // 尝试从本地恢复密钥
        final restored = await _securityManager.checkAndRestoreKeys();
        if (!restored) {
          // 如果恢复失败，尝试重新初始化
          await _securityManager.initAfterLogin();
        }
      }
    } catch (e) {
      LogUtil.e(TAG, '初始化安全服务异常: $e');
    }
  }

  /// 设置交易密码
  Future<void> setPaymentPassword() async {
    try {
      // 检查安全服务是否初始化
      if (!_securityManager.isInitialized) {
        IMViews.showToast('安全服务未初始化');
        return;
      }

      String? loginPassword;
      // 先验证登录密码
      final verified = await _securityService.verifyIdentity(
        passwordTitle: StrRes.walletVerifyLoginPassword,
        onFailure: (error) {
          IMViews.showToast(StrRes.walletVerifyFailed);
        },
        onPasswordInput: (password) {
          loginPassword = password;
        },
      );

      if (!verified) return;

      // 验证通过后，显示设置支付密码对话框
      final result = await Get.dialog(
        SetTransactionPasswordDialog(
          onConfirm: (password) async {
            try {
              // 构造密码数据
              final passwordData = {
                'new_pay_pwd': password,
                'login_pwd': IMUtils.generateMD5(loginPassword ?? ''),
              };

              // 使用AES加密密码数据
              final encryptedPassword =
                  await _securityManager.encryptJson(passwordData);

              // 调用更新密码接口
              final success = await LoadingView.singleton.wrap(
                asyncFunction: () =>
                    _apiService.walletPayPwdUpdate(encryptedPassword),
              );

              if (success) {
                IMViews.showToast('设置成功');
                return true;
              } else {
                IMViews.showToast('设置失败');
                return false;
              }
            } catch (e) {
              LogUtil.e(TAG, '设置交易密码异常: $e');
              IMViews.showToast('设置失败');
              return false;
            }
          },
        ),
      );

      if (result == true) {
        IMViews.showToast(hasPaymentPassword.value
            ? StrRes.walletModifyPasswordSuccess
            : StrRes.walletSetPasswordSuccess);
      }
    } catch (e) {
      LogUtil.e(TAG, '设置交易密码异常: $e');
      IMViews.showToast('设置失败');
    }
  }

  void blacklist() => AppNavigator.startBlacklist();

  /// 清空缓存（临时 + 应用缓存 + IM 本地数据目录 + 图片缓存），达到与安卓「清除数据」类似效果，可解决 WebSocket read limit exceeded
  Future<void> clearCache() async {
    LogUtil.d(TAG, '清空缓存入口被点击');
    final confirm = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: Text(StrRes.clearCache),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(StrRes.clearCacheConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Get.back(result: false),
            child: Text(StrRes.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Get.back(result: true),
            child: Text(StrRes.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) {
      LogUtil.d(TAG, '清空缓存已取消');
      return;
    }
    LogUtil.d(TAG, '清空缓存开始执行（含 IM 数据目录）');
    ClearCacheResult? result;
    await LoadingView.singleton.wrap(asyncFunction: () async {
      result = await CacheClearUtil.clearAppCache(includeImDataDir: true);
    });
    LogUtil.d(TAG, '清空缓存完成: ${result?.itemsCleared ?? 0} 项, ${result?.sizeText ?? ""}, imDataCleared=${result?.imDataCleared ?? false}');
    final String msg;
    if (result != null && result!.imDataCleared) {
      msg = result!.sizeText.isNotEmpty
          ? '${StrRes.clearCacheSuccessRestart}（约 ${result!.sizeText}）'
          : StrRes.clearCacheSuccessRestart;
    } else {
      msg = result != null && result!.sizeText.isNotEmpty
          ? '${StrRes.clearCacheSuccess}（约 ${result!.sizeText}）'
          : StrRes.clearCacheSuccess;
    }
    IMViews.showToast(msg);
  }

  void languageSetting() => AppNavigator.startLanguageSetup();

  void _updateLanguage() {
    var index = app_sp.DataSp.getLanguage() ?? 0;
    switch (index) {
      case 1:
        curLanguage.value = StrRes.chinese;
        break;
      case 2:
        curLanguage.value = StrRes.english;
        break;
      case 3:
        curLanguage.value = StrRes.traditionalChinese;
        break;
      case 0:
      default:
        curLanguage.value = StrRes.followSystem;
        break;
    }
  }

  void _loadBiometricState() {
    isBiometricEnabled.value = app_sp.DataSp.getBiometricEnabled() ?? false;
    // 更新安全服务的生物识别设置
    _securityService.setUseBiometric(isBiometricEnabled.value);
    ILogger.d('加载生物识别状态: ${isBiometricEnabled.value}');
  }

  void toggleBiometric(bool value) async {
    await app_sp.DataSp.setBiometricEnabled(value);
    isBiometricEnabled.value = value;
    // 更新安全服务的生物识别设置
    _securityService.setUseBiometric(value);
    ILogger.d('切换生物识别状态: $value');
  }

  changePassword() async {
    final result = await Get.dialog(SetPasswordDialog(
      onConfirm: (oldPassword, newPassword) async {
        return LoadingView.singleton.wrap(asyncFunction: () async {
          return Apis.changePassword(
              userID: OpenIM.iMManager.userID,
              currentPassword: oldPassword,
              newPassword: newPassword);
        });
      },
    ));
    if (result == true) {
      IMViews.showToast(StrRes.changePasswordSuccess);
      UserUtil.logout();
    }
  }
}
