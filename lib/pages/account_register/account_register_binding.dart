import 'package:get/get.dart';
import 'account_register_logic.dart';

class AccountRegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountRegisterLogic>(() => AccountRegisterLogic());
  }
}