import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../utils/log_util.dart';

/// Shorebird 热更新管理器
///
/// 使用方法:
/// 1. 在应用启动时调用 HotUpdateManager().checkUpdateOnStartup()
/// 2. 在设置页面手动调用 about_us_logic.dart 中的方法
class HotUpdateManager {
  static final HotUpdateManager _instance = HotUpdateManager._internal();
  factory HotUpdateManager() => _instance;
  HotUpdateManager._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  // 更新状态管理,防止并发冲突
  bool _isCheckingUpdate = false;
  bool _isDownloadingUpdate = false;
  DateTime? _lastCheckTime;

  /// 检查 Shorebird 是否可用
  Future<bool> isShorebirdAvailable() async {
    try {
      final available = await _updater.isAvailable;
      LogUtil.i('HotUpdateManager', 'Shorebird 可用性检查: $available');
      return available;
    } catch (e) {
      LogUtil.e('HotUpdateManager', 'Shorebird 可用性检查失败', e);
      return false;
    }
  }

  /// 获取当前补丁信息
  Future<String> getCurrentPatchNumber() async {
    try {
      final available = await isShorebirdAvailable();
      if (!available) {
        LogUtil.i('HotUpdateManager', '获取补丁号: Shorebird 不可用');
        return 'N/A';
      }

      final patch = await _updater.readCurrentPatch();
      if (patch != null && patch.number != null) {
        LogUtil.i('HotUpdateManager', '当前补丁号: ${patch.number}');
        return patch.number.toString();
      } else {
        LogUtil.i('HotUpdateManager', '当前无补丁');
        return 'None';
      }
    } catch (e) {
      LogUtil.e('HotUpdateManager', '获取补丁号失败', e);
      return 'Error';
    }
  }

  /// 应用启动时检查更新状态并主动提醒用户
  ///
  /// 工作模式:
  /// - 静默检查是否有新补丁
  /// - 如果有新版本，通过回调通知 UI 层显示更新对话框
  /// - 用户可以选择立即更新或稍后更新
  ///
  /// 参数:
  /// - onUpdateAvailable: 发现新版本时的回调函数，参数为当前补丁号
  Future<void> checkUpdateOnStartup({
    Function(String currentVersion)? onUpdateAvailable,
  }) async {
    LogUtil.i('HotUpdateManager', '========================================');
    LogUtil.i('HotUpdateManager', '应用启动时检查更新开始');
    LogUtil.i('HotUpdateManager', '========================================');

    // 防止并发检查
    if (_isCheckingUpdate) {
      LogUtil.w('HotUpdateManager', '更新检查已在进行中,忽略重复调用');
      return;
    }

    _isCheckingUpdate = true;
    try {
      // 检查 Shorebird 是否可用
      final available = await isShorebirdAvailable();
      if (!available) {
        LogUtil.w('HotUpdateManager', 'Shorebird 不可用,跳过更新检查');
        LogUtil.i('HotUpdateManager', '========================================');
        return;
      }

      // 获取当前补丁信息
      final currentPatchNumber = await getCurrentPatchNumber();
      LogUtil.i('HotUpdateManager', '启动时补丁状态: $currentPatchNumber');

      // 检查是否有新补丁
      LogUtil.i('HotUpdateManager', '开始检查服务器补丁...');
      final updateStatus = await _updater.checkForUpdate();
      LogUtil.i('HotUpdateManager', '服务器补丁状态: $updateStatus');

      // 记录检查时间
      _lastCheckTime = DateTime.now();

      if (updateStatus == UpdateStatus.outdated) {
        LogUtil.i('HotUpdateManager', '发现新补丁可用,准备提醒用户');

        // 等待500ms确保 SDK 释放内部资源
        LogUtil.i('HotUpdateManager', '等待 SDK 释放资源...');
        await Future.delayed(const Duration(milliseconds: 500));

        // 调用回调，通知 UI 层有新版本
        onUpdateAvailable?.call(currentPatchNumber);
      } else if (updateStatus == UpdateStatus.upToDate) {
        LogUtil.i('HotUpdateManager', '当前已是最新版本,无需更新');
      } else if (updateStatus == UpdateStatus.unavailable) {
        LogUtil.w('HotUpdateManager', 'Shorebird 服务不可用');
      } else {
        LogUtil.w('HotUpdateManager', '未知的更新状态: $updateStatus');
      }
    } catch (e, stackTrace) {
      LogUtil.e('HotUpdateManager', '启动时更新检查失败', e, stackTrace);
    } finally {
      _isCheckingUpdate = false;
    }

    LogUtil.i('HotUpdateManager', '========================================');
    LogUtil.i('HotUpdateManager', '应用启动时检查更新结束');
    LogUtil.i('HotUpdateManager', '========================================');
  }

  /// 下载更新补丁并返回是否成功
  ///
  /// 用于自动更新流程中用户选择"立即更新"后下载补丁
  /// 也可用于手动更新场景
  ///
  /// 返回:
  /// - true: 下载成功
  /// - false: 下载失败（Shorebird 不可用或下载异常）
  Future<bool> downloadUpdateWithProgress() async {
    LogUtil.i('HotUpdateManager', '========================================');
    LogUtil.i('HotUpdateManager', '开始下载更新补丁');
    LogUtil.i('HotUpdateManager', '========================================');

    // 防止并发下载
    if (_isDownloadingUpdate) {
      LogUtil.w('HotUpdateManager', '补丁下载已在进行中,忽略重复调用');
      return false;
    }

    _isDownloadingUpdate = true;
    try {
      final available = await isShorebirdAvailable();
      if (!available) {
        LogUtil.w('HotUpdateManager', 'Shorebird 不可用,无法下载补丁');
        return false;
      }

      // 如果刚检查完更新,额外等待确保 SDK 状态完全释放
      if (_lastCheckTime != null) {
        final timeSinceCheck = DateTime.now().difference(_lastCheckTime!);
        if (timeSinceCheck.inMilliseconds < 1000) {
          final waitTime = 1000 - timeSinceCheck.inMilliseconds;
          LogUtil.i('HotUpdateManager', '距上次检查仅 ${timeSinceCheck.inMilliseconds}ms, 等待 ${waitTime}ms 确保 SDK 就绪...');
          await Future.delayed(Duration(milliseconds: waitTime));
        }
      }

      LogUtil.i('HotUpdateManager', '调用 Shorebird SDK 下载补丁...');
      final downloadStartTime = DateTime.now();

      await _updater.update();

      final downloadDuration = DateTime.now().difference(downloadStartTime);
      LogUtil.i('HotUpdateManager', '补丁下载完成,耗时: ${downloadDuration.inSeconds}秒');

      LogUtil.i('HotUpdateManager', '========================================');
      return true;
    } catch (e, stackTrace) {
      LogUtil.e('HotUpdateManager', '补丁下载失败', e, stackTrace);
      LogUtil.i('HotUpdateManager', '========================================');
      return false;
    } finally {
      _isDownloadingUpdate = false;
    }
  }
}
