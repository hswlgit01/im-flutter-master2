import 'package:get/get.dart';
import './logic.dart';

class ChatNotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatNotificationLogic>(() => ChatNotificationLogic());
  }
}