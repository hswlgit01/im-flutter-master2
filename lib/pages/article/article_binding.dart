import 'package:get/get.dart';
import 'article_logic.dart';

class ArticleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ArticleLogic>(() => ArticleLogic());
  }
}