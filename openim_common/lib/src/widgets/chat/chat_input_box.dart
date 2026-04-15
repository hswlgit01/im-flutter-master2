import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/widgets/chat/emoji_picker.dart';

double kInputBoxMinHeight = 56.h;

/// 自定义底部面板类型
enum PanelType { none, emoji, keyboard, tool, voice }

class ChatInputBox extends StatefulWidget {
  const ChatInputBox({
    super.key,
    required this.toolbox,
    required this.voiceRecordBar,
    this.controller,
    required this.focusNode,
    this.style,
    this.atStyle,
    this.enabled = true,
    this.isNotInGroup = false,
    this.hintText,
    this.forceCloseToolboxSub,
    this.quoteContent,
    this.onClearQuote,
    this.onSend,
    this.directionalText,
    this.onCloseDirectional,
    this.enabledAt = false,
    this.atUserInfo,
    required this.toolboxController,
  });
  final FocusNode focusNode;
  final TextEditingController? controller;
  final TextStyle? style;
  final TextStyle? atStyle;
  final bool enabled;
  final bool enabledAt;
  final bool isNotInGroup;
  final String? hintText;
  final Widget toolbox;
  final Widget voiceRecordBar;
  final Stream? forceCloseToolboxSub;
  final String? quoteContent;
  final ChatBottomPanelContainerController<PanelType> toolboxController;
  final Function()? onClearQuote;
  final Future Function(String, { required List<Uint8List> images })? onSend;
  final TextSpan? directionalText;
  final VoidCallback? onCloseDirectional;
  final List<AtUserInfo>? atUserInfo;

  @override
  State<ChatInputBox> createState() => ChatInputBoxState();
}

