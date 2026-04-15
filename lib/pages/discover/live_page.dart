import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/pages/discover/Live/meeting_view.dart';
import 'dart:convert';
import 'dart:async';
import 'package:openim/utils/logger.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';
import 'Live/create_stream_view.dart';
import '../../core/api_service.dart' as core;

class LivePage extends StatefulWidget {
  @override
  _LivePageState createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  String? _errorMessage;
  bool _loading = false;
  bool _loadingStreams = false;
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final imLogic = Get.find<IMController>();
  final apiService = core.ApiService();
  final orgController = Get.find<OrgController>();
  
  // 直播列表相关
  List<Map<String, dynamic>> _allLiveStreams = [];
  List<Map<String, dynamic>> _filteredLiveStreams = [];
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  
  // 添加分页相关变量
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  String _lastSearchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadLiveStreams();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 搜索变化监听
  void _onSearchChanged() {
    final query = _searchController.text;
    _performSearch(query);
  }

  // 滚动监听 - 检测是否滚动到底部
  void _onScroll() {
    // 如果正在加载、没有更多数据或者在搜索模式，则不触发加载更多
    if (_loadingStreams || !_hasMoreData || _isSearching) return;
    
    // 检测是否滚动到接近底部（距离底部200像素时开始加载）
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  // 加载更多数据
  Future<void> _loadMoreData() async {
    if (_loadingStreams || !_hasMoreData || _isSearching) return;
    
    ILogger.d('LivePage', '加载更多数据，当前页：$_currentPage');
    _currentPage++;
    await _loadLiveStreams();
  }

  // 搜索直播间（调用API）
  Future<void> _searchLiveStreams(String keyword) async {
    if (keyword.trim().isEmpty) {
      // 如果关键词为空，加载所有数据
      await _loadLiveStreams(refresh: true);
      return;
    }

    setState(() {
      _loadingStreams = true;
      _isSearching = true;
      _lastSearchKeyword = keyword;
      _hasMoreData = false; // 搜索模式下不支持分页加载
    });

    try {
      ILogger.d('LivePage', '搜索直播列表，关键词：$keyword');
      
      final result = await apiService.livestreamStatisticsList(
        page: 1,
        page_size: 100, // 搜索时增加页面大小
        keyword: keyword,
      );

      if (result != null && result['data'] != null) {
        final List<dynamic> streamData = result['data'] ?? [];
        
        ILogger.d('LivePage', '搜索到 ${streamData.length} 条数据');
        
        setState(() {
          _filteredLiveStreams = streamData.map((item) => {
            'id': item['id']?.toString() ?? '',
            'title': item['nickname'] ?? StrRes.liveUntitledStream,
            'host': item['user']?['nickname'] ?? StrRes.liveUnknownHost,
            'viewers': _parseIntSafely(item['total_users']) ?? 0,
            'thumbnail':  item['cover'] ,
            'status': item['status'] ?? 'live',
            'room_name': item['room_name'] ?? '',
            'start_time': item['start_time'],
            'end_time': item['end_time'],
          }).toList();
        });
      } else {
        setState(() {
          _filteredLiveStreams = [];
        });
      }
    } catch (e) {
      ILogger.e('LivePage', '搜索直播列表失败: $e');
      setState(() {
        _filteredLiveStreams = [];
      });
    } finally {
      setState(() {
        _loadingStreams = false;
      });
    }
  }

  // 过滤直播列表（本地过滤）
  void _filterLiveStreams(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLiveStreams = List.from(_allLiveStreams);
        _isSearching = false;
      } else {
        _filteredLiveStreams = _allLiveStreams.where((stream) {
          final title = (stream['title'] ?? '').toLowerCase();
          final host = (stream['host'] ?? '').toLowerCase();
          final roomName = (stream['room_name'] ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();
          
          return title.contains(searchQuery) ||
                 host.contains(searchQuery) ||
                 roomName.contains(searchQuery);
        }).toList();
      }
    });
  }

  // 加载直播列表
  Future<void> _loadLiveStreams({bool refresh = false}) async {
    // 如果正在加载且不是刷新操作，则直接返回
    if (_loadingStreams && !refresh) return;

    setState(() {
      _loadingStreams = true;
      if (refresh) {
        _currentPage = 1;
        _hasMoreData = true;
        _isSearching = false;
        _lastSearchKeyword = '';
      }
    });

    try {
      ILogger.d('LivePage', '加载直播列表，页数：$_currentPage，刷新：$refresh');
      
      final result = await apiService.livestreamStatisticsList(
        page: _currentPage,
        page_size: _pageSize,
        keyword: '', // 加载所有数据时不使用关键词
      );

      if (result != null && result['data'] != null) {
        final List<dynamic> streamData = result['data'] ?? [];
        final total = result['total'] ?? 0;
        
        ILogger.d('LivePage', '获取到 ${streamData.length} 条数据，总数：$total');
        
        // 转换数据格式
        final newStreams = streamData.map((item) => {
          'id': item['id']?.toString() ?? '',
          'title': item['nickname'] ?? StrRes.liveUntitledStream,
          'host': item['user']?['nickname'] ?? StrRes.liveUnknownHost,
          'viewers': _parseIntSafely(item['total_users']) ?? 0,
          'thumbnail':  item['cover'] ,
          'status': item['status'] ?? 'live',
          'room_name': item['room_name'] ?? '',
          'start_time': item['start_time'],
          'end_time': item['end_time'],
        }).toList();

        setState(() {
          if (refresh || _currentPage == 1) {
            // 刷新或第一页时，重置数据
            _allLiveStreams = newStreams;
          } else {
            // 加载更多时，追加数据
            _allLiveStreams.addAll(newStreams);
          }
          
          // 检查是否还有更多数据
          final currentTotal = _allLiveStreams.length;
          _hasMoreData = currentTotal < total && newStreams.isNotEmpty;
          
          ILogger.d('LivePage', '当前总数：$currentTotal，服务器总数：$total，还有更多：$_hasMoreData');
          
          // 如果不在搜索模式，更新过滤列表
          if (!_isSearching) {
            _filteredLiveStreams = List.from(_allLiveStreams);
          }
        });
      } else {
        // 如果没有获取到数据
        if (refresh || _currentPage == 1) {
          setState(() {
            _allLiveStreams = [];
            _filteredLiveStreams = [];
            _hasMoreData = false;
          });
        } else {
          // 加载更多时没有数据，说明没有更多了
          setState(() {
            _hasMoreData = false;
          });
        }
      }
    } catch (e) {
      ILogger.e('LivePage', '加载直播列表失败: $e');
      // 如果是加载更多时失败，回退页数
      if (!refresh && _currentPage > 1) {
        _currentPage--;
      }
      if (refresh || _currentPage == 1) {
        setState(() {
          _allLiveStreams = [];
          _filteredLiveStreams = [];
        });
      }
    } finally {
      setState(() {
        _loadingStreams = false;
      });
    }
  }

  Future<void> _joinStreamByRoomId(String roomId) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 确保房间名称格式正确
      final formattedRoomId = roomId.trim();

      // 调用API批准举手请求
      final result = await apiService.joinStream(
        roomName: formattedRoomId, // 房间名字
      );

      if (result != null) {
        final connectionDetails = result['connection_details'];
        final token = connectionDetails['token'];
        final wsUrl = connectionDetails['ws_url'];

        Get.off(
          () => MeetingPage(),
          arguments: {
            'wsUrl': wsUrl,
            'token': token,
          },
          // 设置导航选项禁用侧滑手势返回
          transition: Transition.rightToLeft,
          popGesture: false, // 禁用侧滑返回手势
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = StrRes.liveJoinFailed.replaceFirst('%s', e.toString());
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // 直接加入直播间
  Future<void> _joinLiveStream(String roomName) async {
    await _joinStreamByRoomId(roomName);
  }

  // 清空搜索
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _lastSearchKeyword = '';
      _filteredLiveStreams = List.from(_allLiveStreams);
    });
  }

  // 执行搜索（防抖处理）
  Timer? _searchDebounce;
  void _performSearch(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _searchLiveStreams(query.trim());
      } else {
        _clearSearch();
      }
    });
  }

  void _showJoinStreamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题部分
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.live_tv, color: Colors.red, size: 24),
                    ),
                    SizedBox(width: 12),
                    Text(
                      StrRes.liveJoin,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // 房间号输入框
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _roomIdController,
                    decoration: InputDecoration(
                      hintText: StrRes.liveEnterRoomID,
                      prefixIcon: Icon(Icons.meeting_room, color: Colors.red, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                    style: TextStyle(fontSize: 14),
                    keyboardType: TextInputType.text,
                  ),
                ),

                // 提示信息
                Padding(
                  padding: EdgeInsets.only(top: 12, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          StrRes.liveRoomIDHint,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // 错误信息
                if (_errorMessage != null)
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 24),

                // 按钮部分
                Row(
                  children: [
                    // 取消按钮
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          StrRes.cancel,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // 加入按钮
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        onPressed: _loading
                            ? null
                            : () {
                                if (_roomIdController.text.isEmpty) {
                                  setState(() {
                                    _errorMessage = StrRes.liveEmptyRoomID;
                                  });
                                  return;
                                }
                                Navigator.pop(context);
                                _joinStreamByRoomId(_roomIdController.text);
                              },
                        child: _loading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                StrRes.liveJoinButton,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 构建直播列表项
  Widget _buildLiveStreamItem(Map<String, dynamic> stream) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _joinLiveStream(stream['room_name']),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // 直播缩略图或占位符
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade300, Colors.red.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: stream['thumbnail'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            stream['thumbnail'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.live_tv, color: Colors.white, size: 32);
                            },
                          ),
                        )
                      : Icon(Icons.live_tv, color: Colors.white, size: 32),
                ),
                
                SizedBox(width: 16),
                
                // 直播信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 直播标题
                      Text(
                        stream['title'] ?? StrRes.liveUntitledStream,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: 6),
                      
                      // 主播名称
                      Text(
                        stream['host'] ?? StrRes.liveUnknownHost,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: 10),
                      
                      // 观看人数和状态
                      Row(
                        children: [
                          // 直播状态
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 8),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(width: 12),
                          
                          // 观看人数
                          Row(
                            children: [
                              Icon(Icons.visibility, color: Colors.grey.shade500, size: 14),
                              SizedBox(width: 4),
                              Text(
                                _formatViewerCount(stream['viewers'] ?? 0),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 进入按钮
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 安全解析整数
  int? _parseIntSafely(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value);
    } else if (value is double) {
      return value.toInt();
    }
    return null;
  }

  // 格式化观看人数
  String _formatViewerCount(dynamic count) {
    int viewerCount = 0;
    if (count is int) {
      viewerCount = count;
    } else if (count is String) {
      viewerCount = int.tryParse(count) ?? 0;
    } else if (count is double) {
      viewerCount = count.toInt();
    }
    
    if (viewerCount < 1000) {
      return viewerCount.toString();
    } else if (viewerCount < 10000) {
      return '${(viewerCount / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(viewerCount / 10000).toStringAsFixed(1)}W';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          StrRes.livePage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.refresh, color: Colors.red, size: 20),
            ),
            onPressed: _loadingStreams ? null : () => _loadLiveStreams(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部按钮区域
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 创建直播按钮
                if (orgController.currentOrgRoles.contains("livestream"))
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Get.to(() => CreateStreamView());
                      },
                      icon: Icon(Icons.add_circle_outline, size: 20),
                      label: Text(
                        StrRes.liveCreate,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                
                if (orgController.currentOrgRoles.contains("livestream"))
                  SizedBox(width: 12),
                
                // 加入直播按钮
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      minimumSize: Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.red, width: 1.5),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _showJoinStreamDialog,
                    icon: Icon(Icons.meeting_room_outlined, size: 20),
                    label: Text(
                      StrRes.liveJoin,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 搜索框区域
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: StrRes.liveSearchPlaceholder,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // 搜索结果提示
          if (_isSearching)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.search_outlined, color: Colors.grey.shade600, size: 16),
                  SizedBox(width: 8),
                  Text(
                    StrRes.liveSearchResults(_filteredLiveStreams.length),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // 错误信息显示
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          SizedBox(height: 8),

          // 直播列表区域
          Expanded(
            child: _loadingStreams
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          StrRes.liveLoadingStreams,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredLiveStreams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSearching ? Icons.search_off : Icons.live_tv_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _isSearching ? StrRes.liveNoStreamsFound : StrRes.liveNoStreams,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _isSearching 
                                                  ? StrRes.liveTryDifferentKeywords
                : StrRes.liveCreateOrJoinHint,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadLiveStreams(refresh: true),
                        color: Colors.red,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: 16),
                          itemCount: _filteredLiveStreams.length + (_hasMoreData || _loadingStreams ? 1 : 0),
                          itemBuilder: (context, index) {
                            // 如果是最后一项且需要显示加载指示器
                            if (index == _filteredLiveStreams.length) {
                              return _buildLoadMoreIndicator();
                            }
                            return _buildLiveStreamItem(_filteredLiveStreams[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _loadingStreams
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    StrRes.liveLoadMore,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            : _hasMoreData
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      StrRes.livePullToLoadMore,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      StrRes.liveAllLoaded,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
      ),
    );
  }
}
