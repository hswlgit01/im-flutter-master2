import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class CheckinRulePreviewWidget extends StatefulWidget {
  // 点击更多的回调
  final VoidCallback? onViewMore;

  const CheckinRulePreviewWidget({
    Key? key,
    this.onViewMore,
  }) : super(key: key);

  @override
  State<CheckinRulePreviewWidget> createState() => _CheckinRulePreviewWidgetState();
}

class _CheckinRulePreviewWidgetState extends State<CheckinRulePreviewWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _ruleDescription = '';
  CheckinRule? _rule;

  @override
  void initState() {
    super.initState();
    _fetchRuleDescription();
  }

  // 获取签到规则说明
  Future<void> _fetchRuleDescription() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // 获取签到规则
      final rule = await Apis.getCheckinRule();
      _rule = rule;

      if (rule.content.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = StrRes.noData;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _ruleDescription = rule.content;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      Logger.print('加载签到规则失败: $e');
    }
  }

  // 查找最大连续天数
  int _findMaxStreakDays() {
    if (_rule == null || _rule!.streakRewards.isEmpty) {
      return 1;
    }
    return _rule!.streakRewards.fold(1, (max, reward) => reward.days > max ? reward.days : max);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  StrRes.checkinRuleDescription,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Styles.c_0C1C33,
                  ),
                ),
                if (widget.onViewMore != null)
                  GestureDetector(
                    onTap: widget.onViewMore,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          StrRes.viewMore,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Styles.c_0089FF,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12.sp,
                          color: Styles.c_0089FF,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 分割线
          Divider(height: 1.h, color: Styles.c_E8EAEF),

          // 内容
          if (_isLoading)
            Container(
              height: 100.h,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
              ),
            )
          else if (_hasError)
            Container(
              height: 80.h,
              alignment: Alignment.center,
              child: Text(
                '${StrRes.loadFailed}: $_errorMessage',
                style: Styles.ts_8E9AB0_14sp,
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                // 规则内容预览
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 120.h, // 设置最大高度，超出部分隐藏
                  ),
                  child: ClipRRect(
                    // 圆角裁剪
                    child: SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(), // 禁止滚动，超出部分隐藏
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Html(
                          data: _ruleDescription,
                          style: {
                            "body": Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(14.sp),
                              color: Styles.c_0C1C33,
                            ),
                            "p": Style(
                              margin: Margins.only(bottom: 8),
                            ),
                            "h1,h2,h3,h4,h5,h6": Style(
                              color: Styles.c_0C1C33,
                              fontWeight: FontWeight.bold,
                              fontSize: FontSize(14.sp),
                            ),
                            "strong": Style(
                              fontWeight: FontWeight.bold,
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 连续签到提示（如果有连续签到奖励）
                if (_rule != null && _rule!.enableStreakRewards && _rule!.streakRewards.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Styles.c_0089FF.withOpacity(0.05),
                      border: Border(
                        top: BorderSide(color: Styles.c_E8EAEF, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: Styles.c_0089FF,
                          size: 18.sp,
                        ),
                        8.horizontalSpace,
                        Expanded(
                          child: Text(
                            '连续签到${_findMaxStreakDays()}天可获得最高奖励',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Styles.c_0089FF,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // 底部"查看更多"按钮
          if (!_isLoading && !_hasError && widget.onViewMore != null)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Styles.c_E8EAEF, width: 1),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: GestureDetector(
                onTap: widget.onViewMore,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Styles.c_F2F4F7,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        StrRes.viewFull,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Styles.c_0C1C33_70,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16.sp,
                        color: Styles.c_0C1C33_70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}