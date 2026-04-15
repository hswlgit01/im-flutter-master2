import 'package:get/get.dart';

import 'group_member_list_logic.dart';

class LuckMoneyGroupMemberListBinding extends Bindings {
  @override
  void dependencies() {
    print('Registering LuckMoneyGroupMemberListLogic with tag: luck_money_select');
    Get.lazyPut(() => LuckMoneyGroupMemberListLogic(), tag: 'luck_money_select');
  }
}
