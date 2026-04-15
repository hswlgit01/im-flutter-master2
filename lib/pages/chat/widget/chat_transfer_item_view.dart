import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim_common/openim_common.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/transfer_status_manager.dart';
import '../../../utils/logger.dart';
import '../chat_logic.dart';

/// 转账消息气泡组件
class ChatTransferItemView extends StatefulWidget {
  /// 转账消息数据
  final Map<String, dynamic> data;

  /// 收款成功回调
  final Function(bool success, String status)? onTransferReceived;

  const ChatTransferItemView({
    super.key,
    required this.data,
    this.onTransferReceived,
  });

  @override
  State<ChatTransferItemView> createState() => _ChatTransferItemViewState();
}

class _ChatTransferItemViewState extends State<ChatTransferItemView>
    with AutomaticKeepAliveClientMixin {
  late String currentStatus;
  bool isLoading = false;
  final String _uniqueId = UniqueKey().toString();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 初始化状态,默认为pending
    final status = widget.data['status'] as String? ?? 'pending';
    currentStatus = status;

    // 检查持久化存储中是否已有更新
    _loadPersistedStatus();
  }

  /// 从持久化存储加载状态
  Future<void> _loadPersistedStatus() async {
    final transferId = widget.data['msg_id'];
    final persistedStatus =
        await TransferStatusManager.getTransferStatus(transferId);
    if (persistedStatus != null) {
      setState(() {
        currentStatus = persistedStatus;
      });
    }
  }

  @override
  void didUpdateWidget(ChatTransferItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当widget数据更新时,同步更新状态
    if (oldWidget.data['status'] != widget.data['status']) {
      setState(() {
        currentStatus = widget.data['status'];
      });
    }
  }

  /// 获取状态显示文本
  /// 根据当前状态和过期时间返回对应的显示文本
  String get statusText {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > widget.data['expire_time']) {
      return StrRes.expired;
    }
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return isOutgoing ? StrRes.waitingForRecipient : StrRes.pendingPayment;
      case 'completed':
        return StrRes.completed;
      case 'refunded':
        return StrRes.refunded;
      case 'expired':
        return StrRes.expired;
      default:
        return currentStatus;
    }
  }

  /// 获取状态对应的颜色
  /// 根据当前状态返回对应的显示颜色
  Color get statusColor {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return Colors.white;
      case 'completed':
      case 'refunded':
      case 'expired':
        return Colors.white.withOpacity(0.6);
      default:
        return Colors.white;
    }
  }

  /// 判断是否为发出的转账
  /// 通过比较发送者ID和当前用户ID判断
  bool get isOutgoing => widget.data['sender'] == OpenIM.iMManager.userID;

  /// 显示转账详情页面
  /// 处理收款成功后的状态更新和回调
  void _showTransferDetail() {
    Get.to(() => TransferDetailPage(
          data: widget.data,
          onTransferReceived: (success, newStatus) {
            if (success) {
              debugPrint('收款成功，需要更新状态: $newStatus');
              // 更新持久化存储
              TransferStatusManager.saveTransferStatus(
                  widget.data['msg_id'], newStatus);
              setState(() {
                currentStatus = newStatus;
              });
              // 回调通知父组件
              if (widget.onTransferReceived != null) {
                widget.onTransferReceived!(success, newStatus);
              }
            }
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final isExpired = now > widget.data['expire_time'];
    final isCompleted = currentStatus.toLowerCase() == 'completed';
    final isRefunded = currentStatus.toLowerCase() == 'refunded';

    return GestureDetector(
      onTap: _showTransferDetail,
      child: Container(
        width: 200.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isCompleted || isExpired || isRefunded
                ? [
                    Color(0xFFF5A623).withOpacity(0.6),
                    Colors.red.shade400.withOpacity(0.6)
                  ]
                : [Color(0xFFF5A623), Colors.red.shade600],
          ),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 16.w,
                ),
                8.horizontalSpace,
                Text(
                  StrRes.transfer,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            12.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 金额显示
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.data['currency'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    5.horizontalSpace,
                    Text(
                      widget.data['total_amount'].toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                10.horizontalSpace,
                Flexible(
                    child: // 状态标签
                        Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 转账详情页面
class TransferDetailPage extends StatefulWidget {
  /// 转账消息数据
  final Map<String, dynamic> data;

  /// 收款成功回调
  final Function(bool success, String status)? onTransferReceived;

  const TransferDetailPage({
    super.key,
    required this.data,
    this.onTransferReceived,
  });

  @override
  State<TransferDetailPage> createState() => _TransferDetailPageState();
}

class _TransferDetailPageState extends State<TransferDetailPage> {
  late String currentStatus;
  bool isLoading = false;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 获取当前状态,优先使用持久化存储的状态
    _loadPersistedStatus();
  }

  /// 从持久化存储加载状态
  Future<void> _loadPersistedStatus() async {
    final transferId = widget.data['msg_id'];
    final persistedStatus =
        await TransferStatusManager.getTransferStatus(transferId);
    setState(() {
      currentStatus =
          persistedStatus ?? widget.data['status'] as String? ?? 'pending';
    });
  }

  /// 刷新转账状态
  /// 检查持久化存储中是否有更新
  Future<void> _refreshTransferStatus() async {
    if (isRefreshing) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      // 检查是否有更新的状态
      await _loadPersistedStatus();
      setState(() {
        isRefreshing = false;
      });
    } catch (e) {
      debugPrint('获取转账状态失败: $e');
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  /// 处理收款成功的逻辑
  void _handleReceiveSuccess(Map<String, dynamic> result) async {
    try {
      ILogger.d('处理转账收款成功...');

      // 提取关键数据
      final receivedAmount = widget.data['total_amount']?.toString() ?? '0.00';
      final sender = widget.data['sender_nickname'] ?? StrRes.theRecipient;

      // 更新转账状态
      _updateLocalTransferStatus(receivedAmount);

      // 发送相应的通知消息
      _sendTransferNotification(sender);

      // 显示成功提示
      _showSuccessTip();

      // 延迟返回
      Future.delayed(const Duration(seconds: 1), () {
        Get.back();
      });
    } catch (e) {
      ILogger.d('处理转账收款成功时出错: $e');
      Get.snackbar(StrRes.reminder, StrRes.reminderStr,
          backgroundColor: Colors.amber, colorText: Colors.black);
    }
  }

  // 更新转账本地状态
  void _updateLocalTransferStatus(String receivedAmount) {
    final newStatus = 'completed';
    final transferId = widget.data['msg_id'];
    final receiverId = widget.data['belong_to'] ?? '';
    final transactionType = widget.data['transaction_type'] ?? 'transfer';

    // 更新持久化存储
    final record = TransferRecord(
      transactionId: transferId,
      receiverId: receiverId,
      amount: receivedAmount,
      receivedAt: DateTime.now().toIso8601String(),
      transactionType: transactionType,
      isReceived: true,
    );
    TransferStatusManager.saveTransferRecord(record);
    TransferStatusManager.saveTransferStatus(transferId, newStatus);

    // 更新当前状态
    if (mounted) {
      setState(() {
        currentStatus = newStatus;
      });
    }

    // 更新状态到widget数据
    widget.data['status'] = newStatus;
    widget.data['isReceived'] = true;
  }

  // 发送转账收款通知
  Future<void> _sendTransferNotification(String sender) async {
    try {
      final isFriendTransfer = true; // 目前只有单聊转账

      // 单聊转账处理：发送状态更新消息
      if (isFriendTransfer) {
        try {
          final chatLogic = Get.find<ChatLogic>(tag: GetTags.chat);
          final messageData = {
            "customType": 10086,
            "data": widget.data,
            "viewType": 10086
          };

          chatLogic.sendCustomMsg(
              data: jsonEncode(messageData),
              extension: '',
              description: StrRes.transfer);
        } catch (e) {
          ILogger.d('获取聊天控制器失败: $e');
        }
      }
    } catch (e) {
      ILogger.d('发送转账通知消息失败: $e');
      // 即使通知发送失败，也不影响转账收款流程
    }
  }

  // 显示成功提示
  void _showSuccessTip() {
    // 显示成功提示
    Get.snackbar(
      StrRes.paymentSuccessful,
      StrRes.amountCredited,
      backgroundColor: const Color(0xFF07C160),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.only(bottom: 20.h, left: 20.w, right: 20.w),
    );
  }

  _receiveTransfer() {
    final walletController = Get.find<WalletController>();
    walletController.checkWalletetActivated(() async {
      if (isLoading) return;

      setState(() {
        isLoading = true;
      });

      try {
        debugPrint('开始处理收款...');
        // 调用收款接口
        final apiService = core.ApiService();
        final result = await apiService.transactionReceive(
          transaction_id: widget.data['msg_id'],
        );

        if (result['success'] == true) {
          _handleReceiveSuccess(result);
        } else {
          final message = result['message'] ?? StrRes.paymentFailed;
          throw Exception(message);
        }
      } catch (e) {
        debugPrint('转账收款过程中发生错误: $e');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        // Get.snackbar(
        //   StrRes.paymentFailed,
        //   '${e.toString().replaceAll('Exception: ', '')}',
        //   backgroundColor: Colors.red,
        //   colorText: Colors.white,
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.only(bottom: 20.h, left: 20.w, right: 20.w),
        // );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isExpired = now > widget.data['expire_time'];
    final isPending = currentStatus.toLowerCase() == 'pending';
    final isOutgoing = widget.data['sender'] == OpenIM.iMManager.userID;
    final canReceive = !isOutgoing && isPending && !isExpired;

    final statusText = isExpired
        ? StrRes.expired
        : (isPending
            ? (isOutgoing ? StrRes.waitingForRecipient : StrRes.pendingPayment)
            : (currentStatus.toLowerCase() == 'completed'
                ? StrRes.completed
                : StrRes.refunded));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            Text(StrRes.transferDetails, style: Styles.ts_0C1C33_17sp_medium),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: isRefreshing
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF666666)),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF666666)),
            onPressed: isRefreshing ? null : _refreshTransferStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.only(
                left: 24.w, right: 24.w, top: 10.w, bottom: 36.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.data['total_amount'].toString() + ' ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 40.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      widget.data['currency'],
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 10.h,
            width: double.infinity,
            color: const Color(0xFFF5F5F5),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                _buildDetailItem(
                  StrRes.transferID,
                  widget.data['msg_id'],
                  valueColor: const Color(0xFF999999),
                ),
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                    indent: 0,
                    endIndent: 0),
                _buildDetailItem(
                  StrRes.transferStatus,
                  statusText,
                  valueColor:
                      currentStatus.toLowerCase() == 'refunded' || isExpired
                          ? const Color(0xFF999999)
                          : currentStatus.toLowerCase() == 'completed'
                              ? const Color(0xFF07C160)
                              : const Color(0xFF333333),
                ),
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                    indent: 0,
                    endIndent: 0),
                _buildDetailItem(
                  StrRes.transferTime,
                  _formatDateTime(widget.data['create_time']),
                ),
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                    indent: 0,
                    endIndent: 0),
                _buildDetailItem(
                  widget.data['sender'] == OpenIM.iMManager.userID
                      ? StrRes.recipient
                      : StrRes.sender,
                  widget.data['sender'] == OpenIM.iMManager.userID
                      ? widget.data['belong_to']
                      : widget.data['sender'],
                ),
                if (widget.data['remark']?.isNotEmpty == true) ...[
                  const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Color(0xFFEEEEEE),
                      indent: 0,
                      endIndent: 0),
                  _buildDetailItem(StrRes.note, widget.data['remark']),
                ],
              ],
            ),
          ),
          if (canReceive)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
              child: SizedBox(
                width: double.infinity,
                height: 45.h,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _receiveTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          StrRes.receivePayment,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 格式化时间戳为日期时间字符串
  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  /// 构建详情项组件
  /// [label] 标签文本
  /// [value] 值文本
  /// [valueColor] 值文本颜色
  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF666666),
              fontSize: 15.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF333333),
              fontSize: 15.sp,
            ),
          ),
        ],
      ),
    );
  }
}
