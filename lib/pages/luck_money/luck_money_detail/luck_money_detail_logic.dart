import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/luck_money_status_manager.dart';

class ReceivedRecord {
  final String userId;
  final String userName;
  final String amount;
  final int receivedTime;
  final String faceURL;
  
  ReceivedRecord({
    required this.userId,
    required this.userName,
    required this.amount,
    required this.receivedTime,
    required this.faceURL,
  });
}

class LuckMoneyDetailLogic extends GetxController {
  final luckyMoneyId = ''.obs;
  final amount = '0.00'.obs;
  final receivedAmount = '0.00'.obs;
  final totalAmount = '0.00'.obs;
  final receivedCount = 0.obs;
  final totalCount = 0.obs;
  // 红包金额单位：目前产品统一为 CNY（即使历史数据或接口里带有 USD 等，也统一按 CNY 展示）
  final currency = 'CNY'.obs;
  final senderName = ''.obs;
  final remark = '恭喜发财，大吉大利'.obs;
  final status = ''.obs;
  final receivedList = <ReceivedRecord>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMsg = ''.obs;
  final isErrorRedirect = false.obs;
  // 当前用户是否已经领取（由后端 self_received 决定）
  final selfReceived = false.obs;
  
  final _apiService = core.ApiService();
  bool _isLoading = false;
  
  /// 内部缓存所有原始领取记录（只包含ID、金额、时间），用于分页加载用户信息
  final List<Map<String, dynamic>> _allRecordsData = [];
  int _loadedCount = 0;
  int _totalRecords = 0;
  // 每次加载的记录条数（包含自己），取一个相对大的值，基本可以一次性填满当前屏幕，避免多次网络请求
  final int _pageSize = 50;
  bool _isLoadingMore = false;
  final hasMore = true.obs;
  // 详情快照本地缓存的有效期（秒），在此时间内重复打开不必立即请求服务端，可直接使用快照数据
  static const int _snapshotTTLSeconds = 5;
  // 列表滚动控制器，用于监听滑动到底部加载更多
  final ScrollController scrollController = ScrollController();
  
  @override
  void onInit() {
    super.onInit();
    
    // 获取路由参数
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      luckyMoneyId.value = arguments['msg_id'] ?? '';
      // 获取是否是从错误处理跳转过来的标记
      isErrorRedirect.value = arguments['isErrorRedirect'] ?? false;
      
      // 如果传入了完整的红包数据，先使用这些数据初始化界面
      final data = arguments['data'];
      if (data != null && data is Map<String, dynamic>) {
        _initFromLocalData(data);
      } else {
        // 如果没有本地数据，设置默认值
        senderName.value = '红包';
      }
    }
    
    // 先尝试用本地缓存快照补全（避免先显示 0.00 再跳转），再请求接口
    _loadCacheThenFetch();

