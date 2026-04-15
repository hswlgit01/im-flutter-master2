import 'package:get/get.dart';
import 'lottery_wheel_logic.dart';

class LotteryWheelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LotteryWheelLogic>(() => LotteryWheelLogic());
  }
} 