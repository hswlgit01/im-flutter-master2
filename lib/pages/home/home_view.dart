import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../contacts/contacts_view.dart';
import '../conversation/conversation_view.dart';
import '../mine/mine_view.dart';
import 'home_logic.dart';

class HomePage extends StatelessWidget {
  final logic = Get.find<HomeLogic>();
  late final List<Widget> _pages = [
    ConversationPage(openParentDrawer: () {}),
    ContactsPage(),
    const MinePage(),
  ];

  HomePage({super.key});

  BottomBarItem _buildBottomItem({
    required String selectedImgRes,
    required String unselectedImgRes,
    required String label,
    int count = 0,
  }) =>
      BottomBarItem(
        selectedImgRes: selectedImgRes,
        unselectedImgRes: unselectedImgRes,
        label: label,
        imgWidth: 24.w,
        imgHeight: 24.w,
        count: count,
        onClick: logic.switchTab,
      );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        // dawn 2026-06-22 修复安卓会话页灰色遮罩：移除第三方持久 Tab/Drawer 外壳，避免页面保活或侧滑层残留半屏遮罩。
        backgroundColor: Styles.c_FFFFFF,
        body: ColoredBox(
          color: Styles.c_FFFFFF,
          child: IndexedStack(
            index: logic.index.value,
            children: _pages,
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomBar(
            // dawn 2026-06-22 修复底部导航图标异常放大：恢复项目自定义 BottomBar，显式固定图标尺寸。
            index: logic.index.value,
            items: [
              _buildBottomItem(
                selectedImgRes: ImageRes.homeTab1Sel,
                unselectedImgRes: ImageRes.homeTab1Nor,
                label: StrRes.home,
                count: logic.unreadMsgCount.value,
              ),
              _buildBottomItem(
                selectedImgRes: ImageRes.homeTab2Sel,
                unselectedImgRes: ImageRes.homeTab2Nor,
                label: StrRes.contacts,
                count: logic.unhandledCount.value,
              ),
              _buildBottomItem(
                selectedImgRes: ImageRes.homeTab4Sel,
                unselectedImgRes: ImageRes.homeTab4Nor,
                label: StrRes.mine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
