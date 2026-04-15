import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import './bill_logic.dart';
import './bill_detail/bill_detail_view.dart';

class BillPage extends StatelessWidget {
  final logic = Get.put(BillLogic());

  BillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StrRes.walletBill.toText..style = Styles.ts_0C1C33_17sp_medium,
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildBillList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() => Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        bottom: BorderSide(color: Styles.c_E8EAEF, width: 1),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: logic.showTypeFilter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => Text(
                  logic.selectedType.value['name'].toString(),
                  style: Styles.ts_0C1C33_14sp,
                )),
                Icon(Icons.arrow_drop_down, size: 20.w),
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: logic.showDateFilter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => Text(
                  logic.selectedDate.value['name'].toString(),
                  style: Styles.ts_0C1C33_14sp,
                )),
                Icon(Icons.arrow_drop_down, size: 20.w),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildBillList() => Obx(() => RefreshIndicator(
    onRefresh: logic.onRefresh,
    child: ListView.builder(
      controller: logic.scrollController,
      itemCount: logic.bills.length + 1,
      itemBuilder: (context, index) {
        if (index == logic.bills.length) {
          return _buildLoadingMore();
        }
        final bill = logic.bills[index];
        return _buildBillItem(bill);
      },
    ),
  ));

  Widget _buildLoadingMore() => Obx(() => Container(
    height: 50.h,
    alignment: Alignment.center,
    child: logic.isLoadingMore.value
        ? CircularProgressIndicator(strokeWidth: 2)
        : logic.hasMore.value
            ? null
            : Text(StrRes.walletNoMoreData, style: Styles.ts_8E9AB0_14sp),
  ));

  String _getTransactionTypeText(int type) {
    switch (type) {
      case 1:
        return StrRes.transferExpense;
      case 2:
        return StrRes.transferRefund;
      case 3:
        return StrRes.transferReceipt;
      case 11:
        return StrRes.redPacketRefund;
      case 12:
        return StrRes.redPacketExpense;
      case 13:
        return StrRes.redPacketReceipt;
      case 21:
        return StrRes.recharge;
      case 22:
        return StrRes.withdraw;
      case 23:
        return StrRes.consumption;
      case 42:
        return StrRes.checkinReward;
      default:
        return StrRes.unknownType;
    }
  }

  Widget _buildBillItem(Map<String, dynamic> bill) => GestureDetector(
    onTap: () => Get.to(() => BillDetailPage(), arguments: {'bill': bill}),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Styles.c_E8EAEF, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTransactionTypeText(bill['type'] ?? 0),
                  style: Styles.ts_0C1C33_14sp,
                ),
                4.verticalSpace,
                Text(
                  IMUtils.formatIsoDate(bill['transaction_time']?.toString() ?? ''),
                  style: Styles.ts_8E9AB0_12sp,
                ),
              
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${bill['amount']}',
                style: Styles.ts_0C1C33_17sp_medium,
              ),
            ],
          ),
        ],
      ),
    ),
  );
} 