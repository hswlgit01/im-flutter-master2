import 'package:get/get.dart';
import './logic.dart';

class MuteSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MuteSetupLogic>(() => MuteSetupLogic());
  }
}