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
    if (isDownClose) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          onTap?.call();
        },
        child: child,
      );
    } else {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          onTap?.call();
        },
        child: child,
      );
    }
  }
}
