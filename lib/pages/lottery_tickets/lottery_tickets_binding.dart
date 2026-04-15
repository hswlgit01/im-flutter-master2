import 'package:get/get.dart';
import 'lottery_tickets_logic.dart';

class LotteryTicketsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LotteryTicketsLogic>(() => LotteryTicketsLogic());
  }
}