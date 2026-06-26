import 'package:get/get.dart';

import 'login_logic.dart';
import '../account_register/account_register_logic.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginLogic());
    // dawn 2026-06-26 登录/注册同页 Tab：注册表单需要 AccountRegisterLogic。
    Get.lazyPut<AccountRegisterLogic>(() => AccountRegisterLogic());
  }
}
