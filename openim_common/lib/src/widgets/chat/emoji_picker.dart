import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class EmojiPicker extends StatefulWidget {
  final Function(Map<String, dynamic>) onEmojiSelected;

  const EmojiPicker({
    Key? key,
    required this.onEmojiSelected,
  }) : super(key: key);

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _emojiList = [];
  bool _isLoading = true;
  late TabController _tabController;
  List<String> _categories = [];
  Map<String, List<Map<String, dynamic>>> _categorizedEmojis = {};
  
  // 表情组名称映射
  final Map<int, String> _groupNames = {
    0: '表情与人物',
    1: '动物与自然',
    2: '食物与饮料',
    3: '活动',
    4: '旅行与地点',
    5: '物品',
    6: '符号',
    7: '旗帜',
    8: '工具',
    9: '其他'
  };

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmojis() async {
    try {
      print('开始加载表情包...');
      
      // 从 openim_common 包中加载表情数据
      String jsonString = await rootBundle.loadString('packages/openim_common/assets/emoji/emojis.json');
      print('从 openim_common 包加载成功');
      
      final List<dynamic> emojiData = json.decode(jsonString);
      print('解析到 ${emojiData.length} 个表情');
      
      // 按组分类组织表情
      _categorizedEmojis = {};
      for (var emoji in emojiData) {
        final group = emoji['group'] ?? 9; // 默认为"其他"组
        final groupName = _groupNames[group] ?? '其他';
        
        if (!_categorizedEmojis.containsKey(groupName)) {
          _categorizedEmojis[groupName] = [];
        }
        _categorizedEmojis[groupName]!.add(emoji);
      }
      
      // 获取所有分类
      _categories = _categorizedEmojis.keys.toList();
      
      setState(() {
        _emojiList = emojiData.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
      
      // 初始化TabController
      _tabController = TabController(length: _categories.length, vsync: this);
      
      print('表情列表更新完成，共 ${_emojiList.length} 个表情，${_categories.length} 个分类');
    } catch (e) {
      print('加载表情包失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算表情选择器的高度，避免遮挡
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = screenHeight * 0.4; // 最大高度为屏幕高度的40%
    final safeHeight = maxHeight - bottomPadding - 20; // 减去底部安全区域和一些额外空间
    
    return Container(
      height: safeHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
      ),
      child: Column(
        children: [
          if (_isLoading)
            Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_emojiList.isEmpty)
            Expanded(
              child: Center(child: Text('没有可用的表情')),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: EdgeInsets.symmetric(horizontal: 8.w),
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      tabs: _categories.map((category) {
                        // 获取该分类的第一个表情作为标签
                        final emojis = _categorizedEmojis[category] ?? [];
                        final firstEmoji = emojis.isNotEmpty ? emojis[0]['emoji'] ?? '📦' : '📦';
                        
                        return Tab(
                          child: Text(
                            firstEmoji,
                            style: TextStyle(fontSize: 20.sp),
                          ),
                        );
                      }).toList(),
                      labelColor: Color(0xFF333333),
                      unselectedLabelColor: Color(0xFF999999),
                      indicatorColor: Color(0xFF1B72EC),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _categories.map((category) {
                        final emojis = _categorizedEmojis[category] ?? [];
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(12.w, 12.w, 12.w, 24.w), // 增加底部边距
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8.w,
                            crossAxisSpacing: 8.w,
                            childAspectRatio: 1,
                          ),
                          itemCount: emojis.length,
                          itemBuilder: (context, index) {
                            final emoji = emojis[index];
                            return GestureDetector(
                              onTap: () => widget.onEmojiSelected(emoji),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji['emoji'] ?? '',
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 