import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sprintf/sprintf.dart';
import './logic.dart';

class GroupAcView extends StatelessWidget {
  final logic = Get.find<GroupAcLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.groupAc,
        right: Obx(() {
          if (logic.isOwnerOrAdmin) {
            // 非编辑状态显示编辑按钮，编辑状态显示清除和发布按钮
            if (!logic.isEdit.value) {
              return GestureDetector(
                onTap: () {
                  logic.isEdit.value = true;
                  logic.textController.text =
                      logic.groupInfo.value.notification ?? '';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusScope.of(context).requestFocus(logic.focusNode);
                  });
                },
                child: Text(
                  StrRes.edit,
                  style: Styles.ts_0C1C33_17sp,
                ),
              );
            } else {
              // 编辑状态显示两个按钮：清除和发布
              return Row(
                children: [
                  TextButton(
                    onPressed: () {
                      logic.textController.clear();
                      logic.value.value = '';
                    },
                    child: Text(
                      StrRes.clearAll,
                      style: Styles.ts_0C1C33_17sp,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      logic.saveGroupAnnouncement();
                    },
                    child: Text(
                      StrRes.publish,
                      style: Styles.ts_0C1C33_17sp,
                    ),
                  ),
                ],
              );
            }
          }
          return const SizedBox.shrink();
        }),
      ),
      body: Obx(() {
        return SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logic.groupInfo.value.notificationUserID != null &&
                    logic.groupInfo.value.notificationUserID!.isNotEmpty)
                  Row(
                    children: [
                      AvatarView(
                        text: logic.userInfo.value.nickname,
                        url: logic.userInfo.value.faceURL,
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            logic.userInfo.value.nickname ?? '',
                            style: TextStyle(
                              color: Color(0xFF1B1B1B),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            sprintf(StrRes.updatedOn, [
                              IMUtils.getChatTimeline(
                                  logic.groupInfo.value.notificationUpdateTime!)
                            ]),
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                SizedBox(height: 16.h),
                Container(
                  constraints: BoxConstraints(
                    minHeight: 300.h,
                    maxHeight: logic.isEdit.value ? 300.h : double.infinity,
                  ),
                  child: logic.isEdit.value
                      ? TextField(
                          controller: logic.textController,
                          maxLength: 1000,
                          expands: true,
                          focusNode: logic.focusNode,
                          maxLines: null,
                          minLines: null,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '${logic.value.value.length}/1000',
                          ),
                          onChanged: (value) {
                            logic.value.value = value;
                          },
                        )
                      : Text(
                          "${logic.groupInfo.value.notification}",
                          style: TextStyle(
                            color: Color(0xFF1B1B1B),
                            fontSize: 16.sp,
                          ),
                        ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: Text(
                    '—— ${StrRes.groupAcPermissionTips} ——',
                    style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      }),
    );
  }
}
