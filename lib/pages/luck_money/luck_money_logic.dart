import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/pages/wallet/wallet_view.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import '../../routes/app_navigator.dart';
import '../../utils/logger.dart';
import '../chat/chat_logic.dart';
import '../chat/widget/chat_luck_money_item_view.dart';
import '../../core/security_service.dart';
import '../../core/api_service.dart' as core;

class LuckMoneyProps {
  final GroupInfo? groupInfo;
  final ConversationInfo conversationInfo;

  const LuckMoneyProps(this.groupInfo, this.conversationInfo);
}

enum LuckyMoneyType {
  // 红包类型
  Special('SPECIAL'), // 专属    SPECIAL
  Normal('NORMAL'), // 普通    NORMAL
  Random('RANDOM'), // 拼手气  RANDOM
  Password('PASSWORD'); // 口令红包 PASSWORD

  final String value;
  const LuckyMoneyType(this.value);
}

class LuckMoneyLogic extends GetxController {
  final chartLogic = Get.find<ChatLogic>(tag: GetTags.chat);
  final _apiService = core.ApiService();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  late final decimalPlaces = 2.obs;
  final selectGroupMember = Rxn<GroupMembersInfo>();


  // 拼手气红包放第一个，群聊下为默认选项
  final List<Map<String, String>> _luckMoneyTypes = [
    {
      'label': StrRes.randomAmount,
      'value': LuckyMoneyType.Random.value,
    },
    {
      'label': StrRes.identicalAmount,
      'value': LuckyMoneyType.Normal.value,
    },
    {
      'label': StrRes.exclusive,
      'value': LuckyMoneyType.Special.value,
    },
    {
      'label': StrRes.redPacketPassword,
      'value': LuckyMoneyType.Password.value,
    }
  ];

  late LuckMoneyProps props;

  RxString selectedLabel = ''.obs;
  RxString amount = '0.00'.obs;
  RxString roomId = ''.obs;
  RxInt memberCount = 0.obs;
  String selectedType = LuckyMoneyType.Random.value;
  final balanceData = Rxn<BalanceData>();
  final selectWalletBalance = Rxn<Currency>();

  final errorMessage = ''.obs;
  
  // 表单字段错误状态
  final amountError = false.obs;
  final quantityError = false.obs;
  final currencyError = false.obs;
  final memberError = false.obs;
  final passwordError = false.obs;
  
  List<Map<String, String>> get luckMoneyTypes {
    if (roomId.value.isEmpty) {
      return _luckMoneyTypes.where((item) {
        // 如果是单聊模式，去掉拼手气红包和专属红包
        return item['value'] != LuckyMoneyType.Random.value &&
               item['value'] != LuckyMoneyType.Special.value;
      }).toList();
    }
    // 群聊：去掉普通红包（仅保留拼手气、专属、口令）
    return _luckMoneyTypes.where((item) {
      return item['value'] != LuckyMoneyType.Normal.value;
    }).toList();
  }
  bool get isChinese => DataSp.getLanguage() == 1;  @override
  void onInit() {
    props = LuckMoneyProps(
      Get.arguments['groupInfo'],
      Get.arguments['conversationInfo'],
    );

    roomId.value = props.groupInfo?.groupID ?? '';
    memberCount.value = props.groupInfo?.memberCount ?? 0;
    if (roomId.value.isNotEmpty) {
      selectedLabel.value = StrRes.randomAmount;
      selectedType = LuckyMoneyType.Random.value;
    } else {
      selectedLabel.value = StrRes.identicalAmount;
      selectedType = LuckyMoneyType.Normal.value;
    }

    quantityController.addListener(() {
      _validateForm(false); // 实时验证表单
    });

    amountController.addListener(() {
      amount.value = amountController.text;
      _validateForm(false); // 实时验证表单
    });

    passwordController.addListener(() {
      _validateForm(false); // 实时验证表单
    });

    // 监听钱包选择变化
    ever(selectWalletBalance, (wallet) {
      _validateForm(false); // 当钱包选择变化时也验证表单
    });

    _updateDecimalPlaces();

    super.onInit();
  }

