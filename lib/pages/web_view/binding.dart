import 'package:get/get.dart';
import './logic.dart';

class WebViewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WebViewLogic>(() => WebViewLogic());
  }
}