import 'package:get/get.dart';

import 'luck_money_logic.dart';

class LuckMoneyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LuckMoneyLogic());
  }
}
