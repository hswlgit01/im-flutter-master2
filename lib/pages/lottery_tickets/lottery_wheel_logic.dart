import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';

// 轮盘奖品数据模型
class WheelPrize {
  final String id;
  final String name;
  final String? imageUrl;
  final Color backgroundColor;
  final double probability; // 中奖概率 (0-100)

  WheelPrize({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.backgroundColor,
    required this.probability,
  });
}

class LotteryWheelLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final RxList<WheelPrize> prizes = <WheelPrize>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSpinning = false.obs;
  final RxBool hasUsed = false.obs;
  final RxBool showResult = false.obs;
  final RxInt winningIndex = 0.obs;
  final Rx<WheelPrize?> winningPrize = Rx<WheelPrize?>(null);
  
  late AnimationController animationController;
  late Animation<double> rotationAnimation;
  
  // 参数
  String ticketId = '';
  String lotteryTicketId = '';
  
  // 随机颜色列表
  final List<Color> _colors = [
    const Color(0xFFFF8C8C),
    const Color(0xFFFFC773),
    const Color(0xFF95D881),
    const Color(0xFF73C0DE),
    const Color(0xFF9D95FF),
    const Color(0xFFFF9C6E),
    const Color(0xFFFFB7B7),
    const Color(0xFFFFD700),
    const Color(0xFF98FB98),
    const Color(0xFF87CEEB),
    const Color(0xFFDDA0DD),
    const Color(0xFFF08080),
  ];

  @override
  void onInit() {
    super.onInit();
    
    // 获取参数
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      ticketId = arguments['id'] ?? '';
      lotteryTicketId = arguments['lottery_ticket_id'] ?? '';
    }
    
    // 初始化动画控制器
    animationController = AnimationController(
      duration: const Duration(seconds: 4), // 增加动画时长
      vsync: this,
    );
    
    rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
    ));
    
    // 加载抽奖数据
    fetchLotteryDetail();
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  // 获取抽奖详情
  Future<void> fetchLotteryDetail() async {
    try {
      isLoading.value = true;
      

      
      final response = await Apis.getLotteryDetail(
        id: lotteryTicketId,
      );
      
      ILogger.d('response$response');



      if (response != null ) {
        final lotteryData = response;
        final lotteryConfig = lotteryData['lottery_config'] as List?;
        
        if (lotteryConfig != null) {
          await _parseLotteryConfig(lotteryConfig);
        }
      }
    } catch (e) {
      Logger.print('获取抽奖详情失败: $e');
      // 添加测试数据以便开发调试
    } finally {
      isLoading.value = false;
    }
  }

  /// 解析抽奖配置数据
  Future<void> _parseLotteryConfig(List lotteryConfig) async {
    if (lotteryConfig.isEmpty) {
      ILogger.w('抽奖配置为空');
      prizes.value = [];
      return;
    }

    final List<WheelPrize> tempPrizes = [];
    double totalProbability = 0;
    
    ILogger.d('开始解析奖品配置，数量: ${lotteryConfig.length}');
    
    // 第一遍遍历：解析基础数据并计算总概率
    for (int i = 0; i < lotteryConfig.length; i++) {
      final config = lotteryConfig[i];
      final probability = _calculateProbability(config);
      
      totalProbability += probability;
      
      final rewardInfo = config['lottery_reward_info'] ?? {};
      final prize = WheelPrize(
        id: config['id']?.toString() ?? 'prize_$i',
        name: rewardInfo['name']?.toString() ?? '未知奖品',
        imageUrl: rewardInfo['img']?.toString(),
        backgroundColor: _getPrizeColor(i),
        probability: probability,
      );
      
      tempPrizes.add(prize);
      ILogger.d('解析奖品 ${i + 1}: ${prize.name}, 概率: ${probability.toStringAsFixed(2)}%');
    }
    
    // 第二遍遍历：处理特殊情况并调整概率
    _adjustProbabilities(tempPrizes, totalProbability);
    
    prizes.value = tempPrizes;
    ILogger.d('解析完成，最终奖品数量: ${tempPrizes.length}, 总概率: ${_calculateTotalProbability(tempPrizes).toStringAsFixed(2)}%');
  }

  /// 计算单个奖品的概率
  double _calculateProbability(Map<String, dynamic> config) {
    final left = int.tryParse(config['left']?.toString() ?? '0') ?? 0;
    final right = int.tryParse(config['right']?.toString() ?? '0') ?? 0;
    
    // 处理特殊情况
    if (left == 100 && right == 100) {
      return 0; // 标记为必中奖品
    }
    
    if (left >= right) {
      ILogger.w('概率范围错误: left=$left, right=$right，设置为0');
      return 0;
    }
    
    return (right - left).toDouble();
  }

  /// 获取奖品颜色
  Color _getPrizeColor(int index) {
    return _colors[index % _colors.length];
  }

  /// 调整概率分配
  void _adjustProbabilities(List<WheelPrize> prizes, double originalTotalProbability) {
    if (prizes.isEmpty) return;

    // 检查是否所有奖品都是必中（概率为0）
    final allZeroProbability = prizes.every((p) => p.probability == 0);
    
    if (allZeroProbability) {
      // 所有奖品平均分配概率
      final averageProbability = 100.0 / prizes.length;
      for (int i = 0; i < prizes.length; i++) {
        prizes[i] = _updatePrizeProbability(prizes[i], averageProbability);
      }
      ILogger.d('所有奖品平均分配概率: ${averageProbability.toStringAsFixed(2)}%');
    } else {
      // 处理概率总和不为100%的情况
      final currentTotal = _calculateTotalProbability(prizes);
      if ((currentTotal - 100).abs() > 0.01) { // 允许0.01%的误差
        _normalizeProbabilities(prizes, currentTotal);
      }
    }
  }

  /// 更新奖品概率
  WheelPrize _updatePrizeProbability(WheelPrize prize, double newProbability) {
    return WheelPrize(
      id: prize.id,
      name: prize.name,
      imageUrl: prize.imageUrl,
      backgroundColor: prize.backgroundColor,
      probability: newProbability,
    );
  }

  /// 计算总概率
  double _calculateTotalProbability(List<WheelPrize> prizes) {
    return prizes.fold(0.0, (sum, prize) => sum + prize.probability);
  }

  /// 标准化概率（确保总和为100%）
  void _normalizeProbabilities(List<WheelPrize> prizes, double currentTotal) {
    if (currentTotal <= 0) {
      // 如果总概率为0，平均分配
      final averageProbability = 100.0 / prizes.length;
      for (int i = 0; i < prizes.length; i++) {
        prizes[i] = _updatePrizeProbability(prizes[i], averageProbability);
      }
      ILogger.d('总概率为0，平均分配概率: ${averageProbability.toStringAsFixed(2)}%');
    } else {
      // 按比例调整概率
      final scale = 100.0 / currentTotal;
      for (int i = 0; i < prizes.length; i++) {
        final adjustedProbability = prizes[i].probability * scale;
        prizes[i] = _updatePrizeProbability(prizes[i], adjustedProbability);
      }
      ILogger.d('概率标准化完成，缩放比例: ${scale.toStringAsFixed(4)}');
    }
  }

  /// 验证奖品配置
  bool _validatePrizeConfig(List<dynamic> lotteryConfig) {
    if (lotteryConfig.isEmpty) {
      ILogger.w('奖品配置为空');
      return false;
    }

    for (int i = 0; i < lotteryConfig.length; i++) {
      final config = lotteryConfig[i];
      
      // 检查必需字段
      if (config['id'] == null) {
        ILogger.e('奖品 ${i + 1} 缺少id字段');
        return false;
      }
      
      if (config['lottery_reward_info'] == null) {
        ILogger.e('奖品 ${i + 1} 缺少lottery_reward_info字段');
        return false;
      }
      
      final rewardInfo = config['lottery_reward_info'];
      if (rewardInfo['name'] == null) {
        ILogger.e('奖品 ${i + 1} 缺少name字段');
        return false;
      }
    }

    return true;
  }

  // 开始抽奖
  Future<bool> startSpin() async {
    if (isSpinning.value || hasUsed.value) {
      if (hasUsed.value) {
        IMViews.showToast(StrRes.ticketUsed);
      }
      return false;
    }
    
    try {
      isSpinning.value = true;
      
      // 调用抽奖接口
      final response = await Apis.useLotteryTicket(
        lotteryTicketId: ticketId,
      );
      
      if (response != null && response is Map<String, dynamic>) {
        final data = response;
        String winningId = "thank_you";

        // 检查是否有中奖配置
        if (data['reward_config'] != null && data['reward_config']['id'] != null) {
          winningId = data['reward_config']['id'].toString();
        }

        // 找到中奖索引
        final winIndex = prizes.indexWhere((prize) => prize.id == winningId);

        if (winIndex != -1) {
          // 设置中奖索引
          winningIndex.value = winIndex;
          winningPrize.value = prizes[winIndex];
          
          // 设置状态
          hasUsed.value = true;
          
          // 开始转盘动画
          await _performSpinAnimation(winIndex);
          return true;
        }
      }
      
      // 抽奖失败处理
      _handleLotteryError();
      return false;
      
    } catch (error) {
      ILogger.e('使用奖券失败: $error');
      _handleLotteryError();
      return false;
    } finally {
      isSpinning.value = false;
    }
  }

  /// 处理抽奖错误
  void _handleLotteryError() {
    IMViews.showToast(StrRes.lotteryError);
  }

  // 执行转盘动画
  Future<void> _performSpinAnimation(int targetIndex) async {
    final double targetAngle = _calculateTargetAngle(targetIndex);
    
    // 创建更流畅的动画
    rotationAnimation = Tween<double>(
      begin: 0,
      end: targetAngle + 360 * 5, // 多转5圈增加视觉效果
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutCubic, // 使用更平滑的缓动曲线
    ));
    
    // 开始动画
    await animationController.forward();
    
    // 动画完成后延迟显示结果
    await Future.delayed(const Duration(milliseconds: 500));
    showResult.value = true;
  }

  // 计算目标角度
  double _calculateTargetAngle(int targetIndex) {
    if (prizes.isEmpty) return 0;
    
    final double sectorAngle = 360.0 / prizes.length;
    final double targetAngle = targetIndex * sectorAngle + sectorAngle / 2;
    
    return 360 - targetAngle; // 因为转盘是顺时针转动
  }

  // 获取随机颜色
  Color _getRandomColor(int index) {
    return _colors[index % _colors.length];
  }

  // 关闭结果弹窗
  void closeResult() {
    showResult.value = false;
    // 返回时带上标记，表示有更新
    Get.back(result: true);
  }

  // 重置动画
  void resetAnimation() {
    animationController.reset();
    isSpinning.value = false;
    showResult.value = false;
    hasUsed.value = false;
  }

  // 页面返回时的处理
  // 当用户手动返回时，如果有抽奖操作，也要标记为需要刷新
  void onBackPressed() {
    if (hasUsed.value) {
      Get.back(result: true);
    } else {
      Get.back();
    }
  }

} 