import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'luck_money_log_logic.dart';

class LuckMoneyLogPage extends StatelessWidget {
  LuckMoneyLogPage({Key? key}) : super(key: key);
  final logic = Get.find<LuckMoneyLogLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 36.h),
              _buildAvatar(),
              SizedBox(height: 24.h),
              _buildListSection(),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFD83A3A),
      iconTheme: IconThemeData(color: Colors.white),
      title: Text(
        '发出的红包',
        style: TextStyle(
          fontSize: 16.sp,
          color: Color(0xFFD4AF37),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () {
          Get.back();
        },
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: Get.context!,
                shape: RoundedRectangleBorder(
                  // 添加圆角
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                builder: (context) {
                  return Container(
                    // padding: EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Center(child: Text('收到的红包')),
                          onTap: () {},
                        ),
                        Divider(height: 1, color: Color(0xFFF5F5F5)),
                        ListTile(
                          title: Center(child: Text('发出的红包')),
                          onTap: () {},
                        ),
                        Container(
                          width: double.infinity, // 设置宽度为全屏
                          height: 8.h,
                          color: Colors.grey[300],
                        ),
                        // Divider(height: 1, color: Color(0xFFF5F5F5)),
                        ListTile(
                          title: Center(child: Text('取消')),
                          onTap: () {
                            Get.back();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Center(
        child: Column(children: [
      Container(
        width: 90.w,
        height: 90.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
      SizedBox(height: 12.h),
      Text('一尺一共收到'),
      SizedBox(height: 12.h),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '0.38',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'CNY',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ]));
  }

  Widget _buildListSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildListSectionItem(),
          Divider(height: 1, color: Color(0xFFF5F5F5)),
        ],
      ),
    );
  }

  Widget _buildListSectionItem() {
    return ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 让内容两端对齐
            children: [
              Text('一尺', style: TextStyle(fontSize: 14)),
              Text('0.38元', style: TextStyle(fontSize: 14)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            '21:36',
            style: TextStyle(
              color: Color(0xFF9B9B9B),
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }
}
