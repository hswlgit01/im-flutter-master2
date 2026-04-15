import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/security_manager.dart';
import 'package:openim/core/security_service.dart';
import 'package:openim/pages/wallet/widgets/set_transaction_password_dialog.dart';
import 'package:openim/routes/app_pages.dart';
import 'package:openim/utils/log_util.dart';
import 'package:openim_common/openim_common.dart';
import '../../core/api_service.dart' as app_api;
import '../../../core/data_sp.dart' as app_sp;

class WalletController extends GetxService {
  static WalletController get to => Get.find<WalletController>();
  final orgController = Get.find<OrgController>();

  static const String _TAG = "WalletService";

  final _securityService = SecurityService();
  final isWalletActivated = false.obs; // 钱包是否已激活
  var selectOrgId = DataSp.getOrgId().obs;
  final balanceDetail = Rxn<BalanceData>(); // 钱包余额详情

  final _apiService = app_api.ApiService();
  Timer? _balanceTimer; // 定时器
  static const Duration _updateInterval = Duration(seconds: 5);
  bool _compensationInitAttempted = false; // 标记是否已尝试过初始化补偿金

  OrgData get currentOrg {
    return orgController.orgList.firstWhere(
      (org) => org.organizationId == selectOrgId.value,
      orElse: () => OrgData(),
    );
  }

  @override
  void onInit() {
    super.onInit();
    // 初始化时自动使用当前组织ID (禁止用户切换组织)
    selectOrgId.value = orgController.currentOrgId.value;
    _initSecurityService();
    checkWalletStatus();
  }

  @override
  void onClose() {
    // Clean up any resources or listeners here
    _stopBalanceTimer();
    super.onClose();
  }

  /// 停止余额定时器
  /// 在页面不可见时应调用此方法
  void stopBalanceTimer() {
    LogUtil.i(_TAG, '钱包页面离开，停止余额定时器');
    _stopBalanceTimer();
  }

  /// 恢复余额定时器
  /// 在页面可见时应调用此方法
  void resumeBalanceTimer() {
    LogUtil.i(_TAG, '钱包页面进入，恢复余额定时器');
    if (isWalletActivated.value) {
      _startBalanceTimer();
    }
  }

  /// 重置补偿金初始化状态
  /// 用于在需要重新触发补偿金初始化时调用
  void resetCompensationInitState() {
    _compensationInitAttempted = false;
  }

  Future<void> reinitialize() async {
    // 停止当前的定时器
    _stopBalanceTimer();

    // 重置状态
    isWalletActivated.value = false;
    balanceDetail.value = null;
    // 自动使用当前组织ID (禁止用户切换组织)
    selectOrgId.value = orgController.currentOrgId.value;

    // 重新初始化
    await _initSecurityService();
    await checkWalletStatus();
  }

  /// 初始化安全服务
  Future<void> _initSecurityService() async {
    try {
      // 检查是否已初始化
      final securityManager = SecurityManager();
      if (!securityManager.isInitialized) {
        // 尝试从本地恢复密钥
        final restored = await securityManager.checkAndRestoreKeys();
        if (!restored) {
          // 如果恢复失败，尝试重新初始化
          final success = await securityManager.initAfterLogin();
          if (!success) {
            // 显示错误提示
            IMViews.showToast('初始化失败，请重新登录');
            return;
          }
        }
      }
    } catch (e) {
      LogUtil.e(_TAG, '安全服务初始化异常: $e');
      // 显示错误提示
      IMViews.showToast('初始化失败，请重新登录');
    }
  }

  /// 检查钱包状态
  Future<bool> checkWalletStatus() async {
    try {
      // 等待异步获取本地状态
      bool status = await app_sp.DataSp.getWalletStatus();

      // 如果本地状态不存在，则调用API检查钱包是否存在
      if (!status) {
        status = await _apiService.checkWalletExist();

        // 更新本地存储的钱包状态
        app_sp.DataSp.putWalletStatus(status);
      }

      isWalletActivated.value = status;

      if (status) {
        await _getWalletInfo();
        _startBalanceTimer();
      }
      return status;
    } catch (e) {
      LogUtil.e(_TAG, '检查钱包状态失败: $e');
      isWalletActivated.value = false;
      return false;
    }
  }

