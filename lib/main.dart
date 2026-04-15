import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter/foundation.dart';
import 'utils/log_util.dart';

import 'app.dart';

void main() {
  runZonedGuarded(() {
    // 初始化日志工具
    _initLogger();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      LogUtil.e('FlutterError', details.exception.toString(), details.exception, details.stack);
      Logger.print('FlutterError: ${details.exception.toString()}, ${details.stack.toString()}');
    };

    Config.init(() => runApp(const ChatApp()));
  }, (error, stackTrace) {
    LogUtil.e('ZoneError', error.toString(), error, stackTrace);
    Logger.print('FlutterError: ${error.toString()}, ${stackTrace.toString()}');
  });
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
