#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 备份原始文件
echo -e "${YELLOW}备份原始build.gradle文件...${NC}"
cp -f android/app/build.gradle android/app/build.gradle.backup
if [ $? -ne 0 ]; then
  echo -e "${RED}备份文件失败!${NC}"
  exit 1
fi
echo -e "${GREEN}备份文件成功: android/app/build.gradle.backup${NC}"

# 应用修复
echo -e "${YELLOW}应用依赖冲突修复...${NC}"
cp -f android/app/build.gradle.fixed android/app/build.gradle
if [ $? -ne 0 ]; then
  echo -e "${RED}应用修复失败!${NC}"
  exit 1
fi
echo -e "${GREEN}应用修复成功!${NC}"

# 清理项目
echo -e "${YELLOW}清理项目...${NC}"
flutter clean
if [ $? -ne 0 ]; then
  echo -e "${RED}Flutter clean失败!${NC}"
  exit 1
fi

# 清理Android构建
echo -e "${YELLOW}清理Android构建...${NC}"
cd android && ./gradlew clean && cd ..
if [ $? -ne 0 ]; then
  echo -e "${RED}Android清理失败!${NC}"
  exit 1
fi
echo -e "${GREEN}清理完成!${NC}"

# 重新获取依赖
echo -e "${YELLOW}重新获取依赖...${NC}"
flutter pub get
if [ $? -ne 0 ]; then
  echo -e "${RED}Flutter pub get失败!${NC}"
  exit 1
fi
echo -e "${GREEN}依赖获取完成!${NC}"

# 提示
echo -e "${BLUE}修复已应用! 现在可以尝试构建应用:${NC}"
echo -e "${YELLOW}flutter build apk --release${NC}"
echo ""
echo -e "${BLUE}如果构建仍然失败，请查看 DEPENDENCY_CONFLICT_FIX.md 文件了解更多解决方案。${NC}"
echo -e "${BLUE}要恢复原始配置，运行: cp android/app/build.gradle.backup android/app/build.gradle${NC}"