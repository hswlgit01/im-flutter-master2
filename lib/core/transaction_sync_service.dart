import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import '../utils/transfer_status_manager.dart';
import '../utils/luck_money_status_manager.dart';
import 'api_service.dart' as core;

class TransactionSyncService extends GetxService {
  static TransactionSyncService get to => Get.find();
  
  final _apiService = core.ApiService();
  Timer? _syncTimer;
  final _lastSyncTime = 0.obs;
  final _isSyncing = false.obs;
  
  // 同步间隔时间（毫秒）
  static const int _syncInterval = 5 * 60 * 1000; // 5分钟
  
  @override
  void onInit() {
    super.onInit();
    _startSyncTimer();
  }
  
  @override
  void onClose() {
    _stopSyncTimer();
    super.onClose();
  }
  
  // 启动同步定时器
  void _startSyncTimer() {
    _stopSyncTimer();
    _syncTimer = Timer.periodic(Duration(milliseconds: _syncInterval), (_) {
      _syncTransactions();
    });
  }
  
  // 停止同步定时器
  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // 强制同步
  Future<void> forceSync() async {
    await _syncTransactions(force: true);
  }
  
  // 同步交易状态
  Future<void> _syncTransactions({bool force = false}) async {
    try {
      if (await OpenIM.iMManager.getLoginStatus() != 3) {
        Logger.print('用户未登录，跳过交易状态同步');
        return;
      }
    } on PlatformException catch (e) {
      if (e.code == '10006') {
        Logger.print('SDK 未就绪，跳过交易状态同步');
        return;
      }
      rethrow;
    }
    // 如果正在同步中，且不是强制同步，则跳过
    if (_isSyncing.value && !force) {
      Logger.print('交易状态同步已在进行中，跳过本次同步');
      return;
    }
    
    // 如果不是强制同步，且距离上次同步时间不足5分钟，则跳过
    if (!force && DateTime.now().millisecondsSinceEpoch - _lastSyncTime.value < _syncInterval) {
      Logger.print('距离上次同步时间不足5分钟，跳过本次同步');
      return;
    }
    
    _isSyncing.value = true;
    
    try {
      Logger.print('开始同步交易状态...');
      
      final result = await _apiService.transactionReceiveHistory();
      if (result == null) {
        Logger.print('获取交易历史记录失败');
        return;
      }
      
      final transactions = result['records'] as List;
      Logger.print('获取到 ${transactions.length} 条交易记录');
      
      // 处理每条交易记录
      for (final transaction in transactions) {
        final transactionType = transaction['transaction_type'] ?? '';
        final transactionId = transaction['transaction_id'] ?? '';
        final receiverId = transaction['receiver_id'] ?? '';
        final amount = transaction['amount']?.toString() ?? '';
        final receivedAt = transaction['received_at'] ?? '';
        final isCompleted = receivedAt.isNotEmpty;
        
        // 根据类型区分处理转账和红包
        // 0-单聊转账，1-一对一红包，2-普通红包，3-拼手气红包
        if (transactionType == '0') {
          // 处理单聊转账记录
          final record = TransferRecord(
            transactionId: transactionId,
            receiverId: receiverId,
            amount: amount,
            receivedAt: receivedAt,
            transactionType: 'transfer',
            isReceived: isCompleted,
          );
          
          await TransferStatusManager.saveTransferRecord(record);
          await TransferStatusManager.saveTransferStatus(
            transactionId,
            isCompleted ? 'completed' : 'pending'
          );
        } else if (transactionType == '1' || // 一对一红包
                  transactionType == '2' || // 普通红包
                  transactionType == '3') { // 拼手气红包
          
          final record = LuckMoneyRecord(
            transactionId: transactionId,
            receiverId: receiverId,
            amount: amount,
            receivedAt: receivedAt,
            transactionType: transactionType == '1' ? 'luckyMoney' : 
                          transactionType == '2' ? 'groupLuckyMoney' : 'luckyMoneyGroup',
            isReceived: isCompleted,
          );
          
          await LuckMoneyStatusManager.saveLuckMoneyRecord(record);
          await LuckMoneyStatusManager.saveLuckMoneyStatus(
            transactionId,
            isCompleted ? 'completed' : 'pending',
            userId: receiverId.isNotEmpty ? receiverId : OpenIM.iMManager.userID,
          );
        }
      }
      
      _lastSyncTime.value = DateTime.now().millisecondsSinceEpoch;
      Logger.print('交易状态同步完成');
      
    } catch (e) {
      Logger.print('同步交易状态失败: $e');
    } finally {
      _isSyncing.value = false;
    }
  }
} 