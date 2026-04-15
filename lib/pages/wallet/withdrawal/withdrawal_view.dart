import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/utils/log_util.dart';
import 'package:openim_common/src/models/withdrawal_info.dart';
import 'package:openim_common/src/models/payment_method.dart';
import 'package:openim/routes/app_pages.dart';
import '../wallet_logic.dart';
import 'package:openim_common/openim_common.dart';

class WithdrawalPage extends StatefulWidget {
  final WithdrawalRule rule;
  final List<WithdrawalAccount> accounts;
  final VoidCallback? onSuccess;
  
  const WithdrawalPage({
    super.key,
    required this.rule,
    required this.accounts,
    this.onSuccess,
  });

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final logic = Get.find<WalletLogic>();

  WithdrawalAccount? _selectedAccount;
  double _actualAmount = 0; // 实际到账金额
  double _fee = 0; // 手续费

  // 币种选择相关
  int _selectedCurrencyIndex = 0; // 选中的币种索引

  // 提现结果
  Map<String, dynamic>? _withdrawalResult;

  @override
  void initState() {
    super.initState();
    // 设置默认账户 - 使用logic中的账户列表
    if (logic.withdrawalAccounts.isNotEmpty) {
      _selectedAccount = logic.withdrawalAccounts.firstWhere(
        (account) => account.isDefault == true,
        orElse: () => logic.withdrawalAccounts.first,
      );
    }

    // 默认选择余额最多的币种
    _selectDefaultCurrency();

    _amountController.addListener(_calculateAmount);
  }

  // 选择默认币种（余额最多的）
  void _selectDefaultCurrency() {
    final currencies = logic.walletController.balanceDetail.value?.currency ?? [];
    if (currencies.isEmpty) return;

    double maxBalance = 0;
    int maxIndex = 0;

    for (int i = 0; i < currencies.length; i++) {
      final balance = num.tryParse(currencies[i].balanceInfo?.availableBalance ?? '0') ?? 0;
      if (balance > maxBalance) {
        maxBalance = balance.toDouble();
        maxIndex = i;
      }
    }

    _selectedCurrencyIndex = maxIndex;
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }
  
  // 计算实际到账金额和手续费
  void _calculateAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0;

    // 将金额换算成人民币（手续费按人民币计算）
    final exchangeRate = num.tryParse(_selectedCurrency?.currencyInfo?.exchangeRate ?? '1')?.toDouble() ?? 1.0;
    final cnyRate = logic.rate.value;
    final amountInCNY = amount * exchangeRate * cnyRate;

    // 计算手续费（人民币）
    double feeCNY = 0;
    if (widget.rule.feeRate != null && widget.rule.feeRate! > 0) {
      feeCNY = amountInCNY * (widget.rule.feeRate! / 100);
    }
    if (widget.rule.feeFixed != null && widget.rule.feeFixed! > 0) {
      feeCNY += widget.rule.feeFixed!;
    }

    // 将手续费换算回原币种（用于计算实际到账）
    final feeInCurrency = feeCNY / (exchangeRate * cnyRate);