    // 监听列表滚动事件，接近底部时自动加载更多
    scrollController.addListener(() {
      if (!hasMore.value) return;
      if (!scrollController.hasClients) return;
      final position = scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 100 &&
          !position.outOfRange) {
        loadMore();
      }
    });
  }
  
  // 刷新数据
  Future<void> onRefresh() async {
    hasError.value = false;
    errorMsg.value = '';
    await fetchTransactionDetails();
  }

  /// 先读缓存快照（若无路由 data 或金额仍为 0.00 则用缓存立即展示），再拉接口更新
  Future<void> _loadCacheThenFetch() async {
    final id = luckyMoneyId.value;
    if (id.isEmpty) {
      await fetchTransactionDetails();
      return;
    }
    final snapshot = await LuckMoneyStatusManager.getDetailSnapshot(id, userId: OpenIM.iMManager.userID);
    if (snapshot != null && snapshot.isNotEmpty) {
      // 无论路由是否带了 data, 都优先应用快照, 让首屏尽可能使用本地数据(金额/状态/部分记录)
      _applyDetailSnapshot(snapshot);

      // 若快照在有效期内, 直接使用本地数据即可, 不必立即打接口, 减轻服务端压力
      final ts = snapshot['_ts'] is int ? snapshot['_ts'] as int : null;
      if (ts != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - ts < _snapshotTTLSeconds * 1000) {
          isLoading.value = false;
          _isLoading = false;
          return;
        }
      }
    }
    await fetchTransactionDetails();
  }

  /// 用详情快照更新展示（不覆盖 sender/remark，只更新金额与状态）
  void _applyDetailSnapshot(Map<String, dynamic> snapshot) {
    try {
      final selfAmount = snapshot['self_amount']?.toString();
      final selfReceivedFlag = snapshot['self_received'] == true;
      if (selfReceivedFlag && selfAmount != null && selfAmount.isNotEmpty) {
        amount.value = selfAmount;
      }
      selfReceived.value = selfReceivedFlag;
      if (snapshot['total_amount'] != null) totalAmount.value = snapshot['total_amount']?.toString() ?? totalAmount.value;
      if (snapshot['received_amount'] != null) receivedAmount.value = snapshot['received_amount']?.toString() ?? receivedAmount.value;
      if (snapshot['total_count'] != null) totalCount.value = snapshot['total_count'] as int? ?? totalCount.value;
      if (snapshot['received_count'] != null) receivedCount.value = snapshot['received_count'] as int? ?? receivedCount.value;
      final st = snapshot['status']?.toString();
      if (st != null && st.isNotEmpty) status.value = st;
      final total = totalCount.value > 0 ? totalCount.value : 1;
      if (status.value == 'completed' && receivedCount.value < total) status.value = 'pending';

      // 若快照中包含预览记录, 且当前列表为空, 先用预览填充一屏记录, 避免首次进入时底部一片空白
      final preview = snapshot['records_preview'];
      if (preview is List && preview.isNotEmpty && receivedList.isEmpty) {
        _loadReceivedListFromData(preview);
      }
    } catch (e) {
      ILogger.d('应用详情快照失败: $e');
    }
  }
  
  // 从本地数据初始化
  void _initFromLocalData(Map<String, dynamic> data) {
    try {
      // 基本信息初始化
      // 顶部显示金额：本地初始化阶段一律从 0.00 开始，避免先闪现总金额再跳到实际金额
      // 如果本地消息里已经带有当前用户领取金额（data['amount']），可以作为初始值；否则默认 0.00
      amount.value = data['amount']?.toString() ?? '0.00';

      // 整包统计信息仍可用本地数据预渲染
      receivedAmount.value = data['received_amount']?.toString() ?? '0.00';
      totalAmount.value = data['total_amount']?.toString() ?? totalAmount.value;
      receivedCount.value = data['received_count'] ?? 0;
      totalCount.value = data['total_count'] ?? 1;
      status.value = data['status'] ?? 'pending';
      // 本地 status 与数量一致：若标记为已领完但已领数未满，视为脏数据，等接口拉取后再展示 completed
      final total = totalCount.value > 0 ? totalCount.value : 1;
      if (status.value == 'completed' && receivedCount.value < total) {
        status.value = 'pending';
      }
      // 金额单位统一为 CNY，忽略本地消息里的 currency 字段，避免多端显示不一致
      currency.value = 'CNY';
      
      // 获取发送者信息
      if (data['sender'] == OpenIM.iMManager.userID) {
        senderName.value = OpenIM.iMManager.userInfo.nickname ?? '我';
      } else {
        senderName.value = data['sender_nickname'] ?? data['sender_name'] ?? '用户';
      }
      
      // 获取备注信息
      remark.value = IMUtils.getFirstNonEmptyString([
        data['greeting']?.toString(),
        data['remark']?.toString(),
      ], StrRes.redPacketHitStr);
      
      // 处理接收记录
      if (data['receivers'] != null && data['receivers'] is List) {
        _loadReceivedListFromData(data['receivers']);
      }
    } catch (e) {
      ILogger.d('初始化本地数据错误: $e');
    }
  }
    // 从数据中加载领取记录
  void _loadReceivedListFromData(List<dynamic> receiversData) {
    try {
      receivedList.clear();
      
      for (final receiver in receiversData) {
        if (receiver is Map<String, dynamic>) {
          final record = ReceivedRecord(
            userId: receiver['user_id'] ?? '',
            userName: receiver['nickname'] ?? '用户',
            amount: receiver['amount']?.toString() ?? '0.00',
            receivedTime: receiver['received_time'] ?? DateTime.now().millisecondsSinceEpoch,
            faceURL: receiver['face_url'] ?? '',
          );
          receivedList.add(record);
        }
      }
      
      // 按时间排序，最新领取的排在最前面
      receivedList.sort((a, b) => b.receivedTime.compareTo(a.receivedTime));
      
    } catch (e) {
      ILogger.d('处理领取记录数据失败: $e');
    }
  }
    // 格式化接收时间
  String formatReceivedTime(int timestamp) {
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      
      return '$month-$day $hour:$minute';
    } catch (e) {
      return '未知时间';
    }
  }

  // 从接口获取交易详情
  Future<void> fetchTransactionDetails() async {
    if (luckyMoneyId.value.isEmpty) {
      hasError.value = true;
      errorMsg.value = '红包ID不能为空';
      isLoading.value = false;
      return;
    }
    
    if (_isLoading) return;
    
    isLoading.value = true;
    hasError.value = false;
    _isLoading = true;
    
    try {
      final result = await _apiService.transactionReceiveDetails(
        transaction_id: luckyMoneyId.value,
        opUserImId: OpenIM.iMManager.userID,
        pageNum: 1,
        pageSize: _pageSize,
      );

      if (result != null) {
        final data = result;
        // 整包统计信息
        totalAmount.value = data['total_amount']?.toString() ?? totalAmount.value;
        receivedAmount.value = data['received_amount']?.toString() ?? receivedAmount.value;
        totalCount.value = data['total_count'] ?? totalCount.value;
        receivedCount.value = data['received_count'] ?? receivedCount.value;

        // 统一红包来源与文案（以接口数据为准，避免不同端仅依赖本地消息导致显示不一致）
        try {
          final senderIdFromApi = data['sender']?.toString();
          final senderNicknameFromApi = data['sender_nickname'] ?? data['sender_name'];

          if (senderIdFromApi != null && senderIdFromApi.isNotEmpty) {
            if (senderIdFromApi == OpenIM.iMManager.userID) {
              senderName.value = OpenIM.iMManager.userInfo.nickname ?? '我';
            } else if (senderNicknameFromApi != null &&
                senderNicknameFromApi.toString().isNotEmpty) {
              senderName.value = senderNicknameFromApi.toString();
            }
          }

          // 优先使用接口返回的 greeting / remark 作为红包祝福语
          remark.value = IMUtils.getFirstNonEmptyString(
            [
              data['greeting']?.toString(),
              data['remark']?.toString(),
            ],
            remark.value,
          );

          // 金额单位统一成 CNY：如果接口带了其他币种，也强制覆盖成 CNY，保证所有端展示一致
          currency.value = 'CNY';
        } catch (e) {
          ILogger.d('从接口统一红包来源/单位时出错: $e');
        }

        // 当前用户自己的领取金额（后端已返回 self_amount / self_received）
        final selfAmountStr = data['self_amount']?.toString();
        final selfReceivedFlag = data['self_received'] == true;
        selfReceived.value = selfReceivedFlag;
        if (selfReceivedFlag && selfAmountStr != null) {
          // 已领取：显示自己领取的金额（UI 层如需动画可自行处理）
          amount.value = selfAmountStr;
        } else {
          // 未领取：始终显示 0.00，避免误认为拿到了整包金额
          amount.value = '0.00';
        }

        // 处理领取记录（仅第一页）
        final records = data['records'];
        if (records != null && records is List && records.isNotEmpty) {
          await _processRecords(records);
        } else {
          ILogger.d('API返回的records为空或格式错误');
        }
        
        // 【关键修复】优先使用后端返回的 status，确保状态与服务端一致
        final apiStatus = data['status']?.toString();
        if (apiStatus != null && apiStatus.isNotEmpty) {
          status.value = apiStatus;
        } else {
          // 后端未返回 status 时，根据数量判断（兼容旧版本）
          if (receivedCount.value >= totalCount.value) {
            status.value = 'completed';
          } else {
            status.value = 'pending';
          }
        }

        // 写入详情快照（按当前用户区分），下次打开直接显示抢到金额/已领完，并带一份预览记录。
        // 预览记录从当前 receivedList 中抽取，保证昵称与头像已通过本地/IM SDK 补全。
        List<Map<String, dynamic>> previewRecords = [];
        if (receivedList.isNotEmpty) {
          const int kMaxPreviewRecords = 50;
          for (var i = 0; i < receivedList.length && i < kMaxPreviewRecords; i++) {
            final r = receivedList[i];
            previewRecords.add({
              'user_id': r.userId,
              'nickname': r.userName,
              'amount': r.amount,
              'received_time': r.receivedTime,
              'face_url': r.faceURL,
            });
          }
        }

        LuckMoneyStatusManager.saveDetailSnapshot(luckyMoneyId.value, {
          'self_amount': data['self_amount']?.toString(),
          'self_received': data['self_received'] == true,
          'status': status.value,
          'received_count': receivedCount.value,
          'total_count': totalCount.value,
          'received_amount': receivedAmount.value,
          'total_amount': totalAmount.value,
          'records_preview': previewRecords,
        }, userId: OpenIM.iMManager.userID);

        // 更新总记录数，用于分页判断
        _totalRecords = data['total_records'] is int ? data['total_records'] as int : receivedCount.value;
        hasMore.value = _loadedCount < _totalRecords;
      } else {
        hasError.value = true;
        errorMsg.value = '获取数据失败';
      }
    } catch (e) {
      ILogger.d('获取交易详情异常: $e');
      hasError.value = true;
      errorMsg.value = '网络异常，请稍后重试';
    } finally {
      _isLoading = false;
      isLoading.value = false;
    }
  }
  // 处理记录数据
  Future<void> _processRecords(List records) async {
    _allRecordsData.clear();
    _loadedCount = 0;
    receivedList.clear();

    // 收集本页有效记录（仅ID、金额、时间）
    for (var record in records) {
      if (record == null || record is! Map) continue;

      final receiverId = record['receiver_im_id']?.toString() ?? '';
      if (receiverId.isEmpty) continue;

      _allRecordsData.add({
        'receiverId': receiverId,
        'amount': record['amount']?.toString() ?? '0.00',
        'receivedAt': record['received_at'],
      });
    }

    if (_allRecordsData.isEmpty) {
      hasMore.value = false;
      return;
    }

    // 按时间倒序（最新在前）
    _allRecordsData.sort((a, b) {
      int ta = _parseReceivedTime(a['receivedAt']);
      int tb = _parseReceivedTime(b['receivedAt']);
      return tb.compareTo(ta);
    });

    // 保证当前用户在第一条
    final selfId = OpenIM.iMManager.userID;
    Map<String, dynamic>? selfRecord;
    final others = <Map<String, dynamic>>[];
    for (final r in _allRecordsData) {
      if (r['receiverId'] == selfId && selfRecord == null) {
        selfRecord = r;
      } else {
        others.add(r);
      }
    }

    final initialBatch = <Map<String, dynamic>>[];
    if (selfRecord != null) {
      initialBatch.add(selfRecord);
    }

    // 再取本页其他用户
    final firstPageOthers =
        others.take(_pageSize - initialBatch.length).toList();
    initialBatch.addAll(firstPageOthers);

    await _appendRecords(initialBatch, clearBefore: true);

    _loadedCount = initialBatch.length;
    // hasMore 在 fetchTransactionDetails 中根据 total_records 决定
  }

  /// 下拉到底部时加载更多（只追加下一页，不一次性拉完）
  Future<void> loadMore() async {
    if (!hasMore.value || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final nextPage = (_loadedCount / _pageSize).floor() + 1;
      final result = await _apiService.transactionReceiveDetails(
        transaction_id: luckyMoneyId.value,
        opUserImId: OpenIM.iMManager.userID,
        pageNum: nextPage,
        pageSize: _pageSize,
      );

      final records = result?['records'];
      if (records == null || records is! List || records.isEmpty) {
        hasMore.value = false;
        return;
      }

      final next = <Map<String, dynamic>>[];
      for (final record in records) {
        if (record == null || record is! Map) continue;
        final m = record as Map;
        final receiverId = m['receiver_im_id']?.toString() ?? '';
        if (receiverId.isEmpty) continue;
        next.add({
          'receiverId': receiverId,
          'amount': m['amount']?.toString() ?? '0.00',
          'receivedAt': m['received_at'],
        });
      }

      if (next.isEmpty) {
        hasMore.value = false;
        return;
      }

      await _appendRecords(next, clearBefore: false);
      _loadedCount += next.length;
      hasMore.value = _loadedCount < _totalRecords;
    } finally {
      _isLoadingMore = false;
    }
  }

  /// 将一批原始记录转换成 ReceivedRecord 并追加到列表
  Future<void> _appendRecords(List<Map<String, dynamic>> recordsData,
      {required bool clearBefore}) async {
    if (recordsData.isEmpty) return;

    final tempList = <ReceivedRecord>[];
    final userIds = <String>{};

    for (final recordData in recordsData) {
      final receiverId = recordData['receiverId'] as String;
      if (receiverId.isEmpty) continue;
      userIds.add(receiverId);
    }

    // 第二步：分页内批量获取用户信息，减少一次请求量
    final Map<String, String> userNicknameMap = {};
    final Map<String, String> userFaceURLMap = {};

    try {
      // 当前用户的信息可以直接从本地拿，不必走网络
      final selfId = OpenIM.iMManager.userID;
      if (selfId.isNotEmpty) {
        final selfInfo = OpenIM.iMManager.userInfo;
        if (selfInfo.userID != null) {
          userNicknameMap[selfInfo.userID!] =
              selfInfo.nickname ?? selfInfo.userID!;
          userFaceURLMap[selfInfo.userID!] = selfInfo.faceURL ?? '';
          userIds.remove(selfInfo.userID!);
        }
      }

      if (userIds.isNotEmpty) {
        final userInfoList = await OpenIM.iMManager.userManager.getUsersInfo(
          userIDList: userIds.toList(),
        );

        for (final userInfo in userInfoList) {
          if (userInfo.userID != null) {
            userNicknameMap[userInfo.userID!] =
                userInfo.nickname ?? userInfo.userID!;
            userFaceURLMap[userInfo.userID!] = userInfo.faceURL ?? '';
          }
        }
      }
    } catch (e) {
      ILogger.d('批量获取用户信息失败: $e');
    }

    // 第三步：构建记录
    for (final recordData in recordsData) {
      final receiverId = recordData['receiverId'] as String;
      final amount = recordData['amount'] as String;

      final userName = userNicknameMap[receiverId] ?? receiverId;
      final faceURL = userFaceURLMap[receiverId] ?? '';

      final receivedTime = _parseReceivedTime(recordData['receivedAt']);

      tempList.add(ReceivedRecord(
        userId: receiverId,
        userName: userName,
        amount: amount,
        receivedTime: receivedTime,
        faceURL: faceURL,
      ));
    }

    if (tempList.isEmpty) return;

    // 始终保证当前用户在第一条，其余用户按时间倒序
    final selfId = OpenIM.iMManager.userID;
    final selfRecords = <ReceivedRecord>[];
    final otherRecords = <ReceivedRecord>[];

    for (final r in tempList) {
      if (r.userId == selfId) {
        selfRecords.add(r);
      } else {
        otherRecords.add(r);
      }
    }

    otherRecords.sort((a, b) => b.receivedTime.compareTo(a.receivedTime));
    final ordered = <ReceivedRecord>[];
    ordered.addAll(selfRecords);
    ordered.addAll(otherRecords);

    if (clearBefore) {
      receivedList.clear();
    }
    receivedList.addAll(ordered);
  }

  /// 解析后端返回的时间字段为毫秒时间戳
  int _parseReceivedTime(dynamic receivedAt) {
    try {
      if (receivedAt == null) {
        return DateTime.now().millisecondsSinceEpoch;
      }
      if (receivedAt is String) {
        final dt = DateTime.tryParse(receivedAt);
        return dt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;
      }
      if (receivedAt is int) {
        return receivedAt;
      }
    } catch (e) {
      ILogger.d('解析时间戳失败: $e');
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  // 判断是否为当前用户
  bool isCurrentUser(String userId) {
    return userId == OpenIM.iMManager.userID;
  }

  // 获取显示的用户名
  String getDisplayName(String userId, String userName) {
    if (isCurrentUser(userId)) {
      return StrRes.you;
    }
    return userName;
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
