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

  /// 检查消息是否应该被处理
  /// 返回true表示消息需要处理，false表示消息已处理过应该跳过
  Future<bool> shouldProcessMessage(Message msg) async {
    return _lock.synchronized(() async {
      // 无效消息ID仍然处理
      if (msg.clientMsgID == null || msg.clientMsgID!.isEmpty) {
        return true;
      }

      // 检查消息是否已处理过
      if (_processedMessages.containsKey(msg.clientMsgID!)) {
        Logger.print('跳过重复消息: ${msg.clientMsgID}');
        return false;
      }

      // 标记为已处理
      _processedMessages.put(msg.clientMsgID!, true);
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