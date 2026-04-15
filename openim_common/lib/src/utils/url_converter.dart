import 'package:openim_common/openim_common.dart';

/// URL转换工具类
/// 全局URL域名替换，只要路径包含 api/object/ 的都会进行域名替换
class UrlConverter {
  UrlConverter._();

  /// 转换包含 api/object/ 路径的URL域名
  /// [originalUrl] 原始URL
  /// 返回替换域名后的URL
  static String convertMediaUrl(String originalUrl) {
    try {
      // 如果URL为空，直接返回
      if (originalUrl.isEmpty) {
        return originalUrl;
      }

      // 处理相对路径：如果是纯路径（不包含协议和域名）
      if (!originalUrl.contains('://') && !originalUrl.startsWith('file:')) {
        // 获取API基础URL - 使用Config中现有的imApiUrl逻辑
        final apiUrl = Config.imApiUrl;
        if (apiUrl.isEmpty) {
          return originalUrl;
        }

        // 解析API URL获取基本部分（协议、主机、端口）
        String baseUrl;
        try {
          final uri = Uri.parse(apiUrl);
          // 保留原始端口，不硬编码
          final port = uri.port > 0 && uri.port != 80 && uri.port != 443 ? ":${uri.port}" : "";
          baseUrl = '${uri.scheme}://${uri.host}$port';
        } catch (e) {
          // 如果无法解析，使用完整apiUrl但移除末尾的路径部分
          final endIndex = apiUrl.lastIndexOf('/api');
          baseUrl = endIndex > 0 ? apiUrl.substring(0, endIndex) : apiUrl;
        }

        // 确保路径格式正确，添加特殊处理上传返回的路径
        final path = originalUrl.startsWith('/') ? originalUrl : '/$originalUrl';

        String formattedPath;
        if (path.startsWith('/object/')) {
          formattedPath = path;
        } else if (path.contains('/object/')) {
          formattedPath = '/object/' + path.split('/object/')[1];
        } else {
          // 特别确保上传返回的路径正确添加/object/前缀
          formattedPath = '/object/' + (path.startsWith('/') ? path.substring(1) : path);
        }

        // 拼接完整URL - 确保baseUrl和formattedPath之间只有一个斜杠
        while (baseUrl.endsWith('/') && formattedPath.startsWith('/')) {
          formattedPath = formattedPath.substring(1);
        }
        if (!baseUrl.endsWith('/') && !formattedPath.startsWith('/')) {
          formattedPath = '/' + formattedPath;
        }

        return baseUrl + formattedPath;
      }

      // 以下是处理完整URL的逻辑（向后兼容）

      // 如果无效URL，直接返回
      if (!_isValidUrl(originalUrl)) {
        return originalUrl;
      }

      // 解析原始URL
      final originalUri = Uri.parse(originalUrl);

      // 如果是本地文件，直接返回
      if (originalUri.scheme == 'file') {
        return originalUrl;
      }

      // 检查URL路径是否包含 api/object/ 或 object/
      if (!originalUri.path.contains('api/object/') && !originalUri.path.contains('object/')) {
        return originalUrl;
      }

      // 获取当前自动寻路选择的域名
      final currentHost = _getCurrentHost();
      if (currentHost == null || currentHost.isEmpty) {
        return originalUrl;
      }

      // 判断当前主机是IP还是域名
      final isCurrentHostIP = _isIPAddress(currentHost);

      // 创建新的URI
      final newUri = originalUri.replace(
        scheme: isCurrentHostIP ? 'http' : 'https',
        host: currentHost,
        port: isCurrentHostIP ? _getCurrentPort() : null,
      );

      return newUri.toString();
    } catch (e) {
      // 转换失败时返回原始URL
      return originalUrl;
    }
  }

  /// 为了兼容现有代码，保留旧方法名
  @Deprecated('使用 convertMediaUrl 代替')
  static String convertChatMediaUrl(String originalUrl) {
    return convertMediaUrl(originalUrl);
  }

  /// 专门处理群组头像URL
  static String convertGroupAvatarUrl(String originalUrl) {
    // 如果已经是完整URL，直接返回
    if (originalUrl.contains('://')) {
      return originalUrl;
    }

    // 获取API基础URL
    final apiUrl = Config.imApiUrl;
    if (apiUrl.isEmpty) {
      return originalUrl;
    }

    // 解析API URL获取基本部分
    String baseUrl;
    try {
      final uri = Uri.parse(apiUrl);
      final port = uri.port > 0 && uri.port != 80 && uri.port != 443 ? ":${uri.port}" : "";
      baseUrl = '${uri.scheme}://${uri.host}$port';
    } catch (e) {
      final endIndex = apiUrl.lastIndexOf('/api');
      baseUrl = endIndex > 0 ? apiUrl.substring(0, endIndex) : apiUrl;
    }

    // 处理路径
    final path = originalUrl.startsWith('/') ? originalUrl : '/$originalUrl';

    String formattedPath;
    if (path.startsWith('/object/')) {
      formattedPath = path;
    } else if (path.contains('/object/')) {
      formattedPath = '/object/' + path.split('/object/')[1];
    } else {
      formattedPath = '/object/' + (path.startsWith('/') ? path.substring(1) : path);
    }

    // 拼接完整URL - 确保路径格式正确
    String fullUrl = baseUrl;
    if (fullUrl.endsWith('/') && formattedPath.startsWith('/')) {
      fullUrl += formattedPath.substring(1);
    } else if (!fullUrl.endsWith('/') && !formattedPath.startsWith('/')) {
      fullUrl += '/' + formattedPath;
    } else {
      fullUrl += formattedPath;
    }

    return fullUrl;
  }

  /// 检查URL是否有效
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前自动寻路选择的主机地址
  static String? _getCurrentHost() {
    try {
      // 从配置中获取当前使用的API地址
      final apiUrl = Config.imApiUrl;
      if (apiUrl.isEmpty) {
        return null;
      }

      final uri = Uri.parse(apiUrl);
      return uri.host;
    } catch (e) {
      print('❌ 获取当前主机失败: $e');
      return null;
    }
  }

  /// 获取当前API端口
  static int? _getCurrentPort() {
    try {
      final apiUrl = Config.imApiUrl;
      if (apiUrl.isEmpty) {
        return null;
      }

      final uri = Uri.parse(apiUrl);
      return uri.hasPort ? uri.port : null;
    } catch (e) {
      print('❌ 获取当前端口失败: $e');
      return null;
    }
  }

  /// 获取API基础URL (协议+主机+端口)
  /// @deprecated 使用直接从Config.imApiUrl解析的方式代替
  static String? _getApiBaseUrl() {
    try {
      final apiUrl = Config.imApiUrl;
      if (apiUrl.isEmpty) {
        return null;
      }

      final uri = Uri.parse(apiUrl);
      final host = uri.host;
      final isIP = _isIPAddress(host);

      // 构建基础URL
      final scheme = isIP ? 'http' : 'https';
      final port = uri.hasPort ? ':${uri.port}' : '';

      return '$scheme://$host$port';
    } catch (e) {
      print('❌ 获取API基础URL失败: $e');
      return null;
    }
  }

  /// 判断是否为IP地址
  static bool _isIPAddress(String host) {
    // 简单的IP地址正则检查
    final ipRegex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    return ipRegex.hasMatch(host);
  }
} 