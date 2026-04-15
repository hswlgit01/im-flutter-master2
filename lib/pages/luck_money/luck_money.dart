import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/app.dart';
import 'package:openim/utils/number_input_decimal_formatter.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import 'luck_money_logic.dart';

class LuckMoneyPage extends StatelessWidget {
  final logic = Get.find<LuckMoneyLogic>();
  LuckMoneyPage({super.key});
  Widget _showAmountTitle() {
    return Obx(() {
      Color textColor = logic.amountError.value ? Colors.red : Colors.black;

      if (logic.selectedLabel.value == StrRes.identicalAmount || logic.roomId.isEmpty) {
        return Text(StrRes.amountEach,
            style: TextStyle(fontSize: 14, color: textColor));
      }

      if (logic.selectedLabel.value == StrRes.exclusive) {
        return Text(StrRes.amount,
            style: TextStyle(fontSize: 14, color: textColor));
      }

      return Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.yellow[800],
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Text(
              '拼',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 3),
          Text(StrRes.totalAmount,
              style: TextStyle(fontSize: 14, color: textColor))
        ],
      );
    });
  }

  Widget _buildInputOfType() {
    if (logic.selectedLabel.value == StrRes.exclusive) {
      return _buildBelong2();
    }

    if (logic.roomId.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountInput(),
        Obx(() => _buildMembersCount()),
      ],
    );
  }

  void _showTypeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.zero),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...logic.luckMoneyTypes.map((item) {
              return Column(
                children: [
                  ListTile(
                    title: Center(child: Text(item['label']!)),
                    onTap: () => logic.onTapItem(item),
                  ),
                  Divider(
                    height: 1,
                    color: Styles.c_E8EAEF,
                  ),
                ],
              );
            }).toList(),
            ListTile(
              title: Center(
                child: Text(StrRes.cancel),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPacketType() {
    return GestureDetector(
      onTap: () => _showTypeSelector(Get.context!),
      child: Row(
        children: [
          Obx(() => Text(
                logic.selectedLabel.value,
                style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 194, 161, 33)),
              )),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: const Color.fromARGB(255, 194, 161, 33),
            size: 24,
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmount() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          _showAmountTitle(),
          Spacer(),
          Container(
            width: 150,
            child: Obx(() => TextField(
                  controller: logic.amountController,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: logic.amountError.value ? Colors.red : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    DecimalTextInputFormatter(
                        decimalPlaces: logic.decimalPlaces),
                  ],
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelectBox() {
    return GestureDetector(
      onTap: () => logic.onTapSelectCurrency(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Obx(() => Text(
                  StrRes.currency,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        logic.currencyError.value ? Colors.red : Colors.black,
                  ),
                )),
            Transform.translate(
              offset: const Offset(8, 0),
              child: Row(
                children: [
                  Obx(() => Text(
                        logic.selectWalletBalance.value?.currencyInfo?.name ??
                            '',
                        style: TextStyle(
                          fontSize: 14,
                          color: logic.currencyError.value
                              ? Colors.red
                              : Colors.black,
                        ),
                      )),
                  const Icon(Icons.keyboard_arrow_right_sharp, size: 24),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 专属红包指定人
  Widget _buildBelong2() {
    return GestureDetector(
      onTap: () => logic.onTapSelect(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              child: Text(
                StrRes.sendTo,
                style: TextStyle(
                    color: logic.memberError.value ? Colors.red : Colors.black),
              ),
            ),
            Transform.translate(
              offset: const Offset(8, 0),
              child: Row(
                children: [
                  if (logic.selectGroupMember.value != null)
                    Row(
                      children: [
                        AvatarView(
                          text: logic.selectGroupMember.value?.nickname,
                          url: logic.selectGroupMember.value?.faceURL,
                          width: 30,
                          height: 30,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        6.horizontalSpace,
                        Text(
                          "${logic.selectGroupMember.value?.nickname}",
                          style: TextStyle(fontSize: 15.sp),
                        )
                      ],
                    ),
                  const Icon(
                    Icons.keyboard_arrow_right_sharp,
                    size: 24,
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 红包个数
  Widget _buildCountInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Obx(() => Text(
                StrRes.redPacketQuantity,
                style: TextStyle(
                  fontSize: 14,
                  color: logic.quantityError.value ? Colors.red : Colors.black,
                ),
              )),
          Spacer(),
          Container(
            width: 100,
            child: Obx(() => TextField(
                  controller: logic.quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color:
                        logic.quantityError.value ? Colors.red : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: StrRes.redPacketEnterNumber,
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    border: InputBorder.none,
                  ),
                )),
          ),
          const SizedBox(width: 8),
          if (logic.isChinese)
            Text('个',
                style: TextStyle(
                    fontSize: 14,
                    color:
                        logic.quantityError.value ? Colors.red : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildBlessing() {
    if (logic.selectedLabel.value == StrRes.redPacketPassword) {
      return _buildPasswordInput();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: TextField(
        controller: logic.noteController, // 使用noteController
        decoration: InputDecoration(
          hintText: StrRes.redPacketHitStr,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          counterText: '',
        ),
        maxLines: 1,
        maxLength: 25,
      ),
    );
  }

  /// 口令红包输入框
  Widget _buildPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(StrRes.redPacketCommandContent),
              Text(StrRes.enterCommandToClaim,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          5.verticalSpace,
          Row(
            children: [
              Expanded(
                  child: TextField(
                controller: logic.passwordController,
                decoration: InputDecoration(
                  hintText: StrRes.enterPasswordPrompt,
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  counterText: '',
                ),
                maxLines: 1,
                maxLength: 25,
              )),
            ],
          ),
          Divider(
            height: 1,
            color: logic.passwordError.value ? Colors.red : Styles.c_E8EAEF,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[400],
            minimumSize: Size(180, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => logic.send(),
          child: Text(
            StrRes.prepareRedPacket,
            style: TextStyle(
                fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersCount() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Text(
        sprintf(StrRes.redPacketGroupNumber, [logic.memberCount.value]),
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      color: const Color(0xFFF5F5F5), // 添加背景颜色
      child: Column(
        children: [
          Obx(() => _buildErrorTip()),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logic.roomId.value.isNotEmpty) _buildPacketType(),
                if (logic.roomId.value.isNotEmpty) const SizedBox(height: 10),
                Obx(() => _buildInputOfType()),
                const SizedBox(height: 16),
                _buildTotalAmount(),
                const SizedBox(height: 16),
                _buildCurrencySelectBox(),
                const SizedBox(height: 16),
                Obx(() => _buildBlessing()),
                const SizedBox(height: 16),
                _buildBottomButton(),
              ],
            ),
          ))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TouchCloseSoftKeyboard(
        child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD93B31),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _buildBody(),
    ));
  }

  _buildErrorTip() {
    if (logic.errorMessage.value.isEmpty) {
      return Container();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 186, 156, 106),
      ),
      child: Text(
        logic.errorMessage.value,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
