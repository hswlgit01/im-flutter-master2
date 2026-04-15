import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

class Logger {
  static Logger? _instance;

  factory Logger() {
    final instance = _instance ??= Logger._();
    instance._setPlatformInfo();

    return instance;
  }

  Logger._();

  void _setPlatformInfo() async {
    final pkg = DeviceInfoPlugin();
    final deviceInfo = await pkg.deviceInfo;

    if (deviceInfo is AndroidDeviceInfo) {
      final apiVersion = deviceInfo.version.sdkInt;

      _header = '[*flutter*Android/$apiVersion]';
    } else if (deviceInfo is IosDeviceInfo) {
      final osVersion = deviceInfo.systemVersion;

      _header = '[*flutter*iOS/$osVersion]';
    }
  }

  String _header = '*flutter*iOS';

  static void print(dynamic text,
      {bool isError = false,
      String? fileName,
      String? functionName,
      String? errorMsg,
      List<dynamic>? keyAndValues,
      bool onlyConsole = false}) {
    final time = DateTime.now().toIso8601String();

    log(
      '$time ${Logger()._header} [Console]: $text, ${keyAndValues != null ? ', $keyAndValues' : ''}, isError [${isError || errorMsg != null}]',
    );
    if (!onlyConsole) {
      // OpenIM 日志上报是异步的，这里要显式处理 Future 的错误，
      // 否则 PlatformException 会以未捕获异常的形式在 Zone 里抛出。
      OpenIM.iMManager
          .logs(
            msgs:
                '$time ${Logger()._header} [${functionName ?? ''}]: $text, ${keyAndValues != null ? ', $keyAndValues' : ''}',
            err: errorMsg,
            keyAndValues: keyAndValues ?? [],
          )
          .catchError((e) {
        if (e is PlatformException && e.code == '10006') {
          // OpenIM 原生 SDK 未初始化(10006)或尚未就绪时会报错，忽略避免刷屏
          return;
        }
        // 其他错误仍然抛到 Zone 里，方便在开发阶段发现问题
        Error.throwWithStackTrace(e, StackTrace.current);
      });
    }
  }
}
