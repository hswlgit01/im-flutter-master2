import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatToolBox extends StatelessWidget {
  const ChatToolBox({
    super.key,
    this.onTapAlbum,
    this.onTapCall,
    this.onTapTransfer,
    this.onTapRedEnvelope,
    this.onTapEmoji,
    this.onTapFile,
    this.onTapCarte,
  });
  final Function()? onTapAlbum;
  final Function()? onTapCall;
  final Function()? onTapTransfer;
  final Function()? onTapRedEnvelope;
  final Function()? onTapEmoji;
  final Function()? onTapFile;
  final Function()? onTapCarte;

  @override
  Widget build(BuildContext context) {
    final items = [
      ToolboxItemInfo(
        text: StrRes.toolboxAlbum,
        icon: ImageRes.toolboxAlbum,
        onTap: onTapAlbum,
      ),
      if (onTapCall != null)
        ToolboxItemInfo(
          text: StrRes.toolboxCall,
          icon: ImageRes.toolboxCall,
          onTap: () => Permissions.cameraAndMicrophone(onTapCall),
        ),
      if (onTapTransfer != null)
        ToolboxItemInfo(
          text: StrRes.transfer,
          icon: ImageRes.transfer,
          onTap: onTapTransfer,
        ),
      if (onTapRedEnvelope != null) ToolboxItemInfo(
        text: StrRes.toolboxRedEnvelope,
        icon: ImageRes.redEnvelope,
        onTap: onTapRedEnvelope,
      ),
   
      if (onTapFile != null) ToolboxItemInfo(
        text: StrRes.file,
        icon: ImageRes.toolboxFile,
        onTap: onTapFile,
      ),
      if (onTapCarte != null) ToolboxItemInfo(
        text: StrRes.carte,
        icon: ImageRes.toolboxCard,
        onTap: onTapCarte,
      ),
    ];

    return Container(
      color: Styles.c_F0F2F6,
      height: 224.h,
      child: GridView.builder(
        itemCount: items.length,
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 6.h,
          bottom: 6.h,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 78.w / 105.h,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 2.h,
        ),
        itemBuilder: (_, index) {
          final item = items.elementAt(index);
          return _buildItemView(
            icon: item.icon,
            text: item.text,
            onTap: item.onTap,
          );
        },
      ),
    );
  }

  Widget _buildItemView({
    required String text,
    required String icon,
    Function()? onTap,
  }) =>
      Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 58.w,
              height: 58.h,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Image.asset(
                icon,
                fit: BoxFit.contain,
                package: "openim_common",
              ),
            ),
          ),
          10.verticalSpace,
          text.toText..style = Styles.ts_0C1C33_12sp,
        ],
      );
}

class ToolboxItemInfo {
  String text;
  String icon;
  Function()? onTap;

  ToolboxItemInfo({required this.text, required this.icon, this.onTap});
}
