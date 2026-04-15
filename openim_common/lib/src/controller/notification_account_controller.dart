import 'package:get/get.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

/// 通知账号信息缓存管理控制器
class NotificationAccountController extends GetxController {
  // 通知账号信息缓存，key为userID，value为用户信息
  final Map<String, CachedUserInfo> _userCache = {};

  // 正在请求的用户ID集合，避免重复请求
  final Set<String> _requestingIds = {};

  /// 获取缓存的用户信息，如果缓存不存在或已过期则返回null
  PublicUserInfo? getCachedUserInfo(String? userID) {
    if (userID == null || userID.isEmpty) return null;

    if (_userCache.containsKey(userID) && !_userCache[userID]!.isExpired) {
      return _userCache[userID]!.userInfo;
    }

    return null;
  }

  /// 获取通知账号信息，优先返回缓存，异步更新
  Future<PublicUserInfo?> getNotificationAccount(String? userID) async {
    // 空值检查
    if (userID == null || userID.isEmpty) return null;

    // 1. 检查并返回有效缓存
    if (_userCache.containsKey(userID) && !_userCache[userID]!.isExpired) {
      return _userCache[userID]!.userInfo;
    }

    // 2. 返回过期缓存，但同时异步更新
    final hasExpiredCache = _userCache.containsKey(userID);

    // 3. 异步更新缓存
    _fetchUserInfo(userID);

    // 4. 如果有过期缓存，返回过期缓存
    return hasExpiredCache ? _userCache[userID]!.userInfo : null;
  }

  /// 批量预加载通知账号信息
  Future<void> preloadNotificationAccounts(List<String?> userIDs) async {
    for (var userID in userIDs) {
      if (!_userCache.containsKey(userID) || _userCache[userID]!.isExpired) {
        _fetchUserInfo(userID);
      }
    }
  }

  /// 异步获取用户信息并更新缓存
  Future<void> _fetchUserInfo(String? userID) async {
    // 空值检查
    if (userID == null || userID.isEmpty) return;

    // 避免重复请求
    if (_requestingIds.contains(userID)) return;

    try {
      _requestingIds.add(userID);

      final result = await OpenIM.iMManager.userManager.getUsersInfo(
        userIDList: [userID],
      );

      if (result.isNotEmpty) {
        _userCache[userID] = CachedUserInfo(result.first);

        // 通知UI更新
        update([userID]);
      }
    } catch (e) {
      // 请求失败，保留旧缓存
      Logger.print('获取通知账号信息失败: $e');
    } finally {
      _requestingIds.remove(userID);
    }
  }

  /// 清除缓存
  void clearCache() {
    _userCache.clear();
    _requestingIds.clear();
  }

  /// 清除特定用户ID的缓存
  void clearUserCache(String userID) {
    _userCache.remove(userID);
    update([userID]);
  }
}

/// 带过期时间的缓存用户信息
class CachedUserInfo {
  final PublicUserInfo userInfo;
  final DateTime cacheTime;

  CachedUserInfo(this.userInfo) : cacheTime = DateTime.now();

  /// 缓存是否过期 (5分钟)
  bool get isExpired =>
    DateTime.now().difference(cacheTime).inMinutes > 5;
}