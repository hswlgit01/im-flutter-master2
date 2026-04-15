import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import 'compensation_records_logic.dart';

class CompensationRecordsPage extends StatelessWidget {
  final logic = Get.put(CompensationRecordsLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          StrRes.compensationRecords,
          style: Styles.ts_0C1C33_17sp_medium,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        color: Styles.c_F0F2F6,
        child: Obx(() {
          return SmartRefresher(
            controller: logic.refreshController,
            enablePullDown: true,
            enablePullUp: true,
            header: IMViews.buildHeader(),
            footer: IMViews.buildFooter(),
            onRefresh: logic.onRefresh,
            onLoading: logic.onLoading,
            child: logic.records.isEmpty
                ? _buildEmptyView()
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: logic.records.length,
                    itemBuilder: (context, index) {
                      final record = logic.records[index];
                      return _buildRecordItem(record);
                    },
                  ),
          );
        }),
      ),
    );
  }

  // 空视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80.w,
            color: Styles.c_8E9AB0,
          ),
          16.verticalSpace,
          Text(
            StrRes.noRecord,
            style: Styles.ts_8E9AB0_14sp,
          ),
        ],
      ),
    );
  }

  // 记录项
  Widget _buildRecordItem(Map<String, dynamic> record) {
    final type = record['type'] as int? ?? 0;
    final amount = record['amount'] as String? ?? '0';
    final createdAt = record['created_at'] as String? ?? '';
    final reason = record['reason'] as String? ?? '';

    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：类型和金额
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：交易类型
              Row(
                children: [
                  Icon(
                    Icons.wallet_giftcard,
                    size: 20.w,
                    color: Styles.c_0089FF,
                  ),
                  8.horizontalSpace,
                  Text(
                    logic.getTransactionTypeName(type),
                    style: Styles.ts_0C1C33_16sp_medium,
                  ),
                ],
              ),
              // 右侧：金额
              Text(
                logic.formatAmount(amount),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: logic.getAmountColor(amount),
                ),
              ),
            ],
          ),
          12.verticalSpace,
          // 底部：时间和原因
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 时间
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14.w,
                    color: Styles.c_8E9AB0,
                  ),
                  8.horizontalSpace,
                  Text(
                    logic.formatDateTime(createdAt),
                    style: Styles.ts_8E9AB0_14sp,
                  ),
                ],
              ),
              8.verticalSpace,
              // 原因（如果有）
              if (reason.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14.w,
                      color: Styles.c_8E9AB0,
                    ),
                    8.horizontalSpace,
                    Expanded(
                      child: Text(
                        reason,
                        style: Styles.ts_8E9AB0_14sp,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}