import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/lottery_ticket.dart' as lottery_model;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'lottery_tickets_logic.dart';

class LotteryTicketsView extends StatelessWidget {
  final logic = Get.find<LotteryTicketsLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      appBar: TitleBar.back(
        title: StrRes.myTickets,
        right: GestureDetector(
          onTap: logic.toPrizeRecords,
          child: Text(StrRes.winningRecords),
        ),
      ),
      body: Obx(() {
        if (logic.isLoading.value && logic.tickets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (logic.errorMessage.value.isNotEmpty && logic.tickets.isEmpty) {
          return _buildErrorState();
        }

        if (logic.tickets.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: logic.refreshTickets,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // 触底加载更多
              if (scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent &&
                  !logic.isLoading.value) {
                logic.loadMoreTickets();
              }
              return true;
            },
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: logic.tickets.length +
                  (logic.isLoading.value && logic.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == logic.tickets.length) {
                  return _buildLoadingMoreIndicator();
                }
                final ticket = logic.tickets[index];
                return _buildTicketCard(ticket, index);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_num_outlined,
            size: 80.w,
            color: Styles.c_8E9AB0,
          ),
          SizedBox(height: 16.h),
          Text(
            StrRes.noTickets,
            style: Styles.ts_8E9AB0_16sp,
          ),
          SizedBox(height: 8.h),
          Text(
            StrRes.participateToGetTickets,
            style: Styles.ts_8E9AB0_14sp,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.w,
            color: Styles.c_8E9AB0,
          ),
          SizedBox(height: 16.h),
          Text(
            StrRes.loadFailed,
            style: Styles.ts_8E9AB0_16sp,
          ),
          SizedBox(height: 8.h),
          Text(
            logic.errorMessage.value,
            style: Styles.ts_8E9AB0_14sp,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: logic.refreshTickets,
            child: Text(StrRes.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(lottery_model.LotteryTicket ticket, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Styles.c_000000_opacity4,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            // 渐变背景
            _buildGradientBackground(ticket),
            // 装饰图案
            _buildDecorationPattern(),
            // 内容区域
            _buildTicketContent(ticket),
            // 状态标签
            if (!ticket.isActive) _buildStatusOverlay(ticket),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground(lottery_model.LotteryTicket ticket) {
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
    ];

    final colorIndex = (ticket.id?.hashCode ?? 0).abs() % gradients.length;
    final colors = gradients[colorIndex];

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ticket.isActive
                ? colors
                : [Colors.grey.shade400, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildDecorationPattern() {
    return Positioned(
      right: -20.w,
      top: -10.h,
      child: Opacity(
        opacity: 0.1,
        child: Icon(
          Icons.confirmation_num,
          size: 100.w,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTicketContent(lottery_model.LotteryTicket ticket) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 奖券名称
          Row(
            children: [
              Icon(
                Icons.local_activity,
                color: Colors.white,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  ticket.displayName,
                  style: Styles.ts_FFFFFF_17sp_semibold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // 使用说明
          Text(
            ticket.displayDescription,
            style: Styles.ts_FFFFFF_opacity70_14sp,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 16.h),

          // 底部信息栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 有效期信息
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 14.w,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      ticket.statusText,
                      style: Styles.ts_FFFFFF_12sp,
                    ),
                  ],
                ),
              ),

              // 使用按钮
              if (ticket.isActive)
                GestureDetector(
                  onTap: () => logic.useTicket(ticket.id),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      StrRes.useNow,
                      style: TextStyle(
                        color: Styles.c_0089FF,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay(lottery_model.LotteryTicket ticket) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                ticket.use == true ? StrRes.used : StrRes.expired,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            StrRes.loadingMore,
            style: Styles.ts_8E9AB0_14sp,
          ),
        ],
      ),
    );
  }
}
