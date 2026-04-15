import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/core/api_service.dart' as core;

class CompensationRecordsLogic extends GetxController {
  final walletController = WalletController.to;
  final refreshController = RefreshController(initialRefresh: true);

  // 记录状态
  final records = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;

  // 分页参数
  int page = 1;
  final pageSize = 20;

  @override
  void onInit() {
    super.onInit();
  }

  // 刷新
  void onRefresh() async {
    page = 1;
    await getRecords(isRefresh: true);
    refreshController.refreshCompleted();
  }

  // 加载更多
  void onLoading() async {
    if (!hasMore.value) {
      refreshController.loadNoData();
      return;
    }

    await getRecords(isRefresh: false);
    refreshController.loadComplete();
  }

  // 获取补偿金记录
  Future<void> getRecords({bool isRefresh = false}) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final apiService = core.ApiService();

      // 尝试先不指定币种ID，查询所有类型的补偿金记录
      final result = await apiService.getCompensationRecords(
        page: page,
        pageSize: pageSize,
        // 不再传递currencyId，避免无效币种ID导致的错误
      );

      if (result == null) {
        // 处理没有结果的情况
        Logger.print('获取补偿金记录: 没有数据');
        hasMore.value = false;

        // 如果是刷新操作，清空现有记录
        if (isRefresh) {
          records.clear();
        }
        return;
      }

      // 安全提取数据
      final totalCount = result['total'] as int? ?? 0;
      final List recordsList = result['records'] as List? ?? [];

      Logger.print('获取补偿金记录成功: 总数 $totalCount, 当前页记录数 ${recordsList.length}');

      // 转换并验证每条记录
      final recordsData = recordsList
          .where((e) => e is Map<String, dynamic>) // 过滤掉非Map类型的记录
          .map((e) => e as Map<String, dynamic>)
          .toList();

      // 如果是刷新操作，清空现有记录
      if (isRefresh) {
        records.clear();
      }

      // 添加新记录
      records.addAll(recordsData);

      // 更新分页状态
      hasMore.value = records.length < totalCount;
      if (hasMore.value) {
        page++;
      }

      Logger.print('记录处理完成: ${records.length} 条记录, 是否有更多: ${hasMore.value}');
    } catch (e) {
      // 详细记录错误信息
      Logger.print('获取补偿金记录异常: $e');

      // 显示友好的错误提示
      IMViews.showToast(StrRes.networkError);

      // 如果是首次加载（刷新），显示空数据
      if (isRefresh) {
        records.clear();
      }

      // 假设没有更多数据，避免继续加载
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  // 获取交易类型名称
  String getTransactionTypeName(int type) {
    // 补偿金相关交易类型
    // 类型51: 初始补偿金
    // 类型52: 补偿金扣减
    // 类型53: 补偿金调整
    switch (type) {
      case 51:
        return StrRes.compensationInitial;
      case 52:
        return StrRes.compensationDeduction;
      case 53:
        return StrRes.compensationAdjustment;
      default:
        return StrRes.unknown;
    }
  }

  // 格式化金额，带正负号
  String formatAmount(String amount) {
    if (amount.startsWith('-')) {
      return amount; // 已经是负数
    }

    // 尝试转换为数字判断正负
    try {
      final numAmount = num.parse(amount);
      if (numAmount > 0) {
        return '+$amount'; // 正数加上+号
      }
      return amount; // 零或其他情况
    } catch (e) {
      return amount;
    }
  }

  // 获取金额颜色
  Color getAmountColor(String amount) {
    try {
      final numAmount = num.parse(amount);
      if (numAmount > 0) {
        return Styles.c_18E875; // 绿色 - 收入
      } else if (numAmount < 0) {
        return Styles.c_FF381F; // 红色 - 支出
      } else {
        return Styles.c_0C1C33; // 黑色 - 零
      }
    } catch (e) {
      return Styles.c_0C1C33;
    }
  }

  // 格式化时间
  String formatDateTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}