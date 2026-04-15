import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'checkin_rule_description_logic.dart';

class CheckinRuleDescriptionView extends StatelessWidget {
  final logic = Get.find<CheckinRuleDescriptionLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: TitleBar.back(
        title: StrRes.checkinRuleDescription,
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

        if (logic.hasError.value) {
          return _buildErrorState();
        }

        final rule = logic.rule.value;

        return RefreshIndicator(
          onRefresh: logic.refreshData,
          color: const Color(0xFF0089FF),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                // 主要内容卡片
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Html(
                      data: logic.ruleDescription.value,
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(14.sp),
                          color: Styles.c_0C1C33,
                        ),
                        "p": Style(
                          margin: Margins.only(bottom: 8),
                        ),
                        "h1,h2,h3,h4,h5,h6": Style(
                          color: Styles.c_0C1C33,
                          fontWeight: FontWeight.bold,
                        ),
                        "strong": Style(
                          fontWeight: FontWeight.bold,
                        ),
                        "ul,ol": Style(
                          margin: Margins.only(left: 20, bottom: 10, top: 10),
                        ),
                        "li": Style(
                          margin: Margins.only(bottom: 5),
                        ),
                      },
                    ),
                  ),
                ),

                // 连续签到奖励卡片（如果有）
                if (rule != null && rule.enableStreakRewards && rule.streakRewards.isNotEmpty)
                  _buildStreakRewardsCard(rule),

                // 更新时间
                if (rule != null && rule.updatedAt.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 10.h, bottom: 16.h),
                    child: Text(
                      '最后更新: ${_formatDateTime(rule.updatedAt)}',
                      style: TextStyle(
                        color: Styles.c_8E9AB0,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // 连续签到奖励卡片
  Widget _buildStreakRewardsCard(CheckinRule rule) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '连续签到奖励',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Styles.c_0C1C33,
                ),
              ),
              Divider(height: 24.h, color: Styles.c_E8EAEF),
              ...rule.streakRewards
                  .where((reward) => reward.days > 0 && reward.bonusPercentage > 0)
                  .map((reward) => _buildRewardItem(reward))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  // 连续签到奖励项
  Widget _buildRewardItem(StreakReward reward) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Styles.c_0089FF.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${reward.days}天',
                style: TextStyle(
                  color: Styles.c_0089FF,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续签到${reward.days}天',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Styles.c_0C1C33,
                  ),
                ),
                4.verticalSpace,
                Text(
                  '奖励增加${reward.bonusPercentage}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Styles.c_8E9AB0,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.celebration_outlined,
            color: reward.bonusPercentage >= 50
                ? Colors.orange
                : Styles.c_0089FF,
            size: 24.sp,
          ),
        ],
      ),
    );
  }

  // 格式化日期时间
  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 60.sp,
            color: Styles.c_8E9AB0,
          ),
          16.verticalSpace,
          Text(
            logic.errorMessage.value.isEmpty
                ? StrRes.loadFailed
                : '${StrRes.loadFailed}: ${logic.errorMessage.value}',
            style: Styles.ts_8E9AB0_14sp,
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          TextButton(
            onPressed: logic.refreshData,
            style: TextButton.styleFrom(
              backgroundColor: Styles.c_0089FF,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              StrRes.retry,
              style: Styles.ts_FFFFFF_14sp,
            ),
          ),
        ],
      ),
    );
  }
}