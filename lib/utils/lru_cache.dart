import 'dart:collection';

/// 简单的 LRU 缓存实现
/// 用于存储最近使用的项目，当缓存达到最大容量时自动移除最老的项目
class LruCache<K, V> {
  final int maxSize;
  final _cache = LinkedHashMap<K, V>();

  LruCache({required this.maxSize});

  /// 获取缓存项目
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }
    // 移动到链表末尾(最新位置)
    final value = _cache.remove(key);
    _cache[key] = value as V;
    return value;
  }

  /// 存储缓存项目
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // 移除第一个元素(最老的)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// 检查缓存是否包含某个键
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// 移除缓存项目
  V? remove(K key) {
    return _cache.remove(key);
  }

  /// 清除所有缓存
  void clear() {
    _cache.clear();
  }

  /// 获取缓存大小
  int get length => _cache.length;

  /// 获取所有键
  Iterable<K> get keys => _cache.keys;

  /// 获取所有值
  Iterable<V> get values => _cache.values;
}