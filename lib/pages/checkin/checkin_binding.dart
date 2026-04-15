import 'package:get/get.dart';
import 'checkin_logic.dart';

class SignInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SignInLogic>(() => SignInLogic());
  }
}