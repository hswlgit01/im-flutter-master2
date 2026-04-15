import 'dart:io';

import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/lottery_ticket.dart' as lottery_model;
import 'package:sprintf/sprintf.dart';

// 扩展 API 返回的 LotteryTicket 模型
extension LotteryTicketExtension on lottery_model.LotteryTicket {
  // 获取名称
  String get displayName => lotteryInfo?.name ?? StrRes.unknownTicket;

  // 获取描述
  String get displayDescription => lotteryInfo?.desc ?? "";

  // 获取有效天数
  int get validDays => lotteryInfo?.validDays ?? 0;

  // 获取创建时间
  DateTime get ticketCreatedAt {
    if (createdAt == null || createdAt == "0001-01-01T00:00:00Z") {
      return DateTime.now();
    }
    try {
      return DateTime.parse(createdAt!).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  // 获取过期时间
  DateTime get expireDate {
    if (expiredAt != null && expiredAt != "0001-01-01T00:00:00Z") {
      try {
        return DateTime.parse(expiredAt!);
      } catch (e) {
        // 如果解析失败，使用创建时间 + 有效天数
        return ticketCreatedAt.add(Duration(days: validDays));
      }
    }
    return ticketCreatedAt.add(Duration(days: validDays));
  }

  // 获取剩余天数
  int get remainingDays {
    final now = DateTime.now();
    final remaining = expireDate.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // 是否已过期
  bool get isExpired {
    final now = DateTime.now();
    return expireDate.isBefore(now);
  }

  // 状态文本
  String get statusText {
    if (use == true) return StrRes.used;
    if (isExpired) return StrRes.expired;
    return sprintf(StrRes.daysUntilExpiry, [remainingDays]);
  }

  // 是否可用
  bool get isActive => use != true && !isExpired;
}

class LotteryTicketsLogic extends GetxController {
  final RxList<lottery_model.LotteryTicket> tickets =
      <lottery_model.LotteryTicket>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // 分页相关
  int _currentPage = 1;
  static const int _pageSize = 20;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadTickets();
  }

  // 加载奖券数据
  Future<void> loadTickets() async {
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await Apis.getLotterys(
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (_currentPage == 1) {
        tickets.clear();
      }

      tickets.addAll(response.data ?? []);
      hasMore.value = (response.data?.length ?? 0) >= _pageSize;
    } catch (e) {
      errorMessage.value = '${StrRes.loadFailedPrefix}${e.toString()}';
      Logger.print('${StrRes.loadTicketsFailed}: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // 刷新数据
  Future<void> refreshTickets() async {
    _currentPage = 1;
    hasMore.value = true;
    await loadTickets();
  }

  // 加载更多数据
  Future<void> loadMoreTickets() async {
    if (!hasMore.value || isLoading.value) return;

    _currentPage++;
    await loadTickets();
  }

  // 使用奖券
  void useTicket(String? ticketId) async {
    if (ticketId == null) return;

    final index = tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index != -1) {
      final ticket = tickets[index];
      if (ticket.isActive) {
        // 跳转到本地轮盘抽奖页面
        final result = await AppNavigator.startLotteryWheel(
          id: ticket.id!,
          lotteryTicketId: ticket.lotteryInfo?.id ?? '',
        );
        
        // 如果抽奖页有更新，自动刷新列表
        if (result == true) {
          refreshTickets();
        }
      } else {
        Get.snackbar(StrRes.cannotUse, StrRes.ticketExpiredOrUsed);
      }
    }
  }

  toPrizeRecords() {
    AppNavigator.startPrizeRecords();
  }
}
