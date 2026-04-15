import 'package:get/get.dart';

import 'add_acount_logic.dart';

class AddAcountPageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AddAcountPageLogic>(() => AddAcountPageLogic());
  }
}