import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'compensation_records_logic.dart';

class CompensationRecordsPage extends StatelessWidget {
  final CompensationRecordsLogic logic = Get.put(CompensationRecordsLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('补偿金记录'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Obx(() => _buildContent()),
    );
  }

  Widget _buildContent() {
    if (logic.isLoading.value) {
      return Center(child: CircularProgressIndicator());
    }

    if (logic.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/empty_box.png',
              width: 120.w,
              height: 120.w,
            ),
            SizedBox(height: 16.h),
            Text(
              '暂无补偿金记录',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: logic.onRefresh,
      child: ListView.builder(
        controller: logic.scrollController,
        itemCount: logic.records.length + 1,
        itemBuilder: (context, index) {
          if (index == logic.records.length) {
            return _buildLoadingMore();
          }

          final record = logic.records[index];
          return _buildRecordItem(record);
        },
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Container(
      height: 60.h,
      alignment: Alignment.center,
      child: Obx(() {
        if (logic.isLoadingMore.value) {
          return SizedBox(
            width: 24.w,
            height: 24.w,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          );
        } else if (!logic.hasMore.value) {
          return Text(
            '没有更多记录了',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
            ),
          );
        } else {
          return SizedBox();
        }
      }),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    // 获取交易类型
    final int type = record['type'] ?? 0;
    final String typeName = logic.getTransactionTypeName(type);

    // 获取备注
    final String remark = record['remark'] ?? '';

    // 获取交易时间
    final String transactionTime = logic.formatDateTime(record['transaction_time']);

    // 获取金额
    final String amount = logic.formatAmount(record['amount'] ?? '0');

    // 获取金额颜色
    final Color amountColor = logic.getAmountColor(record);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (remark.isNotEmpty) ...[
              Text(
                '备注: $remark',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4.h),
            ],
            Text(
              '时间: $transactionTime',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}