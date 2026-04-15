import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import '../../widgets/number_keyboard.dart';

// 安全加密
abstract class PaymentSecurity {
  generateToken();
  String encrypt(String text);
  String decrypt(String text);
  Future<bool> verify(String text, String signature);
}

// 支付渠道 虚拟币 人民币
// abstract class PaymentGateway {
//
// }

// 生物验证 | 密码验证
// abstract class PaymentVerify {
abstract class PaymentVerify {
  final LocalAuthentication auth = LocalAuthentication();
  final IPaymentController context;

  Future<bool> authenticate();
  Future<bool> canCheckBiometrics();
  Future<bool> verify();

  PaymentVerify(this.context);
}

// 支付UI控制器
abstract class PaymentUIController {
  final IPaymentController context;

  void onKeyPressed(String value);
  void hide();
  Future<void> show(BuildContext context);

  PaymentUIController(this.context);
}

// 支付错误熔断
abstract class PaymentError {
  int failureCount = 0; // 失败次数
  int max = 3; // 最大失败次数
  bool retry = false; // 自动重试一次 是否重试过
  DateTime failureTime = DateTime.now(); // 开始熔断时间

  void onVerifyError();
  void onRequestError();
  Future<void> requestRetry();

  final IPaymentController context;
  PaymentError(this.context);
}

class IPaymentError implements PaymentError {
  @override
  int failureCount = 0; // 失败次数 校验失败次数也算作支付失败
  @override
  int max = 5; // 最大失败次数
  @override
  bool retry = false; // 自动重试一次 是否重试过

  @override
  DateTime failureTime = DateTime.now();

  @override
  final IPaymentController context;
  IPaymentError(this.context);

  @override
  void onVerifyError() {
    failureCount++;
    context.onError!('生物验证失败');

    // 超过最大次数 开始熔断
    if (failureCount >= max) {
      failureTime = DateTime.now();
    }
  }

  @override
  void onRequestError() async {
    if (!retry && failureCount < max) {
      failureCount++;
      retry = true;
      context.onError!('支付失败');
      return await requestRetry();
    }

    // 超过最大次数 开始熔断
    failureTime = DateTime.now();
  }

  @override
  Future<void> requestRetry() async {
    await context.execute();
  }
}

class IPaymentVerify implements PaymentVerify {
  @override
  final IPaymentController context;
  IPaymentVerify(this.context);

  @override
  LocalAuthentication auth = LocalAuthentication();

  @override
  Future<bool> authenticate() async {
    bool success = await auth.authenticate(
      localizedReason: '请验证以完成支付',
    );

    if (!success) {
      context.error.onVerifyError();
      context.onError!('生物验证失败');
    }

    return success;
  }

  @override
  Future<bool> canCheckBiometrics() async {
    return await auth.canCheckBiometrics;
  }

  @override
  Future<bool> verify() async {
    // todo context.password 校验
    bool success = await auth.authenticate(
      localizedReason: '请验证以完成支付',
    );

    if (!success) {
      context.error.onVerifyError();
      context.onError!('密码验证失败');
    }

    return false;
  }
}

class IPaymentUIController implements PaymentUIController {
  @override
  final IPaymentController context;
  IPaymentUIController(this.context);

  @override
  onKeyPressed(String value) {
    context.password = value;
    if (context.password.length == context.passwordNumber) {
      context.execute();
    }
  }

  @override
  show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      builder: (ctx) => NumberKeyboard(onKeyPressed: onKeyPressed),
    );
  }

  @override
  hide() {
    return Get.back();
  }
}

abstract class IPaymentController {
  int passwordNumber = 6;
  String password = '';
  String token = ''; // 支付时的动态token

  final double amount = 0.0;
  final String channel = '';

  final Map<String, dynamic> user = {};
  final Map<String, dynamic> config = {};

  late final PaymentSecurity security; // 支付安全
  // late final PaymentGateway paymentGateway;  // 支付渠道
  late final IPaymentVerify verify; // 验证
  late final PaymentError error; // 错误熔断
  late final PaymentUIController uiController; // UI控制器

  final void Function()? onStart;
  final void Function(String msg)? onError;
  final void Function()? onComplete;

  IPaymentController({
    this.onStart,
    this.onError,
    this.onComplete,
  }) {
    error = IPaymentError(this);
    verify = IPaymentVerify(this);
    uiController = IPaymentUIController(this);
  }

  void setChannel(); // 设置支付渠道
  void setAmount(); // 设置支付金额

  Future<void> execute(); // 执行支付 校验密码 发送支付请求
}
// 支付流程
// 页面发起钱包 调起UI 选择渠道 选择验证方式 发送支付请求  支付失败  支付成功
