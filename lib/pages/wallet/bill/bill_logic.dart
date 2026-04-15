import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/log_util.dart';

class BillLogic extends GetxController {
  /// 日志TAG
  static const String TAG = "BillLogic";

  final bills = <Map<String, dynamic>>[].obs;
  final selectedType = Rx<Map<String, dynamic>>({'name': StrRes.walletAllTypes, 'value': null});
  final selectedDate = Rx<Map<String, dynamic>>({'name': StrRes.walletAllTime, 'start_time': null, 'end_time': null});
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  late String? currentyId;
  final pageSize = 20;
  int currentPage = 1;
  
  final ScrollController scrollController = ScrollController();
  
  /// 补偿金相关类型不在钱包明细中展示，仅在「补偿金」页展示
  static const List<int> _compensationTypes = [51, 52, 53]; // 初始补偿金、补偿金扣减、补偿金调整

  final billTypes = [
    {'name': StrRes.walletAllTypes, 'value': null},  // 全部
    {'name': StrRes.transferExpense, 'value': 1},     // 转账支出
    {'name': StrRes.transferRefund, 'value': 2},     // 转账退款
    {'name': StrRes.transferReceipt, 'value': 3},     // 转账领取
    {'name': StrRes.orgTransferReceipt, 'value': 4},     // 组织账户转账
    {'name': StrRes.redPacketRefund, 'value': 11},    // 红包退款
    {'name': StrRes.redPacketExpense, 'value': 12},    // 红包支出
    {'name': StrRes.redPacketReceipt, 'value': 13},    // 红包领取
    {'name': StrRes.recharge, 'value': 21},        // 充值
    {'name': StrRes.withdraw, 'value': 22},        // 提现
    {'name': StrRes.consumption, 'value': 23},        // 消费
    {'name': StrRes.checkinReward, 'value': 42},        // 签到奖励
  ];

  final dateFilters = [
    {'name': StrRes.walletAllTime, 'start_time': null, 'end_time': null},
    {'name': StrRes.walletLastWeek, 'start_time': DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch ~/ 1000},
    {'name': StrRes.walletLastMonth, 'start_time': DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch ~/ 1000},
    {'name': StrRes.walletLastThreeMonths, 'start_time': DateTime.now().subtract(Duration(days: 90)).millisecondsSinceEpoch ~/ 1000},
  ];

  @override
  void onInit() {
    super.onInit();
    currentyId = Get.arguments['currentyId'];
    scrollController.addListener(_onScroll);
    selectedDate.value = dateFilters[0];
    getBills();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (!isLoadingMore.value && hasMore.value) {
        loadMoreBills();
      }
    }
  }

  Future<void> onRefresh() async {
    currentPage = 1;
    hasMore.value = true;
    await getBills();
  }

  /// 获取账单列表
  Future<void> getBills() async {
    if (isLoadingMore.value) return;

    isLoadingMore.value = true;

    try {
      final apiService = core.ApiService();
      final result = await apiService.walletTsRecord(
        type: selectedType.value['value'],
        page: currentPage,
        pageSize: pageSize,
        order: 'created_at',
        start_time: selectedDate.value['start_time'],
        end_time: selectedDate.value['end_time'],
        currenty_id: currentyId,
      );

      if (result != null) {
        final List<dynamic> rawData = result['data'];
        final List<Map<String, dynamic>> allItems = rawData.map((item) => Map<String, dynamic>.from(item)).toList();
        // 钱包明细不展示补偿金账变，仅补偿金页展示
        final List<Map<String, dynamic>> billData = allItems
            .where((b) => !_compensationTypes.contains(b['type']))
            .toList();

        if (currentPage == 1) {
          bills.value = billData;
        } else {
          bills.addAll(billData);
        }

        hasMore.value = allItems.length >= pageSize;
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      LogUtil.e(TAG, '获取账单列表失败: $e');
      IMViews.showToast('获取账单列表失败');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreBills() async {
    if (isLoadingMore.value) return;
    
    isLoadingMore.value = true;
    try {
      currentPage++;
      final apiService = core.ApiService();
      final result = await apiService.walletTsRecord(
        type: selectedType.value['value'],
        page: currentPage,
        pageSize: pageSize,
        order: 'created_at',
        start_time: selectedDate.value['start_time'],
        end_time: selectedDate.value['end_time'],
      );

      if (result != null) {
        final List<dynamic> rawData = result['data'];
        final List<Map<String, dynamic>> allItems = rawData.map((item) => Map<String, dynamic>.from(item)).toList();
        // 钱包明细不展示补偿金账变
        final List<Map<String, dynamic>> billData = allItems
            .where((b) => !_compensationTypes.contains(b['type']))
            .toList();

        if (rawData.length < pageSize) {
          hasMore.value = false;
        }

        bills.addAll(billData);
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      LogUtil.e(TAG, '加载更多账单失败: $e');
      IMViews.showToast('加载更多账单失败');
    } finally {
      isLoadingMore.value = false;
    }
  }

  // 显示类型筛选
  void showTypeFilter() {
    Get.bottomSheet(
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
                    StrRes.selectType,
                    style: Styles.ts_0C1C33_17sp_medium,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: billTypes.length,
                  itemBuilder: (context, index) {
                    final type = billTypes[index];
                    return GestureDetector(
                      onTap: () {
                        selectedType.value = type;
                        Get.back();
                        getBills();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Styles.c_E8EAEF),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              type['name'].toString(),
                              style: Styles.ts_0C1C33_14sp,
                            ),
                            if (selectedType.value['value'] == type['value'])
                              Icon(
                                Icons.check,
                                color: Colors.blue,
                                size: 20.w,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // 显示日期筛选
  void showDateFilter() {
    Get.bottomSheet(
      Container(
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
                    StrRes.selectTime,
                    style: Styles.ts_0C1C33_17sp_medium,
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: dateFilters.length,
              itemBuilder: (context, index) {
                final date = dateFilters[index];
                return GestureDetector(
                  onTap: () {
                    selectedDate.value = date;
                    Get.back();
                    getBills();  // 重新加载账单列表
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Styles.c_E8EAEF),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          date['name'].toString(),
                          style: Styles.ts_0C1C33_14sp,
                        ),
                        if (selectedDate.value['name'] == date['name'])
                          Icon(
                            Icons.check,
                            color: Colors.blue,
                            size: 20.w,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
} 