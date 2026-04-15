import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'chat_search_video_logic.dart';

class ChatSearchVideoPage extends StatelessWidget {
  ChatSearchVideoPage({super.key});
  final logic = Get.find<ChatSearchVideoLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.video,
      ),
      backgroundColor: Styles.c_FFFFFF,
      body: Obx(() {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: ListView.builder(
            itemCount: logic.messageMap.entries.length,
            itemBuilder: (context, index) {
              final listItem = logic.messageMap.entries.toList()[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 12.h,
                  ),
                  Text(
                    listItem.key,
                    style: Styles.ts_8E9AB0_15sp,
                  ),
                  Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: List.generate(listItem.value.length, (i) {
                        return LayoutBuilder(builder: (context, constraints) {
                          return SizedBox(
                            width: (constraints.maxWidth - 2 * 3) * 0.25,
                            height: (constraints.maxWidth - 2 * 3) * 0.25,
                            child: GestureDetector(
                              onTap: () {
                                IMUtils.previewMediaFile(
                                    context: Get.context!,
                                    message: listItem.value[i]);
                              },
                              child: Stack(
                                children: [
                                  ImageUtil.networkImage(
                                    url: listItem
                                            .value[i].videoElem?.snapshotUrl ??
                                        "",
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned.fill(
                                      child: Center(
                                    child: ImageRes.videoPause.toImage
                                      ..width = 30.w,
                                  ))
                                ],
                              ),
                            ),
                          );
                        });
                      }))
                ],
              );
            },
          ),
        );
      }),
    );
  }
}
