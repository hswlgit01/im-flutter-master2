import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'prize_records_logic.dart';

class PrizeRecordsView extends StatelessWidget {
  final logic = Get.find<PrizeRecordsLogic>();

  PrizeRecordsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: TitleBar.back(
        title: StrRes.prizeRecords,
        backgroundColor: Colors.white,
        titleStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Obx(() {
              // 显示加载中状态（仅在首次加载时）
              if (logic.isLoading.value && logic.prizeRecords.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  ),
                );
              }

              // 显示错误状态（仅在首次加载失败时）
              if (logic.hasError.value && logic.prizeRecords.isEmpty) {
                return _buildEmptyState();
              }

              final records = logic.filteredRecords;
              if (records.isEmpty && !logic.isLoading.value) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: logic.refresh,
                color: const Color(0xFF007AFF),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length + (logic.hasMore.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == records.length) {
                      // 加载更多指示器
                      if (logic.hasMore.value) {
                        // 触发加载更多
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          logic.loadMore();
                        });
                        return Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: logic.hasError.value 
                              ? Text(
                                  StrRes.loadFailed,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF999999),
                                  ),
                                )
                              : const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                                ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    return _buildPrizeCard(records[index]);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 构建筛选栏
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(() => Row(
        children: [
          _buildFilterChip(StrRes.pending, 'pending', logic.selectedFilter.value == 'pending'),
          _buildFilterChip(StrRes.delivered, 'delivered', logic.selectedFilter.value == 'delivered'),
        ],
      )),
    );
  }

  // 构建筛选标签
  Widget _buildFilterChip(String title, String value, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => logic.setFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF666666),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  // 构建奖品卡片
  Widget _buildPrizeCard(PrizeRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 奖品图片
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF0F0F0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  record.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF0F0F0),
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Color(0xFF999999),
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 奖品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      _buildStatusBadge(record.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    logic.formatTime(record.createTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  if (record.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      record.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建状态标签
  Widget _buildStatusBadge(DeliveryStatus status) {
    final isDelivered = status == DeliveryStatus.delivered;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDelivered 
            ? const Color(0xFF34C759).withOpacity(0.1)
            : const Color(0xFFFF9500).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDelivered 
              ? const Color(0xFF34C759)
              : const Color(0xFFFF9500),
        ),
      ),
    );
  }

  // 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.card_giftcard_outlined,
              size: 60,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            StrRes.noPrizeRecords,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            StrRes.participateToWinPrizes,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }
}