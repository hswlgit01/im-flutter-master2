#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 显示帮助信息
function show_help {
  echo -e "${BLUE}OpenIM Flutter Docker 构建工具${NC}"
  echo ""
  echo "用法: $0 [选项] [环境]"
  echo ""
  echo "选项:"
  echo "  apk              构建Android APK"
  echo "  web              构建Web应用"
  echo "  dev              启动开发环境容器并进入"
  echo "  setup-sdk        在容器内设置Android SDK（手动安装SDK组件）"
  echo "  clean            清理构建缓存和容器"
  echo "  help             显示此帮助信息"
  echo ""
  echo "Shorebird 热更新选项:"
  echo "  shorebird-login  登录 Shorebird 账号"
  echo "  shorebird-init   初始化 Shorebird 项目"
  echo "  shorebird-release  使用 Shorebird 发布基础版本"
  echo "  shorebird-patch    推送 Shorebird 热更新补丁"
  echo "  shorebird-list     查看 Shorebird 发布历史"
  echo "  shorebird-shell    进入容器并打开 Shorebird shell"
  echo ""
  echo "环境 (可选):"
  echo "  dev         开发环境 (默认)"
  echo "  test        测试环境"
  echo "  prod        生产环境"
  echo ""
  echo "示例:"
  echo "  $0 apk                 # 构建开发环境的 Android APK"
  echo "  $0 apk prod            # 构建生产环境的 Android APK"
  echo "  $0 web test            # 构建测试环境的 Web 应用"
  echo "  $0 dev                 # 启动开发环境"
  echo "  $0 setup-sdk           # 安装Android SDK组件"
  echo ""
  echo "Shorebird 使用示例:"
  echo "  $0 shorebird-login     # 登录 Shorebird"
  echo "  $0 shorebird-init      # 初始化项目"
  echo "  $0 shorebird-release   # 发布基础版本"
  echo "  $0 shorebird-patch dev # 推送开发环境补丁"
}

# 检查Docker和Docker Compose是否已安装
function check_docker {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    echo "请访问 https://www.docker.com/get-started 安装Docker"
    exit 1
  fi

  if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装${NC}"
    echo "请访问 https://docs.docker.com/compose/install/ 安装Docker Compose"
    exit 1
  fi
}

# 构建Android APK
function build_apk {
  local env=${1:-dev}
  echo -e "${YELLOW}开始构建Android APK (环境: ${env})...${NC}"
  docker compose run --rm -e BUILD_ENV=${env} build_apk bash -c "flutter clean && flutter pub get && flutter build apk --release --dart-define=ENV=${env}"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}APK构建成功!${NC}"
    echo -e "环境: ${BLUE}${env}${NC}"
    echo -e "APK文件位于: ${BLUE}$(pwd)/build/app/outputs/flutter-apk/${NC}"
  else
    echo -e "${RED}APK构建失败!${NC}"
    exit 1
  fi
}

# 构建Web应用
function build_web {
  local env=${1:-dev}
  echo -e "${YELLOW}开始构建Web应用 (环境: ${env})...${NC}"
  docker compose run --rm -e BUILD_ENV=${env} build_web bash -c "flutter clean && flutter pub get && flutter build web --release --dart-define=ENV=${env}"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Web应用构建成功!${NC}"
    echo -e "环境: ${BLUE}${env}${NC}"
    echo -e "Web应用文件位于: ${BLUE}$(pwd)/build/web/${NC}"
  else
    echo -e "${RED}Web应用构建失败!${NC}"
    exit 1
  fi
}

# 启动开发环境
function start_dev {
  echo -e "${YELLOW}启动Flutter开发环境...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}开发环境启动成功!${NC}"
    echo -e "${YELLOW}正在进入容器...${NC}"
    docker compose exec flutter bash --rcfile /app/.bashrc_docker
  else
    echo -e "${RED}开发环境启动失败!${NC}"
    exit 1
  fi
}

