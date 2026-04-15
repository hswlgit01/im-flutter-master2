import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'lottery_wheel_logic.dart';

class LotteryWheelView extends StatelessWidget {
  final logic = Get.find<LotteryWheelLogic>();

  LotteryWheelView({Key? key}) : super(key: key);

  /// 处理图片URL，使用项目统一的URL转换机制
  String _processImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return imageUrl;
    
    // 使用项目统一的URL转换工具
    return UrlConverter.convertMediaUrl(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        logic.onBackPressed();
        return false; // 阻止默认返回行为，由onBackPressed处理
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: TitleBar.back(
          title: StrRes.luckWheel,
          backgroundColor: const Color(0xFF1A1A2E),
          titleStyle: const TextStyle(color: Colors.white),
          backIconColor: Colors.white,
        ),
        body: Obx(() {
          if (logic.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              // 背景装饰
              _buildBackground(),
              
              // 主要内容
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 40.h),
                    
                    // 标题
                    _buildTitle(),
                    
                    SizedBox(height: 40.h),
                    
                    // 转盘区域
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: _buildWheelArea(),
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    // 抽奖按钮
                    _buildSpinButton(),
                    
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
              
              // 结果弹窗
              if (logic.showResult.value)
                _buildResultModal(),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F1A2E),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(25.r),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            StrRes.luckWheel,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          StrRes.spinToWin,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildWheelArea() {
    if (logic.prizes.isEmpty) {
      return Container(
        width: 300.w,
        height: 300.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Center(
      child: Container(
        width: 320.w,
        height: 320.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 转盘外圈装饰
            Container(
              width: 310.w,
              height: 310.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
            
            // 转盘本体
            AnimatedBuilder(
              animation: logic.rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: logic.rotationAnimation.value * pi / 180,
                  child: Container(
                    width: 290.w,
                    height: 290.w,
                    child: CustomPaint(
                      painter: WheelPainter(logic.prizes),
                      size: Size(290.w, 290.w),
                    ),
                  ),
                );
              },
            ),
            
            // 指针
            Positioned(
              top: 15.h,
              child: CustomPaint(
                painter: PointerPainter(),
                size: Size(30.w, 40.h),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSpinButton() {
    return Obx(() {
      final bool canSpin = !logic.isSpinning.value && !logic.hasUsed.value;
      
      return GestureDetector(
        onTap: canSpin ? logic.startSpin : null,
        child: Container(
          width: 200.w,
          height: 60.h,
          decoration: BoxDecoration(
            gradient: canSpin
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF666666), Color(0xFF999999)],
                  ),
            borderRadius: BorderRadius.circular(30.r),
            boxShadow: canSpin
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: logic.isSpinning.value
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    logic.hasUsed.value ? StrRes.used : StrRes.startLottery,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      );
    });
  }

  Widget _buildResultModal() {
    final prize = logic.winningPrize.value;
    if (prize == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40.w),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 结果图标
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: prize.id == 'thank_you'
                      ? Colors.orange
                      : Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  prize.id == 'thank_you'
                      ? Icons.sentiment_neutral
                      : Icons.celebration,
                  color: Colors.white,
                  size: 40.w,
                ),
              ),
              
              SizedBox(height: 20.h),
              
              // 结果标题
              Text(
                prize.id == 'thank_you' ? StrRes.noLuck : StrRes.congratulations,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              
              SizedBox(height: 12.h),
              
              // 奖品信息
              if (prize.imageUrl != null)
                Container(
                  width: 60.w,
                  height: 60.w,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    color: prize.backgroundColor.withOpacity(0.1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      _processImageUrl(prize.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: prize.backgroundColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.card_giftcard,
                            color: prize.backgroundColor,
                            size: 30.w,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            color: prize.backgroundColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(prize.backgroundColor),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              Text(
                prize.id == 'thank_you'
                    ? StrRes.tryNextTime
                    : StrRes.prizeWon.replaceAll('%s', prize.name),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 24.h),
              
              // 确认按钮
              GestureDetector(
                onTap: logic.closeResult,
                child: Container(
                  width: double.infinity,
                  height: 44.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                    ),
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                  child: Center(
                                          child: Text(
                        StrRes.confirm,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 转盘绘制器
class WheelPainter extends CustomPainter {
  final List<WheelPrize> prizes;

  WheelPainter(this.prizes);

  /// 处理图片URL，使用项目统一的URL转换机制
  String _processImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return imageUrl;
    
    // 使用项目统一的URL转换工具
    return UrlConverter.convertMediaUrl(imageUrl);
  }

  /// 绘制礼物盒图标
  void _drawGiftIcon(Canvas canvas, Offset center, Paint paint) {
    // 绘制礼物盒主体（矩形）
    final boxRect = Rect.fromCenter(
      center: center,
      width: 16,
      height: 12,
    );
    canvas.drawRect(boxRect, paint);
    
    // 绘制礼物盒盖子（矩形）
    final lidRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 8),
      width: 20,
      height: 4,
    );
    canvas.drawRect(lidRect, paint);
    
    // 绘制丝带（垂直线）
    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 6),
      ribbonPaint,
    );
    
    // 绘制丝带（水平线）
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      ribbonPaint,
    );
    
    // 绘制蝴蝶结
    final bowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 10), 2, bowPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    print('WheelPainter.paint 被调用, prizes数量: ${prizes.length}');
    
    if (prizes.isEmpty) {
      // 如果没有奖品数据，绘制一个提示
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2;
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
      
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '加载中...',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
      );
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sectorAngle = 2 * pi / prizes.length;

    // 绘制外圆环
    final outerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, outerCirclePaint);

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * sectorAngle - pi / 2;

      // 绘制扇形背景
      final paint = Paint()
        ..color = prizes[i].backgroundColor
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        sectorAngle,
        false,
      );
      path.close();
      canvas.drawPath(path, paint);

      // 绘制扇形边框
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);

      // 绘制奖品图标（使用默认图标）
      if (prizes[i].imageUrl != null && prizes[i].imageUrl!.isNotEmpty) {
        final imageAngle = startAngle + sectorAngle / 2;
        final imageRadius = radius * 0.5;
        final imageX = center.dx + cos(imageAngle) * imageRadius;
        final imageY = center.dy + sin(imageAngle) * imageRadius;
        
        // 绘制图标背景
        final iconBgPaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(imageX, imageY), 18, iconBgPaint);
        
        // 绘制图标边框
        final iconBorderPaint = Paint()
          ..color = prizes[i].backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(imageX, imageY), 18, iconBorderPaint);
        
        // 绘制默认图标（礼物图标）
        final iconPaint = Paint()
          ..color = prizes[i].backgroundColor
          ..style = PaintingStyle.fill;
        
        // 绘制礼物盒图标
        _drawGiftIcon(canvas, Offset(imageX, imageY), iconPaint);
      }

      // 绘制奖品文字
      final textAngle = startAngle + sectorAngle / 2;
      final textRadius = radius * (prizes[i].imageUrl != null && prizes[i].imageUrl!.isNotEmpty ? 0.8 : 0.7); // 有图片时文字位置外移
      final textX = center.dx + cos(textAngle) * textRadius;
      final textY = center.dy + sin(textAngle) * textRadius;

      // 根据奖品数量调整文字大小 - 优化为更小的字体
      double fontSize = 12.0;
      if (prizes.length > 8) {
        fontSize = 8.0;
      } else if (prizes.length > 6) {
        fontSize = 10.0;
      } else if (prizes.length > 4) {
        fontSize = 11.0;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i].name,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: [
              const Shadow(
                color: Colors.black87,
                offset: Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2, // 允许两行显示
      );

      // 限制文字宽度，确保在扇形内
      final maxTextWidth = radius * 0.6;
      textPainter.layout(maxWidth: maxTextWidth);
      
      // 保存canvas状态
      canvas.save();
      
      // 移动到扇形中心位置
      canvas.translate(textX, textY);
      
      // 计算文字旋转角度 - 让文字始终朝向圆心外侧
      double rotationAngle = textAngle + pi / 2;
      
      // 确保文字不会倒置显示
      if (rotationAngle > pi / 2 && rotationAngle < 3 * pi / 2) {
        rotationAngle += pi; // 翻转180度
      }
      
      canvas.rotate(rotationAngle);
      
      // 绘制半透明文字背景
      final textBgPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      final textBgRect = Rect.fromCenter(
        center: Offset.zero,
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(textBgRect, const Radius.circular(8)),
        textBgPaint,
      );
      
      // 绘制文字，确保居中
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      
      // 恢复canvas状态
      canvas.restore();
    }

    // 绘制中心圆
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 25, centerPaint);

    // 绘制中心圆边框
    final centerBorderPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 25, centerBorderPaint);

    // 绘制中心圆内部小圆
    final centerInnerPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, centerInnerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 指针绘制器
class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // 绘制指针阴影
    final shadowPath = Path();
    shadowPath.moveTo(size.width / 2 + 1, 3);
    shadowPath.lineTo(size.width / 2 - 15 + 1, size.height + 3);
    shadowPath.lineTo(size.width / 2 + 15 + 1, size.height + 3);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // 绘制指针主体
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width / 2 - 15, size.height);
    path.lineTo(size.width / 2 + 15, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // 绘制指针边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);

    // 绘制指针顶部圆形
    final circlePaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, 8), 8, circlePaint);

    final circleBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width / 2, 8), 8, circleBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 