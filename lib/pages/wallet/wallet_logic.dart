import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import '../../../utils/log_util.dart';
import 'bill/bill_view.dart';
import '../../core/api_service.dart' as app_api;
import 'dart:async';
import 'dart:convert';
import 'package:openim_common/src/models/withdrawal_info.dart';
import 'package:openim_common/src/models/payment_method.dart';
import 'withdrawal/withdrawal_view.dart';
import 'withdrawal_records/withdrawal_records_view.dart';
import '../../core/security_manager.dart';

class WalletLogic extends GetxController {
  final walletController = Get.find<WalletController>();
  final imLogic = Get.find<IMController>();

  // 身份认证数据
  final Rx<IdentityVerifyInfo?> _identityInfo = Rx<IdentityVerifyInfo?>(null);

  // 获取身份信息
  IdentityVerifyInfo? get identityInfo {
    return _identityInfo.value;
  }

  static const String TAG = "WalletLogic";

  final balance = "0.00".obs; // 钱包余额

  final exchageRateInfoIsLoading = true.obs; // 汇率信息是否加载中
  ExchageRateInfo? exchageRateInfo;

  bool get isWalletActivated =>
      walletController.isWalletActivated.value; // 钱包是否已激活
  final transactions = <Map<String, dynamic>>[].obs;

  final _apiService = app_api.ApiService();

  final refreshController = RefreshController(initialRefresh: true);

  final currency = "CNY".obs; // 货币类型
  final rate = 1.0.obs; // 汇率
  final withdrawalRule = Rx<WithdrawalRule?>(null);
  final withdrawalAccounts = <WithdrawalAccount>[].obs;
  final selectedAccount = Rx<WithdrawalAccount?>(null);
  final canWithdraw = false.obs; // 是否可以提现

  String get totalBalance =>
      IMUtils.getCurrencySymbol(currency.value) +
      IMUtils.formatNumberWithCommas(num.parse(
              (walletController.balanceDetail.value?.totalBalanceUsd ?? "0")) *
          rate.value);

  @override
  void onInit() {
    super.onInit();

    // 初始化安全服务
    _initSecurityService();
    getExchageRate();
    walletController.checkWalletStatus();
    checkWithdrawalRule();
    getIdentityInfo();

    // 恢复余额定时器（页面初始化时）
    walletController.resumeBalanceTimer();
  }

  @override
  void onClose() {
    // 停止钱包余额定时器
    walletController.stopBalanceTimer();
    super.onClose();
  }

  // 添加页面生命周期管理钩子
  void onPageVisible() {
    // 当页面变为可见时，恢复余额定时器
    walletController.resumeBalanceTimer();
  }

