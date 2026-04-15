import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/log_util.dart';
import 'package:openim/core/urls.dart';

class CompensationRecordsLogic extends GetxController {
  static const String TAG = "CompensationRecordsLogic";

  final records = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final pageSize = 20;
  int currentPage = 1;

  final ScrollController scrollController = ScrollController();

  // 补偿金相关交易类型
  final compensationTypes = [51, 52, 53]; // 初始补偿金、补偿金扣减、补偿金调整

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    getCompensationRecords();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (!isLoadingMore.value && hasMore.value) {
        loadMoreRecords();
      }
    }
  }

  Future<void> onRefresh() async {
    currentPage = 1;
    hasMore.value = true;
    await getCompensationRecords();
  }

  // 获取补偿金记录
  Future<void> getCompensationRecords() async {
    if (isLoadingMore.value) return;

    isLoading.value = true;
    isLoadingMore.value = true;

    try {
      // 直接构建请求URL并添加type_in参数
      Map<String, String> queryParams = {
        'page': currentPage.toString(),
        'page_size': pageSize.toString(),
        'order': 'created_at',
        'type_in': compensationTypes.join(','), // 使用多类型查询参数
      };

      final String url = '${Urls.walletTsRecord}?' + queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      LogUtil.i(TAG, '补偿金记录查询URL: $url');

      // 发送API请求
      final result = await HttpUtil.get(
        url,
        options: Apis.chatTokenOptions,
      );

      // 打印完整的响应结构，以便调试
      LogUtil.i(TAG, '补偿金记录API返回数据: ${result.runtimeType}, 内容: $result');

      try {
        // 尝试不同的解析策略
        List<Map<String, dynamic>> recordData = [];
        int? total;

        // 策略1: 标准解析 (result['data']['data'])
        if (result != null && result is Map && result['data'] is Map) {
          final dataMap = result['data'] as Map;
          LogUtil.i(TAG, '解析策略1: result[data]是Map');

          // 提取total
          if (dataMap['total'] != null) {
            total = dataMap['total'] as int;
            LogUtil.i(TAG, '找到total: $total');
          }

          // 提取data数组
          if (dataMap['data'] is List) {
            final rawData = dataMap['data'] as List;
            LogUtil.i(TAG, '找到data数组，长度: ${rawData.length}');
            recordData = rawData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          }
        }
        // 策略2: 直接data (result['data'])
        else if (result != null && result['data'] is List) {
          LogUtil.i(TAG, '解析策略2: result[data]是List');
          final rawData = result['data'] as List;
          recordData = rawData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
        // 策略3: 直接result
        else if (result != null && result is List) {
          LogUtil.i(TAG, '解析策略3: result本身是List');
          recordData = result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }

        LogUtil.i(TAG, '成功解析记录数: ${recordData.length}');

        if (currentPage == 1) {
          records.value = recordData;
        } else {
          records.addAll(recordData);
        }

        // 判断是否还有更多数据
        hasMore.value = total != null ?
            (records.length < total) :
            (recordData.length >= pageSize);

      } catch (parseError, parseStack) {
        LogUtil.e(TAG, '解析数据出错: $parseError');
        LogUtil.e(TAG, '解析错误堆栈:', parseStack);
        throw '数据解析错误: $parseError';
      }
      else {
        LogUtil.i(TAG, '没有结果数据，设置hasMore=false');
        hasMore.value = false;
      }
    } catch (e, stackTrace) {
      LogUtil.e(TAG, '获取补偿金记录失败: $e');
      LogUtil.e(TAG, '堆栈信息:', stackTrace);
      IMViews.showToast('获取补偿金记录失败: ${e.toString()}');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreRecords() async {
    if (isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      currentPage++;

      // 直接构建请求URL并添加type_in参数
      Map<String, String> queryParams = {
        'page': currentPage.toString(),
        'page_size': pageSize.toString(),
        'order': 'created_at',
        'type_in': compensationTypes.join(','), // 使用多类型查询参数
      };

      final String url = '${Urls.walletTsRecord}?' + queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      LogUtil.i(TAG, '加载更多补偿金记录查询URL: $url');

      // 发送API请求
      final result = await HttpUtil.get(
        url,
        options: Apis.chatTokenOptions,
      );

      // 打印完整的响应结构，以便调试
      LogUtil.i(TAG, '加载更多补偿金记录API返回数据: ${result.runtimeType}, 内容: $result');

      try {
        // 尝试不同的解析策略
        List<Map<String, dynamic>> recordData = [];
        int? total;

        // 策略1: 标准解析 (result['data']['data'])
        if (result != null && result is Map && result['data'] is Map) {
          final dataMap = result['data'] as Map;
          LogUtil.i(TAG, '解析策略1: result[data]是Map');

          // 提取total
          if (dataMap['total'] != null) {
            total = dataMap['total'] as int;
            LogUtil.i(TAG, '找到total: $total');
          }

          // 提取data数组
          if (dataMap['data'] is List) {
            final rawData = dataMap['data'] as List;
            LogUtil.i(TAG, '找到data数组，长度: ${rawData.length}');
            recordData = rawData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          }
        }
        // 策略2: 直接data (result['data'])
        else if (result != null && result['data'] is List) {
          LogUtil.i(TAG, '解析策略2: result[data]是List');
          final rawData = result['data'] as List;
          recordData = rawData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
        // 策略3: 直接result
        else if (result != null && result is List) {
          LogUtil.i(TAG, '解析策略3: result本身是List');
          recordData = result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }

        LogUtil.i(TAG, '成功解析记录数: ${recordData.length}');

        // 判断是否还有更多数据
        if (total != null) {
          hasMore.value = (records.length + recordData.length) < total;
        } else {
          hasMore.value = recordData.length >= pageSize;
        }

        records.addAll(recordData);

      } catch (parseError, parseStack) {
        LogUtil.e(TAG, '解析数据出错: $parseError');
        LogUtil.e(TAG, '解析错误堆栈:', parseStack);
        throw '数据解析错误: $parseError';
      }
      else {
        LogUtil.i(TAG, '没有结果数据，设置hasMore=false');
        hasMore.value = false;
      }
    } catch (e, stackTrace) {
      LogUtil.e(TAG, '加载更多补偿金记录失败: $e');
      LogUtil.e(TAG, '堆栈信息:', stackTrace);
      IMViews.showToast('加载更多补偿金记录失败: ${e.toString()}');
    } finally {
      isLoadingMore.value = false;
    }
  }

  // 获取交易类型名称
  String getTransactionTypeName(int type) {
    switch (type) {
      case 51:
        return '初始补偿金';
      case 52:
        return '补偿金扣减';
      case 53:
        return '补偿金调整';
      default:
        return '未知类型';
    }
  }

  // 格式化金额（添加正负号）
  String formatAmount(String amount) {
    try {
      final double value = double.parse(amount);
      if (value > 0) {
        return '+$amount';
      } else {
        return amount; // 负数已经有负号
      }
    } catch (e) {
      return amount;
    }
  }

  // 获取金额颜色
  Color getAmountColor(Map<String, dynamic> record) {
    try {
      final String amountStr = record['amount'] ?? '0';
      final double amount = double.parse(amountStr);
      if (amount > 0) {
        return Colors.green;
      } else if (amount < 0) {
        return Colors.red;
      } else {
        return Colors.grey;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  // 格式化日期时间
  String formatDateTime(dynamic dateTime) {
    try {
      if (dateTime is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(dateTime * 1000);
        return DateUtil.formatDateTime(date, format: 'yyyy-MM-dd HH:mm');
      } else if (dateTime is String) {
        // 尝试解析ISO格式日期
        final date = DateTime.parse(dateTime);
        return DateUtil.formatDateTime(date, format: 'yyyy-MM-dd HH:mm');
      }
      return '-';
    } catch (e) {
      return '-';
    }
  }
}