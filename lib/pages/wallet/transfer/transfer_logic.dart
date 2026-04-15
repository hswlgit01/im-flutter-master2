import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/pages/wallet/wallet_view.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:sprintf/sprintf.dart';
import '../../../utils/log_util.dart';
import '../../../utils/logger.dart';
import '../../chat/chat_logic.dart';
import '../../../core/security_service.dart';
import '../../../core/api_service.dart' as core;

class TransferLogic extends GetxController {
  static const String TAG = "TransferLogic";

  final amountController = TextEditingController();
  final remarkController = TextEditingController();
  final amount = ''.obs;
  final remark = ''.obs;
  final isLoading = false.obs;
  final balanceData = Rxn<BalanceData>();
  late final decimalPlaces = 2.obs;

  late final ChatLogic chatLogic;
  late final String receiverID;
  late final String receiverName;
  final _securityService = SecurityService();
  final _apiService = core.ApiService();

  final selectWalletBalance = Rxn<Currency>();

  @override
  void onInit() {
    super.onInit();
    // 获取传递过来的参数
    final arguments = Get.arguments;
    receiverID = arguments['receiverID'];
    receiverName = arguments['receiverName'] ?? StrRes.theRecipient;
    chatLogic = arguments['chatLogic'];

    // 初始化转账说明
    remarkController.text = sprintf(StrRes.transferTo, [receiverName]);
    remark.value = sprintf(StrRes.transferTo, [receiverName]);

    _updateDecimalPlaces();
  }

  @override
  void onReady() {
    getWalletBalance();
    super.onReady();
  }

  @override
  void onClose() {
    amountController.dispose();
    remarkController.dispose();
    super.onClose();
  }

  // 监听钱包余额变化并更新小数位数和金额
  void _updateDecimalPlaces() {
    ever(selectWalletBalance, (wallet) {
      final newDecimalPlaces = wallet?.currencyInfo?.decimals ?? 2;
      
      // 处理amountController的值
      if (amountController.text.isNotEmpty) {
        final currentAmount = amountController.text;
        final dotIndex = currentAmount.indexOf('.');
        
        // 如果有小数部分且小数位数超过新的精度限制
        if (dotIndex != -1) {
          final decimalPart = currentAmount.substring(dotIndex + 1);
          if (decimalPart.length > newDecimalPlaces) {
            // 截取到指定精度
            final newAmount = double.parse(currentAmount).toStringAsFixed(newDecimalPlaces);
            amountController.text = newAmount;
            // 保持光标位置在最后
            amountController.selection = TextSelection.fromPosition(
              TextPosition(offset: amountController.text.length),
            );
          }
        }
      }
      
      decimalPlaces.value = newDecimalPlaces;
    });
  }

  getWalletBalance() {
    LoadingView.singleton.wrap(asyncFunction: () async {
      balanceData.value =
          await _apiService.walletBalanceByOrg(DataSp.getOrgId());
      selectWalletBalance.value = balanceData.value?.currency?.firstOrNull;
    });
  }

