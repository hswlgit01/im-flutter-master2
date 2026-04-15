import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// 日志工具类
/// 
/// 提供统一的日志记录接口，支持控制台打印和开发者工具日志
class LogUtil {
  /// 是否启用日志
  static bool _enabled = true;
  
  /// 日志级别
  static LogLevel _level = LogLevel.debug;
  
  /// 设置日志启用状态
  static void setEnable(bool enabled) {
    _enabled = enabled;
  }
  
  /// 设置日志级别
  static void setLevel(LogLevel level) {
    _level = level;
  }
  
  /// 输出调试级别日志
  static void d(String tag, String message) {
    if (_enabled && _level.index <= LogLevel.debug.index) {
      _print('D', tag, message);
    }
  }
  
  /// 输出信息级别日志
  static void i(String tag, String message) {
    if (_enabled && _level.index <= LogLevel.info.index) {
      _print('I', tag, message);
    }
  }
  
  /// 输出警告级别日志
  static void w(String tag, String message) {
    if (_enabled && _level.index <= LogLevel.warn.index) {
      _print('W', tag, message);
    }
  }
  
  /// 输出错误级别日志
  static void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    if (_enabled && _level.index <= LogLevel.error.index) {
      _print('E', tag, message);
      if (error != null) {
        _print('E', tag, 'Error: $error');
      }
      if (stackTrace != null) {
        _print('E', tag, 'Stack: $stackTrace');
      }
    }
  }
  
  /// 内部打印方法
  static void _print(String level, String tag, String message) {
    final logStr = '[$level/$tag] $message';
    
    // 使用debugPrint确保在控制台中按顺序显示
    debugPrint(logStr);
    
    // 使用developer.log将日志记录到开发者工具
    developer.log(message, name: tag, level: _getLevelValue(level));
  }
  
  /// 获取日志级别值
  static int _getLevelValue(String level) {
    switch (level) {
      case 'D': return 500;
      case 'I': return 800;
      case 'W': return 900;
      case 'E': return 1000;
      default: return 500;
    }
  }
}

/// 日志级别枚举
enum LogLevel {
  /// 调试级别，记录所有日志
  debug,
  
  /// 信息级别，记录信息、警告和错误
  info,
  
  /// 警告级别，只记录警告和错误
  warn,
  
  /// 错误级别，只记录错误
  error,
  
  /// 关闭所有日志
  none,
} 