import 'package:get/get.dart';

import 'luck_money_detail_logic.dart';

class LuckMoneyDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LuckMoneyDetailLogic());
  }
}