  onTapSelectCurrency() async {
    Currency? selectReslut = await Get.bottomSheet(
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
                child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: balanceData.value?.currency?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = balanceData.value!.currency![index];
                  return GestureDetector(
                    onTap: () {},
                    child: TokenItem(
                      tokenIconUrl: item.currencyInfo?.icon ?? '',
                      tokenAmount:
                          IMUtils.formatNumberWithCommas(item.balanceInfo?.availableBalance ?? '0.00'),
                      tokenName: item.currencyInfo?.name ?? '',
                      exchangeRateText:
                          '汇率: 1 ${item.currencyInfo?.name} = ${IMUtils.formatNumberWithCommas((item.currencyInfo?.exchangeRate ?? 0))} CNY',
                      tokenValue:
                          "${IMUtils.getCurrencySymbol("CNY")}${IMUtils.formatNumberWithCommas(num.parse(item.balanceInfo?.balanceToUsd ?? '0'))}",
                      onTap: () {
                        Get.back(result: item);
                      },
                    ),
                  );
                },
              ),
            )),
          ],
        ),
      ),
      isScrollControlled: true,    );
    if (selectReslut != null) {
      selectWalletBalance.value = selectReslut;
    }
  }

  Future<void> transfer() async {
    if (isLoading.value) return;

    if (amount.value.isEmpty) {
      IMViews.showToast(StrRes.transferAmountToast);
      return;
    }

    final amountValue = double.tryParse(amount.value);
    if (amountValue == null || amountValue <= 0) {
      IMViews.showToast(StrRes.transferAmountVaildToast);
      return;
    }

    // 最大转账金额检查
    if (amountValue > 10000) {
      IMViews.showToast(
          sprintf(StrRes.transferAmountLimitVaildToast, ["10000"]));
      return;
    }

    if (selectWalletBalance.value == null) {
      IMViews.showToast(sprintf(StrRes.notEntered, [StrRes.currency]));
      return;
    }

    if (amountValue > num.parse(selectWalletBalance.value?.balanceInfo?.availableBalance ?? '0')) {
      Get.snackbar(StrRes.reminder, sprintf(StrRes.balanceExceeded, ["${selectWalletBalance.value?.currencyInfo?.name}${selectWalletBalance.value?.balanceInfo?.availableBalance}"]));
      return;
    }

    try {
      // 显示加载中对话框
      isLoading.value = true;
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(StrRes.processing,
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final data = {
        "transaction_type": 0, // 转账类型：0-单聊转账
        "total_amount": amountValue.toString(), // 转账金额
        "total_count": 1, // 单聊转账固定为1
        "target_id": receiverID, // 接收方ID
        "greeting": remark.value.isNotEmpty
            ? remark.value
            : sprintf(StrRes.transferTo, [receiverName]), // 转账说明
        "currency_id": selectWalletBalance.value?.currencyInfo?.id,
      };

      // 使用安全服务验证和加密数据
      final encryptedResult = await _securityService.verifyAndEncrypt(
        data: data,
        biometricReason: StrRes.verifyIdentityTransfer,
        passwordTitle: StrRes.enterPaymentPassword,
        onFailure: () {
          // 关闭加载对话框
          Get.back();
          isLoading.value = false;
          IMViews.showToast(StrRes.verificationFailedMsg);
        },
      );

      if (encryptedResult == null) {
        // 关闭加载对话框
        Get.back();
        isLoading.value = false;
        return;
      }

      // 解析加密结果
      final resultMap = jsonDecode(encryptedResult);

      // 调用transactionCreate接口
      final response = await _apiService.transactionCreate(
        encryptedData: resultMap['encrypted_data'],
        needRsaVerify: resultMap['need_rsa_verify'],
      );

      // 关闭加载对话框
      Get.back();
      isLoading.value = false;

      if (response['success']) {
        // 获取交易ID
        final transactionId = response['transaction_id'];

        // 构建转账数据
        final transferData = {
          'customType': 10086,
          'data': {
            'msg_id': transactionId,
            'create_time': DateTime.now().millisecondsSinceEpoch,
            'creator': OpenIM.iMManager.userID,
            'room_id': chatLogic.conversationInfo.conversationID,
            'total_amount': amountValue,
            'code': 'IM_CHART_TRANSFER',
            'currency': selectWalletBalance.value?.currencyInfo?.name,
            'sender': OpenIM.iMManager.userID,
            'sender_nickname': OpenIM.iMManager.userInfo.nickname,
            'sender_face_url': OpenIM.iMManager.userInfo.faceURL,
            'belong_to': receiverID,
            'expire_time': DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch,
            'remark': remark.value,
            'status': 'pending',
            'extension': {
              'scene': 'FRIEND', // 标记为单聊
            },
          },
          'viewType': 10086,
        };

        // 发送转账消息
        chatLogic.sendCustomMsg(
          data: jsonEncode(transferData),
          extension: '',
          description: '[${StrRes.transfer}]',
        );

        Get.back();

        // 显示成功提示
        Get.snackbar(
          StrRes.transferSuccessful,
          StrRes.transferSent,
          backgroundColor: const Color(0xFF07C160),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        );
      } else {
        final errorMsg =
            response['message'] ?? StrRes.transferFailedAndTryAgain;

        // Get.snackbar(
        //   StrRes.transferFailed,
        //   errorMsg,
        //   backgroundColor: Colors.red,
        //   colorText: Colors.white,
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        // );
      }
    } catch (e) {
      // 关闭加载对话框
      if (Get.isDialogOpen == true) {
        Get.back();
      }
      isLoading.value = false;

      ILogger.d('转账过程中发生错误: $e');
      // Get.snackbar(
      //   StrRes.transferFailed,
      //   StrRes.transferFailedAndTryAgain,
      //   backgroundColor: Colors.red,
      //   colorText: Colors.white,
      //   snackPosition: SnackPosition.BOTTOM,
      //   margin: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      // );
    }
  }
}
