import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pasteboard/pasteboard.dart';

class ChatTextField extends StatelessWidget {
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final Function()? onTap;
  final String? hintText;

  final TextStyle? style;
  final TextStyle? atStyle;
  final bool enabled;
  final bool enabledAt;
  final TextAlign textAlign;
  final List<AtUserInfo>? atUserInfo;
  final bool readOnly;
  final bool showCursor;
  final Function(Uint8List imageData)? onImagePaste;

  const ChatTextField({
    Key? key,
    this.focusNode,
    this.controller,
    this.hintText,
    this.style,
    this.atStyle,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.enabledAt = false,
    this.readOnly = false,
    this.showCursor = false,
    this.atUserInfo, 
    this.onTap,
    this.onImagePaste,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExtendedTextField(
      style: style,
      focusNode: focusNode,
      readOnly: readOnly,
      showCursor: showCursor,
      onTap: onTap,
      controller: controller,
      keyboardType: TextInputType.multiline,
      enabled: enabled,
      autofocus: false,
      minLines: 1,
      maxLines: 4,
      textAlign: textAlign,
      extendedContextMenuBuilder: (context, editableTextState) {
        final defaultButtons = editableTextState.contextMenuButtonItems.where((item) => item.type != ContextMenuButtonType.paste);
        
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: [
            ...defaultButtons,
            ContextMenuButtonItem(
                onPressed: () async {
                  // 首先尝试获取文字内容
                  final text = await Pasteboard.text;
                  
                  if (text != null && text.isNotEmpty) {
                    // 如果有文字内容，执行默认粘贴行为
                    editableTextState.pasteText(SelectionChangedCause.keyboard);
                  } else {
                    // 如果没有文字内容，尝试获取图片
                    final image = await Pasteboard.image;
                    if (image != null && onImagePaste != null) {
                      // 如果有图片且提供了回调，通知外部组件
                      onImagePaste!(image);
                    }
                  }
                  ContextMenuController.removeAny();
                },
                type: ContextMenuButtonType.paste,
              )
          ],
        );
      },
      specialTextSpanBuilder:
          enabledAt ? MySpecialTextSpanBuilder(atUserInfo: atUserInfo) : null,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: hintText,
        hintStyle: Styles.ts_8E9AB0_17sp,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4.w,
          vertical: 8.h,
        ),
      ),
    );
  }
}

class MySpecialTextSpanBuilder extends SpecialTextSpanBuilder {
  final List<AtUserInfo>? atUserInfo;
  MySpecialTextSpanBuilder({this.atUserInfo});

  @override
  SpecialText? createSpecialText(String flag,
      {TextStyle? textStyle,
      SpecialTextGestureTapCallback? onTap,
      required int index}) {
    if (flag == "") return null;

    if (isStart(flag, AtText.flag)) {
      return AtText(textStyle, index - (AtText.flag.length - 1),
          atUserInfo: atUserInfo ?? []);
    }
    return null;
  }
}

class AtText extends SpecialText {
  final List<AtUserInfo> atUserInfo;
  static const String flag = "@";
  final int start;

  AtText(TextStyle? textStyle, this.start, {required this.atUserInfo})
      : super(flag, " ", textStyle);

  String get atText => toString();

  List<String> get ids => _extractIds(atText);

  @override
  InlineSpan finishText() {
    final TextStyle? textStyle = this.textStyle;
    final id = ids[0];
    final userInfo = atUserInfo.where((item) => item.atUserID == id);

    if (userInfo.isEmpty) {
      return SpecialTextSpan(
        text: atText,
        actualText: atText,
        start: start,
        deleteAll: false,
        style: textStyle);
    }
    final name = userInfo.toList()[0].groupNickname == 'all' ? StrRes.everyone : userInfo.toList()[0].groupNickname;
    return SpecialTextSpan(
        text: "$startFlag${name ?? atText}$endFlag",
        actualText: atText,
        start: start,
        deleteAll: true,
        style: textStyle?.copyWith(color: Styles.c_0089FF));
  }

  List<String> _extractIds(String text) {
    RegExp regExp = RegExp(r'@(\S+)');
    return regExp.allMatches(text).map((match) => match.group(1)!).toList();
  }
}
