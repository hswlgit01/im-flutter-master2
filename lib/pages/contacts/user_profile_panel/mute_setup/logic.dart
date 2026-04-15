import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';

class MuteOption {
  final String title;
  final Duration duration;

  MuteOption(this.title, this.duration);
}

class MuteSetupLogic extends GetxController {
  String? userID;
  String? groupID;
  final RxInt selectedIndex = (-1).obs;
  final TextEditingController customTimeController = TextEditingController();

  final List<MuteOption> presetOptions = [
    MuteOption(StrRes.tenMinutes, Duration(minutes: 10)),
    MuteOption(StrRes.oneHour, Duration(hours: 1)),
    MuteOption(StrRes.twelveHours, Duration(hours: 12)),
    MuteOption(StrRes.oneDay, Duration(days: 1)),
    MuteOption(StrRes.unmute, Duration.zero),
  ];

  @override
  void onInit() {
    userID = Get.arguments['userID'];
    groupID = Get.arguments['groupID'];

    super.onInit();
  }

  void selectPreset(int index, Duration duration) {
    selectedIndex.value = index;
    customTimeController.clear();
  }

  void onCustomTimeChanged(String value) {
    if (value.isNotEmpty) {
      selectedIndex.value = -1;
    }
  }

  void changeGroupMemberMute() async {
    final int seconds = selectedIndex.value == -1
        ? int.parse(customTimeController.text)
        : presetOptions[selectedIndex.value].duration.inSeconds;
    if (seconds < 0) {
      EasyLoading.showToast(StrRes.muteTimeCannotBeLessThanZero);
      return;
    }
    EasyLoading.show();
    try {
      await OpenIM.iMManager.groupManager.changeGroupMemberMute(
        groupID: groupID!,
        userID: userID!,
        seconds: seconds,
      );
      EasyLoading.dismiss();
      Get.back(result: true);
    } catch (e) {
      EasyLoading.dismiss();

      // 根据错误码识别官方账号保护错误
      try {
        final dynamic exception = e;
        final errorCode = exception.code;

        // 1208 = OfficialAccountProtected
        if (errorCode == 1208 || errorCode == '1208') {
          IMViews.showToast('此用户为官方客服，无法禁言');
          return;
        }
      } catch (_) {}

      // 通用错误提示
      IMViews.showToast('操作失败，请稍后重试');
    }
  }
}
