import 'package:get/get.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';

class ArticleLogic extends GetxController {
  // 文章数据
  var title = ''.obs;
  var content = ''.obs;
  var updatedAt = ''.obs;
  var isLoading = true.obs;

  @override
  onInit() {
    super.onInit();
    loadArticleDetail();
  }

  void loadArticleDetail() {
    isLoading.value = true;

    // 获取路由参数,支持 'articleId' 和 'id' 两种参数名
    final articleId = Get.arguments?['articleId'] ?? Get.arguments?['id'];

    if (articleId == null) {
      ILogger.e('文章ID为空');
      isLoading.value = false;
      return;
    }

    Apis.getArticleDetail(articleId).then((value) {
      title.value = value['title'] ?? '';
      content.value = value['content'] ?? '';
      updatedAt.value = value['updated_at'] ?? '';
      isLoading.value = false;
    }).catchError((error) {
      // 错误处理
      ILogger.e('获取文章详情失败: $error');
      isLoading.value = false;
    });
  }
}