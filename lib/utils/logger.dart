import 'package:logger/logger.dart';

class ILogger {
  static final ILogger _instance = ILogger._internal();
  factory ILogger(String value) => _instance;
  ILogger._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  static void d(dynamic message, [dynamic message2]) {
    if (message2 != null &&
        (message is String || message is num || message is bool)) {
      _instance._logger.d('${message}: ${_deepConvert(message2)}');
    } else {
      _instance._logger.d(_deepConvert(message));
    }
  }

  static bool _hasToJsonMethod(dynamic obj) {
    try {
      final toJson = obj.toJson;
      return toJson is Function;
    } catch (e) {
      return false;
    }
  }

  static dynamic _deepConvert(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is Map) {
      return _convertMap(value);
    } else if (value is List) {
      return _convertList(value);
    } else if (value is String || value is num || value is bool) {
      return value;
    } else if (_hasToJsonMethod(value)) {
      return value.toJson();
    } else {
      return value.toString();
    }
  }

  static Map _convertMap(Map map) {
    return Map.fromEntries(map.entries.map((entry) {
      return MapEntry(entry.key, _deepConvert(entry.value));
    }));
  }

  static List _convertList(List list) {
    return list.map(_deepConvert).toList();
  }

  // static void d(dynamic message) => _instance._logger.d( const JsonEncoder.withIndent('  ').convert(message.toJson()));
  static void i(dynamic message) => _instance._logger.i(message);
  static void w(dynamic message) => _instance._logger.w(message);
  static void e(String message, [dynamic error]) =>
      _instance._logger.e(message, error: error);
}
