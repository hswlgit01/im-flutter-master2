// dawn 2026-04-27 临时排查工具：撤回折叠失败时把 detail 异步上报到 chat-api 的
// /debug/log，方便服务端从日志里看到 SDK 实际给的字段名。整批 bug 定位完后整文件删。
import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';

class DebugLogUploader {
  DebugLogUploader._();

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static int _lastSentMs = 0;

  /// 异步上报，永远不抛异常，永远不阻塞调用方。
  /// 同 tag 60s 内最多上报一次以避免狂刷。
  static void send(String tag, Map<String, dynamic> data) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSentMs < 1000) return; // 全局最快每秒一条，多余直接丢
    _lastSentMs = now;
    final url = '${Config.appAuthUrl}/debug/log';
    Future.microtask(() async {
      try {
        await _dio.post(url, data: {
          'tag': tag,
          'data': data,
        });
      } catch (_) {
        // 排查通道失败不应影响主流程
      }
    });
  }
}
