import 'package:chat_listview/chat_listview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// dawn 2026-06-22 修复聊天页大块灰色空白：本地实现稳定列表，去掉第三方组件 center 锚点导致的半屏占位。
class StableChatListView<T> extends StatefulWidget {
  const StableChatListView({
    super.key,
    required this.itemBuilder,
    required this.controller,
    this.scrollController,
    this.onScrollToTopLoad,
    this.onScrollToBottomLoad,
    this.enabledBottomLoad = false,
    this.enabledTopLoad = false,
    this.indicatorColor,
  });

  final CustomChatListViewItemBuilder<T> itemBuilder;
  final CustomChatListViewController<T> controller;
  final ScrollController? scrollController;
  final Future<bool> Function()? onScrollToTopLoad;
  final Future<bool> Function()? onScrollToBottomLoad;
  final bool enabledTopLoad;
  final bool enabledBottomLoad;
  final Color? indicatorColor;

  @override
  State<StableChatListView<T>> createState() => _StableChatListViewState<T>();
}

class _StableChatListViewState<T> extends State<StableChatListView<T>> {
  static const double _edgeThreshold = 24;

  var _bottomHasMore = true;
  var _topHasMore = true;
  var _loadingBottom = false;
  var _loadingTop = false;

  ScrollController? get _controller => widget.scrollController;

  @override
  void initState() {
    super.initState();
    _controller?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant StableChatListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      _controller?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final position = _controller?.position;
    if (position == null || !position.hasPixels) return;

    if (widget.enabledBottomLoad &&
        _bottomHasMore &&
        !_loadingBottom &&
        position.pixels >= position.maxScrollExtent - _edgeThreshold) {
      _onScrollToBottomLoadMore();
      return;
    }

    if (widget.enabledTopLoad &&
        _topHasMore &&
        !_loadingTop &&
        position.pixels <= position.minScrollExtent + _edgeThreshold) {
      _onScrollToTopLoadMore();
    }
  }

  Future<void> _onScrollToBottomLoadMore() async {
    final loader = widget.onScrollToBottomLoad;
    if (loader == null) return;
    _loadingBottom = true;
    try {
      final hasMore = await loader();
      if (!mounted) return;
      setState(() {
        _bottomHasMore = hasMore;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBottom = false;
        });
      }
    }
  }

  Future<void> _onScrollToTopLoadMore() async {
    final loader = widget.onScrollToTopLoad;
    final scrollController = _controller;
    if (loader == null || scrollController == null) return;
    _loadingTop = true;

    final oldMaxScrollExtent = scrollController.hasClients
        ? scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels =
        scrollController.hasClients ? scrollController.position.pixels : 0.0;

    var hasMore = _topHasMore;
    try {
      hasMore = await loader();
    } finally {
      if (mounted) {
        setState(() {
          _topHasMore = hasMore;
          _loadingTop = false;
        });
      }
    }

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final delta =
          scrollController.position.maxScrollExtent - oldMaxScrollExtent;
      if (delta <= 0) return;
      scrollController.jumpTo(
        (oldPixels + delta).clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  Widget _buildLoadMoreView() => Container(
        alignment: Alignment.center,
        height: 44,
        child: CupertinoActivityIndicator(
          color: widget.indicatorColor ?? Colors.blueAccent,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final topList = widget.controller.topList;
    final bottomList = widget.controller.bottomList;
    final topLength = topList.length;
    final children = <Widget>[
      if (_topHasMore && widget.enabledTopLoad) _buildLoadMoreView(),
      ...List.generate(topLength, (index) {
        final position = topLength - index - 1;
        final item = topList[position];
        return widget.itemBuilder(context, position, position, item);
      }),
      ...List.generate(bottomList.length, (index) {
        final position = topLength + index;
        return widget.itemBuilder(
          context,
          index,
          position,
          bottomList[index],
        );
      }),
      if (_bottomHasMore && widget.enabledBottomLoad) _buildLoadMoreView(),
    ];

    // dawn 2026-06-22 修复部分安卓机型聊天页灰色半屏：列表内容少时仍铺满白底并贴底展示，避免露出 Scaffold 灰底。
    return ColoredBox(
      color: Colors.white,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
