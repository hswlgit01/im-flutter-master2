import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'bill_detail_logic.dart';

class BillDetailPage extends StatelessWidget {
  final logic = Get.put(BillDetailLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StrRes.walletBillDetail.toText
          ..style = Styles.ts_0C1C33_17sp_medium,
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (logic.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (logic.billDetail.value == null) {
          return Center(
            child: Text('未找到账单信息', style: Styles.ts_0C1C33_17sp),
          );
        }

        return _buildBillDetailContent();
      }),
    );
  }

  Widget _buildBillDetailContent() {
    final bill = logic.billDetail.value!;
    final isIncome = !bill['amount']!.startsWith('-');

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildAmountCard(bill, isIncome),
          16.verticalSpace,
          _buildDetailsList(bill),
        ],
      ),
    );
  }

  Widget _buildAmountCard(Map<String, dynamic> bill, bool isIncome) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            logic.getTransactionTypeText(bill['type'] ?? 0),
            style: Styles.ts_0C1C33_17sp_medium,
          ),
          16.verticalSpace,
          Text(
            '${bill['amount']} ${bill['currency_info']['name']}',
            style: TextStyle(
              color: isIncome ? Color(0xFF1ED089) : Color(0xFFFF381F),
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          // 8.verticalSpace,
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          //   decoration: BoxDecoration(
          //     color: Color(0xFFF5F6FA),
          //     borderRadius: BorderRadius.circular(16.r),
          //   ),
          //   child: Text(
          //     bill['source']?.toString() ?? StrRes.walletSuccess,
          //     style: Styles.ts_8E9AB0_12sp,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDetailsList(Map<String, dynamic> bill) {
    final List<Map<String, String>> details = [
      {
        'label': StrRes.walletBillType,
        'value': logic.getTransactionTypeText(bill['type'] ?? 0)
      },
      {
        'label': StrRes.walletBillTime,
        'value': IMUtils.formatIsoDate(bill['transaction_time']?.toString() ?? '')
      },
      {
        'label': StrRes.walletBillOrderNo,
        'value': bill['id']?.toString() ?? '',
        'copyable': 'true'
      },
      if (bill['remark']?.toString().isNotEmpty == true)
        {
          'label': StrRes.walletBillRemark,
          'value': bill['remark']?.toString() ?? ''
        },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: details.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Styles.c_E8EAEF,
          indent: 16.w,
          endIndent: 16.w,
        ),
        itemBuilder: (context, index) {
          final item = details[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: Styles.ts_8E9AB0_14sp),
                10.horizontalSpace,
                Expanded(
                    child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                        child: Text(
                      item['value']!,
                      style: Styles.ts_0C1C33_14sp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (item['copyable'] == 'true') ...[
                      8.horizontalSpace,
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: item['value']!));
                          IMViews.showToast(StrRes.walletCopied);
                        },
                        child: Icon(Icons.copy_outlined,
                            size: 16, color: Styles.c_0089FF),
                      ),
                    ],
                  ],
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}
