import 'package:get/get.dart';
import 'checkin_rule_description_logic.dart';

class CheckinRuleDescriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CheckinRuleDescriptionLogic>(() => CheckinRuleDescriptionLogic());
  }
}