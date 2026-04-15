import 'package:get/get.dart';
import './logic.dart';

class MyQrcodeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyQrcodeLogic>(() => MyQrcodeLogic());
  }
}