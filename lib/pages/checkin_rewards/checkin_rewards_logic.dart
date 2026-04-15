import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/checkin_reward.dart';

// 本地奖励类型枚举，用于UI显示
enum RewardTypeDisplay {
  lottery('lottery'),
  cash('cash'),
  integral('integral'),
  other('other');

  const RewardTypeDisplay(this.typeKey);
  final String typeKey;

  String get displayName {
    switch (this) {
      case RewardTypeDisplay.lottery:
        return StrRes.lotteryReward;
      case RewardTypeDisplay.cash:
        return StrRes.cashReward;
      case RewardTypeDisplay.integral:
        return StrRes.pointReward;
      case RewardTypeDisplay.other:
        return StrRes.otherReward;
    }
  }

  static RewardTypeDisplay fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'lottery':
        return RewardTypeDisplay.lottery;
      case 'cash':
        return RewardTypeDisplay.cash;
      case 'integral':
      case 'points':
        return RewardTypeDisplay.integral;
      default:
        return RewardTypeDisplay.other;
    }
  }
}

// 本地奖励状态枚举，用于UI显示
enum RewardStatusDisplay {
  apply('apply'),
  pending('pending');

  const RewardStatusDisplay(this.statusKey);
  final String statusKey;

  String get displayName {
    switch (this) {
      case RewardStatusDisplay.apply:
        return StrRes.rewardApplied;
      case RewardStatusDisplay.pending:
        return StrRes.rewardPending;
    }
  }

  static RewardStatusDisplay fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'apply':
        return RewardStatusDisplay.apply;
      case 'pending':
        return RewardStatusDisplay.pending;
      default:
        return RewardStatusDisplay.pending;
    }
  }
}

class CheckinRewardsLogic extends GetxController {
  // 奖励列表 - 使用API模型
  final rewardsList = <CheckinReward>[].obs;

  // 加载状态
  final isLoading = true.obs;

  // 是否正在加载更多
  final isLoadingMore = false.obs;

  // 分页参数
  int currentPage = 1;
  final int pageSize = 20;

  // 是否还有更多数据
  final hasMore = true.obs;

  // 总数
  final total = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadRewardsData();
  }

  /// 加载奖励数据
  Future<void> loadRewardsData({bool isRefresh = false}) async {
    if (isRefresh) {
      currentPage = 1;
      hasMore.value = true;
    }

    isLoading.value = true;

    try {
      final response = await Apis.getCheckinRewards(
        page: currentPage,
        pageSize: pageSize,
      );

      if (response.data != null) {
        if (isRefresh) {
          rewardsList.clear();
        }

        rewardsList.addAll(response.data!);
        total.value = response.total ?? 0;

        // 判断是否还有更多数据
        hasMore.value = rewardsList.length < total.value;

        if (!isRefresh) {
          currentPage++;
        }
      }
    } catch (e) {
      print('加载签到奖励失败: $e');
      IMViews.showToast(StrRes.checkinNetworkError);
    } finally {
      isLoading.value = false;
    }
  }

  /// 刷新数据
  Future<void> refreshData() async {
    await loadRewardsData(isRefresh: true);
  }

  /// 加载更多数据
  Future<void> loadMoreData() async {
    if (!hasMore.value || isLoading.value) return;
    isLoadingMore.value = true; // 开始加载更多数据

    // 显示底部加载指示器，但不显示全屏加载
    try {
      final response = await Apis.getCheckinRewards(
        page: currentPage,
        pageSize: pageSize,
      );

      if (response.data != null && response.data!.isNotEmpty) {
        rewardsList.addAll(response.data!);
        total.value = response.total ?? 0;

        // 判断是否还有更多数据
        hasMore.value = rewardsList.length < total.value;
        currentPage++;
      } else {
        // 没有更多数据了
        hasMore.value = false;
      }
    } catch (e) {
      print('加载更多签到奖励失败: $e');
      IMViews.showToast(StrRes.checkinNetworkError);
    } finally {
      isLoadingMore.value = false; // 结束加载更多数据
    }
  }

  /// 格式化时间显示
  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return '';
    }
    final time = DateTime.parse(timeStr).toLocal();
    return IMUtils.getChatTimeline(time.millisecondsSinceEpoch);
  }

  /// 获取奖励类型显示枚举
  RewardTypeDisplay getRewardTypeDisplay(CheckinReward reward) {
    return RewardTypeDisplay.fromString(reward.type);
  }

  /// 获取奖励状态显示枚举
  RewardStatusDisplay getRewardStatusDisplay(CheckinReward reward) {
    return RewardStatusDisplay.fromString(reward.status);
  }

  /// 格式化奖励金额显示
  String formatRewardAmount(CheckinReward reward) {
    final type = getRewardTypeDisplay(reward);
    final amount = reward.amount ?? '0';

    switch (type) {
      case RewardTypeDisplay.cash:
        final currencyCode = reward.rewardCurrencyInfo?.name ?? 'CNY';
        final currencySymbol = IMUtils.getCurrencySymbol(currencyCode);
        return '$currencySymbol$amount';
      case RewardTypeDisplay.lottery:
        return '$amount${StrRes.lotteryTicket}';
      case RewardTypeDisplay.integral:
        return '$amount ${StrRes.points}';
      case RewardTypeDisplay.other:
        return amount;
    }
  }

  /// 获取奖励名称
  String getRewardName(CheckinReward reward) {
    final type = getRewardTypeDisplay(reward);

    switch (type) {
      case RewardTypeDisplay.cash:
        return StrRes.cashReward;
      case RewardTypeDisplay.lottery:
        return reward.rewardLotteryInfo?.name ?? StrRes.lotteryReward;
      case RewardTypeDisplay.integral:
        return StrRes.pointReward;
      case RewardTypeDisplay.other:
        return StrRes.otherReward;
    }
  }
}
