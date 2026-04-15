import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import 'withdrawal_records_logic.dart';

class WithdrawalRecordsPage extends StatelessWidget {
  final logic = Get.put(WithdrawalRecordsLogic());

  WithdrawalRecordsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('提现记录'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() {
        if (logic.isLoading.value && logic.recordList.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        if (logic.recordList.isEmpty) {
          return _buildEmptyView();
        }

        return SmartRefresher(
          controller: logic.refreshController,
          enablePullDown: true,
          enablePullUp: true,
          onRefresh: logic.onRefresh,
          onLoading: logic.onLoading,
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: logic.recordList.length,
            itemBuilder: (context, index) {
              final record = logic.recordList[index];
              return _buildRecordItem(record);
            },
          ),
        );
      }),
    );
  }

  // 空状态视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80.w,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无提现记录',
            style: TextStyle(
              fontSize: 16.sp,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  // 提现记录项
  Widget _buildRecordItem(WithdrawalRecord record) {
    return GestureDetector(
      onTap: () => logic.viewDetail(record),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：金额 + 状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '¥${record.amount?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1C33),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Color(int.parse(record.statusColor.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    record.statusText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Color(int.parse(record.statusColor.replaceFirst('#', '0xFF'))),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // 收款方式
            Row(
              children: [
                Icon(
                  _getPaymentIcon(record.paymentType),
                  size: 16.w,
                  color: Color(0xFF666666),
                ),
                SizedBox(width: 4.w),
                Text(
                  record.paymentTypeText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // 手续费和实际到账
            Row(
              children: [
                Text(
                  '手续费 ¥${record.fee?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF999999),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  '实际到账 ¥${record.actualAmount?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // 底部：订单号 + 时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订单号: ${record.orderNo ?? ''}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF999999),
                  ),
                ),
                Text(
                  _formatTime(record.createdAt),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),

            // 拒绝原因（如果有）
            if (record.rejectReason?.isNotEmpty == true) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16.w,
                      color: Color(0xFFFF9800),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        '拒绝原因: ${record.rejectReason}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 取消按钮（仅待审核状态显示）
            if (record.canCancel) ...[
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 36.h,
                child: OutlinedButton(
                  onPressed: () => logic.cancelWithdrawal(record),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFFFF9800)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  child: Text(
                    '取消提现',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 获取收款方式图标
  IconData _getPaymentIcon(int? type) {
    switch (type) {
      case 0:
        return Icons.account_balance;
      case 1:
        return Icons.wechat;
      case 2:
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
