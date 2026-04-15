import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

class WithdrawalRecordsLogic extends GetxController {
  final refreshController = RefreshController(initialRefresh: false);
  final recordList = <WithdrawalRecord>[].obs;
  final isLoading = false.obs;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    _loadRecords();
  }

  @override
  void onClose() {
    refreshController.dispose();
    super.onClose();
  }

  // 加载提现记录
  Future<void> _loadRecords({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!_hasMore && !isRefresh) return;

    try {
      isLoading.value = true;

      final result = await Apis.getWithdrawalRecords(
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (result != null) {
        final records = (result['records'] as List?)
            ?.map((e) => WithdrawalRecord.fromJson(e))
            .toList() ?? [];

        if (isRefresh) {
          recordList.value = records;
        } else {
          recordList.addAll(records);
        }

        _hasMore = records.length >= _pageSize;
        _currentPage++;
      }

      if (isRefresh) {
        refreshController.refreshCompleted();
      } else {
        refreshController.loadComplete();
      }
    } catch (e) {
      Logger.print('加载提现记录失败: $e');
      if (isRefresh) {
        refreshController.refreshFailed();
      } else {
        refreshController.loadFailed();
      }
    } finally {
      isLoading.value = false;
    }
  }

  // 下拉刷新
  void onRefresh() {
    _loadRecords(isRefresh: true);
  }

  // 上拉加载更多
  void onLoading() {
    _loadRecords(isRefresh: false);
  }

  // 取消提现
  Future<void> cancelWithdrawal(WithdrawalRecord record) async {
    if (!record.canCancel) {
      IMViews.showToast('当前状态不可取消');
      return;
    }

    try {
      await Apis.cancelWithdrawal(record.orderNo!);
      IMViews.showToast('取消成功');
      onRefresh(); // 刷新列表
    } catch (e) {
      Logger.print('取消提现失败: $e');
      IMViews.showToast('取消失败');
    }
  }

  // 查看详情
  void viewDetail(WithdrawalRecord record) {
    // TODO: 跳转到详情页面
    Get.bottomSheet(
      _buildDetailSheet(record),
      backgroundColor: Styles.c_FFFFFF,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    );
  }

  // 构建详情底部弹窗
  Widget _buildDetailSheet(WithdrawalRecord record) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '提现详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Get.back(),
                child: Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildDetailRow('订单号', record.orderNo ?? ''),
          _buildDetailRow('提现金额', '¥${record.amount?.toStringAsFixed(2) ?? '0.00'}'),
          _buildDetailRow('手续费', '¥${record.fee?.toStringAsFixed(2) ?? '0.00'}'),
          _buildDetailRow('实际到账', '¥${record.actualAmount?.toStringAsFixed(2) ?? '0.00'}'),
          _buildDetailRow('收款方式', record.paymentTypeText),
          _buildDetailRow('状态', record.statusText),
          if (record.rejectReason?.isNotEmpty == true)
            _buildDetailRow('拒绝原因', record.rejectReason!),
          _buildDetailRow('创建时间', _formatTime(record.createdAt)),
          if (record.approveTime != null)
            _buildDetailRow('审批时间', _formatTime(record.approveTime)),
          if (record.transferTime != null)
            _buildDetailRow('打款时间', _formatTime(record.transferTime)),
          if (record.completeTime != null)
            _buildDetailRow('完成时间', _formatTime(record.completeTime)),
          SizedBox(height: 20),
          if (record.canCancel)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  cancelWithdrawal(record);
                },
                child: Text('取消提现'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Color(0xFF0C1C33),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
