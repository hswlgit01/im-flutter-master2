import 'package:get/get.dart';

import 'chat_search_image_logic.dart';

class ChatSearchImageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatSearchImageLogic());
  }
}
