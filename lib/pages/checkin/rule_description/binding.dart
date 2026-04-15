import 'package:get/get.dart';

import 'logic.dart';

class RuleDescriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RuleDescriptionLogic());
  }
}