  @override
  void onReady() {
    getWalletBalance();
    super.onReady();
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    quantityController.dispose();
    passwordController.dispose();

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
      _validateForm(false); // 钱包变化时验证表单
    });
  }

  getWalletBalance() {
    LoadingView.singleton.wrap(asyncFunction: () async {
      balanceData.value =
          await _apiService.walletBalanceByOrg(DataSp.getOrgId());
      selectWalletBalance.value = balanceData.value?.currency?.firstOrNull;
    });
  }
  void onTapItem(Map<String, String> item) {
    selectedLabel.value = item['label']!;
    selectedType = item['value']!;
    _validateForm(false); // 红包类型变化时验证表单
    Get.back();
  }

  void onTapSelect() async {
    GroupMembersInfo? groupMembersInfo = await AppNavigator.startLuckMoneySelectedMember(props.groupInfo as GroupInfo);
    if (groupMembersInfo != null) {
      // 选择了成员，更新红包数量
      quantityController.text = '1'; // 默认设置为1个红包
      selectGroupMember.value = groupMembersInfo;
      _validateForm(false); // 更新后验证表单
    }
  }
  void send() async {
    String roomId = props.groupInfo?.groupID ?? '';
    _validateForm(true);

    // 检查表单是否有错误
    if (amountError.value || quantityError.value || currencyError.value || errorMessage.value.isNotEmpty) {
      return;
    }

    try {
      // 显示加载中状态
      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 15),
                Text('${StrRes.sending}...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // 构建红包数据
      Map<String, dynamic> luckMoneyData = _buildLuckyMoneyData(roomId);

      // 使用安全服务进行验证和加密
      final securityService = SecurityService();
      final encryptedData = await securityService.verifyAndEncrypt(
        data: luckMoneyData,
        onFailure: () {
          Get.back(); // 关闭加载对话框
          Get.snackbar('验证失败', '发送红包失败，请重试',
              backgroundColor: Colors.red[400], colorText: Colors.white);
        },
      );

      if (encryptedData == null) {
        Get.back(); // 关闭加载对话框
        return; // 用户取消，直接返回
      }

      // 解析加密结果
      final resultMap = jsonDecode(encryptedData);

      // 调用transactionCreate接口
      final response = await _apiService.transactionCreate(
        encryptedData: resultMap['encrypted_data'],
        needRsaVerify: resultMap['need_rsa_verify'],
      );

      // 关闭加载对话框
      Get.back(); 
      if (response['success']) {
        // 发送成功,创建消息
        await _sendLuckyMoneyMessage(response, roomId);

        // 返回到聊天界面
        Get.back();

        // 显示成功消息
        Get.snackbar(StrRes.reminder, StrRes.sentSuccessfully,
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar(
          StrRes.reminder, 
          response['message'] ?? StrRes.sendFailed,
          backgroundColor: Colors.red[400], 
          colorText: Colors.white
        );
      }
    } catch (e) {
      // 关闭加载对话框
      Get.back();

      ILogger.d('发送红包出错: $e');
      // Get.snackbar(StrRes.reminder, StrRes.sendFailed,
      //     backgroundColor: Colors.red[400], colorText: Colors.white);
    }
  }  // 实时验证表单 strict 参数用于控制是否严格验证
  // 如果 strict 为 false时不做是否为空判断，只在有内容时验证格式
  // 校验顺序：数量 -> 金额 -> 货币
  void _validateForm(bool strict) {
    // 重置所有错误状态
    amountError.value = false;
    quantityError.value = false;
    currencyError.value = false;
    passwordError.value = false;
    errorMessage.value = '';

    List<String> errorMessages = [];
    bool hasAmountInput = amountController.text.isNotEmpty;
    bool hasQuantityInput = quantityController.text.isNotEmpty;
    
    // 1. 首先验证红包数量(群聊模式)
    int? count;
    if (props.groupInfo != null) {
      if (selectGroupMember.value == null && strict && selectedType == LuckyMoneyType.Special.value) {
        memberError.value = true;
        errorMessages.add(sprintf(StrRes.notEntered, [StrRes.sendTo]));
      } else {
        memberError.value = false;
      }

      if (quantityController.text.isEmpty) {
        if (strict) {
          quantityError.value = true;
          errorMessages.add(sprintf(StrRes.notEntered, [StrRes.redPacketQuantity]));
        }
      } else {
        try {
          count = int.tryParse(quantityController.text);
        } catch (e) {
          count = null;
        }

        if (count == null || count <= 0) {
          quantityError.value = true;
          errorMessages.add(sprintf(StrRes.notEntered, [StrRes.redPacketQuantity]));
        } else {
          // 检查红包数量不能超过群聊人数
          if (count > memberCount.value) {
            quantityError.value = true;
            errorMessages.add(StrRes.exceedGroupMemberLimit);
          }
        }
      }
    } else {
      count = 1;
    }

    // 2. 然后验证金额
    double? amount;
    if (amountController.text.isEmpty) {
      if (strict) {
        amountError.value = true;
        String labelStr = "";
        if (selectedLabel.value == StrRes.identicalAmount) {
          labelStr = StrRes.amountEach;
        }
        if (selectedLabel.value == StrRes.exclusive) {
          labelStr = StrRes.amount;
        }
        errorMessages.add(sprintf(StrRes.notEntered, [labelStr]));
      }
    } else {
      // 尝试解析金额
      try {
        amount = double.tryParse(amountController.text);
      } catch (e) {
        amount = null;
      }

      if (amount == null || amount <= 0) {
        amountError.value = true;
        errorMessages.add(StrRes.invalidAmount);
      } else {        
        // 检查单个红包金额限制
        if (selectWalletBalance.value != null && count != null && count > 0) {
          final maxRedPacketAmount = num.parse(selectWalletBalance.value?.currencyInfo?.maxRedPacketAmount ?? "0");
          double singleRedPacketAmount;
          
          if (selectedType == LuckyMoneyType.Random.value || selectedType == LuckyMoneyType.Password.value) {
            // 拼手气红包：总金额除以红包个数得到平均单个红包金额
            singleRedPacketAmount = amount / count;
          } else {
            // 普通红包：输入的金额就是单个红包金额
            singleRedPacketAmount = amount;
          }
          
          if (singleRedPacketAmount > maxRedPacketAmount) {
            amountError.value = true;
            quantityError.value = true;
            errorMessages.add(sprintf(StrRes.amountExceedMax, [
              "${selectWalletBalance.value?.currencyInfo?.name}${selectWalletBalance.value?.currencyInfo?.maxRedPacketAmount}"
            ]));
          }
        }

        // 检查余额不足
        if (selectWalletBalance.value != null && amount >
            num.parse(
                selectWalletBalance.value?.balanceInfo?.availableBalance ?? '0')) {
          amountError.value = true;
          errorMessages.add(sprintf(StrRes.balanceExceeded, [
            "${selectWalletBalance.value?.currencyInfo?.name}${selectWalletBalance.value?.balanceInfo?.availableBalance}"
          ]));
        }

        // 拼手气红包检查每个人至少0.01元（需要同时有有效的数量和金额）
        if (props.groupInfo != null && count != null && count > 0 && selectedType == LuckyMoneyType.Random.value) {
          if (amount < count * 0.01) {
            amountError.value = true;
            quantityError.value = true;
            errorMessages.add(sprintf(StrRes.redPacketAmountVail, ['CNY']));
          }
        }
      }
    }

    // 3. 最后验证钱包选择
    if (selectWalletBalance.value == null) {
      if (strict) {
        currencyError.value = true;
        errorMessages.add(sprintf(StrRes.notEntered, [StrRes.currency]));
      }
    }

    if (selectedType == LuckyMoneyType.Password.value) {
      // 口令红包需要口令是否填写
      if (passwordController.text.isEmpty && strict) {
        passwordError.value = true;

        // todo 文案
        errorMessages.add(sprintf(StrRes.notEntered, [StrRes.password]));
      } else {
        passwordError.value = false; // 密码输入有效
      }
    } else {
      passwordError.value = false; // 非口令红包不需要验证
    }

    // 设置错误信息（显示第一个错误）
    if (errorMessages.isNotEmpty) {
      errorMessage.value = errorMessages.first;
    }

    // 非严格模式下，如果没有任何输入，清除所有错误状态
    if (!strict && !hasAmountInput && !hasQuantityInput) {
      amountError.value = false;
      quantityError.value = false;
      currencyError.value = false;
      errorMessage.value = '';
    }
  }

  int getTransactionType() {
    final isGroup = roomId.value.isNotEmpty;
    if (isGroup) {
      if (selectedType == LuckyMoneyType.Normal.value) {
        return 2; // 2-普通红包
      }
      if (selectedType == LuckyMoneyType.Random.value) {
        return 3; // 3-拼手气红包
      }
      if (selectedType == LuckyMoneyType.Password.value) {
        return 6; // 6-口令红包
      }
      if (selectedType == LuckyMoneyType.Special.value) {
        return 5; // 5-专属红包
      }
      return 2; // 默认返回普通红包
    } else {
      return 1; // 1-一对一红包
    }
  }

  /// 计算总金额
  String calculateTotalAmount() {
    if (selectedType == LuckyMoneyType.Normal.value) {
      // 普通红包：单个金额 * 红包个数
      double singleAmount = double.tryParse(amountController.text) ?? 0.0;
      int count = int.tryParse(quantityController.text) ?? 1;
      return (singleAmount * count).toStringAsFixed(2);
    } else {
      // 拼手气红包、单聊红包、专属红包、口令红包直接使用输入金额
      return amountController.text.toString();
    }
  }

  /// 计算红包数量
  int calculateTotalCount() {
    if (selectedType == LuckyMoneyType.Normal.value ||
        selectedType == LuckyMoneyType.Random.value ||
        selectedType == LuckyMoneyType.Password.value) {
      return int.tryParse(quantityController.text) ?? 1;
    } else {
      // 单聊红包、专属红包、数量默认为1
      return 1;
    }
  }

  // 构建红包数据
  Map<String, dynamic> _buildLuckyMoneyData(String roomId) {
    final isGroup = roomId.isNotEmpty;
    final transactionType = getTransactionType();
    String totalAmount = calculateTotalAmount();
    int totalCount = calculateTotalCount();

    return {
      "transaction_type": transactionType,
      "total_amount": totalAmount,
      "total_count": totalCount,
      "target_id": isGroup ? roomId : props.conversationInfo.userID,
      "greeting": noteController.text,
      "password": passwordController.text.trim(),
      "currency_id": selectWalletBalance.value?.currencyInfo?.id,
      "exclusive_receiver_id": selectedType == LuckyMoneyType.Special.value ? selectGroupMember.value?.userID : null,
    };
  }

  // 发送红包消息
  Future<void> _sendLuckyMoneyMessage(
      Map<String, dynamic> response, String roomId) async {
    final transactionId = response['transaction_id'];
    if (transactionId == null || transactionId.isEmpty) {
      return;
    }

    // 构建红包消息数据
    Map<String, dynamic> messageData = {
      "customType": CustomMessageType.luckMoney,
      "data": {
        'msg_id': transactionId,
        "create_time": DateTime.now().millisecondsSinceEpoch,
        "createor": OpenIM.iMManager.userID,
        "roomid": roomId,
        "total_amount": amountController.text,
        "sender": OpenIM.iMManager.userID,
        "sender_nickname": OpenIM.iMManager.userInfo.nickname,
        "sender_face_url": OpenIM.iMManager.userInfo.faceURL,
        "code": LuckyMoneyCode.LuckyMoneyGroupNormal.value,
        "state": 'pending',
        "currency": selectWalletBalance.value?.currencyInfo?.name,
        "belong_to": null,
        "expire_time":
            DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
        "remark": noteController.text,
        "viewType": CustomMessageType.luckMoney,
        "isReceived": false,
        "status": 'pending',
        "received_count": 0,
        "total_count": int.tryParse(quantityController.text) ?? 1,
        "extension": {
          "lucky_money_type": selectedType,
          "lucky_money_total_count": int.tryParse(quantityController.text) ?? 1,
          "lucky_money_scene": roomId.isEmpty
              ? LuckMoneyScene.Friend.value
              : LuckMoneyScene.Group.value,
          "special_receiver_id": selectedType == LuckyMoneyType.Special.value ? selectGroupMember.value?.userID : null,
          "special_receiver_name": selectedType == LuckyMoneyType.Special.value ? selectGroupMember.value?.nickname : null,
        }
      }
    };

    // 发送消息
    chartLogic.sendCustomMsg(
        data: jsonEncode(messageData), extension: '', description: '红包');
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
                          '${IMUtils.formatNumberWithCommas(item.balanceInfo?.availableBalance ?? '0.00')}',
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
      _validateForm(false); // 选择钱包后触发验证
    }
  }
}