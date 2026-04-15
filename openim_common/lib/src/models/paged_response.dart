/// 分页响应的泛型模型
class PagedResponse<T> {
  /// 总数
  int? total;
  
  /// 数据列表
  List<T>? data;

  PagedResponse({
    this.total,
    this.data,
  });

  /// 从 JSON 创建 PagedResponse 实例
  /// [json] JSON 数据
  /// [fromJsonT] 将 JSON Map 转换为 T 类型的函数
  PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    if (json["total"] is int) {
      total = json["total"];
    }
    if (json["data"] is List) {
      data = (json["data"] as List<dynamic>)
          .where((item) => item is Map<String, dynamic>)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList();
    }
  }

  /// 从 JSON 列表创建 PagedResponse 列表
  static List<PagedResponse<T>> fromList<T>(
    List<Map<String, dynamic>> list,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return list
        .map((json) => PagedResponse<T>.fromJson(json, fromJsonT))
        .toList();
  }

  /// 转换为 JSON
  /// [toJsonT] 将 T 类型转换为 JSON Map 的函数
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["total"] = total;
    if (data != null) {
      _data["data"] = data!.map((item) => toJsonT(item)).toList();
    }
    return _data;
  }

  /// 判断是否为空
  bool get isEmpty => data?.isEmpty ?? true;

  /// 判断是否不为空
  bool get isNotEmpty => !isEmpty;

  /// 数据数量
  int get length => data?.length ?? 0;

  /// 是否还有更多数据
  bool get hasMore => (total ?? 0) > length;
}
