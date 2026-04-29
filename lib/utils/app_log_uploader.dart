import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AppLogUploader {
  AppLogUploader._();

  static final AppLogUploader instance = AppLogUploader._();

  static const _maxStoredRows = 1000;
  static const _maxUploadRows = 200;
  static const _maxFlushBatches = 3;
  static const _maxMessageLength = 4000;
  static const _maxStackLength = 12000;

  final List<Map<String, dynamic>> _buffer = [];
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  File? _file;
  Future<void>? _initFuture;
  PackageInfo? _packageInfo;
  final String _sessionId = const Uuid().v4();
  Timer? _persistTimer;
  bool _uploading = false;

  void capture(
    String level,
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final sanitized = _redact(message);
    if (sanitized.trim().isEmpty) return;

    _buffer.add({
      'level': _normalizeLevel(level),
      'tag': _limit(tag, 80),
      'message': _limit(sanitized, _maxMessageLength),
      'client_time': DateTime.now().millisecondsSinceEpoch,
      if (error != null) 'extra': {'error': _limit(_redact('$error'), 1000)},
      if (stackTrace != null)
        'stack': _limit(_redact('$stackTrace'), _maxStackLength),
    });

    if (_buffer.length > _maxStoredRows) {
      _buffer.removeRange(0, _buffer.length - _maxStoredRows);
    }
    _schedulePersist();
  }

  Future<bool> flush({String reason = 'manual'}) async {
    if (_uploading) return false;
    if (!_hasUploadCredential()) {
      await _persistBuffer();
      return false;
    }

    _uploading = true;
    _persistTimer?.cancel();
    _persistTimer = null;

    try {
      await _persistBuffer(force: true);

      var batches = 0;
      while (batches < _maxFlushBatches) {
        final rows = await _readRows();
        if (rows.isEmpty) return true;

        final batch = rows.take(_maxUploadRows).toList();
        final uploaded = await _uploadBatch(batch, reason);
        if (!uploaded) return false;

        await _writeRows(rows.skip(batch.length).toList());
        batches++;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _uploading = false;
      if (_buffer.isNotEmpty) {
        _schedulePersist();
      }
    }
  }

  Future<void> _ensureInitialized() {
    final existing = _initFuture;
    if (existing != null) return existing;
    _initFuture = _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    final dir = await getApplicationSupportDirectory();
    final logDir = Directory('${dir.path}/app_logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _file = File('${logDir.path}/app_log.jsonl');
    _packageInfo = await PackageInfo.fromPlatform();
  }

  void _schedulePersist() {
    if (_uploading || _persistTimer?.isActive == true) return;
    _persistTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persistBuffer());
    });
  }

  Future<void> _persistBuffer({bool force = false}) async {
    if (_uploading && !force) return;
    if (_buffer.isEmpty) return;
    await _ensureInitialized();

    final rows = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    final file = _file;
    if (file == null) return;
    final payload = rows.map(jsonEncode).join('\n');
    await file.writeAsString('$payload\n', mode: FileMode.append, flush: true);
    await _trimFileIfNeeded();
  }

  Future<List<Map<String, dynamic>>> _readRows() async {
    await _ensureInitialized();
    final file = _file;
    if (file == null || !await file.exists()) return [];

    final lines = await file.readAsLines();
    final effectiveLines = lines.length > _maxStoredRows
        ? lines.sublist(lines.length - _maxStoredRows)
        : lines;
    final rows = <Map<String, dynamic>>[];
    for (final line in effectiveLines) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) rows.add(decoded);
      } catch (_) {
        // Ignore a damaged line and keep the rest of the local log file usable.
      }
    }
    return rows;
  }

  Future<void> _writeRows(List<Map<String, dynamic>> rows) async {
    await _ensureInitialized();
    final file = _file;
    if (file == null) return;
    if (rows.isEmpty) {
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
      return;
    }
    final kept = rows.length > _maxStoredRows
        ? rows.sublist(rows.length - _maxStoredRows)
        : rows;
    await file.writeAsString('${kept.map(jsonEncode).join('\n')}\n',
        flush: true);
  }

  Future<void> _trimFileIfNeeded() async {
    final rows = await _readRows();
    if (rows.length > _maxStoredRows) {
      await _writeRows(rows);
    }
  }

  Future<bool> _uploadBatch(
      List<Map<String, dynamic>> logs, String reason) async {
    if (logs.isEmpty) return true;
    final token = DataSp.chatToken;
    final orgId = DataSp.orgId;
    if (token == null ||
        token.isEmpty ||
        orgId == null ||
        orgId.isEmpty ||
        orgId == 'orgId') {
      return false;
    }

    final packageInfo = _packageInfo;
    final appVersion = packageInfo == null
        ? ''
        : '${packageInfo.version}+${packageInfo.buildNumber}';
    final batchId = const Uuid().v4();
    final response = await _dio.post<Map<String, dynamic>>(
      Urls.appLogUpload,
      data: {
        'batch_id': batchId,
        'reason': reason,
        'device_id': DataSp.getDeviceID(),
        'platform': IMUtils.getPlatform(),
        'system_type': _systemType,
        'app_version': appVersion,
        'session_id': _sessionId,
        'logs': logs,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'operationID': 'app-log-$batchId',
          'token': token,
          'orgId': orgId,
          'source': _source,
        },
      ),
    );
    return response.data?['errCode'] == 0;
  }

  bool _hasUploadCredential() {
    final token = DataSp.chatToken;
    final orgId = DataSp.orgId;
    return token != null &&
        token.isNotEmpty &&
        orgId != null &&
        orgId.isNotEmpty &&
        orgId != 'orgId';
  }

  String get _source {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String get _systemType {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String _normalizeLevel(String level) {
    switch (level.toUpperCase()) {
      case 'D':
      case 'DEBUG':
        return 'DEBUG';
      case 'I':
      case 'INFO':
        return 'INFO';
      case 'W':
      case 'WARN':
      case 'WARNING':
        return 'WARN';
      case 'E':
      case 'ERROR':
        return 'ERROR';
      default:
        return level.toUpperCase();
    }
  }

  static String _redact(String input) {
    var output = input;
    final patterns = [
      RegExp(
        r'(token|chatToken|imToken|password|pwd|verifyCode|verificationCode)\s*[:=]\s*[^,\s}]+',
        caseSensitive: false,
      ),
      RegExp(
        r'"(token|chatToken|imToken|password|pwd|verifyCode|verificationCode)"\s*:\s*"[^"]*"',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      output = output.replaceAllMapped(pattern, (match) {
        final key = match.group(1) ?? 'secret';
        return '$key=[REDACTED]';
      });
    }
    return output;
  }

  static String _limit(String input, int maxLength) {
    final text = input.trim();
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }
}
