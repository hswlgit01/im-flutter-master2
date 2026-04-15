import 'package:get/get.dart';
import 'checkin_rewards_logic.dart';

class CheckinRewardsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CheckinRewardsLogic>(() => CheckinRewardsLogic());
  }
}