import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../../../utils/log_util.dart';

class BillDetailLogic extends GetxController {
  static const String TAG = "BillDetailLogic";
  
  final billDetail = Rx<Map<String, dynamic>?>(null);
  final isLoading = true.obs;
  
  // 获取交易类型文字说明
  String getTransactionTypeText(int type) {
    switch (type) {
      case 1:
        return StrRes.transferExpense;
      case 2:
        return StrRes.transferRefund;
      case 3:
        return StrRes.transferReceipt;
      case 11:
        return StrRes.redPacketRefund;
      case 12:
        return StrRes.redPacketExpense;
      case 13:
        return StrRes.redPacketReceipt;
      case 21:
        return StrRes.recharge;
      case 22:
        return StrRes.withdraw;
      case 23:
        return StrRes.consumption;
      case 42:
        return StrRes.checkinReward;
      default:
        return StrRes.unknownType;
    }
  }
  
  @override
  void onInit() {
    super.onInit();
    final Map<String, dynamic>? bill = Get.arguments?['bill'];
    
    if (bill != null) {
      billDetail.value = bill;
      isLoading.value = false;
    } else {
      LogUtil.e(TAG, '缺少必要的账单信息');
      isLoading.value = false;
      IMViews.showToast(StrRes.walletOperationFailed);
      Get.back();
    }
  }
} 