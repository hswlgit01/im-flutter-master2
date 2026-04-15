import 'package:get/get.dart';
import './payment_method_logic.dart';

class PaymentMethodBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PaymentMethodLogic());
  }
}