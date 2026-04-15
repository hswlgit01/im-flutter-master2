import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'article_logic.dart';

class ArticleView extends StatelessWidget {
  final logic = Get.find<ArticleLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(),
      body: Obx(() {
        if (logic.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 文章标题
              Text(
                logic.title.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              
              // 更新时间
              if (logic.updatedAt.value.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${StrRes.updateTime}: ${_formatDateTime(logic.updatedAt.value)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              
              Divider(color: Colors.grey[300]),
              SizedBox(height: 16),
              
              // 文章内容 - 使用 HTML 渲染 (带自定义图片URL转换)
              Html(
                data: logic.content.value,
                style: {
                  "body": Style(
                    fontSize: FontSize(16),
                    lineHeight: LineHeight(1.6),
                    color: Colors.black87,
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    margin: Margins.only(bottom: 12),
                  ),
                  "h1, h2, h3, h4, h5, h6": Style(
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(top: 20, bottom: 10),
                  ),
                  "blockquote": Style(
                    backgroundColor: Colors.grey[100],
                    border: Border(left: BorderSide(color: Colors.blue, width: 4)),
                    padding: HtmlPaddings.all(12),
                    margin: Margins.symmetric(vertical: 8),
                  ),
                  "code": Style(
                    backgroundColor: Colors.grey[200],
                    padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                    fontFamily: 'monospace',
                  ),
                  "pre": Style(
                    backgroundColor: Colors.grey[100],
                    padding: HtmlPaddings.all(12),
                    margin: Margins.symmetric(vertical: 8),
                  ),
                },
                // 添加自定义图片渲染扩展，处理相对路径
                extensions: [
                  // 使用TagExtension处理img标签，转换相对路径为绝对URL
                  TagExtension(
                    tagsToExtend: {'img'},
                    builder: (extensionContext) {
                      // 获取img标签的src属性
                      final src = extensionContext.attributes['src'];
                      if (src == null || src.isEmpty) {
                        return Container(); // 如果没有src属性，显示空容器
                      }

                      // 转换相对路径为绝对URL
                      final String imageUrl;
                      if (src.startsWith('/object/') || (!src.contains('://') && !src.startsWith('asset:') && !src.startsWith('data:'))) {
                        imageUrl = UrlConverter.convertMediaUrl(src);
                      } else {
                        imageUrl = src;
                      }

                      // 返回支持交互的图片组件
                      return GestureDetector(
                        // 添加双击查看原图功能
                        onDoubleTap: () {
                          // 在全屏模式下查看图片
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  iconTheme: IconThemeData(color: Colors.white),
                                  title: Text(
                                    '查看图片',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                body: Center(
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.white, size: 48),
                                              SizedBox(height: 16),
                                              Text(
                                                '图片加载失败',
                                                style: TextStyle(color: Colors.white, fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
                        // 为图片添加轻微放大效果的视觉反馈
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 24),
                                      SizedBox(height: 4),
                                      Text(
                                        '图片加载失败',
                                        style: TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // 添加放大提示图标
                            Container(
                              margin: EdgeInsets.all(4),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr).toLocal();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}