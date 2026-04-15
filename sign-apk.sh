#!/bin/bash
# APK 签名脚本

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}用法: $0 <apk文件路径>${NC}"
    echo ""
    echo "示例:"
    echo "  $0 universal.apk"
    echo "  $0 /path/to/app.apk"
    exit 1
fi

INPUT_APK=$1
OUTPUT_APK="${INPUT_APK%.apk}-signed.apk"
KEYSTORE="android/app/openim"
KEY_ALIAS="openim"
STORE_PASS="openim"
KEY_PASS="openim"

# 检查输入文件
if [ ! -f "$INPUT_APK" ]; then
    echo -e "${RED}错误: 文件不存在: $INPUT_APK${NC}"
    exit 1
fi

# 检查 keystore 文件
if [ ! -f "$KEYSTORE" ]; then
    echo -e "${RED}错误: Keystore 文件不存在: $KEYSTORE${NC}"
    exit 1
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}APK 签名工具${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "输入文件: ${YELLOW}$INPUT_APK${NC}"
echo -e "输出文件: ${YELLOW}$OUTPUT_APK${NC}"
echo -e "Keystore: ${YELLOW}$KEYSTORE${NC}"
echo -e "Key Alias: ${YELLOW}$KEY_ALIAS${NC}"
echo ""

# 检查 apksigner 是否可用
if command -v apksigner &> /dev/null; then
    echo -e "${GREEN}使用 apksigner 签名...${NC}"

    apksigner sign \
      --ks "$KEYSTORE" \
      --ks-key-alias "$KEY_ALIAS" \
      --ks-pass "pass:$STORE_PASS" \
      --key-pass "pass:$KEY_PASS" \
      --out "$OUTPUT_APK" \
      "$INPUT_APK"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}签名成功!${NC}"

        # 验证签名
        echo ""
        echo -e "${YELLOW}验证签名...${NC}"
        apksigner verify --verbose "$OUTPUT_APK"

        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}签名验证通过!${NC}"
            echo ""
            echo -e "签名后的 APK: ${BLUE}$OUTPUT_APK${NC}"
            echo ""
            echo -e "安装命令:"
            echo -e "  ${YELLOW}adb install $OUTPUT_APK${NC}"
        else
            echo -e "${RED}签名验证失败!${NC}"
            exit 1
        fi
    else
        echo -e "${RED}签名失败!${NC}"
        exit 1
    fi

elif command -v jarsigner &> /dev/null && command -v zipalign &> /dev/null; then
    echo -e "${GREEN}使用 jarsigner + zipalign 签名...${NC}"

    ALIGNED_APK="${INPUT_APK%.apk}-aligned.apk"

    # 对齐
    echo "对齐 APK..."
    zipalign -v -p 4 "$INPUT_APK" "$ALIGNED_APK"

    if [ $? -ne 0 ]; then
        echo -e "${RED}APK 对齐失败!${NC}"
        exit 1
    fi

    # 签名
    echo "签名 APK..."
    jarsigner -verbose \
      -sigalg SHA256withRSA \
      -digestalg SHA-256 \
      -keystore "$KEYSTORE" \
      -storepass "$STORE_PASS" \
      -keypass "$KEY_PASS" \
      "$ALIGNED_APK" \
      "$KEY_ALIAS"

    if [ $? -eq 0 ]; then
        mv "$ALIGNED_APK" "$OUTPUT_APK"
        echo -e "${GREEN}签名成功!${NC}"

        # 验证签名
        echo ""
        echo -e "${YELLOW}验证签名...${NC}"
        jarsigner -verify -verbose -certs "$OUTPUT_APK"

        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}签名验证通过!${NC}"
            echo ""
            echo -e "签名后的 APK: ${BLUE}$OUTPUT_APK${NC}"
            echo ""
            echo -e "安装命令:"
            echo -e "  ${YELLOW}adb install $OUTPUT_APK${NC}"
        else
            echo -e "${RED}签名验证失败!${NC}"
            exit 1
        fi
    else
        echo -e "${RED}签名失败!${NC}"
        rm -f "$ALIGNED_APK"
        exit 1
    fi

else
    echo -e "${RED}错误: 未找到 apksigner 或 jarsigner/zipalign 工具${NC}"
    echo ""
    echo "请确保以下工具之一已安装:"
    echo "  1. apksigner (Android SDK Build Tools)"
    echo "  2. jarsigner (JDK) + zipalign (Android SDK Build Tools)"
    echo ""
    echo "安装方法:"
    echo "  apksigner: 包含在 Android SDK Build Tools 中"
    echo "  路径通常为: \$ANDROID_HOME/build-tools/<version>/apksigner"
    exit 1
fi
