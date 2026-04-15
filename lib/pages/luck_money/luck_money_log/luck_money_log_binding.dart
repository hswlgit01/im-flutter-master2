import 'package:get/get.dart';

import 'luck_money_log_logic.dart';

class LuckMoneyLogBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LuckMoneyLogLogic());
  }
}