# 清理构建缓存
function clean_all {
  echo -e "${YELLOW}正在清理Flutter和Gradle缓存...${NC}"

  # 在容器内清理 Flutter 缓存
  echo -e "${BLUE}  → 清理 Flutter 缓存${NC}"
  docker compose run --rm flutter bash -c "
    flutter clean
    rm -rf .dart_tool
    rm -rf build
    rm -rf .flutter-plugins
    rm -rf .flutter-plugins-dependencies
    rm -rf pubspec.lock
    rm -rf openim_common/pubspec.lock openim_common/.flutter-plugins openim_common/.dart_tool
    rm -rf openim_live/pubspec.lock openim_live/.flutter-plugins openim_live/.dart_tool
    echo 'Flutter 缓存已清理'
  " 2>/dev/null || echo -e "${YELLOW}  ⚠ 容器未运行，跳过容器内清理${NC}"

  # 在容器内清理 Gradle 缓存
  echo -e "${BLUE}  → 清理 Gradle 缓存${NC}"
  docker compose run --rm flutter bash -c "
    rm -rf android/.gradle
    rm -rf android/app/build
    rm -rf android/build
    echo 'Gradle 缓存已清理'
  " 2>/dev/null || echo -e "${YELLOW}  ⚠ 容器未运行，跳过容器内清理${NC}"

  # 清理主机上的缓存文件（如果有权限问题，使用 alpine 容器清理）
  echo -e "${BLUE}  → 清理主机缓存文件${NC}"
  docker run --rm -v $(pwd):/app -w /app alpine sh -c "
    rm -rf .dart_tool build .flutter-plugins .flutter-plugins-dependencies pubspec.lock
    rm -rf android/.gradle android/app/build android/build
  " 2>/dev/null

  # 停止并删除容器和卷
  echo -e "${YELLOW}正在清理Docker容器和缓存卷...${NC}"
  docker compose down -v

  # 删除 Docker 卷
  echo -e "${BLUE}  → 删除 Docker 缓存卷${NC}"
  docker volume rm im-flutter_flutter_cache im-flutter_gradle_cache 2>/dev/null || true

  echo -e "${GREEN}✓ 清理完成!${NC}"
  echo -e "${BLUE}已清理内容：${NC}"
  echo -e "  • Flutter 缓存 (.dart_tool, build, pubspec.lock)"
  echo -e "  • Gradle 缓存 (android/.gradle, android/app/build)"
  echo -e "  • Docker 容器和卷"
}

# 检查Docker安装
check_docker

# 处理命令行参数
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

# 在容器中设置Android SDK
function setup_sdk {
  echo -e "${YELLOW}启动Android SDK安装...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}容器启动成功!${NC}"
    echo -e "${YELLOW}正在安装Android SDK组件...${NC}"
    docker compose exec flutter ./setup-android-sdk.sh
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Android SDK安装成功!${NC}"
    else
      echo -e "${RED}Android SDK安装失败!${NC}"
      exit 1
    fi
  else
    echo -e "${RED}容器启动失败!${NC}"
    exit 1
  fi
}

# 验证环境参数
function validate_env {
  local env=$1
  if [[ "$env" != "dev" && "$env" != "test" && "$env" != "prod" ]]; then
    echo -e "${RED}错误: 无效的环境参数 '$env'${NC}"
    echo -e "有效的环境: dev, test, prod"
    exit 1
  fi
}

# 获取环境参数（第二个参数），默认为 dev
ENV_PARAM=${2:-dev}

# 如果第二个参数存在，验证它
if [ -n "$2" ]; then
  validate_env "$ENV_PARAM"
fi

# ==================== Shorebird 相关函数 ====================

# 登录 Shorebird
function shorebird_login {
  echo -e "${YELLOW}启动容器并登录 Shorebird...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}容器启动成功!${NC}"
    echo -e "${YELLOW}正在登录 Shorebird...${NC}"
    echo ""
    echo "选择登录方式:"
    echo "1) 浏览器登录 (推荐)"
    echo "2) 使用 CI Token"
    read -p "请选择 [1-2]: " login_choice

    case $login_choice in
      1)
        docker compose exec flutter shorebird login
        ;;
      2)
        read -p "请输入 CI Token: " token
        docker compose exec flutter shorebird login --ci-token "$token"
        ;;
      *)
        echo -e "${RED}无效的选择${NC}"
        exit 1
        ;;
    esac

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}登录成功!${NC}"
    else
      echo -e "${RED}登录失败!${NC}"
      exit 1
    fi
  else
    echo -e "${RED}容器启动失败!${NC}"
    exit 1
  fi
}

# 初始化 Shorebird 项目
function shorebird_init {
  echo -e "${YELLOW}初始化 Shorebird 项目...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}容器启动成功!${NC}"
    docker compose exec flutter shorebird init
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Shorebird 项目初始化成功!${NC}"
      echo -e "${BLUE}已创建 shorebird.yaml 文件${NC}"
    else
      echo -e "${RED}初始化失败!${NC}"
      exit 1
    fi
  else
    echo -e "${RED}容器启动失败!${NC}"
    exit 1
  fi
}

