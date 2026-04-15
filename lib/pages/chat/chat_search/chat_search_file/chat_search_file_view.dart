import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'chat_search_file_logic.dart';

class ChatSearchFilePage extends StatelessWidget {
  ChatSearchFilePage({super.key});
  final logic = Get.find<ChatSearchFileLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.file,
      ),
      backgroundColor: Styles.c_FFFFFF,
      body: Obx(() {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
          child: ListView.builder(
            itemCount: logic.messages.length,
            itemBuilder: (context, index) {
              final item = logic.messages[index];
              return GestureDetector(
                onTap: () {
                  IMUtils.previewFile(item);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
                  child: Row(
                    children: [
                      IMUtils.fileIcon(item.fileElem?.fileName ?? "").toImage
                        ..width = 30.w,
                      SizedBox(
                        width: 10.w,
                      ),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileElem?.fileName ?? "",
                            style: Styles.ts_0C1C33_17sp,
                          ),
                          Row(
                            children: [
                              Text(
                                IMUtils.formatBytes(
                                    item.fileElem?.fileSize ?? 0),
                                style: Styles.ts_8E9AB0_15sp,
                              ),
                              SizedBox(
                                width: 10.w,
                              ),
                              Text(item.senderNickname ?? "",
                                  style: Styles.ts_8E9AB0_15sp),
                              SizedBox(
                                width: 10.w,
                              ),
                              Text(
                                  IMUtils.getChatTimeline(
                                      item.sendTime!, 'HH:mm'),
                                  style: Styles.ts_8E9AB0_15sp)
                            ],
                          )
                        ],
                      ))
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
