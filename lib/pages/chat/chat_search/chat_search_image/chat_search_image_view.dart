import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'chat_search_image_logic.dart';

class ChatSearchImagePage extends StatelessWidget {
  ChatSearchImagePage({super.key});
  final logic = Get.find<ChatSearchImageLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.picture,
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
                          return GestureDetector(
                            onTap: () {
                              IMUtils.previewPicture(listItem.value[i]);
                            },
                            child: ImageUtil.networkImage(
                            url: listItem
                                    .value[i].pictureElem?.bigPicture?.url ??
                                "",
                            width: (constraints.maxWidth - 2 * 3) * 0.25,
                            height: (constraints.maxWidth - 2 * 3) * 0.25,
                            fit: BoxFit.cover,
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
