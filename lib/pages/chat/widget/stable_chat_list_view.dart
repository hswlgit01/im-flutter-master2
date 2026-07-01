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

  // dawn 2026-06-23 修复聊天页消息少时留白：条目不超过该值且无分页时贴底渲染，超过则改懒加载。
  static const int _bottomAnchorMaxItem = 20;

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
    if (oldWidget.enabledTopLoad && !widget.enabledTopLoad && _topHasMore) {
      _topHasMore = false;
      _loadingTop = false;
    }
    if (oldWidget.enabledBottomLoad &&
        !widget.enabledBottomLoad &&
        _bottomHasMore) {
      _bottomHasMore = false;
      _loadingBottom = false;
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

  Widget _buildListItem(
    BuildContext context,
    int visualIndex,
    List<T> topList,
    List<T> bottomList,
  ) {
    final showTopLoader = _topHasMore && widget.enabledTopLoad;
    final topLength = topList.length;
    var index = visualIndex;

    if (showTopLoader) {
      if (index == 0) return _buildLoadMoreView();
      index -= 1;
    }

    if (index < topLength) {
      final position = topLength - index - 1;
      final item = topList[position];
      return widget.itemBuilder(context, position, position, item);
    }

    index -= topLength;
    if (index < bottomList.length) {
      final position = topLength + index;
      return widget.itemBuilder(
        context,
        index,
        position,
        bottomList[index],
      );
    }

    return _buildLoadMoreView();
  }

  @override
  Widget build(BuildContext context) {
    final topList = widget.controller.topList;
    final bottomList = widget.controller.bottomList;
    final topLength = topList.length;
    final showTopLoader = _topHasMore && widget.enabledTopLoad;
    final showBottomLoader = _bottomHasMore && widget.enabledBottomLoad;
    final itemCount = topLength +
        bottomList.length +
        (showTopLoader ? 1 : 0) +
        (showBottomLoader ? 1 : 0);

    // 无分页且条目少时用 Column 避免列表锚点产生大块空白；消息仍从顶部开始展示。
    final shortAndNoPaging = !showTopLoader &&
        !showBottomLoader &&
        itemCount <= _bottomAnchorMaxItem;

    // dawn 2026-06-23 修复聊天页红色溢出：使用 SliverList 懒加载消息，避免 3 万人群/大量历史消息被 Column 一次性撑爆。
    return ColoredBox(
      color: Colors.white,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (itemCount == 0)
            const SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: ColoredBox(color: Colors.white),
            )
          else if (shortAndNoPaging)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  itemCount,
                  (index) => _buildListItem(
                    context,
                    index,
                    topList,
                    bottomList,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildListItem(
                  context,
                  index,
                  topList,
                  bottomList,
                ),
                childCount: itemCount,
              ),
            ),
        ],
      ),
    );
  }
}
