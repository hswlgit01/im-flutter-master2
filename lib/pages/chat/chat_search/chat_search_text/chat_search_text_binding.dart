import 'package:get/get.dart';

import 'chat_search_text_logic.dart';

class ChatSearchTextBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatSearchTextLogic());
  }
}
