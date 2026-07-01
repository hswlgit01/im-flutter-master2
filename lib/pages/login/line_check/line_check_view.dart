import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

/// dawn 2026-06-26 线路检测页：测试后台返回的全部线路(不限固定2条)，展示延迟/可用状态，
/// 支持重新测速、同步线路(重新拉远程配置)、手动选择并切换线路。
class LineCheckPage extends StatefulWidget {
  const LineCheckPage({super.key});

  @override
  State<LineCheckPage> createState() => _LineCheckPageState();
}

class _LineCheckPageState extends State<LineCheckPage> {
  List<LineTestResult> _lines = [];
  // dawn 2026-06-26 按索引选择(可能存在同 host 的多条线路，不能用 host 当选中标识)。
  int _selectedIndex = 0;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _retest();
  }

  int _defaultIndex(List<LineTestResult> lines) {
    // 优先选中当前已应用线路；否则选第一条可用；都没有则第一条。
    final cur = ApiAutoRoute.currentHost;
    if (cur != null && cur.isNotEmpty) {
      final i = lines.indexWhere((l) => l.host == cur && l.isSuccess);
      if (i >= 0) return i;
    }
    final ok = lines.indexWhere((l) => l.isSuccess);
    return ok >= 0 ? ok : 0;
  }

  Future<void> _retest({bool sync = false}) async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      if (sync) {
        try {
          await Config.refreshRemoteConfig();
        } catch (_) {}
      }
      final lines = await ApiAutoRoute.testAllLines();
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _selectedIndex = _defaultIndex(lines);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _apply() async {
    if (_selectedIndex < 0 || _selectedIndex >= _lines.length) return;
    final host = _lines[_selectedIndex].host;
    if (host.isEmpty) return;
    await LoadingView.singleton
        .wrap(asyncFunction: () => ApiAutoRoute.applyHost(host));
    IMViews.showToast('已切换线路');
    Get.back(result: host);
  }

  Widget _statusBadge(LineTestResult l) {
    final ok = l.isSuccess;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: (ok ? const Color(0xFF34C759) : const Color(0xFFFF381F))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        ok ? '良好' : '无法连通',
        style: TextStyle(
          color: ok ? const Color(0xFF34C759) : const Color(0xFFFF381F),
          fontSize: 12.sp,
        ),
      ),
    );
  }

  Widget _lineRow(LineTestResult l, int index) {
    final selected = _selectedIndex == index;
    final selectable = l.isSuccess;
    return InkWell(
      onTap: selectable ? () => setState(() => _selectedIndex = index) : null,
      child: Container(
        color: Styles.c_FFFFFF,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Styles.c_0089FF
                  : (selectable ? Styles.c_8E9AB0 : const Color(0xFFD0D5DD)),
              size: 20.w,
            ),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.name, style: Styles.ts_0C1C33_17sp),
                  4.verticalSpace,
                  Text(
                    l.isSuccess ? '${l.responseTime}ms' : '--',
                    style: Styles.ts_8E9AB0_14sp,
                  ),
                ],
              ),
            ),
            _statusBadge(l),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _selectedIndex >= 0 &&
        _selectedIndex < _lines.length &&
        _lines[_selectedIndex].isSuccess;
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      appBar: AppBar(
        backgroundColor: Styles.c_FFFFFF,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0C1C33)),
        title: Text('线路检测', style: Styles.ts_0C1C33_17sp_medium),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _testing ? null : () => _retest(sync: true),
            child: Text('同步线路',
                style: TextStyle(color: Styles.c_0089FF, fontSize: 15.sp)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (_testing && _lines.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : (_lines.isEmpty
                    ? Center(
                        child: Text('暂无可用线路',
                            style: Styles.ts_8E9AB0_14sp))
                    : ListView.separated(
                        padding: EdgeInsets.only(top: 10.h),
                        itemCount: _lines.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Color(0xFFF0F0F0)),
                        itemBuilder: (_, i) => _lineRow(_lines[i], i),
                      )),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _testing ? null : () => _retest(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 46.h),
                      side: BorderSide(color: Styles.c_0089FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r)),
                    ),
                    child: Text(_testing ? '测速中…' : '重新测速',
                        style: TextStyle(color: Styles.c_0089FF)),
                  ),
                  10.verticalSpace,
                  ElevatedButton(
                    onPressed: (_testing || !canApply) ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 46.h),
                      backgroundColor: Styles.c_0089FF,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r)),
                    ),
                    child: const Text('使用选中线路',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
