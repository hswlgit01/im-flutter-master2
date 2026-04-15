import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/checkin_reward.dart';
import 'checkin_rewards_logic.dart';

class CheckinRewardsView extends StatelessWidget {
  final logic = Get.find<CheckinRewardsLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: TitleBar.back(
        title: StrRes.checkinReward,
        backgroundColor: Colors.white,
      ),
      body: Obx(() {
        if (logic.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0089FF)),
            ),
          );
        }

        if (logic.rewardsList.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: logic.refreshData,
          color: const Color(0xFF0089FF),
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: logic.rewardsList.length + (logic.hasMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              // 如果是最后一项且还有更多数据，显示加载更多
              if (index == logic.rewardsList.length) {
                return _buildLoadMoreWidget();
              }
              
              final reward = logic.rewardsList[index];
              return _buildRewardItem(reward, index);
            },
          ),
        );
      }),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 80.w,
            color: const Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16.h),
          Text(
            StrRes.noCheckinRewards,
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF999999),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            StrRes.goCheckinToGetRewards,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建奖励项
  Widget _buildRewardItem(CheckinReward reward, int index) {
    final typeDisplay = logic.getRewardTypeDisplay(reward);
    final statusDisplay = logic.getRewardStatusDisplay(reward);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // 左侧图标
            _buildRewardIcon(typeDisplay),
            SizedBox(width: 12.w),
            
            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 奖励名称
                  Text(
                    logic.getRewardName(reward),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  
                  // 时间和类型
                  Row(
                    children: [
                      Text(
                        logic.formatTime(reward.createdAt),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      // 只在中文环境下显示类型标签，英语文本太长会影响布局
                      if (Get.locale?.languageCode != 'en') ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(typeDisplay).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            typeDisplay.displayName,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: _getTypeColor(typeDisplay),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // 右侧金额和状态
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 金额
                Text(
                  logic.formatRewardAmount(reward),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0089FF),
                  ),
                ),
                SizedBox(height: 4.h),
                
                // 状态
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusDisplay).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    statusDisplay.displayName,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: _getStatusColor(statusDisplay),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建奖励图标
  Widget _buildRewardIcon(RewardTypeDisplay type) {
    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: _getTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Icon(
        _getTypeIcon(type),
        size: 24.w,
        color: _getTypeColor(type),
      ),
    );
  }

  /// 获取类型图标
  IconData _getTypeIcon(RewardTypeDisplay type) {
    switch (type) {
      case RewardTypeDisplay.cash:
        return Icons.monetization_on;
      case RewardTypeDisplay.lottery:
        return Icons.confirmation_number;
      case RewardTypeDisplay.integral:
        return Icons.stars;
      case RewardTypeDisplay.other:
        return Icons.card_giftcard;
    }
  }

  /// 获取类型颜色
  Color _getTypeColor(RewardTypeDisplay type) {
    switch (type) {
      case RewardTypeDisplay.cash:
        return const Color(0xFF4CAF50);
      case RewardTypeDisplay.lottery:
        return const Color(0xFFFF9800);
      case RewardTypeDisplay.integral:
        return const Color(0xFF2196F3);
      case RewardTypeDisplay.other:
        return const Color(0xFF9C27B0);
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(RewardStatusDisplay status) {
    switch (status) {
      case RewardStatusDisplay.apply:
        return const Color(0xFF4CAF50);
      case RewardStatusDisplay.pending:
        return const Color(0xFFFF9800);
    }
  }

  /// 构建加载更多Widget
  Widget _buildLoadMoreWidget() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Obx(() => GestureDetector(
          onTap: logic.isLoadingMore.value ? null : logic.loadMoreData,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0089FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logic.isLoadingMore.value) ...[
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0089FF)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Text(
                  logic.isLoadingMore.value ? StrRes.loading : StrRes.loadMoreRewards,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF0089FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }
}