# 发布 Shorebird 基础版本
function shorebird_release {
  local env=${1:-dev}
  echo -e "${YELLOW}使用 Shorebird 发布 Android 版本 (环境: ${env})...${NC}"

  # 构建命令
  local build_cmd="flutter pub get && shorebird release android"
  if [ "$env" != "dev" ]; then
    build_cmd="${build_cmd} --dart-define=ENV=${env}"
  fi

  docker compose run --rm flutter bash -c "$build_cmd"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Shorebird 发布成功!${NC}"
    echo -e "环境: ${BLUE}${env}${NC}"
    echo -e "APK位于: ${BLUE}$(pwd)/build/app/outputs/flutter-apk/${NC}"
    echo ""
    echo -e "${YELLOW}提示: 记录此版本号,以便后续推送补丁${NC}"
  else
    echo -e "${RED}发布失败!${NC}"
    exit 1
  fi
}

# 推送 Shorebird 补丁
function shorebird_patch {
  local env=${1:-dev}
  echo -e "${YELLOW}推送 Shorebird 补丁 (环境: ${env})...${NC}"

  # 构建命令
  local patch_cmd="flutter pub get && shorebird patch android"
  if [ "$env" != "dev" ]; then
    patch_cmd="${patch_cmd} --dart-define=ENV=${env}"
  fi

  # 可选: 指定发布版本
  read -p "是否指定目标发布版本? [y/N]: " specify_version
  if [[ $specify_version =~ ^[Yy]$ ]]; then
    read -p "请输入发布版本号 (如: 0.6.8+1): " version
    patch_cmd="${patch_cmd} --release-version=${version}"
  fi

  docker compose run --rm flutter bash -c "$patch_cmd"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}补丁推送成功!${NC}"
    echo -e "环境: ${BLUE}${env}${NC}"
    echo ""
    echo -e "${YELLOW}提示: 用户下次启动应用时将自动下载并应用此补丁${NC}"
  else
    echo -e "${RED}补丁推送失败!${NC}"
    exit 1
  fi
}

# 查看 Shorebird 发布历史
function shorebird_list {
  echo -e "${YELLOW}查看 Shorebird 发布历史...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo ""
    echo -e "${BLUE}=== 发布列表 ===${NC}"
    docker compose exec flutter shorebird releases list
    echo ""
    read -p "是否查看某个版本的补丁列表? [y/N]: " show_patches
    if [[ $show_patches =~ ^[Yy]$ ]]; then
      read -p "请输入发布版本号 (如: 0.6.8+1): " version
      echo ""
      echo -e "${BLUE}=== 补丁列表 (${version}) ===${NC}"
      docker compose exec flutter shorebird patches list --release-version="$version"
    fi
  else
    echo -e "${RED}容器启动失败!${NC}"
    exit 1
  fi
}

# 进入 Shorebird shell
function shorebird_shell {
  echo -e "${YELLOW}启动容器并进入 Shorebird shell...${NC}"
  docker compose up -d flutter
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}容器启动成功!${NC}"
    echo -e "${BLUE}您现在可以在容器内执行任何 shorebird 命令${NC}"
    echo ""
    echo "快捷命令:"
    echo "  sb login          # 登录 Shorebird"
    echo "  sb release dev    # 发布版本"
    echo "  sb patch dev      # 推送补丁"
    echo "  sb list           # 查看历史"
    echo ""
    echo "或使用原始命令:"
    echo "  shorebird releases list                    # 查看发布列表"
    echo "  shorebird patches list --release-version=X # 查看补丁"
    echo "  shorebird account                          # 查看账号信息"
    echo "  shorebird doctor                           # 检查环境"
    echo ""
    docker compose exec flutter bash --rcfile /app/.bashrc_docker
  else
    echo -e "${RED}容器启动失败!${NC}"
    exit 1
  fi
}

# ==================== 主逻辑 ====================

case "$1" in
  apk)
    build_apk "$ENV_PARAM"
    ;;
  web)
    build_web "$ENV_PARAM"
    ;;
  dev)
    start_dev
    ;;
  setup-sdk)
    setup_sdk
    ;;
  clean)
    clean_all
    ;;
  shorebird-login)
    shorebird_login
    ;;
  shorebird-init)
    shorebird_init
    ;;
  shorebird-release)
    shorebird_release "$ENV_PARAM"
    ;;
  shorebird-patch)
    shorebird_patch "$ENV_PARAM"
    ;;
  shorebird-list)
    shorebird_list
    ;;
  shorebird-shell)
    shorebird_shell
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo -e "${RED}错误: 未知选项 '$1'${NC}"
    show_help
    exit 1
    ;;
esac

exit 0