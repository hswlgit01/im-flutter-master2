import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';

class TouchCloseSoftKeyboard extends StatelessWidget {
  final Widget child;
  final Function? onTouch;
  final bool isGradientBg;
  final bool isDownClose;

  const TouchCloseSoftKeyboard({
    super.key,
    required this.child,
    this.onTouch,
    this.isGradientBg = false, 
    this.isDownClose = true,
  });

  @override
  Widget build(BuildContext context) {

    return _buildContainer(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          currentFocus.unfocus();
        }
      },
      child: isGradientBg
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Styles.c_0089FF_opacity10,
                    Styles.c_FFFFFF_opacity0,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: child,
            )
          : child,
    );
  }

  _buildContainer({ required Widget child, Function? onTap }) {
    // Why GestureDetector (not Listener): Listener.onPointerDown fires on every
    // pointer-down including taps inside TextFields, racing with the field's focus
    // request. On some devices / custom keyboards this prevented the keyboard
    // from appearing on the password field. GestureDetector competes in the
    // gesture arena, so taps on a TextField go to the field and only taps on
    // blank area dismiss the keyboard.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        onTap?.call();
      },
      child: child,
    );
  }
}
