import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import 'luck_money_detail_logic.dart';

class LuckMoneyDetailPage extends StatelessWidget {
  LuckMoneyDetailPage({Key? key}) : super(key: key);
  final logic = Get.find<LuckMoneyDetailLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: logic.onRefresh,
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(height: 60.h),
                    // 顶部红包信息区
                    _buildHeader(),
                    // 分割线
                    Container(
                      width: double.infinity,
                      height: 8.h,
                      color: Color(0xFFF5F5F5),
                    ),
                    _buildBaseInfo(),
                    // 领取列表
                    Expanded(child: _buildListSection()),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCircle(),
                ),
          
                // 错误提示
                Obx(() => logic.hasError.value
                    ? Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                logic.errorMsg.value,
                                style: TextStyle(
                                  color: Color(0xFF999999),
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              TextButton(
                                onPressed: logic.onRefresh,
                                child: Text(
                                  '点击重试',
                                  style: TextStyle(
                                    color: Color(0xFFD83A3A),
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFD83A3A),
      iconTheme: IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () {
          Get.back();
        },
      ),
    );
  }

  Widget _buildCircle() {
    return Container(
      height: 46.h,
      width: double.infinity,
      color: Colors.white,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -MediaQuery.of(Get.context!).size.width, // 向左偏移屏幕宽度
              bottom: 10.h,
              child: Container(
                width: MediaQuery.of(Get.context!).size.width * 3,
                height: MediaQuery.of(Get.context!).size.width * 3,
                decoration: BoxDecoration(
                  color: Color(0xFFD83A3A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6.0,
                      spreadRadius: 1.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseInfo() {
    return Container(
        color: Colors.white,
        width: MediaQuery.of(Get.context!).size.width,
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16), // 添加左侧内边距
              child: Obx(() => Text(
                    sprintf(StrRes.redPacketSendInfo, [
                      logic.receivedCount.value,
                      logic.totalCount.value > 0 ? logic.totalCount.value : 1,
                      logic.receivedAmount.value,
                      logic.totalAmount.value,
                      logic.currency.value
                    ]),
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12.sp,
                    ),
                  )),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
        ]));
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      width: MediaQuery.of(Get.context!).size.width,
      height: 160.h,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Obx(() => Text(
                    sprintf(StrRes.formRedPacket, [logic.senderName.value]),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  )),
              SizedBox(height: 4.h),
              Obx(() => Text(
                    logic.remark.value,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                  )),
              SizedBox(height: 12.h),
              // 顶部金额区：未抢到且红包已领完时优先展示“红包已领取完”，用本地/缓存状态即可，避免先出现 0.00+已存入零钱再跳转
              Obx(() {
                final isCompleted = logic.status.value == 'completed';
                final hasReceived = logic.selfReceived.value;
                final total = logic.totalCount.value > 0 ? logic.totalCount.value : 1;
                final dataConsistent = logic.receivedCount.value >= total;

                // 已领完且本人未抢到：直接展示“红包已领取完”（含本地/缓存态，不依赖接口加载完成）
                if (isCompleted && !hasReceived) {
                  return Column(
                    children: [
                      Text(
                        '红包已领取完',
                        style: TextStyle(
                          color: const Color(0xFFD4AF37),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                // 正常情况：显示金额 + 状态文案（仅已领取时显示“已存入零钱”）
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          logic.amount.value,
                          style: TextStyle(
                            color: const Color(0xFFD4AF37),
                            fontSize: 50.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          logic.currency.value,
                          style: TextStyle(
                            color: const Color(0xFFD4AF37),
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      logic.isErrorRedirect.value
                          ? ""
                          : (hasReceived
                              ? StrRes.transferredToWallet
                              : StrRes.waitingToBeClaimed),
                      style: TextStyle(
                        color: const Color(0xFFD4AF37),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                );
              }),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildListSection() {
    return Container(
      color: Colors.white,
      child: Obx(() => logic.receivedList.isEmpty &&
              !logic.isLoading.value &&
              !logic.hasError.value
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    StrRes.noClaim,
                    style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              controller: logic.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: logic.receivedList.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 72.w,
                color: Color(0xFFF5F5F5),
              ),
              itemBuilder: (context, index) {
                final record = logic.receivedList[index];
                return _buildListItem(record);
              },
            )),
    );
  }

  Widget _buildListItem(ReceivedRecord record) {
    return ListTile(
      leading: AvatarView(
        width: 40.w,
        height: 40.w,
        text: record.userName,
        url: record.faceURL,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.userName,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${record.amount} ${logic.currency.value}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            logic.formatReceivedTime(record.receivedTime),
            style: TextStyle(
              color: Color(0xFF9B9B9B),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
