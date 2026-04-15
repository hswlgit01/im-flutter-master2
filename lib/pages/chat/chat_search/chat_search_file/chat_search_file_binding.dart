import 'package:get/get.dart';

import 'chat_search_file_logic.dart';

class ChatSearchFileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatSearchFileLogic());
  }
}
