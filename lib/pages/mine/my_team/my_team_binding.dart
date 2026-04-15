import 'package:get/get.dart';

import 'my_team_logic.dart';

class MyTeamBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyTeamLogic());
  }
}