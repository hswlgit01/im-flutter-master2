import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class CheckinRuleWidget extends StatefulWidget {
  const CheckinRuleWidget({Key? key}) : super(key: key);

  @override
  State<CheckinRuleWidget> createState() => _CheckinRuleWidgetState();
}

class _CheckinRuleWidgetState extends State<CheckinRuleWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _ruleDescription = '';

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

      // 获取签到规则说明
      final description = await Apis.getCheckinRuleDescription();

      setState(() {
        _isLoading = false;
        _ruleDescription = description;
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

  @override
  Widget build(BuildContext context) {
    // 如果内容为空或正在加载中则什么都不显示
    if (_ruleDescription.isEmpty && !_isLoading) {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
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
            Padding(
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
                  ),
                  "strong": Style(
                    fontWeight: FontWeight.bold,
                  ),
                },
              ),
            ),
        ],
      ),
    );
  }
}