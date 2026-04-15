import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatToolBox extends StatelessWidget {
  final Function()? onTapAlbum;
  final Function()? onTapCall;
  final Function()? onTapTransfer;
  final Function()? onTapRedEnvelope;
  final Function()? onTapEmoji;
  final Function()? onTapFile;

  const ChatToolBox({
    Key? key,
    this.onTapAlbum,
    this.onTapCall,
    this.onTapTransfer,
    this.onTapRedEnvelope,
    this.onTapEmoji,
    this.onTapFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
      ),
      child: Column(
        children: [
          Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEEEEEE),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '工具箱',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Color(0xFF333333),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 18.w,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              padding: EdgeInsets.all(16.w),
              mainAxisSpacing: 16.w,
              crossAxisSpacing: 16.w,
              children: [
                _buildToolItem(
                  icon: 'toolboxAlbum',
                  label: '相册',
                  onTap: onTapAlbum,
                ),
                _buildToolItem(
                  icon: 'toolboxCall',
                  label: '语音通话',
                  onTap: onTapCall,
                ),
                _buildToolItem(
                  icon: 'toolboxTransfer',
                  label: '转账',
                  onTap: onTapTransfer,
                ),
                _buildToolItem(
                  icon: 'toolboxRedEnvelope',
                  label: '红包',
                  onTap: onTapRedEnvelope,
                ),
                _buildToolItem(
                  icon: 'toolboxEmoji',
                  label: '表情',
                  onTap: onTapEmoji,
                ),
                _buildToolItem(
                  icon: 'toolboxFile1',
                  label: '文件',
                  onTap: onTapFile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required String icon,
    required String label,
    Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/$icon.png',
              width: 32.w,
              height: 32.w,
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 