    setState(() {
      _fee = feeCNY; // 保存的是人民币手续费
      _actualAmount = amount - feeInCurrency; // 实际到账用原币种
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.withdrawal,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提现金额输入
            _buildAmountInput(),
            SizedBox(height: 20.h),
            
            // 提现规则
            _buildWithdrawalRules(),
            SizedBox(height: 20.h),

            // 提现方式选择
            Obx(() {
              if (logic.withdrawalAccounts.isNotEmpty) {
                return Column(
                  children: [
                    _buildAccountSelection(),
                    SizedBox(height: 20.h),
                  ],
                );
              }
              return SizedBox.shrink();
            }),

            // 提交按钮
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
  
  // 获取当前选中的币种信息
  dynamic get _selectedCurrency {
    final currencies = logic.walletController.balanceDetail.value?.currency ?? [];
    if (currencies.isEmpty || _selectedCurrencyIndex >= currencies.length) {
      return null;
    }
    return currencies[_selectedCurrencyIndex];
  }

  // 获取当前币种的余额
  double get _currentBalance {
    final currency = _selectedCurrency;
    if (currency == null) return 0;
    return num.tryParse(currency.balanceInfo?.availableBalance ?? '0')?.toDouble() ?? 0;
  }

  // 获取当前币种的符号
  String get _currencySymbol {
    final currency = _selectedCurrency;
    if (currency == null) return '\$';
    final name = currency.currencyInfo?.name ?? 'CNY';
    // 根据币种名称返回符号
    if (name == 'CNY') return '¥';
    return '\$';
  }

  // 获取当前币种名称
  String get _currencyName {
    final currency = _selectedCurrency;
    return currency?.currencyInfo?.name ?? 'CNY';
  }

  // 转换为人民币（用于参考显示）
  double _convertToCNY(double amount) {
    final currency = _selectedCurrency;
    if (currency == null) return amount * 7.0; // 默认汇率

    // 获取当前币种兑人民币汇率
    final exchangeRate = num.tryParse(currency.currencyInfo?.exchangeRate ?? '1')?.toDouble() ?? 1.0;
    final cnyRate = logic.rate.value; // 用户选择的货币汇率

    // 先转换为USD，再转换为CNY
    return amount * exchangeRate * cnyRate;
  }

  // 币种选择器
  Widget _buildCurrencySelector(List<dynamic> currencies) {
    return GestureDetector(
      onTap: () => _showCurrencyPicker(currencies),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Color(0xFFF0F2F6),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currencyName,
              style: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF0C1C33),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18.w,
              color: Color(0xFF0C1C33),
            ),
          ],
        ),
      ),
    );
  }

  // 显示币种选择器
  void _showCurrencyPicker(List<dynamic> currencies) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Color(0xFFE8EAEF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  '选择币种',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0C1C33),
                  ),
                ),
              ),
              Divider(height: 1, color: Color(0xFFE8EAEF)),
              ListView.builder(
                shrinkWrap: true,
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final balance = num.tryParse(currency.balanceInfo?.availableBalance ?? '0') ?? 0;
                  final name = currency.currencyInfo?.name ?? '';
                  final isSelected = index == _selectedCurrencyIndex;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCurrencyIndex = index;
                        _amountController.clear(); // 清空金额输入
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFFF0F8FF) : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0C1C33),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${StrRes.currentBalance} ${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Color(0xFF0089FF),
                              size: 20.w,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  // 金额输入区域
  Widget _buildAmountInput() {
    final currencies = logic.walletController.balanceDetail.value?.currency ?? [];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.withdrawalAmount,
            style: TextStyle(
              fontSize: 16.sp,
              color: Color(0xFF0C1C33),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 币种选择器（左侧）
              if (currencies.isNotEmpty) ...[
                _buildCurrencySelector(currencies),
                SizedBox(width: 8.w),
              ],
              // 如果没有币种，显示币种符号
              if (currencies.isEmpty)
                Text(
                  _currencySymbol,
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: Color(0xFF0C1C33),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (currencies.isEmpty)
                SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: StrRes.enterAmount,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 24.sp,
                      color: Color(0xFF999999),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: Color(0xFF0C1C33),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _amountController.text = _currentBalance.toStringAsFixed(2);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F2F6),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    StrRes.all,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Color(0xFF0089FF),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Divider(color: Color(0xFFE8EAEF), height: 20.h),

          // 余额显示
          Text(
            '${StrRes.currentBalance} $_currencySymbol${_currentBalance.toStringAsFixed(2)} $_currencyName',
            style: TextStyle(
              fontSize: 12.sp,
              color: Color(0xFF999999),
            ),
          ),
          
          // 手续费显示（人民币）
          if (_fee > 0) ...[
            SizedBox(height: 8.h),
            Text(
              '${StrRes.withdrawalFee} ¥${_fee.toStringAsFixed(2)} (${widget.rule.feeRate}%)',
              style: TextStyle(
                fontSize: 12.sp,
                color: Color(0xFF999999),
              ),
            ),
          ],

          // 实际到账金额
          if (_actualAmount > 0) ...[
            SizedBox(height: 8.h),
            Text(
              '${StrRes.actualArrival} $_currencySymbol${_actualAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Color(0xFF52C41A),
              ),
            ),
          ],

          // 人民币参考（如果不是人民币）
          if (_currencyName != 'CNY' && _actualAmount > 0) ...[
            SizedBox(height: 4.h),
            Text(
              '≈ ¥${_convertToCNY(_actualAmount).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11.sp,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 提现规则
  Widget _buildWithdrawalRules() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.withdrawalRules,
            style: TextStyle(
              fontSize: 16.sp,
              color: Color(0xFF0C1C33),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),

          // 规则列表
          if (widget.rule.minAmount != null)
            _buildRuleItem('1. ${widget.rule.minAmount!.toStringAsFixed(2)}${StrRes.minWithdrawal}'),
          if (widget.rule.maxAmount != null)
            _buildRuleItem('2. ${StrRes.singleTransaction}${widget.rule.maxAmount!.toStringAsFixed(2)}${StrRes.maxWithdrawal}'),
          _buildRuleItem('3. ${StrRes.withdrawalInstructions} 1-3 ${StrRes.businessDays}'),
        ],
      ),
    );
  }
  
  Widget _buildRuleItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF666666),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 账户选择
  Widget _buildAccountSelection() {
    return Obx(() => Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.withdrawTo,
            style: TextStyle(
              fontSize: 16.sp,
              color: Color(0xFF0C1C33),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),

          ...logic.withdrawalAccounts.map((account) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAccount = account;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFE8EAEF),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 图标
                    _buildAccountIcon(account.type),
                    SizedBox(width: 12.w),
                    
                    // 账户信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedAccountText(account), // 使用本地化方法
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Color(0xFF0C1C33),
                            ),
                          ),
                          if (account.accountName != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              '${StrRes.accountName}: ${account.accountName!}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // 单选按钮
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedAccount?.id == account.id 
                              ? Color(0xFF0089FF) 
                              : Color(0xFFD9D9D9),
                          width: 1.5,
                        ),
                      ),
                      child: _selectedAccount?.id == account.id
                          ? Center(
                              child: Container(
                                width: 10.w,
                                height: 10.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0089FF),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          
          // 添加新账户按钮
          GestureDetector(
            onTap: _addNewAccount,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 20.w,
                    color: Color(0xFF0089FF),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    StrRes.addAccount,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Color(0xFF0089FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildAccountIcon(String? type) {
    switch (type) {
      case 'bank':
        return Icon(
          Icons.account_balance,
          size: 24.w,
          color: Color(0xFF1890FF),
        );
      case 'alipay':
        return Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: Color(0xFF1890FF),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              StrRes.alipay.substring(0, 1), // 取第一个字
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'wechat':
        return Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: Color(0xFF07C160),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              StrRes.wechat.substring(0, 1), // 取第一个字
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      default:
        return Icon(
          Icons.account_balance_wallet,
          size: 24.w,
          color: Color(0xFF666666),
        );
    }
  }
  
  // 提交按钮
  Widget _buildSubmitButton() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final totalBalance = num.parse(logic.walletController.balanceDetail.value?.totalBalanceUsd ?? "0");
    final isAmountValid = amount >= (widget.rule.minAmount ?? 0) && amount <= totalBalance;
    final isAccountSelected = _selectedAccount != null;
    final isFormValid = isAmountValid && isAccountSelected;
    
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: isFormValid ? _submitWithdrawal : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFormValid ? Color(0xFF0089FF) : Color(0xFFCCCCCC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          StrRes.submitApplication,
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  
  // 添加新账户
  void _addNewAccount() async {
    // 跳转到收款方式管理页面
    await Get.toNamed(AppRoutes.paymentMethod);

    // 返回后刷新收款方式列表
    try {
      final methods = await Apis.getPaymentMethods();
      if (methods != null && methods.isNotEmpty) {
        // 转换为WithdrawalAccount格式
        final updatedAccounts = methods.map((pm) {
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

        // 更新父页面的收款方式列表
        logic.withdrawalAccounts.value = updatedAccounts;

        // 刷新当前页面状态
        setState(() {
          // 如果当前没有选中账户，设置默认账户
          if (_selectedAccount == null && updatedAccounts.isNotEmpty) {
            _selectedAccount = updatedAccounts.firstWhere(
              (account) => account.isDefault == true,
              orElse: () => updatedAccounts.first,
            );
          }
        });

        IMViews.showToast('刷新成功');
      }
    } catch (e) {
      LogUtil.e('WithdrawalPage', '刷新收款方式失败: $e');
      IMViews.showToast('刷新失败: $e');
    }
  }
  
  // 提交提现申请
  void _submitWithdrawal() async {
    final amount = double.parse(_amountController.text);

    // 验证金额
    if (amount < (widget.rule.minAmount ?? 0)) {
      IMViews.showToast('${StrRes.minWithdrawal}${widget.rule.minAmount}');
      return;
    }

    // 验证账户
    if (_selectedAccount == null) {
      IMViews.showToast(StrRes.selectAccount);
      return;
    }

    // 检查是否有未完成的提现
    try {
      final pendingCheck = await Apis.checkPendingWithdrawal();
      if (pendingCheck != null && pendingCheck['hasPending'] == true) {
        final pendingInfo = pendingCheck['pendingWithdrawal'];
        final orderNo = pendingInfo['orderNo'] ?? '';
        final statusText = pendingInfo['statusText'] ?? '';
        IMViews.showToast('您有一个提现申请正在处理中(订单号: $orderNo, 状态: $statusText),请等待完成后再申请新的提现');
        return;
      }
    } catch (e) {
      LogUtil.e('WithdrawalPage', '检查未完成提现失败: $e');
      // 检查失败不阻止继续流程
    }

    // 验证支付密码
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) {
      return;
    }

    // 提交申请
    final success = await _processWithdrawal(amount, password);
    if (success) {
      // 显示成功页面
      await _showSuccessPage();

      // 回调成功
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }

      Get.back();
    }
  }
  
  // 显示支付密码输入框
  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    
    return await Get.dialog<String>(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Container(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                StrRes.inputPaymentPassword,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: controller,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: StrRes.enter6DigitPassword,
                  border: OutlineInputBorder(),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  letterSpacing: 10.w,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(StrRes.cancel),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: controller.text),
                      child: Text(StrRes.confirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 处理提现申请
  Future<bool> _processWithdrawal(double amount, String password) async {
    try {
      // 获取当前选中的币种ID
      String? currencyId;
      final currency = _selectedCurrency;
      if (currency != null && currency.currencyInfo?.id != null) {
        currencyId = currency.currencyInfo!.id!;
      }

      // 调用真实的提现API
      final result = await Apis.submitWithdrawal(
        amount: amount,
        paymentMethodId: _selectedAccount!.id!,
        payPassword: password,
        currencyId: currencyId,  // 传递币种ID
      );

      if (result != null) {
        _withdrawalResult = result;  // 保存提现结果
        return true;
      } else {
        IMViews.showToast(StrRes.withdrawalFailed);
        return false;
      }
    } catch (e) {
      LogUtil.e('WithdrawalPage', '${StrRes.withdrawalFailed}: $e');
      IMViews.showToast('${StrRes.withdrawalFailed}: $e');
      return false;
    }
  }
  
  // 显示成功页面
  Future<void> _showSuccessPage() async {
    // 从API返回结果中获取数据
    final orderNo = _withdrawalResult?['orderNo'] ?? 'W${DateTime.now().millisecondsSinceEpoch}';
    final amount = _withdrawalResult?['amount'] ?? double.parse(_amountController.text);
    final fee = _withdrawalResult?['fee'] ?? _fee;
    final actualAmount = _withdrawalResult?['actualAmount'] ?? _actualAmount;

    // 获取币种符号
    final currencySymbol = _currencySymbol;

    // 计算人民币金额（用于显示）
    // 注意：手续费(fee)已经是人民币金额，不需要换算
    final exchangeRate = num.tryParse(_selectedCurrency?.currencyInfo?.exchangeRate ?? '1')?.toDouble() ?? 1.0;
    final cnyRate = logic.rate.value;
    final amountInCNY = amount * exchangeRate * cnyRate;
    final actualAmountInCNY = actualAmount * exchangeRate * cnyRate;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Container(
          padding: EdgeInsets.all(20.w),
          width: Get.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 60.w,
                color: Color(0xFF52C41A),
              ),
              SizedBox(height: 20.h),
              Text(
                StrRes.withdrawalSuccess,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                StrRes.processing,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 20.h),
              Divider(),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(StrRes.withdrawalAmount),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currencyName != 'CNY')
                        Text(
                          '¥${amountInCNY.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFF999999),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('手续费'),
                  Text(
                    '¥${fee.toStringAsFixed(2)}',
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('实际到账'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol${actualAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF52C41A),
                        ),
                      ),
                      if (_currencyName != 'CNY')
                        Text(
                          '¥${actualAmountInCNY.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFF999999),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(StrRes.orderNumber),
                  Text(orderNo),
                ],
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: Text(StrRes.confirm),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  String _getLocalizedAccountText(WithdrawalAccount account) {
    switch (account.type) {
      case 'bank':
        final bankName = account.bankName?.isNotEmpty == true 
            ? account.bankName! 
            : StrRes.bankCard;
        final last4Digits = account.accountNumber != null && account.accountNumber!.length >= 4 
            ? account.accountNumber!.substring(account.accountNumber!.length - 4)
            : '';
        return last4Digits.isNotEmpty ? '$bankName $last4Digits' : bankName;
      case 'alipay':
        return '${StrRes.alipay}(${account.alipayAccount ?? ''})';
      case 'wechat':
        return StrRes.wechat;
      default:
        return '';
    }
  }

  // 辅助方法：获取账户类型名称
  String? _getAccountTypeName(String? type) {
    switch (type) {
      case 'bank': return StrRes.bankCard;
      case 'alipay': return StrRes.alipay;
      case 'wechat': return StrRes.wechat;
      default: return null;
    }
  }
}