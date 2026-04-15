import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class VoiceRecordBar extends StatefulWidget {
  final Function(int duration, String path)? onSondVoice;
  final String? quoteContent;
  const VoiceRecordBar({super.key, this.onSondVoice, this.quoteContent});

  @override
  State<VoiceRecordBar> createState() => _VoiceRecordBarState();
}

class _VoiceRecordBarState extends State<VoiceRecordBar> {
  final GlobalKey _key = GlobalKey();
  bool _isPressed = false;
  bool _isOut = false;
  late VoiceRecord _voiceRecord;
  bool get _showQuoteView => IMUtils.isNotNullEmptyStr(widget.quoteContent);

  @override
  void initState() {
    super.initState();
    _voiceRecord = VoiceRecord(
        maxRecordSec: 120, onInterrupt: _onInterrupt, onFinished: _onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerMove: _handlePointerMove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          child: Container(
            margin: EdgeInsets.only(top: 10.h, bottom: _showQuoteView ? 4.h : 10.h),
            key: _key,
            width: double.infinity,
            height: 39.h,
            decoration: BoxDecoration(
              color: _isPressed ? Styles.c_E8EAEF : Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Center(
              child: Text(
                _isPressed
                    ? _isOut
                        ? StrRes.liftFingerToCancelSend
                        : StrRes.releaseToSend
                    : StrRes.holdTalk,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ));
  }

  _onFinished(int duration, String path) {
    if (duration >= 1) {
      widget.onSondVoice?.call(duration, path);
    } else {
      IMViews.showToast(StrRes.talkTooShort);
    }
  }

  _onInterrupt(int a, String b) {
    print("_onFinished: 超时");
  }

  void _handlePointerDown(PointerDownEvent event) {
    _voiceRecord.start();
    VoiceRecordToast.show(context);
    setState(() {
      _isPressed = true;
      _isOut = false;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    VoiceRecordToast.hide();
    setState(() {
      _isPressed = false;
    });
    if (_isPointInside(event.position)) {
      _voiceRecord.stop();
    } else {
      _voiceRecord.stop(isInterrupt: true);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    VoiceRecordToast.hide();
    _voiceRecord.stop(isInterrupt: true);
    setState(() {
      _isPressed = false;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isPointInside(event.position)) {
      if (_isOut) {
        VoiceRecordToast.updateCancelState(!_isOut);
        setState(() {
          _isOut = false;
        });
      }
    } else {
      if (!_isOut) {
        VoiceRecordToast.updateCancelState(!_isOut);
        setState(() {
          _isOut = true;
        });
      }
    }
  }

  bool _isPointInside(Offset globalPosition) {
    final RenderBox renderBox =
        _key.currentContext?.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = position & size;
    return rect.contains(globalPosition);
  }
}

class VoiceRecordToast {
  static OverlayEntry? _overlayEntry;
  static bool _isCancel = false;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(false),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void updateCancelState(bool isCancel) {
    if (_overlayEntry == null) return;
    if (_isCancel == isCancel) return; // 没变化就不用重建
    _isCancel = isCancel;
    _overlayEntry!.markNeedsBuild();
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isCancel = false;
  }

  static Widget _buildOverlay(bool _) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCancel
                  ? Colors.red.withOpacity(0.8)
                  : Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LottieView(
                  name: "assets/anim/voice_record.json",
                  width: 70.w,
                ),
                Text(
                  _isCancel ? StrRes.liftFingerToCancelSend : StrRes.releaseToSendSwipeUpToCancel,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
