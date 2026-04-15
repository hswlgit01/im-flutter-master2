import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/lottery.dart';

// 奖品记录数据模型 - 基于 Lottery 模型
class PrizeRecord {
  final String id;
  final String name;
  final String imageUrl;
  final DeliveryStatus status;
  final DateTime createTime;
  final String? description;
  final bool isWin;
  final String? rewardId;
  final String? winTime;

  PrizeRecord({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.status,
    required this.createTime,
    this.description,
    required this.isWin,
    this.rewardId,
    this.winTime,
  });

  // 从 Lottery 模型转换
  factory PrizeRecord.fromLottery(Lottery lottery) {
    return PrizeRecord(
      id: lottery.id ?? '',
      name: lottery.rewardInfo?.name ?? StrRes.unknownPrize,
      imageUrl: lottery.rewardInfo?.img ?? '',
      status: _getDeliveryStatus(lottery.status),
      createTime: _parseDateTime(lottery.createdAt),
      description: lottery.rewardInfo?.remark,
      isWin: lottery.isWin ?? false,
      rewardId: lottery.rewardId,
      winTime: lottery.winTime,
    );
  }

  static DeliveryStatus _getDeliveryStatus(int? status) {
    // 根据实际业务逻辑调整状态映射
    switch (status) {
      case 1:
        return DeliveryStatus.delivered;
      case 0:
      default:
        return DeliveryStatus.pending;
    }
  }

  static DateTime _parseDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return DateTime.now();
    }
    try {
      return DateTime.parse(dateTimeStr).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }
}

// 发放状态枚举
enum DeliveryStatus {
  delivered,
  pending;

  String get displayName {
    switch (this) {
      case DeliveryStatus.delivered:
        return StrRes.delivered;
      case DeliveryStatus.pending:
        return StrRes.pending;
    }
  }
}

class PrizeRecordsLogic extends GetxController {
  final RxList<PrizeRecord> prizeRecords = <PrizeRecord>[].obs;
  final RxBool isLoading = false.obs;
  final RxString selectedFilter = 'pending'.obs; // pending, pending
  final RxBool hasMore = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  int currentPage = 1;
  final int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    loadPrizeRecords();
  }

  // 加载奖品记录数据
  Future<void> loadPrizeRecords({bool isRefresh = false}) async {
    if (isRefresh) {
      currentPage = 1;
      hasMore.value = true;
      hasError.value = false;
    }
    
    if (isLoading.value || (!hasMore.value && !isRefresh)) return;
    
    isLoading.value = true;
    hasError.value = false;
    
    try {
      final response = await Apis.getPrizeRecord(
        page: currentPage,
        pageSize: pageSize,
        status: _getStatusFromFilter(selectedFilter.value),
      );
      
      final List<PrizeRecord> newRecords = response.data
          ?.map((lottery) => PrizeRecord.fromLottery(lottery))
          .toList() ?? [];
      
      if (isRefresh) {
        prizeRecords.value = newRecords;
      } else {
        prizeRecords.addAll(newRecords);
      }
      
      // 检查是否还有更多数据
      hasMore.value = newRecords.length >= pageSize;
      if (hasMore.value) {
        currentPage++;
      }
      
    } catch (e) {
      hasError.value = true;
      errorMessage.value = StrRes.loadFailedRetry;
      Logger.print('加载奖品记录失败: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // 根据筛选条件获取状态参数
  int? _getStatusFromFilter(String filter) {
    switch (filter) {
      case 'delivered':
        return 1;
      case 'pending':
        return 0;
      default:
        return 1; // 默认返回已发放状态
    }
  }

  // 筛选奖品记录
  List<PrizeRecord> get filteredRecords {
    return prizeRecords;
  }

  // 设置筛选条件
  void setFilter(String filter) {
    if (selectedFilter.value != filter) {
      selectedFilter.value = filter;
      // 切换筛选条件时重新加载数据
      prizeRecords.clear();
      currentPage = 1;
      hasMore.value = true;
      loadPrizeRecords(isRefresh: true);
    }
  }

  // 刷新数据
  Future<void> refresh() async {
    await loadPrizeRecords(isRefresh: true);
  }

  // 加载更多数据
  Future<void> loadMore() async {
    if (!isLoading.value && hasMore.value) {
      await loadPrizeRecords();
    }
  }

  // 格式化时间显示
  String formatTime(DateTime time) {
    return IMUtils.getChatTimeline(time.millisecondsSinceEpoch);
  }
}