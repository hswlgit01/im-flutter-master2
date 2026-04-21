import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';
import 'package:synchronized/synchronized.dart';

import 'lru_cache.dart';

/// 消息去重器
/// 用于防止同一消息被多次处理和显示
class MessageDeduplicator {
  // 单例模式
  static final MessageDeduplicator _instance = MessageDeduplicator._();
  static MessageDeduplicator get instance => _instance;
  MessageDeduplicator._();

  // 使用LRU缓存保存已处理的消息ID
  final _processedMessages = LruCache<String, bool>(maxSize: 500);

  // 使用锁保证线程安全
  final _lock = Lock();

  String? _dedupeKey(Message msg) {
    final serverMsgID = msg.serverMsgID;
    if (serverMsgID != null && serverMsgID.isNotEmpty) {
      return 'server:$serverMsgID';
    }

    final conversationID = msg.conversationID;
    final seq = msg.seq;
    if (conversationID != null && conversationID.isNotEmpty && seq != null && seq > 0) {
      return 'seq:$conversationID:$seq';
    }

    final clientMsgID = msg.clientMsgID;
    if (clientMsgID != null && clientMsgID.isNotEmpty) {
      return 'client:$clientMsgID';
    }
    return null;
  }

  /// 检查消息是否应该被处理
  /// 返回true表示消息需要处理，false表示消息已处理过应该跳过
  Future<bool> shouldProcessMessage(Message msg) async {
    return _lock.synchronized(() async {
      final key = _dedupeKey(msg);
      // 无有效消息ID仍然处理
      if (key == null) {
        return true;
      }

      // 检查消息是否已处理过
      if (_processedMessages.containsKey(key)) {
        Logger.print('跳过重复消息: $key');
        return false;
      }

      // 标记为已处理
      _processedMessages.put(key, true);
      return true;
    });
  }

  /// 清除去重器缓存
  /// 通常在用户切换时调用
  void clear() {
    _lock.synchronized(() => _processedMessages.clear());
  }

  /// 记录内存缓存状态（用于调试）
  void logStatus() {
    Logger.print('消息去重器缓存大小: ${_processedMessages.length}');
  }
}
