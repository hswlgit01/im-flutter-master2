import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class CheckinRuleDescriptionLogic extends GetxController {
  final isLoading = true.obs;
  final ruleDescription = ''.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;
  final rule = Rx<CheckinRule?>(null);

  @override
  void onInit() {
    super.onInit();
    _fetchRuleDescription();
  }

  Future<void> _fetchRuleDescription() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      // 获取签到规则
      final checkinRule = await Apis.getCheckinRule();
      rule.value = checkinRule;

      if (checkinRule.content.isEmpty) {
        isLoading.value = false;
        hasError.value = true;
        errorMessage.value = StrRes.noData;
        return;
      }

      ruleDescription.value = checkinRule.content;
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      hasError.value = true;
      errorMessage.value = e.toString();
      Logger.print('加载签到规则失败: $e');
    }
  }

  /// 刷新数据
  Future<void> refreshData() async {
    await _fetchRuleDescription();
  }
}