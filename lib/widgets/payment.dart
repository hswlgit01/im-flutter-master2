import 'package:flutter/material.dart';

import 'number_keyboard.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:openim_common/openim_common.dart';
// import 'package:percent_indicator/linear_percent_indicator.dart';
// import 'package:sprintf/sprintf.dart';

class PaymentView extends StatefulWidget {
  final int paymentType; // 支付类型 默认0  0: 红包 1: 转账
  final int paymentVerifyType; // 支付验证方式 默认0 0: 密码 1: 指纹
  final int paymentChannel; // 支付渠道 默认0 0: 账户
  final int paymentAmount;

  final Function() onError;
  final Function() onConfirm; // 校验通过时
  final Function() onComplete; // 支付完成时

  const PaymentView({
    super.key,
    this.paymentType = 0,
    this.paymentChannel = 0,
    this.paymentVerifyType = 0,
    required this.paymentAmount,
    required this.onError,
    required this.onConfirm,
    required this.onComplete,
  });

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  String password = '';

  _handleKeyPress(String key) {
    String value =
        key == '⌫' && password != '' ? password = password.substring(0, password.length - 1) : password += '*';
    // 调用API
    setState(() {
      password = value;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 10);
  }

  Widget _buildKeyboard(BuildContext context) {
    return NumberKeyboard(onKeyPressed: _handleKeyPress);
  }
}
