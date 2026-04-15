/// 版本比较工具类
/// 处理应用版本号比较、提取和规范化
class VersionUtils {
  /// 比较版本号，如果version1 > version2返回1，等于返回0，小于返回-1
  ///
  /// 版本格式："1.2.3"
  /// 支持任意数量的版本段（1.2、1.2.3.4都可以）
  static int compareVersions(String version1, String version2) {
    // 确保输入非空
    if (version1.isEmpty || version2.isEmpty) {
      throw ArgumentError('版本号不能为空');
    }

    try {
      // 将版本号按点分割成段并转换为整数
      final List<int> v1Parts = version1.split('.').map(int.parse).toList();
      final List<int> v2Parts = version2.split('.').map(int.parse).toList();

      // 补齐版本号，确保两个版本号的段数相同
      final int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
      while (v1Parts.length < maxLength) v1Parts.add(0);
      while (v2Parts.length < maxLength) v2Parts.add(0);

      // 逐段比较
      for (int i = 0; i < maxLength; i++) {
        if (v1Parts[i] > v2Parts[i]) return 1;
        if (v1Parts[i] < v2Parts[i]) return -1;
      }

      return 0; // 版本完全相等
    } catch (e) {
      // 版本格式不正确时的处理
      print('版本比较出错: $e, version1=$version1, version2=$version2');
      return 0; // 出错时认为版本相等，避免误判
    }
  }

  /// 提取主版本号（从格式如"0.7.5+1 (Patch 2)"中提取"0.7.5"）
  static String extractBaseVersion(String fullVersion) {
    if (fullVersion.isEmpty) {
      return '';
    }

    try {
      // 查找加号位置，提取前面部分
      final plusIndex = fullVersion.indexOf('+');
      if (plusIndex != -1) {
        return fullVersion.substring(0, plusIndex).trim();
      }

      // 如果没有加号，查找空格位置
      final spaceIndex = fullVersion.indexOf(' ');
      if (spaceIndex != -1) {
        return fullVersion.substring(0, spaceIndex).trim();
      }

      // 如果没有空格或加号，返回原始版本
      return fullVersion.trim();
    } catch (e) {
      print('提取基础版本出错: $e, fullVersion=$fullVersion');
      return fullVersion; // 出错时返回原始字符串
    }
  }

  /// 规范化版本号，确保有3个段（例如：1.2 -> 1.2.0）
  static String normalizeVersion(String version) {
    if (version.isEmpty) {
      return '0.0.0';
    }

    try {
      final parts = version.split('.');
      while (parts.length < 3) parts.add('0');
      return parts.join('.');
    } catch (e) {
      print('规范化版本出错: $e, version=$version');
      return version; // 出错时返回原始字符串
    }
  }
}