class ChatInputBoxState
    extends State<ChatInputBox> /*with TickerProviderStateMixin */ {
  bool _sendButtonVisible = false;
  bool _isSending = false;
  bool _showSendingIndicator = false;
  bool readOnly = false;
  bool showCursor = true;
  List<Uint8List> pasteImages = [];
  Widget? _emojiPanel;

  bool get _showQuoteView => IMUtils.isNotNullEmptyStr(widget.quoteContent);

  double get _opacity => (widget.enabled ? 1 : .4);

  bool get _showDirectionalView => widget.directionalText != null;

  bool get isKeyboard {
    final data = widget.toolboxController.data;
    return PanelType.voice != data;
  }

  @override
  void initState() {
    widget.controller?.addListener(inputChange);
    _emojiPanel = _buildEmojiPickerPanel();
    super.initState();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(inputChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) widget.controller?.clear();
    final emailImage = widget.toolboxController.data == PanelType.emoji
        ? ImageRes.openKeyboard
        : ImageRes.openEmoji;
    return widget.isNotInGroup
        ? const ChatDisableInputBox()
        : Column(
            children: [
              if (pasteImages.isNotEmpty) Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    ...List.generate(
                      pasteImages.length,
                      (index) => Container(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.w,
                                ),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: Image.memory(
                                  pasteImages[index],
                                  width: 60.w,
                                  height: 60.h,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2.w,
                              top: 2.h,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    pasteImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  width: 18.w,
                                  height: 18.h,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: BoxConstraints(minHeight: kInputBoxMinHeight),
                color: Styles.c_F0F2F6,
                child: Row(
                  children: [
                    12.horizontalSpace,
                    _renderKeyboardOrVoice(isKeyboard),
                    12.horizontalSpace,
                    Expanded(
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Visibility(
                                visible: isKeyboard,
                                child: _textFiled,
                              ),
                              Visibility(
                                visible: !isKeyboard,
                                child: widget.voiceRecordBar,
                              ),
                              Visibility(
                                  visible:
                                      widget.quoteContent != null && isKeyboard,
                                  child: Container(
                                    color: Styles.c_FFFFFF,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 1.h,
                                      horizontal: 2.w,
                                    ),
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.quoteContent ?? "",
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        ImageRes.clearText.toImage
                                          ..width = 22.w
                                          ..onTap = () {
                                            widget.onClearQuote?.call();
                                          },
                                      ],
                                    ),
                                  ))
                            ],
                          ),
                        ],
                      ),
                    ),
                    12.horizontalSpace,
                    emailImage.toImage
                      ..width = 32.w
                      ..height = 32.h
                      ..opacity = _opacity
                      ..onTap = () {
                        if (!widget.enabled) return;
                        if (widget.toolboxController.data == PanelType.voice) {
                          widget.toolboxController.data = PanelType.keyboard;
                        }
                        readOnly = true;
                        showCursor = true;
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (widget.toolboxController.data ==
                              PanelType.emoji) {
                            widget.toolboxController.updatePanelType(
                              ChatBottomPanelType.keyboard,
                              data: PanelType.keyboard,
                              forceHandleFocus:
                                  ChatBottomHandleFocus.requestFocus,
                            );
                          } else {
                            widget.toolboxController.updatePanelType(
                              ChatBottomPanelType.other,
                              data: PanelType.emoji,
                              forceHandleFocus:
                                  ChatBottomHandleFocus.requestFocus,
                            );
                          }
                          setState(() {});
                        });
                      },
                    8.horizontalSpace,
                    _buildSendButton(),
                    12.horizontalSpace,
                  ],
                ),
              ),
              if (_showDirectionalView)
                _SubView(
                  textSpan: widget.directionalText,
                  onClose: () {
                    widget.onCloseDirectional?.call();
                  },
                ),
              _buildPanelContainer(),
            ],
          );
  }

  inputChange() {
    setState(() {
      _sendButtonVisible = widget.controller!.text.isNotEmpty;
    });
  }

  Widget _buildSendButton() {
    if (_sendButtonVisible) {
      if (_showSendingIndicator) {
        // 发送中状态，显示加载动画
        return Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: Styles.c_0089FF.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: SizedBox(
              width: 16.w,
              height: 16.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
              ),
            ),
          ),
        );
      } else {
        // 正常发送按钮
        return ImageRes.sendMessage.toImage
          ..width = 32.w
          ..height = 32.h
          ..opacity = _opacity
          ..onTap = send;
      }
    } else {
      // 工具箱按钮
      return ImageRes.openToolbox.toImage
        ..width = 32.w
        ..height = 32.h
        ..opacity = _opacity
        ..onTap = toggleToolbox;
    }
  }

  Widget _buildPanelContainer() {
    return ChatBottomPanelContainer<PanelType>(
      controller: widget.toolboxController,
      inputFocusNode: widget.focusNode,
      otherPanelWidget: (type) {
        switch (type) {
          case PanelType.emoji:
            return SizedBox(
              height: widget.toolboxController.keyboardHeight == 0
                  ? 300.h
                  : widget.toolboxController.keyboardHeight,
              child: _emojiPanel,
            );
          case PanelType.tool:
            return widget.toolbox;
          default:
            return const SizedBox.shrink();
        }
      },
      onPanelTypeChange: (panelType, data) {
        if (panelType == ChatBottomPanelType.keyboard) {
          readOnly = false;
        }
        if (panelType == ChatBottomPanelType.none) {
          widget.toolboxController.data = PanelType.none;
          widget.toolboxController.currentPanelType = ChatBottomPanelType.none;
          readOnly = false;
          showCursor = true;
          widget.focusNode.unfocus();
        }
        setState(() {});
      },
    );
  }

  Widget _renderKeyboardOrVoice(bool keyboard) {
    String image = !keyboard ? ImageRes.openKeyboard : ImageRes.openVoice;
    return Opacity(
      opacity: _opacity,
      child: image.toImage
        ..width = 32.w
        ..height = 32.w
        ..onTap = () {
          toggleLeftButton(keyboard);
        },
    );
  }

  Widget _buildEmojiPickerPanel() {
    return EmojiPicker(
      onEmojiSelected: (value) {
        final emoji = value['emoji'] as String;
        if (widget.controller != null) {
          // 插入表情到输入框光标位置
          final text = widget.controller!.text;
          final selection = widget.controller!.selection;
          final newText = text.replaceRange(
            selection.start,
            selection.end,
            emoji,
          );
          widget.controller!.text = newText;
          widget.controller!.selection = TextSelection.fromPosition(
            TextPosition(offset: selection.start + emoji.length),
          );
        }
      },
    );
  }

  Widget get _textFiled => Container(
        margin: EdgeInsets.only(top: 10.h, bottom: _showQuoteView ? 4.h : 10.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: ChatTextField(
          controller: widget.controller,
          readOnly: readOnly,
          showCursor: showCursor,
          focusNode: widget.focusNode,
          style: widget.style ?? Styles.ts_0C1C33_17sp,
          atStyle: widget.atStyle ?? Styles.ts_0089FF_17sp,
          enabled: widget.enabled,
          enabledAt: widget.enabledAt,
          atUserInfo: widget.atUserInfo,
          hintText: widget.hintText,
          textAlign: widget.enabled ? TextAlign.start : TextAlign.center,
          onImagePaste: (imageData) => setState(() {
            pasteImages.add(imageData);
          }),
          onTap: () {
            showCursor = true;
            setState(() {});
            if (readOnly) {
              widget.toolboxController.updatePanelType(
                ChatBottomPanelType.keyboard,
                forceHandleFocus: ChatBottomHandleFocus.requestFocus,
              );
            }
          },
        ),
      );

  void send() async {
    if (!widget.enabled || _isSending) return;
    if (null != widget.onSend && null != widget.controller) {
      // 设置发送中状态，但不立即显示加载指示器
      setState(() {
        _isSending = true;
        _showSendingIndicator = false;
      });
      
      // 延迟100ms后显示加载指示器
      final showIndicatorTimer = Timer(const Duration(milliseconds: 100), () {
        if (_isSending && mounted) {
          setState(() {
            _showSendingIndicator = true;
          });
        }
      });
      
      try {
        // 创建副本避免并发修改异常
        final imagesCopy = List<Uint8List>.from(pasteImages);
        await widget.onSend!(widget.controller!.text.toString().trim(), images: imagesCopy);
      } catch (e) {
        // 发送失败，可以在这里处理错误
        print('发送消息失败: $e');
      } finally {
        // 取消定时器并重置发送状态
        showIndicatorTimer.cancel();
        if (mounted) {
          setState(() {
            _isSending = false;
            _showSendingIndicator = false;
          });
        }
      }
    }
  }

  void clearPasteImages() {
    setState(() {
      pasteImages.clear();
    });
  }

  void toggleToolbox() {
    if (!widget.enabled) return;
    if (widget.toolboxController.data == PanelType.voice ||
        widget.toolboxController.data == PanelType.emoji) {
      widget.toolboxController.data = PanelType.keyboard;
    }
    showCursor = true;
    if (widget.toolboxController.data == PanelType.tool) {
      widget.toolboxController.updatePanelType(ChatBottomPanelType.keyboard,
          data: PanelType.keyboard,
          forceHandleFocus: ChatBottomHandleFocus.requestFocus);
      setState(() {});
    } else {
      readOnly = true;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.toolboxController.updatePanelType(ChatBottomPanelType.other,
            data: PanelType.tool,
            forceHandleFocus: ChatBottomHandleFocus.requestFocus);

        showCursor = false;
        setState(() {});
      });
    }
  }

  void toggleLeftButton(bool keyboard) {
    if (!widget.enabled) return;
    showCursor = true;
    if (keyboard) {
      widget.toolboxController.updatePanelType(
        ChatBottomPanelType.other,
        data: PanelType.voice,
        forceHandleFocus: ChatBottomHandleFocus.unfocus,
      );
    } else {
      widget.toolboxController.updatePanelType(
        ChatBottomPanelType.keyboard,
        data: PanelType.keyboard,
        forceHandleFocus: ChatBottomHandleFocus.requestFocus,
      );
    }
    setState(() {});
  }
}

class _SubView extends StatelessWidget {
  const _SubView({
    this.onClose,
    this.title,
    this.content,
    this.textSpan,
  }) : assert(content != null || textSpan != null,
            'Either content or textSpan must be provided.');
  final VoidCallback? onClose;
  final String? title;
  final String? content;
  final InlineSpan? textSpan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 10.h, left: 56.w, right: 100.w),
      color: Styles.c_F0F2F6,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onClose,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: Styles.ts_8E9AB0_14sp,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (content != null)
                      Text(
                        title!,
                        style: Styles.ts_8E9AB0_14sp,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (textSpan != null)
                      Expanded(
                        child: RichText(
                          text: textSpan!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              ImageRes.delQuote.toImage
                ..width = 14.w
                ..height = 14.h,
            ],
          ),
        ),
      ),
    );
  }
}
