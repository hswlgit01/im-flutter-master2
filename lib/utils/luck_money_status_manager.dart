import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 红包记录数据模型
class LuckMoneyRecord {
  final String transactionId;
  final String receiverId;
  final String amount;
  final String receivedAt;
  final String transactionType; // 类型：普通红包、拼手气红包、专属红包等
  final bool isReceived; // 是否已领取
  final int timestamp; // 记录创建时间戳

  LuckMoneyRecord({
    required this.transactionId,
    required this.receiverId,
    required this.amount,
    required this.receivedAt,
    required this.transactionType,
    this.isReceived = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'receiver_id': receiverId,
      'amount': amount,
      'received_at': receivedAt,
      'transaction_type': transactionType,
      'is_received': isReceived,
      'timestamp': timestamp,
    };
  }

  factory LuckMoneyRecord.fromJson(Map<String, dynamic> json) {
    return LuckMoneyRecord(
      transactionId: json['transaction_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      amount: json['amount'] ?? '',
      receivedAt: json['received_at'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      isReceived: json['is_received'] ?? false,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 红包状态管理器
/// 用于持久化存储红包状态和记录
class LuckMoneyStatusManager {
  static const String _luckyMoneyKey = 'all_lucky_money';
  static const int _maxRecordCount = 200; // 最大保存记录数
  static const int _maxRetentionDays = 30; // 保留记录的最大天数
  // 红包整体状态（是否已结束/被抢完），不区分用户，用于会话列表等全局维度展示
  static const String _packetStatusKey = 'all_lucky_money_packet_status';

  /// 获取红包状态（按当前用户区分，同机换账号后不会误显示上一账号的「已领取」）
  /// [luckyMoneyId] 红包ID
  /// [userId] 当前登录用户 id，传入后只查该用户对该红包的领取状态
  static Future<String?> getLuckMoneyStatus(String luckyMoneyId, {String? userId}) async {
    if (luckyMoneyId.isEmpty) {
      return 'pending';
    }

    final luckyMoneys = await getAllLuckyMoneys();

    final luckyMoney = luckyMoneys.firstWhere(
      (t) => t.transactionId == luckyMoneyId && (userId == null || userId.isEmpty || t.receiverId == userId),
      orElse: () => LuckMoneyRecord(
        transactionId: luckyMoneyId,
        receiverId: userId ?? '',
        amount: '',
        receivedAt: '',
        transactionType: 'luckyMoney',
        isReceived: false,
      ),
    );

    return luckyMoney.isReceived ? 'completed' : 'pending';
  }

  /// 保存红包状态（按当前用户区分，避免覆盖其他账号的状态）
  /// [userId] 当前登录用户 id，传入后只更新该用户对该红包的状态
  static Future<void> saveLuckMoneyStatus(String luckyMoneyId, String status, {String? userId}) async {
    if (luckyMoneyId.isEmpty) {
      return;
    }

    final luckyMoneys = await getAllLuckyMoneys();
    final received = status.toLowerCase() == 'completed';
    final receiverId = userId ?? '';

    final index = luckyMoneys.indexWhere((t) =>
        t.transactionId == luckyMoneyId && (receiverId.isEmpty || t.receiverId == receiverId));

    if (index >= 0) {
      final existingRecord = luckyMoneys[index];
      luckyMoneys[index] = LuckMoneyRecord(
        transactionId: existingRecord.transactionId,
        receiverId: receiverId.isNotEmpty ? receiverId : existingRecord.receiverId,
        amount: existingRecord.amount,
        receivedAt: existingRecord.receivedAt,
        transactionType: existingRecord.transactionType,
        isReceived: received,
        timestamp: existingRecord.timestamp,
      );
    } else {
      luckyMoneys.add(LuckMoneyRecord(
        transactionId: luckyMoneyId,
        receiverId: receiverId,
        amount: '',
        receivedAt: '',
        transactionType: 'luckyMoney',
        isReceived: received,
      ));
    }

    final cleanedList = _cleanupOldRecords(luckyMoneys);
    await _saveLuckyMoneys(cleanedList);
  }
  
  /// 保存完整的红包记录
  /// [record] 红包记录
  static Future<void> saveLuckMoneyRecord(LuckMoneyRecord record) async {
    if (record.transactionId.isEmpty) {
      return;
    }
    
    final luckyMoneys = await getAllLuckyMoneys();
    
    // 查找是否已存在该红包记录
    final index = luckyMoneys.indexWhere((t) => t.transactionId == record.transactionId);
    
    if (index >= 0) {
      // 更新现有记录
      luckyMoneys[index] = record;
    } else {
      // 添加新记录
      luckyMoneys.add(record);
    }
    
    // 清理过期记录
    final cleanedList = _cleanupOldRecords(luckyMoneys);
    
    // 保存更新后的列表
    await _saveLuckyMoneys(cleanedList);
  }
  
  /// 获取所有红包记录
  static Future<List<LuckMoneyRecord>> getAllLuckyMoneys() async {
    final prefs = await SharedPreferences.getInstance();
    final luckyMoneyJson = prefs.getString(_luckyMoneyKey);
    
    if (luckyMoneyJson == null || luckyMoneyJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(luckyMoneyJson);
      return jsonList.map((json) => LuckMoneyRecord.fromJson(json)).toList();
    } catch (e) {
      print('解析红包记录失败: $e');
      return [];
    }
  }
  
  /// 保存红包记录列表
  static Future<void> _saveLuckyMoneys(List<LuckMoneyRecord> luckyMoneys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = luckyMoneys.map((t) => t.toJson()).toList();
      await prefs.setString(_luckyMoneyKey, json.encode(jsonList));
    } catch (e) {
      print('保存红包记录失败: $e');
    }
  }
  
  /// 清理过期的记录
  /// 保留最近30天的记录,最多200条
  static List<LuckMoneyRecord> _cleanupOldRecords(List<LuckMoneyRecord> records) {
    if (records.isEmpty) {
      return records;
    }
    
    // 按时间戳排序(最新的在前)
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // 如果记录数量超过限制,只保留最新的200条
    if (records.length > _maxRecordCount) {
      records = records.sublist(0, _maxRecordCount);
    }
    
    // 计算30天前的时间戳
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: _maxRetentionDays)).millisecondsSinceEpoch;
    
    // 过滤掉30天前的记录
    return records.where((record) => record.timestamp >= thirtyDaysAgo).toList();
  }
  
  /// 清除所有红包记录
  static Future<void> clearAllLuckMoneyStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_luckyMoneyKey);
    } catch (e) {
      print('清除红包记录失败: $e');
    }
  }
  
  /// 获取所有红包状态（按当前用户过滤，避免同机多账号时互相覆盖）
  /// [userId] 当前登录用户 id，传入后只返回该用户对各个红包的领取状态
  static Future<Map<String, String>> getAllLuckMoneyStatuses({String? userId}) async {
    final luckyMoneys = await getAllLuckyMoneys();
    final Map<String, String> result = {};
    
    for (final luckyMoney in luckyMoneys) {
      // 按用户过滤：若指定了 userId，只采纳该用户的记录，避免多账号时“已领取”被“待领取”覆盖
      if (userId != null && userId.isNotEmpty && luckyMoney.receiverId != userId) {
        continue;
      }
      result[luckyMoney.transactionId] = luckyMoney.isReceived ? 'completed' : 'pending';
    }
    
    return result;
  }

  /// 保存红包整体状态（与具体领取人无关，用于标记红包是否已被抢完/已结束）
  /// [status] 目前使用 'completed' / 'pending' / 'expired' / 'refunded' 等语义
  static Future<void> savePacketStatus(String luckyMoneyId, String status) async {
    if (luckyMoneyId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_packetStatusKey);
      final Map<String, dynamic> all = (jsonStr != null && jsonStr.isNotEmpty)
          ? Map<String, dynamic>.from(json.decode(jsonStr) as Map)
          : {};
      all[luckyMoneyId] = status;
      await prefs.setString(_packetStatusKey, json.encode(all));
    } catch (e) {
      print('保存红包整体状态失败: $e');
    }
  }

  /// 获取所有红包整体状态（不区分用户）
  static Future<Map<String, String>> getAllPacketStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_packetStatusKey);
      if (jsonStr == null || jsonStr.isEmpty) return {};
      final Map<String, dynamic> all = json.decode(jsonStr) as Map<String, dynamic>;
      return all.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('读取红包整体状态失败: $e');
      return {};
    }
  }

  /// 定期清理过期红包记录
  /// 建议在应用启动时调用
  static Future<void> cleanupExpiredRecords() async {
    final records = await getAllLuckyMoneys();
    final cleanedRecords = _cleanupOldRecords(records);
    
    // 如果清理后数量减少了,则保存清理后的列表
    if (cleanedRecords.length < records.length) {
      await _saveLuckyMoneys(cleanedRecords);
    }
  }

  // ---------- 详情页本地快照（打开即显示抢到金额/已领完，避免先 0.00 再跳转）----------
  // 按「红包 id + 当前用户 id」存储，避免同机换账号后读到上一账号的领取状态（如一号已领、二号看到 17.18/已存入零钱）
  static const String _detailSnapshotsKey = 'luck_money_detail_snapshots';
  static const int _maxDetailSnapshots = 100;

  static String _detailSnapshotKey(String transactionId, String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return '${transactionId}_$userId';
    }
    return transactionId;
  }

  /// 获取某红包、某用户的详情快照（用于进入详情页时本地优先展示）
  /// [userId] 当前登录用户 id，必传则快照按用户区分，换账号不会读到上一账号的缓存
  static Future<Map<String, dynamic>?> getDetailSnapshot(String transactionId, {String? userId}) async {
    if (transactionId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_detailSnapshotsKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final Map<String, dynamic> all = json.decode(jsonStr) as Map<String, dynamic>;
      final key = _detailSnapshotKey(transactionId, userId);
      final snap = all[key];
      return snap is Map<String, dynamic> ? snap : null;
    } catch (e) {
      return null;
    }
  }

  /// 保存详情快照（接口返回或领取成功后调用，下次打开详情可直接展示）
  /// [userId] 当前登录用户 id，必传则快照按用户区分
  static Future<void> saveDetailSnapshot(String transactionId, Map<String, dynamic> snapshot, {String? userId}) async {
    if (transactionId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_detailSnapshotsKey);
      Map<String, dynamic> all = (jsonStr != null && jsonStr.isNotEmpty)
          ? Map<String, dynamic>.from(json.decode(jsonStr) as Map)
          : {};
      final key = _detailSnapshotKey(transactionId, userId);
      all[key] = {
        ...snapshot,
        '_ts': DateTime.now().millisecondsSinceEpoch,
      };
      if (all.length > _maxDetailSnapshots) {
        final entries = all.entries.toList()
          ..sort((a, b) => ((b.value as Map)?['_ts'] ?? 0).compareTo((a.value as Map)?['_ts'] ?? 0));
        all = Map.fromEntries(entries.take(_maxDetailSnapshots));
      }
      await prefs.setString(_detailSnapshotsKey, json.encode(all));
    } catch (e) {
      // ignore
    }
  }
} 