  void onPageInvisible() {
    // 当页面不可见时，停止余额定时器
    walletController.stopBalanceTimer();
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
      LogUtil.e(TAG, '安全服务初始化异常: $e');
      // 显示错误提示
      IMViews.showToast('初始化失败，请重新登录');
    }
  }

  /// 获取身份认证信息
  Future<void> getIdentityInfo() async {
    try {
      final info = await Apis.getIdentityInfo();
      _identityInfo.value = info;
      LogUtil.d(TAG, '获取身份认证信息成功: status=${info?.status}');
    } catch (e) {
      LogUtil.e(TAG, '获取身份认证信息失败: $e');
      _identityInfo.value = IdentityVerifyInfo(status: 0);
    }
  }

  void recharge() {
    IMViews.showToast(StrRes.walletRechargeDeveloping);
    return;
    final controller = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text(StrRes.walletRecharge),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: StrRes.enterTopUpAmount,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(StrRes.cancel),
          ),
          TextButton(
            onPressed: () async {
              final amount = controller.text;
              if (amount.isEmpty) {
                IMViews.showToast(StrRes.enterTopUpAmount);
                return;
              }
              Get.back();
              await _handleRecharge(amount);
            },
            child: Text(StrRes.confirm),
          ),
        ],
      ),
    );
  }

  /// 处理充值请求
  Future<void> _handleRecharge(String amount) async {
    try {
      final success = await _apiService.walletBalanceRechargeTest(amount);

      if (success) {
        IMViews.showToast(StrRes.topUpSuccessful);
        walletController.checkWalletStatus(); // 刷新余额
      } else {
        IMViews.showToast(StrRes.topUpFailed);
      }
    } catch (e) {
      LogUtil.e(TAG, '充值请求异常: $e');
      IMViews.showToast(StrRes.topUpFailed);
    }
  }

  void viewBill(Currency currency) {
    Get.to(() => BillPage(), arguments: {
      'currentyId': currency.currencyInfo?.id,
    });
  }

  /// 处理付款
  Future<bool> _handlePayment(String amount, String paymentInfo) async {
    try {
      // 获取安全管理器
      final securityManager = SecurityManager();
      if (!securityManager.isInitialized) {
        return false;
      }

      // 准备支付数据
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final paymentData = {
        'amount': amount,
        'info': paymentInfo,
        'timestamp': timestamp,
      };

      // 将数据转为JSON字符串
      final paymentDataJson = jsonEncode(paymentData);

      // 使用RSA私钥签名
      final signature = await securityManager.signData(paymentDataJson);

      // 使用AES加密数据
      final encryptedData = await securityManager.encryptData(paymentDataJson);

      // 准备API请求数据
      final Map<String, String> requestData = {
        'data': encryptedData,
        'signature': signature,
        'timestamp': timestamp,
      };

      // 调用支付API
      final result = await _apiService.processPayment(requestData);
      return result;
    } catch (e) {
      LogUtil.e(TAG, '处理支付失败: $e');
      return false;
    }
  }

  void onRefresh() async {
    walletController.checkWalletStatus();
    refreshController.refreshCompleted();
  }

  getExchageRate() async {
    exchageRateInfoIsLoading.value = true;
    exchageRateInfo = await _apiService.getExchageRate();
    exchageRateInfoIsLoading.value = false;
  }

  selectCurrency() async {
    if (exchageRateInfo != null) {
      final rates = (exchageRateInfo!.rates?.rates ?? {});
      final currencyList =
          rates.keys.toList().where((item) => item != "BTC").toList();
      // 弹出选择框
      final selectReslut = await Get.bottomSheet(
        Container(
          constraints: BoxConstraints(
            maxHeight: Get.height * 0.7, // 最大高度为屏幕高度的70%
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Styles.c_E8EAEF),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      StrRes.selectCurrency,
                      style: Styles.ts_0C1C33_17sp_medium,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currencyList.length,
                  itemBuilder: (context, index) {
                    final type = currencyList[index];
                    return GestureDetector(
                      onTap: () {
                        Get.back(result: {
                          'currency': type,
                          'rate': rates[type],
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 16.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Styles.c_E8EAEF),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              type,
                              style: Styles.ts_0C1C33_14sp,
                            ),
                            if (type == currency.value)
                              Icon(
                                Icons.check,
                                color: Colors.blue,
                                size: 20.w,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        isScrollControlled: true,
      );
      currency.value = selectReslut['currency'];
      rate.value = selectReslut['rate'];
    }
  }

  selectOrg() async {
    String? orgId = await Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.7, // 最大高度为屏幕高度的70%
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Styles.c_E8EAEF),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    StrRes.selectOrg,
                    style: Styles.ts_0C1C33_17sp_medium,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: walletController.orgController.orgList.length,
                itemBuilder: (context, index) {
                  final org = walletController.orgController.orgList[index];
                  return GestureDetector(
                    onTap: () {
                      Get.back(result: org.organizationId);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 16.h, horizontal: 16.w),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Styles.c_E8EAEF),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            org.organization?.name ?? StrRes.unknownOrg,
                            style: Styles.ts_0C1C33_14sp,
                          ),
                          if (org.organizationId ==
                              walletController.selectOrgId.value)
                            Icon(
                              Icons.check,
                              color: Colors.blue,
                              size: 20.w,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    if (orgId != null) {
      walletController.selectOrgId.value = orgId;
      walletController.checkWalletStatus();
    }
  }

  // 检查提现规则
  Future<void> checkWithdrawalRule() async {
    try {
      // 调用真实API获取提现规则
      final rule = await Apis.getWithdrawalRule();
      withdrawalRule.value = rule;

      // 检查是否满足提现条件
      await _checkWithdrawalConditions(withdrawalRule.value);
    } catch (e) {
      LogUtil.e(TAG, '获取提现规则失败: $e');
      // 如果获取失败,设置为null,表示提现不可用
      withdrawalRule.value = null;
      canWithdraw.value = false;
    }
  }

// 已删除模拟数据方法,现在使用真实API

  // 检查提现条件
  Future<void> _checkWithdrawalConditions(WithdrawalRule? rule) async {
    if (rule == null) {
      canWithdraw.value = false;
      return;
    }

    // 检查余额
    final balance =
        num.parse(walletController.balanceDetail.value?.totalBalanceUsd ?? "0");
    if (balance < (rule.minAmount ?? 0)) {
      canWithdraw.value = false;
      return;
    }

    // 检查实名认证
    if (rule.needRealName == true) {
      // 从身份认证获取状态
      if (identityInfo?.status != 2) {
        // 2=已认证
        canWithdraw.value = false;
        return;
      }
    }

    // 检查绑定账户
    if (rule.needBindAccount == true) {
      // 获取真实的收款方式
      try {
        final methods = await Apis.getPaymentMethods();
        if (methods != null && methods.isNotEmpty) {
          withdrawalAccounts.value = methods.map((pm) {
            return WithdrawalAccount(
              id: pm.id,
              type:
                  pm.type == PaymentMethodType.bankCard ? 'bank' : (pm.type == PaymentMethodType.wechat ? 'wechat' : 'alipay'),
              accountName: pm.accountName,
              accountNumber: pm.cardNumber,
              bankName: pm.bankName,
              bankBranch: pm.branchName,
              alipayAccount: pm.type == PaymentMethodType.alipay ? pm.accountName : null,
              isDefault: pm.isDefault,
            );
          }).toList();
        } else {
          withdrawalAccounts.value = [];
        }
      } catch (e) {
        LogUtil.e(TAG, '获取收款方式失败: $e');
        withdrawalAccounts.value = [];
      }

      if (withdrawalAccounts.isEmpty) {
        canWithdraw.value = false;
        return;
      }
    }

    canWithdraw.value = true;
  }

// 提现方法
  void withdraw() async {
    // 刷新身份认证状态，确保获取最新数据
    await getIdentityInfo();

    // 获取最新的提现规则
    await checkWithdrawalRule();

    // 检查是否有未处理的提现申请
    try {
      final pendingResult = await Apis.checkPendingWithdrawal();
      if (pendingResult != null && pendingResult['hasPending'] == true) {
        final pending = pendingResult['pendingWithdrawal'];
        if (pending != null) {
          final currencySymbol = pending['currencySymbol'] ?? '\$';
          // 安全地转换 amount,支持 int 和 double
          final amountValue = pending['amount'];
          final amount = (amountValue is int) ? amountValue.toDouble() : (amountValue as double? ?? 0.0);
          final statusText = pending['statusText'] ?? '处理中';
          final orderNo = pending['orderNo'] ?? '';

          _showPendingWithdrawalDialog(
            orderNo: orderNo,
            currencySymbol: currencySymbol,
            amount: amount,
            statusText: statusText,
          );
          return; // 阻止进入提现页面
        }
      }
    } catch (e) {
      LogUtil.e(TAG, '检查未处理提现失败: $e');
      // 如果检查失败，为了安全起见，提示用户稍后再试
      IMViews.showToast('检查提现状态失败，请稍后再试');
      return; // 阻止进入提现页面
    }

    // 获取收款方式列表
    try {
      final methods = await Apis.getPaymentMethods();
      if (methods != null && methods.isNotEmpty) {
        // 将PaymentMethod转换为WithdrawalAccount(临时兼容)
        // TODO: 重构WithdrawalPage直接使用PaymentMethod
        withdrawalAccounts.value = methods.map((pm) {
          return WithdrawalAccount(
            id: pm.id,
            type: pm.type == PaymentMethodType.bankCard ? 'bank' : (pm.type == PaymentMethodType.wechat ? 'wechat' : 'alipay'),
            accountName: pm.accountName,
            accountNumber: pm.cardNumber,
            bankName: pm.bankName,
            bankBranch: pm.branchName,
            alipayAccount: pm.type == PaymentMethodType.alipay ? pm.accountName : null,
            isDefault: pm.isDefault,
          );
        }).toList();
      } else {
        withdrawalAccounts.value = [];
      }
    } catch (e) {
      LogUtil.e(TAG, '获取收款方式失败: $e');
      withdrawalAccounts.value = [];
    }

    // 检查条件
    await _checkWithdrawalConditions(withdrawalRule.value);

    if (!canWithdraw.value) {
      _showWithdrawalError();
      return;
    }

    // 跳转到提现页面
    Get.to(
      () => WithdrawalPage(
        rule: withdrawalRule.value!,
        accounts: withdrawalAccounts,
        onSuccess: _onWithdrawalSuccess,
      ),
    );
  }

// 显示提现错误提示
  void _showWithdrawalError() {
    final rule = withdrawalRule.value;
    if (rule == null) {
      IMViews.showToast('暂不可提现');
      return;
    }

    final balance =
        num.parse(walletController.balanceDetail.value?.totalBalanceUsd ?? "0");

    if (balance < (rule.minAmount ?? 0)) {
      IMViews.showToast('余额不足${rule.minAmount}元，无法提现');
      return;
    }

    if (rule.needRealName == true && identityInfo?.status != 2) {
      IMViews.showToast('请先完成实名认证');
      return;
    }

    if (rule.needBindAccount == true && withdrawalAccounts.isEmpty) {
      IMViews.showToast('请先绑定收款账户');
      return;
    }

    IMViews.showToast('暂不可提现');
  }

  // 显示未处理提现提示对话框
  void _showPendingWithdrawalDialog({
    required String orderNo,
    required String currencySymbol,
    required double amount,
    required String statusText,
  }) {
    Get.dialog(
      AlertDialog(
        title: const Text('提示'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您有一笔提现申请正在处理中，暂时无法提交新的提现申请。'),
            const SizedBox(height: 16),
            Text('订单号：$orderNo'),
            Text('金额：$currencySymbol${amount.toStringAsFixed(2)}'),
            Text('状态：$statusText'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  // 提现成功回调
  void _onWithdrawalSuccess() {
    // 刷新余额
    walletController.checkWalletStatus();
    // 可以刷新交易记录等
  }

  // 跳转到提现记录页面
  void viewWithdrawalRecords() {
    Get.to(() => WithdrawalRecordsPage());
  }
}
