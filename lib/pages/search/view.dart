import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import './logic.dart';

class SearchView extends StatelessWidget {
  final logic = Get.find<SearchLogic>();

  SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: TitleBar.search(
          controller: logic.inputCtrl,
          onSubmitted: (_) => logic.submit(),
        ),
        body: Obx(() {
          Widget child;
          switch (logic.index.value) {
            case 0:
              child = _buildComprehensiveView();
              break;
            case 1:
              child = _buildContactView();
              break;
            case 2:
              child = _buildGroupView();
              break;
            case 3:
              child = _buildChatRecordView();
              break;
            case 4:
              child = _buildFileView();
              break;
            default:
              child = const SizedBox();
          }
          return Column(
            children: [
              CustomTabBar(
                  index: logic.index.value,
                  indicatorColor: Styles.c_0089FF,
                  selectedStyle: TextStyle(
                      color: Styles.c_0089FF,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500),
                  unselectedStyle: TextStyle(
                      color: Styles.c_8E9AB0,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400),
                  onTabChanged: (i) => logic.switchTab(i),
                  showUnderline: true,
                  labels: [
                    StrRes.globalSearchAll,
                    StrRes.globalSearchContacts,
                    StrRes.globalSearchGroup,
                    StrRes.globalSearchChatHistory,
                    StrRes.globalSearchChatFile
                  ]),
              Expanded(
                child: child,
              )
            ],
          );
        }));
  }

  Widget _buildComprehensiveView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 10.h,
          ),
          if (logic.friends.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: _buildComprehensiveItemView(
                  title: "联系人",
                  moreText: "查看更多相关联系人",
                  showMore: logic.friends.length > 2,
                  onTapMore: () {
                    logic.switchTab(1);
                  },
                  child: Column(
                      children: List.generate(
                    min(2, logic.friends.length),
                    (i) {
                      return _buildContactItemView(logic.friends[i]);
                    },
                  ))),
            ),
          if (logic.groups.isNotEmpty)
            SizedBox(
              height: 10.h,
            ),
          if (logic.groups.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: _buildComprehensiveItemView(
                  title: "群组",
                  moreText: "查看更多相关群组",
                  showMore: logic.groups.length > 2,
                  onTapMore: () {
                    logic.switchTab(2);
                  },
                  child: Column(
                      children: List.generate(
                    min(2, logic.groups.length),
                    (i) {
                      return _buildGroupItemView(logic.groups[i]);
                    },
                  ))),
            ),
          if (logic.chatTexts.isNotEmpty)
            SizedBox(
              height: 10.h,
            ),
          if (logic.chatTexts.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: _buildComprehensiveItemView(
                  title: "聊天记录",
                  moreText: "查看更多相关聊天记录",
                  showMore: logic.chatTexts.length > 2,
                  onTapMore: () {
                    logic.switchTab(3);
                  },
                  child: Column(
                      children: List.generate(
                    min(2, logic.chatTexts.length),
                    (i) {
                      return _buildChatItemView(logic.chatTexts[i]);
                    },
                  ))),
            ),
          if (logic.chatFiles.isNotEmpty)
            SizedBox(
              height: 10.h,
            ),
          if (logic.chatFiles.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: _buildComprehensiveItemView(
                  title: "文件",
                  moreText: "查看更多相关文件",
                  showMore: logic.chatFiles.length > 2,
                  onTapMore: () {
                    logic.switchTab(4);
                  },
                  child: Column(
                      children: List.generate(
                    min(2, logic.chatFiles.length),
                    (i) {
                      return _buildFileItemView(logic.chatFiles[i]);
                    },
                  ))),
            )
        ],
      ),
    );
  }

  Widget _buildContactView() {
    return ListView.builder(
        itemCount: logic.friends.length,
        itemBuilder: (context, i) {
          return _buildContactItemView(logic.friends[i]);
        });
  }

  Widget _buildGroupView() {
    return ListView.builder(
        itemCount: logic.groups.length,
        itemBuilder: (context, i) {
          return _buildGroupItemView(logic.groups[i]);
        });
  }

  Widget _buildChatRecordView() {
    return ListView.builder(
        itemCount: logic.chatTexts.length,
        itemBuilder: (context, i) {
          return _buildChatItemView(logic.chatTexts[i]);
        });
  }

  Widget _buildFileView() {
    return ListView.builder(
        itemCount: logic.chatFiles.length,
        itemBuilder: (context, i) {
          return _buildFileItemView(logic.chatFiles[i]);
        });
  }

  Widget _buildComprehensiveItemView(
      {required Widget child,
      required String title,
      required String moreText,
      bool showMore = false,
      Function? onTapMore}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8.r))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 10.h),
            child: Text(
              title,
              style: Styles.ts_8E9AB0_15sp,
            ),
          ),
          child,
          Divider(
            color: Styles.c_E8EAEF,
            height: 1,
          ),
          if (showMore)
            GestureDetector(
              onTap: () => onTapMore?.call(),
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      moreText,
                      style: Styles.ts_0089FF_17sp,
                    ),
                    ImageRes.rightArrow.toImage..width = 24.w
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildContactItemView(SearchFriendsInfo info) {
    return Ink(
      height: 64.h,
      color: Styles.c_FFFFFF,
      child: InkWell(
        onTap: () => logic.toFriendDetail(info),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              AvatarView(
                url: info.faceURL,
                text: info.nickname,
              ),
              10.horizontalSpace,
              "${info.nickname}".toText..style = Styles.ts_0C1C33_17sp,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupItemView(GroupInfo info) {
    return Ink(
      height: 64.h,
      color: Styles.c_FFFFFF,
      child: InkWell(
        onTap: () => logic.toGroupChat(info),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              const AvatarView(
                isGroup: true,
              ),
              10.horizontalSpace,
              "${info.groupName}".toText..style = Styles.ts_0C1C33_17sp,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItemView(SearchResultItems item) {
    return Ink(
      height: 64.h,
      color: Styles.c_FFFFFF,
      child: InkWell(
        onTap: () => logic.toChatText(item),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              AvatarView(
                isGroup: ConversationType.superGroup == item.conversationType,
                url: item.faceURL,
                text: item.showName,
              ),
              10.horizontalSpace,
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      "${item.showName}".toText..style = Styles.ts_0C1C33_17sp,
                      Text(
                        IMUtils.getChatTimeline(
                            item.messageList?.lastOrNull?.sendTime ?? 0,
                            'HH:mm'),
                        style: Styles.ts_8E9AB0_14sp,
                      )
                    ],
                  ),
                  Text("${item.messageCount}条相关的聊天记录",
                      style: Styles.ts_8E9AB0_14sp)
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileItemView(Message item) {
    return Ink(
      height: 64.h,
      color: Styles.c_FFFFFF,
      child: InkWell(
        onTap: () => logic.previewFile(item),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.fileElem?.fileName ?? "",
                    style: Styles.ts_0C1C33_17sp,
                  ),
                  Row(
                    children: [
                      Text(
                        IMUtils.formatBytes(item.fileElem?.fileSize ?? 0),
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
                      Text(IMUtils.getChatTimeline(item.sendTime!, 'HH:mm'),
                          style: Styles.ts_8E9AB0_15sp)
                    ],
                  )
                ],
              ))
            ],
          ),
        ),
      ),
    );
  }
}