  /// 检查钱包是否已激活，如果未激活则提示用户开通钱包
  checkWalletetActivated(Function callBack, {String? tipHint}) {
    if (isWalletActivated.value) {
      callBack();
    } else {
      LoadingView.singleton.wrap(asyncFunction: () async {
        final state = await checkWalletStatus();
        if (!state) {
          Get.dialog(CustomDialog(title: tipHint ?? StrRes.toCreateWallet))
              .then((val) {
            if (val) {
              // 跳转到钱包开通页面
              Get.toNamed(AppRoutes.wallet);
            }
          });
          return;
        } else {
          callBack();
        }
      });
    }
  }

  /// 获取钱包信息
  Future<void> _getWalletInfo() async {
    try {
      final walletData =
          await _apiService.walletBalanceByOrg(selectOrgId.value);

      if (walletData != null) {
        // 调试信息
        LogUtil.i(_TAG, '钱包数据：${walletData.toJson()}');
        LogUtil.i(_TAG, '补偿金余额：${walletData.compensationBalance}');

        // 检查补偿金余额是否为0或空
        final compensationStr = walletData.compensationBalance ?? '0';
        final hasCompensation = compensationStr != '0' &&
                               compensationStr != '0.00' &&
                               compensationStr.isNotEmpty;

        if (!hasCompensation && isWalletActivated.value && !_compensationInitAttempted) {
          // 标记为已尝试初始化，防止重复触发
          _compensationInitAttempted = true;

          // 如果补偿金为0，可能是因为钱包是在补偿金系统启用前创建的
          // 或者异步初始化未完成，尝试通过API请求触发补偿金初始化
          LogUtil.i(_TAG, '检测到补偿金为0，首次尝试触发初始化');

          // 调用触发补偿金初始化的API
          final success = await _apiService.triggerCompensationInit();

          if (success) {
            LogUtil.i(_TAG, '补偿金初始化触发成功，等待后端处理');

            // 延迟10秒后重新获取钱包信息，以便查看补偿金是否已初始化（增加间隔时间）
            Future.delayed(Duration(seconds: 10), () async {
              LogUtil.i(_TAG, '延迟10秒后重新获取钱包信息，以确认补偿金是否已初始化');
              // 不要连环调用_getWalletInfo，而是直接通过API获取最新数据
              final updatedWalletData = await _apiService.walletBalanceByOrg(selectOrgId.value);
              if (updatedWalletData != null) {
                balanceDetail.value = updatedWalletData;
                final updatedCompensation = updatedWalletData.compensationBalance ?? '0';
                LogUtil.i(_TAG, '初始化后补偿金余额: $updatedCompensation');
              }
            });
          } else {
            LogUtil.e(_TAG, '补偿金初始化触发失败，不再重试');
          }
        }

        // 更新余额
        balanceDetail.value = walletData;
      } else {
        _handleWalletError('获取钱包信息失败: 返回数据为空');
      }
    } catch (e) {
      _handleWalletError('获取钱包信息异常: $e');
    }
  }

  /// 开始定时更新余额
  void _startBalanceTimer() {
    _stopBalanceTimer(); // 确保之前的定时器被取消
    _balanceTimer = Timer.periodic(_updateInterval, (_) => _updateBalance());
  }

  /// 处理钱包错误
  void _handleWalletError(String message) {
    _stopBalanceTimer(); // 发生错误时停止定时更新
  }

  /// 更新余额
  Future<void> _updateBalance() async {
    try {
      if (await OpenIM.iMManager.getLoginStatus() != 3) {
        Logger.print('用户未登录，跳过交易状态同步');
        return;
      }
    } on PlatformException catch (e) {
      if (e.code == '10006') return;
      rethrow;
    }
    if (!isWalletActivated.value) {
      _stopBalanceTimer();
      return;
    }
    await _getWalletInfo();
  }

  /// 停止定时更新余额
  void _stopBalanceTimer() {
    _balanceTimer?.cancel();
    _balanceTimer = null;
  }

