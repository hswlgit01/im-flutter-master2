import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openim_common/openim_common.dart';
import 'utils/app_log_uploader.dart';
import 'utils/log_util.dart';

import 'app.dart';

Future<void> main() async {
  final appStart = runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // dawn 2026-06-22 修复安卓灰色半屏：首帧前锁定竖屏，避免系统横竖屏度量污染布局缓存。
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 初始化日志工具
    _initLogger();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      LogUtil.e('FlutterError', details.exception.toString(), details.exception,
          details.stack);
      Logger.print(
          'FlutterError: ${details.exception.toString()}, ${details.stack.toString()}');
    };

    Config.init(() {
      unawaited(AppLogUploader.instance.flush(reason: 'startup'));
      runApp(const ChatApp());
    });
  }, (error, stackTrace) {
    LogUtil.e('ZoneError', error.toString(), error, stackTrace);
    Logger.print('FlutterError: ${error.toString()}, ${stackTrace.toString()}');
  });
  if (appStart != null) {
    await appStart;
  }
}

// 初始化日志工具
void _initLogger() {
  // 在发布模式下禁用调试级别日志，仅保留更重要的日志
  if (kReleaseMode) {
    LogUtil.setLevel(LogLevel.info);
  } else {
    // 在开发和调试模式下显示所有日志
    LogUtil.setLevel(LogLevel.debug);
  }

  LogUtil.i('App', '应用启动，日志系统初始化完成');
}
