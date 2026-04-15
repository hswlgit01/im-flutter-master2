import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/checkin_histore.dart';
import 'package:openim_common/src/models/checkin_reward.dart';

class SignInLogic extends GetxController
    with GetSingleTickerProviderStateMixin {
  // 签到日期处理策略：
  // 1. 所有日期以YYYY-MM-DD格式的字符串存储（例如"2026-01-12"）
  // 2. API返回的日期直接使用split('T')[0]提取日期部分，避免DateTime.parse的时区问题
  // 3. 比较日期时直接比较字符串，而不是DateTime对象
  // 4. 使用_formatDate方法统一格式化日期字符串

  // 签到状态
  final isSignedIn = false.obs;

  // 已签到的日期列表 (存储日期字符串 'yyyy-MM-dd')
  final signedInDates = <String>[].obs;

  // 动画控制器 - 使用可空类型，避免初始化问题
  AnimationController? _flipAnimationController;
  Animation<double>? _flipAnimation;

  // 获取动画的getter，确保安全访问
  AnimationController get flipAnimationController => _flipAnimationController!;
  Animation<double> get flipAnimation => _flipAnimation!;

  // 动画是否已初始化
  final isAnimationReady = false.obs;

  // 是否正在签到中
  final isSigningIn = false.obs;

  // 连续签到天数
  final consecutiveSignInDays = 0.obs;

  // 已移除查看完整规则说明方法，因为规则直接显示在页面上

  // 月份签到记录缓存 key: 'YYYY-MM', value: List<String> (签到日期列表)
  final Map<String, List<String>> _monthCheckinCache = {};

  // 正在加载的月份，避免重复请求
  final Set<String> _loadingMonths = {};

  // 是否正在初始化加载数据
  final isInitialLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimation();
    _forceRefreshCheckinData();
  }

  /// 上月1号 00:00（自然日，用于请求范围）
  /// 明确处理 1 月：上月为上年 12 月，避免跨年/时区歧义
  static DateTime _startOfPreviousMonth(DateTime now) {
    if (now.month == 1) {
      return DateTime(now.year - 1, 12, 1);
    }
    return DateTime(now.year, now.month - 1, 1);
  }

  /// 强制刷新签到数据，确保获取最新状态
  void _forceRefreshCheckinData() async {
    try {
      // 标记为加载中
      isInitialLoading.value = true;

      // 清空所有缓存数据
      _monthCheckinCache.clear();
      _loadingMonths.clear();
      signedInDates.clear();
      signedInDates.refresh();

      // 准备API请求参数：必须包含上月，否则每月1号未签到时服务端只看到当月0条记录，会错误返回 streak=0
      final now = DateTime.now();
      final startOfPreviousMonth = _startOfPreviousMonth(now);
      final endOfCurrentMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      final startTime = startOfPreviousMonth.millisecondsSinceEpoch ~/ 1000;
      final endTime = endOfCurrentMonth.millisecondsSinceEpoch ~/ 1000;

      // 请求数据（上月1号～当月末），保证连续签到天数跨月正确、每月1号不被错误清零
      final response = await Apis.queryCheckinRecord(
        startTime: startTime,
        endTime: endTime,
      );

      // 仅在有成功响应时更新连续签到天数和今日签到状态（避免请求失败时误清零）
      consecutiveSignInDays.value = response.streak;
      isSignedIn.value = response.todayCheckin != null;

      // 处理签到记录
      for (final checkin in response.checkinRecord) {
        if (checkin.date != null) {
          // 直接提取YYYY-MM-DD部分，避免DateTime.parse的时区问题
          final datePart = checkin.date!.split('T')[0];
          if (!signedInDates.contains(datePart)) {
            signedInDates.add(datePart);
          }
        }
      }

      // 添加今天的签到记录（如果有）
      if (response.todayCheckin?.date != null) {
        final todayDatePart = response.todayCheckin!.date!.split('T')[0];
        if (!signedInDates.contains(todayDatePart)) {
          signedInDates.add(todayDatePart);
        }
      }
    } catch (e) {
      // 请求失败时不重置连续签到天数和今日状态，避免网络/服务异常导致误清零
      // signedInDates 可清空以便重试后重新拉取
      signedInDates.clear();
    } finally {
      // 加载完成并刷新UI
      isInitialLoading.value = false;
      signedInDates.refresh();
    }
  }

  void _initializeAnimation() {
    // 初始化翻转动画控制器
    _flipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // 创建翻转动画
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipAnimationController!,
      curve: Curves.easeInOut,
    ));

    // 标记动画已准备好
    isAnimationReady.value = true;
  }

  /// 初始化签到数据
  void _initializeCheckinData() async {
    final now = DateTime.now();

    try {
      // 1. 先加载当前月份数据（这会调用API并缓存结果）
      await _loadCheckinDataForMonth(now, isInitialLoad: true);

      // 2. 预加载上个月数据（不阻塞UI）
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      _preloadMonthData(lastMonth);
    } catch (e) {
      print('初始化签到数据失败: $e');
      // 初始化失败时不重置连续签到天数，避免误清零
    } finally {
      // 标记初始化加载完成
      isInitialLoading.value = false;
    }
  }

  /// 获取指定月份的API响应（统一的API调用方法）
  /// 当 [month] 为当前月时，调用方应传入包含上月的 [startTime] 范围，以保证 streak 跨月正确（见 _loadCheckinDataForMonth）
  Future<CheckinHistore> _fetchCheckinApiResponse(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth =
        DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

    final startTime = startOfMonth.millisecondsSinceEpoch ~/ 1000;
    final endTime = endOfMonth.millisecondsSinceEpoch ~/ 1000;

    final response = await Apis.queryCheckinRecord(
      startTime: startTime,
      endTime: endTime,
    );

    // 仅用成功响应更新连续签到天数和今天签到状态
    consecutiveSignInDays.value = response.streak;
    isSignedIn.value = response.todayCheckin != null;

    return response;
  }

  /// 生成月份缓存key
  String _getMonthKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  /// 预加载月份数据（异步，不阻塞UI）
  void _preloadMonthData(DateTime month) {
    final monthKey = _getMonthKey(month);

    // 如果已有缓存或正在加载，则跳过
    if (_monthCheckinCache.containsKey(monthKey) ||
        _loadingMonths.contains(monthKey)) {
      return;
    }

    // 异步加载，不阻塞当前操作
    Future.microtask(() async {
      await _fetchAndCacheMonthData(month, forceRefresh: false);
    });
  }

  /// 获取并缓存月份数据
  Future<List<String>> _fetchAndCacheMonthData(DateTime month, {bool forceRefresh = false}) async {
    final monthKey = _getMonthKey(month);

    // 如果不是强制刷新，则检查缓存
    if (!forceRefresh && _monthCheckinCache.containsKey(monthKey)) {
      return _monthCheckinCache[monthKey]!;
    }

    // 如果不是强制刷新，则检查是否正在加载
    if (!forceRefresh && _loadingMonths.contains(monthKey)) {
      // 等待加载完成
      while (_loadingMonths.contains(monthKey)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _monthCheckinCache[monthKey] ?? [];
    }

    // 标记正在加载
    _loadingMonths.add(monthKey);

    try {
      // 使用统一的API调用方法
      final response = await _fetchCheckinApiResponse(month);

      // 处理并缓存签到日期数据
      final checkinDates = _extractDatesFromResponse(response, month);
      _monthCheckinCache[monthKey] = checkinDates;

      return checkinDates;
    } finally {
      // 移除加载标记
      _loadingMonths.remove(monthKey);
    }
  }

  /// 从API响应中提取签到日期
  List<String> _extractDatesFromResponse(CheckinHistore response, DateTime month) {
    final List<String> checkinDates = [];

    // 用于调试
    print('提取签到记录开始 - 当前月: ${month.year}-${month.month}');

    if (response.todayCheckin != null) {
      try {
        // 先尝试标准解析
        final parsedDate = DateTime.parse(response.todayCheckin!.date!);

        // 规范化日期，只保留年月日部分，消除时区差异
        final todayDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

        // 输出调试信息
        final formattedDate = _formatDate(todayDate);
        print('今日签到: 原始=${response.todayCheckin!.date!}, 解析后=$formattedDate');

        // 只有当今天的签到记录属于当前查询月份时才添加
        if (todayDate.year == month.year && todayDate.month == month.month) {
          checkinDates.add(formattedDate);
        }
      } catch (e) {
        print('解析今日签到日期失败: ${response.todayCheckin!.date} - $e');
      }
    }

    // 添加历史签到记录
    for (final checkin in response.checkinRecord) {
      if (checkin.date != null) {
        try {
          // 先尝试标准解析
          final parsedDate = DateTime.parse(checkin.date!);

          // 规范化日期，只保留年月日部分，消除时区差异
          final checkinDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

          // 输出调试信息
          final formattedDate = _formatDate(checkinDate);
          print('历史签到: 原始=${checkin.date!}, 解析后=$formattedDate, ID=${checkin.id}');

          checkinDates.add(formattedDate);
        } catch (e) {
          print('解析历史签到日期失败: ${checkin.date} - $e');

          // 备用方案：尝试手动解析YYYY-MM-DD格式
          try {
            final dateParts = checkin.date!.split('T')[0].split('-');
            if (dateParts.length == 3) {
              final year = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final day = int.parse(dateParts[2]);

              final checkinDate = DateTime(year, month, day);
              checkinDates.add(_formatDate(checkinDate));

              print('手动解析成功: ${_formatDate(checkinDate)}');
            }
          } catch (e2) {
            print('手动解析也失败: ${checkin.date} - $e2');
          }
        }
      }
    }

    // 最终结果日志
    print('提取完成，共${checkinDates.length}条签到记录: $checkinDates');

    return checkinDates;
  }

  /// 格式化日期为字符串 (格式: YYYY-MM-DD)
  /// 统一使用这个方法来确保日期格式的一致性
  String _formatDate(DateTime date) {
    // 确保月和日始终是两位数
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 检查指定日期是否已签到
  bool isDateSignedIn(DateTime date) {
    // 使用统一的格式化方法
    final dateString = _formatDate(date);

    // 直接比较字符串格式的日期
    return signedInDates.contains(dateString);
  }

  @override
  void onReady() {
    super.onReady();
    // 页面准备好后也进行一次刷新
    _forceRefreshCheckinData();
  }

  @override
  void onClose() {
    _flipAnimationController?.dispose();
    // 清理缓存
    _monthCheckinCache.clear();
    _loadingMonths.clear();
    super.onClose();
  }

  /// 当页面重新获得焦点时调用
  void onResume() {
    // 每次页面恢复时强制刷新数据，确保签到状态最新
    _forceRefreshCheckinData();
  }

  /// 执行签到
  performSignIn() {
    final walletController = Get.find<WalletController>();
    walletController.checkWalletetActivated(() async {
      if (isSignedIn.value || isSigningIn.value || !isAnimationReady.value) {
        return;
      }
      try {
        isSigningIn.value = true;

        // 开始翻转动画
        await _flipAnimationController!.forward();

        final result = await Apis.checkin();

        // 用服务端返回的连续签到天数回显（数据库已更新，保证与后端一致）
        consecutiveSignInDays.value = result.streak;
        isSignedIn.value = true;

        // 用服务端返回的今日签到记录更新已签到列表与缓存
        final todayStr = result.todayCheckin?.date != null
            ? result.todayCheckin!.date!.split('T')[0]
            : _formatDate(DateTime.now());
        if (!signedInDates.contains(todayStr)) {
          signedInDates.add(todayStr);
          final now = DateTime.now();
          final monthKey = _getMonthKey(now);
          if (_monthCheckinCache.containsKey(monthKey)) {
            _monthCheckinCache[monthKey]!.add(todayStr);
          }
        }

        // 生成奖励显示文本
        final rewardTexts = _generateRewardTexts(result.checkinRewards);

        // 显示签到成功提示
        showGeneralDialog(
          context: Get.context!,
          barrierLabel: "Dialog",
          barrierDismissible: true,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, anim1, anim2) => Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                            top: -25.w,
                            left: 0,
                            right: 0,
                            child: ImageRes.signinSuccessImg.toImage
                              ..width = 250.w),
                        Positioned(
                            right: 3.w,
                            top: 3.w,
                            child: IconButton(
                                onPressed: () {
                                  Get.back();
                                },
                                icon: Icon(
                                  Icons.close,
                                  color: Styles.c_8E9AB0,
                                ))),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 185.w, width: 250.w),
                            Text(
                              StrRes.congratulationsCheckinSuccess,
                              style: Styles.ts_8E9AB0_13sp,
                            ),
                            // 动态显示奖励信息
                            ...rewardTexts.map((text) => Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(text, style: Styles.ts_8E9AB0_13sp),
                            )),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Styles.c_0089FF,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.r),
                                ),
                              ),
                              onPressed: () {
                                Get.back();
                              },
                              child: SizedBox(
                                width: 150.w,
                                child: Center(
                                  child: Text(
                                    StrRes.complete,
                                    style: Styles.ts_FFFFFF_16sp,
                                  ),
                                ),
                              ),
                            ),
                            20.verticalSpace
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          transitionBuilder: (context, anim1, anim2, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: anim1,
                child: child,
              ),
            );
          },
        );
      } catch (e) {
        // 如果签到失败，重置动画
        _flipAnimationController?.reset();
        Get.snackbar(
          StrRes.checkinFailed,
          StrRes.checkinNetworkError,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFFF5252),
          colorText: Colors.white,
        );
      } finally {
        isSigningIn.value = false;
      }
    });
  }

  toLotteryTicketsPage() {
    AppNavigator.startCheckinRewards();
  }

  onPageChanged(DateTime focusedDay) {
    // 当用户切换到不同的月份时，重新获取该月份的签到记录
    _loadCheckinDataForMonth(focusedDay);

    // 预加载相邻月份数据
    final nextMonth = DateTime(focusedDay.year, focusedDay.month + 1, 1);
    final prevMonth = DateTime(focusedDay.year, focusedDay.month - 1, 1);

    _preloadMonthData(nextMonth);
    _preloadMonthData(prevMonth);
  }

  /// 加载指定月份的签到数据
  Future<void> _loadCheckinDataForMonth(DateTime month,
      {bool isInitialLoad = false}) async {
    try {
      final now = DateTime.now();
      final isCurrentMonth = month.year == now.year && month.month == now.month;

      // 当前月时请求范围必须包含上月，否则每月1号连续签到天数会被错误清零
      final DateTime rangeStart;
      final DateTime rangeEnd =
          DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
      if (isCurrentMonth) {
        rangeStart = _startOfPreviousMonth(now);
      } else {
        rangeStart = DateTime(month.year, month.month, 1);
      }
      final startTime = rangeStart.millisecondsSinceEpoch ~/ 1000;
      final endTime = rangeEnd.millisecondsSinceEpoch ~/ 1000;

      // 直接调用API获取数据
      final response = await Apis.queryCheckinRecord(
        startTime: startTime,
        endTime: endTime,
      );

      // 更新连续签到天数（仅当是当前月份的数据时）
      if (isCurrentMonth) {
        consecutiveSignInDays.value = response.streak;
        isSignedIn.value = response.todayCheckin != null;
      }

      // 初始加载时，清空所有数据
      if (isInitialLoad) {
        signedInDates.clear();
      } else {
        // 非初始加载时，仅移除该月份的旧数据
        signedInDates.removeWhere((dateStr) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final year = int.parse(parts[0]);
            final monthValue = int.parse(parts[1]);
            return year == month.year && monthValue == month.month;
          }
          return false;
        });
      }

      // 处理签到记录
      for (final checkin in response.checkinRecord) {
        if (checkin.date != null) {
          // 直接提取YYYY-MM-DD部分
          final datePart = checkin.date!.split('T')[0];

          // 添加到签到列表（如果不存在）
          if (!signedInDates.contains(datePart)) {
            signedInDates.add(datePart);
          }
        }
      }

      // 处理今日签到（如果有且是当月）
      if (response.todayCheckin?.date != null) {
        final todayDatePart = response.todayCheckin!.date!.split('T')[0];
        if (!signedInDates.contains(todayDatePart)) {
          signedInDates.add(todayDatePart);
        }
      }

      // 通知UI更新
      signedInDates.refresh();

    } catch (e) {
      // 请求失败时不重置连续签到天数，避免误清零；仅清空该次涉及的列表
      if (isInitialLoad) {
        signedInDates.clear();
      }
    }
  }

  /// 根据签到奖励数据生成显示文本
  List<String> _generateRewardTexts(List<CheckinReward> rewards) {
    final List<String> texts = [];
    
    // 直接遍历奖励数组
    for (final reward in rewards) {
      final type = reward.type;
      final amount = reward.amount ?? 0;
      
      if (type == 'cash') {
        // 现金奖励 - 直接显示金额和货币符号
        final currencyCode = reward.rewardCurrencyInfo?.name ?? 'CNY';
        final currencySymbol = IMUtils.getCurrencySymbol(currencyCode);
        texts.add(StrRes.gotReward('$currencySymbol$amount'));
      } else if (type == 'lottery') {
        // 抽奖券奖励 - 使用简洁格式
        final lotteryName = reward.rewardLotteryInfo?.name ?? StrRes.lotteryReward;
        texts.add(StrRes.gotTicket(lotteryName, amount.toString()));
      } else {
        // 其他类型奖励（如积分等）
        final displayName = _getRewardDisplayName(type);
        texts.add(StrRes.gotReward('$displayName $amount'));
      }
    }
    
    return texts;
  }

  /// 获取奖励类型的显示名称
  String _getRewardDisplayName(String? type) {
    switch (type) {
      case 'cash':
        return StrRes.cashReward;
      case 'lottery':
        return StrRes.lotteryReward;
      case 'integral':
        return StrRes.pointReward;
      default:
        return type ?? '';
    }
  }
}