  /// 开通钱包流程
  Future<void> activateWallet() async {
    try {
      // 用于存储API调用的完整结果
      Map<String, dynamic>? apiResult;

      final setPasswordResult = await Get.dialog(
        SetTransactionPasswordDialog(
          onConfirm: (password) async {
            // 创建一个适配器函数，将Map结果转换为布尔值
            final result = await LoadingView.singleton.wrap(
              asyncFunction: () => _handleSetPassword(password),
            );

            // 存储完整结果以便后续使用
            if (result is Map<String, dynamic>) {
              apiResult = result;
              // 只返回success布尔值给对话框
              return result['success'] == true;
            }
            return false; // 如果结果不是预期的Map，返回false
          },
        ),
      );

      // 检查密码设置结果
      if (setPasswordResult == true) {
        // 从API返回结果中获取真实的钱包开通说明文本
        String? rawNoticeText = apiResult?['noticeText'];
        final String noticeText = (rawNoticeText != null && rawNoticeText.toString().trim().isNotEmpty)
            ? rawNoticeText.toString().trim()
            : '';

        LogUtil.i(_TAG, '从API获取到的钱包开通说明文本: "$noticeText"');

        // 先设置钱包激活状态，获取初始钱包信息
        isWalletActivated.value = true;
        selectOrgId.value = DataSp.getOrgId();
        await _getWalletInfo();
        _startBalanceTimer();

        // 显示简单的成功提示
        IMViews.showToast(StrRes.walletActivateSuccess);

        // 异步延迟再次获取钱包信息，以确保捕获异步初始化的补偿金
        Future.delayed(Duration(seconds: 2), () async {
          LogUtil.i(_TAG, '延迟再次获取钱包信息，以确保获取到补偿金余额');
          await _getWalletInfo();
        });

        // 检查是否有补偿金说明文本需要显示
        if (noticeText.isNotEmpty) {
          // 显示补偿金说明文本对话框，不显示标题
          LogUtil.i(_TAG, '显示钱包开通说明文本对话框: "$noticeText"');
          await Get.dialog(
            CustomDialog(
              title: '', // 不显示标题
              content: noticeText,
              showLeft: false, // 只显示"确定"按钮
            ),
            barrierDismissible: false, // 防止用户点击外部关闭对话框
          );
        } else {
          // 没有说明文本，显示标准成功对话框
          LogUtil.i(_TAG, '显示标准钱包激活成功对话框');
          await Get.dialog(
            CustomDialog(
              title: StrRes.walletActivateSuccess,
              content: StrRes.walletActivateSuccessDesc,
              showLeft: false, // 只显示"确定"按钮
            ),
            barrierDismissible: false, // 防止用户点击外部关闭对话框
          );
        }
      } else {
        LogUtil.w(_TAG, '交易密码设置失败或用户取消');
      }
    } catch (e) {
      LogUtil.e(_TAG, '钱包激活流程异常: $e');
      IMViews.showToast(StrRes.walletActivateFailed);
    }
  }

  /// 处理设置密码
  Future<Map<String, dynamic>> _handleSetPassword(String password) async {
    try {
      // 检查安全服务是否已初始化
      final isInitialized = await _securityService.isRSAAvailable();
      if (!isInitialized) {
        LogUtil.e(_TAG, '安全服务未初始化，无法继续');
        return {'success': false, 'noticeText': ''};
      }

      // 构建密码数据
      final passwordData = {
        'pay_pwd': password,
      };

      // 使用AES加密JSON数据
      final encryptedPassword =
          await _securityService.encryptJson(passwordData);

      if (encryptedPassword == null) {
        LogUtil.e(_TAG, '密码加密失败');
        return {'success': false, 'noticeText': ''};
      }

      // 调用API创建钱包，获取完整响应
      final result = await _apiService.createWallet(encryptedPassword);

      // 记录完整的API响应，便于排查问题
      LogUtil.i(_TAG, '钱包创建API响应: $result');

      // 获取并记录通知文本
      final String noticeText = result['noticeText'] ?? '';
      LogUtil.i(_TAG, '从API响应中提取的通知文本: "$noticeText"');

      // 如果创建成功，更新本地钱包状态
      if (result['success'] == true) {
        await app_sp.DataSp.putWalletStatus(true);
      }

      // 返回完整结果，包含success状态和noticeText
      return {
        'success': result['success'] ?? false,
        'noticeText': noticeText,
      };
    } catch (e) {
      LogUtil.e(_TAG, '处理设置密码异常: $e');
      return {'success': false, 'noticeText': ''};
    }
  }

  /// 处理激活成功
  Future<void> _handleActivationSuccess() async {
    isWalletActivated.value = true;
    selectOrgId.value = DataSp.getOrgId();

    // 显示成功提示
    IMViews.showToast(StrRes.walletActivateSuccess);

    // 获取钱包信息
    await _getWalletInfo();

    // 开始余额定时更新
    _startBalanceTimer();

    // 异步延迟再次获取钱包信息，以确保捕获异步初始化的补偿金
    Future.delayed(Duration(seconds: 2), () async {
      LogUtil.i(_TAG, '延迟再次获取钱包信息，以确保获取到补偿金余额');
      await _getWalletInfo();
    });
  }
}
