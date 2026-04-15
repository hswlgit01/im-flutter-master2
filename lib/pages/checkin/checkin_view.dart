import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 添加此导入以获取 AsyncCallback
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:table_calendar/table_calendar.dart';
import 'checkin_logic.dart';
import 'checkin_rule_widget.dart';

/// 生命周期事件处理器，用于监听应用的生命周期变化
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? suspendingCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) {
          await resumeCallBack!();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) {
          await suspendingCallBack!();
        }
        break;
      default:
        break;
    }
  }
}

class SignInView extends StatefulWidget {
  @override
  _SignInViewState createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final logic = Get.find<SignInLogic>();
  LifecycleEventHandler? lifecycleObserver;

  @override
  void initState() {
    super.initState();

    // 创建生命周期观察者
    lifecycleObserver = LifecycleEventHandler(
      resumeCallBack: () async {
        // 当应用重新获取焦点时刷新签到数据
        logic.onResume();
      },
    );

    // 注册观察者
    WidgetsBinding.instance.addObserver(lifecycleObserver!);
  }

  @override
  void dispose() {
    // 移除观察者，避免内存泄漏
    if (lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(lifecycleObserver!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = 64.h + mq.padding.top;

    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.checkin,
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        padding: EdgeInsets.only(top: top, right: 16.w, left: 16.w, bottom: 16.h),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD1E7F9),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        // 使用SingleChildScrollView包装内容，使页面可滚动
        child: Obx(() {
          // 如果正在初始化加载，显示加载效果
          if (logic.isInitialLoading.value) {
            return Transform.translate(
              offset: Offset(0, top * -1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40.w,
                      height: 40.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 加载完成后显示正常内容
          return SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StrRes.dailyCheckinReward,
                        style: TextStyle(
                            fontSize: 24.sp, fontWeight: FontWeight.w500),
                      ),
                      8.verticalSpace,
                      GestureDetector(
                        onTap: () => logic.toLotteryTicketsPage(),
                        child: Row(
                          children: [
                            Text(
                              StrRes.myRewards,
                              style: Styles.ts_0C1C33_12sp,
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12.sp,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  // 连续签到天数显示
                  Obx(() => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              StrRes.consecutiveCheckin,
                              style: Styles.ts_FFFFFF_10sp,
                            ),
                            2.verticalSpace,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${logic.consecutiveSignInDays.value}",
                                  style: Styles.ts_FFFFFF_16sp.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                2.horizontalSpace,
                                Text(
                                  StrRes.day,
                                  style:
                                      Styles.ts_FFFFFF_opacity70_14sp.copyWith(
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                ],
              ),
              20.verticalSpace,
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Styles.c_FFFFFF,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: TableCalendar(
                  focusedDay: DateTime.now(),
                  firstDay: DateTime.utc(2012, 1, 1),
                  lastDay: DateTime.now(),
                  onPageChanged: (focusedDay) =>
                      logic.onPageChanged(focusedDay),
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month'
                  },
                  headerStyle: const HeaderStyle(titleCentered: true),
                  locale: Get.locale == null
                      ? "en_US"
                      : "${Get.locale!.languageCode}_${Get.locale!.countryCode}",
                  calendarBuilders: CalendarBuilders(
                    // 自定义星期显示 - 英语首字母大写
                    dowBuilder: (context, day) {
                      const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                      // day.weekday 返回 1(Monday) 到 7(Sunday)
                      // 我们需要转换为 0(Sunday) 到 6(Saturday)
                      final index = day.weekday % 7;
                      return Center(
                        child: Text(
                          weekdays[index],
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                    // 历史签到日期的显示
                    defaultBuilder: (context, day, focusedDay) {
                      // 只有已签到的日期才显示特殊样式
                      if (logic.isDateSignedIn(day)) {
                        return Center(
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFF52C41A), // 柔和的绿色，表示已签到
                              shape: BoxShape.circle,
                            ),
                            child: ImageRes.signinSuccess.toImage
                              ..width = 20.w
                              ..height = 20.h
                              ..color = Styles.c_FFFFFF,
                          ),
                        );
                      }
                      // 返回 null 表示使用默认样式
                      return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Styles.c_0089FF,
                            shape: BoxShape.circle,
                          ),
                          child: Obx(() {
                            // 确保动画已初始化
                            if (!logic.isAnimationReady.value) {
                              return Text(
                                '${day.day}',
                                style: Styles.ts_FFFFFF_16sp,
                              );
                            }

                            // 如果今天已经签到，直接显示签到成功图标
                            if (logic.isSignedIn.value) {
                              return ImageRes.signinSuccess.toImage
                                ..width = 20.w
                                ..height = 20.h
                                ..color = Styles.c_FFFFFF;
                            }

                            // 如果今天未签到，显示翻转动画
                            return AnimatedBuilder(
                              animation: logic.flipAnimation,
                              builder: (context, child) {
                                // 计算翻转角度
                                final rotationValue =
                                    logic.flipAnimation.value * 180;

                                // 当角度超过90度时显示签到成功图标，否则显示数字
                                final showSuccess = rotationValue >= 90;

                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // 透视效果
                                    ..rotateY(rotationValue * 3.14159 / 180),
                                  child: showSuccess
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()
                                            ..rotateY(3.14159), // 翻转180度使图标正向显示
                                          child: ImageRes.signinSuccess.toImage
                                            ..width = 20.w
                                            ..height = 20.h
                                            ..color = Styles.c_FFFFFF,
                                        )
                                      : Text(
                                          '${day.day}',
                                          style: Styles.ts_FFFFFF_16sp,
                                        ),
                                );
                              },
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ),
              20.verticalSpace,
              // 先放置签到按钮
              Container(
                width: double.infinity,
                height: 44.h,
                child: Obx(() {
                  return ElevatedButton(
                    onPressed: (logic.isSigningIn.value ||
                            !logic.isAnimationReady.value ||
                            logic.isSignedIn.value)
                        ? null
                        : () {
                            // 执行签到
                            logic.performSignIn();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: logic.isSignedIn.value
                          ? const Color(0xFF52C41A)
                          : Styles.c_0089FF,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child: logic.isSigningIn.value
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Styles.c_FFFFFF),
                            ),
                          )
                        : Text(
                            logic.isSignedIn.value
                                ? StrRes.complete
                                : StrRes.checkin,
                            style: Styles.ts_FFFFFF_16sp,
                          ),
                  );
                }),
              ),
              20.verticalSpace,
              // 然后放置签到规则说明组件
              CheckinRuleWidget(),
            ],
          ),
          );
        }),
      ),
    );
  }
}
