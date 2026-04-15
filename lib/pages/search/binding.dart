import 'package:get/get.dart';
import './logic.dart';

class searchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SearchLogic>(() => SearchLogic());
  }
}