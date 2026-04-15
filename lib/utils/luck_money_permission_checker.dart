import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim/utils/logger.dart';

/// 红包权限检查工具类
/// 集中所有红包权限判断逻辑，确保各处判断标准一致
class LuckMoneyPermissionChecker {
  /// 检查用户是否可以查看红包详情 - 统一逻辑
  static bool canViewDetails({
    required Map<String, dynamic> data,
    required bool hasReceived,
  }) {
    Logger.print('=== 红包权限检查开始 ===');

    // 1. 发送者始终可查看
    final bool isSender = data['sender'] == OpenIM.iMManager.userID;
    Logger.print('是否发送者: $isSender (当前用户ID: ${OpenIM.iMManager.userID}, 红包发送者ID: ${data['sender']})');
    if (isSender) {
      Logger.print('发送者可以查看详情，返回true');
      return true;
    }

    // 2. 已领取者可查看
    Logger.print('是否已领取: $hasReceived');
    if (hasReceived) {
      Logger.print('已领取可以查看详情，返回true');
      return true;
    }

    // 3. 如果尚未领完且尚未过期可查看（可能还能领取）
    final expireTimeInMs = data['expire_time'] ?? 0;
    final nowTimeInMs = DateTime.now().millisecondsSinceEpoch;
    final bool isExpired = nowTimeInMs > expireTimeInMs;

    final int receivedCount = data['received_count'] ?? 0;
    final int totalCount = data['total_count'] ?? 1;
    final bool isCompleted = receivedCount >= totalCount;
    final bool isRefunded = data['status'] == 'refunded';

    Logger.print('红包过期时间: $expireTimeInMs, 当前时间: $nowTimeInMs');
    Logger.print('是否已过期: $isExpired');
    Logger.print('已领取数量: $receivedCount, 总数量: $totalCount');
    Logger.print('是否已领完: $isCompleted');
    Logger.print('是否已退还: $isRefunded');

    // 如果红包已失效且用户是旁观者，不允许查看
    if ((isCompleted || isExpired || isRefunded) && !isSender && !hasReceived) {
      Logger.print('红包已失效且用户是旁观者，不允许查看详情，返回false');
      return false;
    }

    Logger.print('红包未失效或用户不是旁观者，允许查看详情，返回true');
    return true;
  }

  /// 获取错误提示信息
  static String getErrorMessage(Map<String, dynamic> data) {
    Logger.print('=== 获取红包错误提示信息 ===');

    final int receivedCount = data['received_count'] ?? 0;
    final int totalCount = data['total_count'] ?? 1;
    final int expireTime = data['expire_time'] ?? 0;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final String status = data['status'] ?? 'unknown';

    Logger.print('已领取数量: $receivedCount, 总数量: $totalCount');
    Logger.print('过期时间: $expireTime, 当前时间: $currentTime');
    Logger.print('红包状态: $status');

    if (receivedCount >= totalCount) {
      Logger.print('返回错误: 红包已被领完');
      return StrRes.redPacketFull;
    }

    if (currentTime > expireTime) {
      Logger.print('返回错误: 红包已过期');
      return StrRes.redPacketExpired;
    }

    if (status == 'refunded') {
      Logger.print('返回错误: 红包已退回');
      return StrRes.redPacketInvalid;
    }

    Logger.print('返回默认错误: 红包无效');
    return StrRes.redPacketInvalid;
  }
}