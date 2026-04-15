import 'package:get/get.dart';
import 'prize_records_logic.dart';

class PrizeRecordsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrizeRecordsLogic>(() => PrizeRecordsLogic());
  }
}