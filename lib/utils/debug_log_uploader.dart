// dawn 2026-04-27 临时排查工具：撤回折叠失败时把 detail 异步上报到 chat-api 的
// /debug/log，方便服务端从日志里看到 SDK 实际给的字段名。整批 bug 定位完后整文件删。
import 'package:dio/dio.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

class DebugLogUploader {
  DebugLogUploader._();

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    // dawn 2026-04-27 chat-api 全局中间件要求 operationID header，否则 400
    headers: {'operationID': 'flutter-debug'},
  ));

  // dawn 2026-04-27 改成按 tag 限频：每个 tag 1s 内最多一条，不同 tag 不互
  // 阻挡。原全局 1s 一条会让快速串发的 newmsg/apply_revoked_info 被吞掉。
  static final Map<String, int> _lastSentPerTag = {};

  /// 异步上报，永远不抛异常，永远不阻塞调用方。
  /// dawn 2026-04-27 自动注入 me=当前用户ID，方便从同 NAT 公网 IP 区分两台手机。
  static void send(String tag, Map<String, dynamic> data) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSentPerTag[tag] ?? 0;
    if (now - last < 1000) return;
    _lastSentPerTag[tag] = now;
    final url = '${Config.appAuthUrl}/debug/log';
    String me = '?';
    try {
      me = OpenIM.iMManager.userID;
    } catch (_) {}
    final payload = <String, dynamic>{'me': me, ...data};
    Future.microtask(() async {
      try {
        await _dio.post(url, data: {
          'tag': tag,
          'data': payload,
        });
      } catch (_) {
        // 排查通道失败不应影响主流程
      }
    });
  }
}
