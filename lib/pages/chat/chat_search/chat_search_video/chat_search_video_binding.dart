import 'package:get/get.dart';

import 'chat_search_video_logic.dart';

class ChatSearchVideoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatSearchVideoLogic());
  }
}
