import 'package:flutter/material.dart';
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

  Widget _setupIcon(Widget icon, int unReadCount) {
    return Stack(
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          top: 0,
          right: 0,
          child: Transform.translate(
            offset: const Offset(2, -2),
            child: UnreadCountView(count: unReadCount),
          ),
        ),
      ],
    );
  }

  BottomNavigationBarItem _buildItem({
    required Widget icon,
    required Widget inactiveIcon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: inactiveIcon,
      activeIcon: icon,
      label: label,
    );
  }

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
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 0.5,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: logic.index.value,
              onTap: logic.switchTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Styles.c_FFFFFF,
              selectedItemColor: Styles.c_0089FF,
              unselectedItemColor: Styles.c_8E9AB0,
              selectedLabelStyle: Styles.ts_0089FF_10sp_semibold,
              unselectedLabelStyle: Styles.ts_8E9AB0_10sp,
              elevation: 0,
              items: [
                _buildItem(
                  icon: _setupIcon(
                    ImageRes.homeTab1Sel.toImage,
                    logic.unreadMsgCount.value,
                  ),
                  inactiveIcon: _setupIcon(
                    ImageRes.homeTab1Nor.toImage,
                    logic.unreadMsgCount.value,
                  ),
                  label: StrRes.home,
                ),
                _buildItem(
                  icon: _setupIcon(
                    ImageRes.homeTab2Sel.toImage,
                    logic.unhandledCount.value,
                  ),
                  inactiveIcon: _setupIcon(
                    ImageRes.homeTab2Nor.toImage,
                    logic.unhandledCount.value,
                  ),
                  label: StrRes.contacts,
                ),
                _buildItem(
                  icon: ImageRes.homeTab4Sel.toImage,
                  inactiveIcon: ImageRes.homeTab4Nor.toImage,
                  label: StrRes.mine,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
