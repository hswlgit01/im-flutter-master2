import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import './logic.dart';

class MuteSetupView extends StatelessWidget {
  final logic = Get.find<MuteSetupLogic>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: TitleBar.back(title: StrRes.setMute, right: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            logic.changeGroupMemberMute();
          },
          child: Text(StrRes.determine, style: Styles.ts_0C1C33_17sp,),
        )),
        body: Obx(() {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Column(
                    children: List.generate(logic.presetOptions.length, (index) {
                      final item = logic.presetOptions[index];
                      return _buildListItem(
                        title: item.title,
                        index: index,
                        duration: item.duration,
                        context: context,
                      );
                    }),
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                    onTap: () {
                      logic.selectedIndex.value = -1;
                    },
                    title: Row(
                      children: [
                        Text(StrRes.custom, style: TextStyle(fontSize: 16.sp)),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: logic.customTimeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintStyle:
                                  TextStyle(fontSize: 16.sp, color: Colors.grey),
                            ),
                            onChanged: logic.onCustomTimeChanged,
                          ),
                        ),
                        Text(StrRes.day, style: TextStyle(fontSize: 16.sp)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildListItem({
    required String title,
    required int index,
    required Duration duration,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        logic.selectPreset(index, duration);
      },
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
        title: Text(title),
        trailing: logic.selectedIndex.value == index
            ? const Icon(Icons.check, color: Colors.blue)
            : null,
      ),
    );
  }
}
