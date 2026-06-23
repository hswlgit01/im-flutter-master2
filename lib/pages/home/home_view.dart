import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../contacts/contacts_view.dart';
import '../conversation/conversation_view.dart';
import '../mine/mine_view.dart';
import 'home_logic.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final logic = Get.find<HomeLogic>();
  late final PageController _pageController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: logic.index.value);
    _pages = [
      ConversationPage(openParentDrawer: () {}),
      ContactsPage(),
      const MinePage(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (logic.index.value != index) {
      logic.switchTab(index);
    }
    if (_pageController.hasClients &&
        (_pageController.page?.round() ?? logic.index.value) != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

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
        // dawn 2026-06-22 修复底部导航图标异常放大：手机端导航图标使用固定逻辑像素，不跟随 ScreenUtil 宽度缩放。
        imgWidth: 24,
        imgHeight: 24,
        count: count,
        onClick: _switchTab,
      );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        // dawn 2026-06-22 修复安卓会话页灰色遮罩：移除第三方持久 Tab/Drawer 外壳，避免页面保活或侧滑层残留半屏遮罩。
        backgroundColor: Styles.c_FFFFFF,
        body: ColoredBox(
          color: Styles.c_FFFFFF,
          child: PageView(
            // dawn 2026-06-22 恢复首页左右滑动：使用原生 PageView 管理三个主页面，避免第三方 Drawer/Tab 层残留灰色遮罩。
            controller: _pageController,
            onPageChanged: (index) {
              if (logic.index.value != index) {
                logic.switchTab(index);
              }
            },
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
