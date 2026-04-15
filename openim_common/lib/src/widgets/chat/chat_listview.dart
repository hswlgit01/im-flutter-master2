
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({
    Key? key,
    this.physics,
    this.onTouch,
    this.itemCount,
    this.controller,
    required this.itemBuilder,
    this.enabledScrollTopLoad = false,
    this.onScrollToBottomLoad,
    this.onScrollToTopLoad,
    this.onScrollToBottom,
    this.onScrollToTop,
  }) : super(key: key);
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final int? itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final Future<bool> Function()? onScrollToBottomLoad;

  final Future<bool> Function()? onScrollToTopLoad;
  final Function()? onScrollToBottom;
  final Function()? onScrollToTop;

  final bool enabledScrollTopLoad;
  final Function()? onTouch;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  bool _scrollToBottomLoadMore = true;
  bool _scrollToTopLoadMore = true;

  bool get _isBottom =>
      widget.controller!.offset >= widget.controller!.position.maxScrollExtent;

  bool get _isTop => widget.controller!.offset <= 0;

  @override
  void dispose() {
    widget.controller?.removeListener(_scrollListener);
    super.dispose();
  }

  @override
  void initState() {
    _onScrollToBottomLoadMore();
    widget.controller?.addListener(_scrollListener);
    super.initState();
  }

  _scrollListener() {
    if (_isBottom) {
      Logger.print('-------------ChatListView scroll to bottom');
      _onScrollToBottomLoadMore();
    } else if (_isTop) {
      Logger.print('-------------ChatListView scroll to top');
      _onScrollToTopLoadMore();
    }
  }

  void _onScrollToBottomLoadMore() {
    widget.onScrollToBottom?.call();
    widget.onScrollToBottomLoad?.call().then((hasMore) {
      if (!mounted) return;
      setState(() {
        _scrollToBottomLoadMore = hasMore;
      });
    });
  }

  void _onScrollToTopLoadMore() {
    widget.onScrollToTop?.call();
    if (widget.enabledScrollTopLoad) {
      widget.onScrollToTopLoad?.call().then((hasMore) {
        if (!mounted) return;
        setState(() {
          _scrollToTopLoadMore = hasMore;
        });
      });
    }
  }

  Widget get loadMoreView => Container(
        alignment: Alignment.center,
        height: 44,
        child: CupertinoActivityIndicator(color: Styles.c_0089FF),
      );

  @override
  Widget build(BuildContext context) {
    return TouchCloseSoftKeyboard(
      onTouch: widget.onTouch,
      child: Align(
        alignment: Alignment.topCenter,
        child: ListView.builder(
          reverse: true,
          shrinkWrap: true,
          physics: widget.physics ?? const ClampingScrollPhysics(),
          itemCount: widget.itemCount ?? 0,
          padding: EdgeInsets.only(top: 10.h),
          controller: widget.controller,
          itemBuilder: (context, index) => _wrapLoadMoreItem(index),
        ),
      ),
    );
  }

  Widget _wrapLoadMoreItem(int index) {
    final child = widget.itemBuilder(context, index);
    if (index == widget.itemCount! - 1) {
      return _scrollToBottomLoadMore
          ? Column(children: [loadMoreView, child])
          : child;
    }
    if (index == 0 && widget.enabledScrollTopLoad) {
      return _scrollToTopLoadMore
          ? Column(children: [child, loadMoreView])
          : child;
    }
    return child;
  }
}

class PositionRetainedScrollPhysics extends ClampingScrollPhysics {
  final bool shouldRetain;

  const PositionRetainedScrollPhysics({super.parent, this.shouldRetain = true});

  @override
  PositionRetainedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PositionRetainedScrollPhysics(
      parent: buildParent(ancestor),
      shouldRetain: shouldRetain,
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

    if (oldPosition.pixels > oldPosition.minScrollExtent &&
        diff > 0 &&
        shouldRetain) {
      return position + diff;
    } else {
      return position;
    }
  }
}
