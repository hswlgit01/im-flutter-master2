import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/utils/number_input_decimal_formatter.dart';
import 'package:openim_common/openim_common.dart';
import 'transfer_logic.dart';

class TransferPage extends StatelessWidget {
  final logic = Get.put(TransferLogic());
  @override
  Widget build(BuildContext context) {
    return TouchCloseSoftKeyboard(
        child: Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          StrRes.walletTransfer,
          style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFFD83A3A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20.w, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(),
    ));
  }

  Widget _buildBody() {
    return Container(
      color: Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountInput(),
            16.verticalSpace,
            _buildCurrencySelectBox(),
            16.verticalSpace,
            _buildRemarkInput(),
            40.verticalSpace,
            _buildTransferButton(),
          ],
        ),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Text(StrRes.currency, style: TextStyle(fontSize: 14)),
            const Spacer(),
            Obx(() => Text(
                  logic.selectWalletBalance.value?.currencyInfo?.name ?? '',
                  style: const TextStyle(fontSize: 14),
                )),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6.r,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.walletTransferAmount,
            style: TextStyle(
              fontSize: 14.sp,
              color: Styles.c_0C1C33,
              fontWeight: FontWeight.w500,
            ),
          ),
          24.verticalSpace,
          TextField(
            controller: logic.amountController,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 36.sp,
              color: Styles.c_0C1C33,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 36.sp,
                color: Colors.grey[300],
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            inputFormatters: [
              DecimalTextInputFormatter(
                        decimalPlaces: logic.decimalPlaces),
            ],
            onChanged: (value) => logic.amount.value = value,
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6.r,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.walletTransferDescription,
            style: TextStyle(
              fontSize: 14.sp,
              color: Styles.c_0C1C33,
              fontWeight: FontWeight.w500,
            ),
          ),
          16.verticalSpace,
          TextField(
            controller: logic.remarkController,
            maxLines: 1,
            maxLength: 25,
            style: TextStyle(
              fontSize: 15.sp,
              color: Styles.c_0C1C33,
            ),
            decoration: InputDecoration(
              hintText: StrRes.transferPotePlaceholder,
              hintStyle: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey[500],
              ),
              border: InputBorder.none,
              counterText: '',
            ),
            onChanged: (value) => logic.remark.value = value,
          ),
        ],
      ),
    );
  }

  Widget _buildTransferButton() {
    return Center(
      child: Container(
        width: 240.w,
        height: 48.h,
        margin: EdgeInsets.only(top: 20.h),
        child: Obx(() => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD83A3A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              onPressed: logic.isLoading.value ? null : logic.transfer,
              child: logic.isLoading.value
                  ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.w,
                      ),
                    )
                  : Text(
                      StrRes.confirmTransfer,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            )),
      ),
    );
  }
}
