import 'package:flutter/material.dart';

class ChatListViewCustom extends StatefulWidget {
  final Widget child;
  final ValueNotifier<bool> shouldRetainNotifier;

  const ChatListViewCustom({
    super.key,
    required this.child,
    required this.shouldRetainNotifier,
  });

  @override
  State<ChatListViewCustom> createState() => _ChatListViewCustomState();
}

class _ChatListViewCustomState extends State<ChatListViewCustom> {
  late final ScrollController _scrollController;
  late final ValueNotifier<bool> _shouldRetainNotifier;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _shouldRetainNotifier = widget.shouldRetainNotifier;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent) {
            _shouldRetainNotifier.value = true;
          } else {
            _shouldRetainNotifier.value = false;
          }
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        physics: PositionRetainedScrollPhysics(
          shouldRetainNotifier: _shouldRetainNotifier,
        ),
        children: [widget.child],
      ),
    );
  }
}

class PositionRetainedScrollPhysics extends ScrollPhysics {
  final ValueNotifier<bool> shouldRetainNotifier;

  PositionRetainedScrollPhysics({
    super.parent,
    required this.shouldRetainNotifier,
  });

  @override
  PositionRetainedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PositionRetainedScrollPhysics(
      parent: buildParent(ancestor),
      shouldRetainNotifier: shouldRetainNotifier,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final position = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    final diff = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;

    if (diff > 0 && shouldRetainNotifier.value) {
      print('diff: $diff');
      return position + diff;
    } else {
      print('position: $position');
      return position;
    }
  }
}