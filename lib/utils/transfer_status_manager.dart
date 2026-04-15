import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 转账记录数据模型
class TransferRecord {
  final String transactionId;
  final String receiverId;
  final String amount;
  final String receivedAt;
  final String transactionType; // 类型：红包、转账、群转账等
  final bool isReceived; // 是否已收款

  TransferRecord({
    required this.transactionId,
    required this.receiverId,
    required this.amount,
    required this.receivedAt,
    required this.transactionType,
    this.isReceived = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'receiver_id': receiverId,
      'amount': amount,
      'received_at': receivedAt,
      'transaction_type': transactionType,
      'is_received': isReceived,
    };
  }

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      transactionId: json['transaction_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      amount: json['amount'] ?? '',
      receivedAt: json['received_at'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      isReceived: json['is_received'] ?? false,
    );
  }
}

/// 转账状态管理器
/// 用于持久化存储转账状态和记录
class TransferStatusManager {
  static const String _transfersKey = 'all_transfers';
  
  /// 获取转账状态
  /// [transferId] 转账ID
  static Future<String?> getTransferStatus(String transferId) async {
    final prefs = await SharedPreferences.getInstance();
    final transfers = await getAllTransfers();
    
    final transfer = transfers.firstWhere(
      (t) => t.transactionId == transferId,
      orElse: () => TransferRecord(
        transactionId: transferId,
        receiverId: '',
        amount: '',
        receivedAt: '',
        transactionType: 'transfer',
        isReceived: false,
      ),
    );
    
    return transfer.isReceived ? 'completed' : 'pending';
  }
  
  /// 保存转账状态
  /// [transferId] 转账ID
  /// [status] 状态
  static Future<void> saveTransferStatus(String transferId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final transfers = await getAllTransfers();
    
    // 查找是否已存在该转账记录
    final index = transfers.indexWhere((t) => t.transactionId == transferId);
    
    if (index >= 0) {
      // 更新现有记录
      final existingRecord = transfers[index];
      transfers[index] = TransferRecord(
        transactionId: existingRecord.transactionId,
        receiverId: existingRecord.receiverId,
        amount: existingRecord.amount,
        receivedAt: existingRecord.receivedAt,
        transactionType: existingRecord.transactionType,
        isReceived: status.toLowerCase() == 'completed',
      );
    } else {
      // 添加新记录
      transfers.add(TransferRecord(
        transactionId: transferId,
        receiverId: '',
        amount: '',
        receivedAt: '',
        transactionType: 'transfer',
        isReceived: status.toLowerCase() == 'completed',
      ));
    }
    
    // 保存更新后的列表
    await _saveTransfers(transfers);
  }
  
  /// 保存完整的转账记录
  /// [record] 转账记录
  static Future<void> saveTransferRecord(TransferRecord record) async {
    final transfers = await getAllTransfers();
    
    // 查找是否已存在该转账记录
    final index = transfers.indexWhere((t) => t.transactionId == record.transactionId);
    
    if (index >= 0) {
      // 更新现有记录
      transfers[index] = record;
    } else {
      // 添加新记录
      transfers.add(record);
    }
    
    // 保存更新后的列表
    await _saveTransfers(transfers);
  }
  
  /// 获取所有转账记录
  static Future<List<TransferRecord>> getAllTransfers() async {
    final prefs = await SharedPreferences.getInstance();
    final transfersJson = prefs.getString(_transfersKey);
    
    if (transfersJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(transfersJson);
      return jsonList.map((json) => TransferRecord.fromJson(json)).toList();
    } catch (e) {
      print('解析转账记录失败: $e');
      return [];
    }
  }
  
  /// 保存转账记录列表
  static Future<void> _saveTransfers(List<TransferRecord> transfers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = transfers.map((t) => t.toJson()).toList();
    await prefs.setString(_transfersKey, json.encode(jsonList));
  }
  
  /// 清除所有转账记录
  static Future<void> clearAllTransferStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transfersKey);
  }
  
  /// 获取所有转账状态
  static Future<Map<String, String>> getAllTransferStatuses() async {
    final transfers = await getAllTransfers();
    final Map<String, String> result = {};
    
    for (final transfer in transfers) {
      result[transfer.transactionId] = transfer.isReceived ? 'completed' : 'pending';
    }
    
    return result;
  }
} 