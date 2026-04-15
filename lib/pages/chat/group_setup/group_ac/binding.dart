import 'package:get/get.dart';
import './logic.dart';

class GroupAcBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GroupAcLogic>(() => GroupAcLogic());
  }
}