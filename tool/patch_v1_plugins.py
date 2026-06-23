#!/usr/bin/env python3
# dawn 2026-06-23 CI 兼容补丁:
# 部分老插件(image_cropper 5.0.1、ffmpeg_kit 等)的 Android Java 仍实现了 Flutter 3.29+ 已移除的
# v1 嵌入接口 `public static void registerWith(PluginRegistry.Registrar registrar)`,在新 Flutter
# (3.41.x)上 `compileReleaseJavaWithJavac` 会因 `cannot find symbol class Registrar` 失败。
# 本地 pub-cache 是被手动改过的所以能编;CI 全新缓存拉到原始代码就挂。
# 此脚本在 `flutter pub get` 之后运行,自动把这些遗留的 registerWith 方法整段删除(花括号配对),
# 使老插件在新 Flutter 下可编译。幂等、只动 pub-cache 里 android 目录下的 .java。
import os
import re

def candidate_roots():
    roots = []
    pub_cache = os.environ.get("PUB_CACHE") or os.path.join(os.path.expanduser("~"), ".pub-cache")
    for sub in ("hosted", "git"):
        p = os.path.join(pub_cache, sub)
        if os.path.isdir(p):
            roots.append(p)
    return roots

# 匹配:可选注解/修饰符 + static void registerWith( ... Registrar ... ) {
HEAD = re.compile(
    r'\n[ \t]*(?:@[\w.]+\s*)*(?:public\s+|private\s+|protected\s+)?static\s+void\s+registerWith\s*\([^)]*Registrar[^)]*\)\s*\{'
)

def strip_register_with(src: str):
    changed = False
    while True:
        m = HEAD.search(src)
        if not m:
            break
        # 从方法体起始 { 做花括号配对,找到方法结束 }
        brace_start = src.index('{', m.end() - 1)
        depth = 0
        i = brace_start
        end = None
        while i < len(src):
            c = src[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    end = i
                    break
            i += 1
        if end is None:
            break  # 花括号不配对,放弃,避免破坏文件
        src = src[:m.start()] + '\n' + src[end + 1:]
        changed = True
    return src, changed

def main():
    patched = 0
    for root in candidate_roots():
        for dirpath, _dirs, files in os.walk(root):
            parts = dirpath.split(os.sep)
            if 'android' not in parts:
                continue
            for fn in files:
                if not fn.endswith('.java'):
                    continue
                fp = os.path.join(dirpath, fn)
                try:
                    with open(fp, encoding='utf-8') as f:
                        src = f.read()
                except Exception:
                    continue
                if 'registerWith' not in src or 'Registrar' not in src:
                    continue
                new, changed = strip_register_with(src)
                if changed and new != src:
                    with open(fp, 'w', encoding='utf-8') as f:
                        f.write(new)
                    patched += 1
                    print('patched legacy registerWith:', fp)
    print(f'patch_v1_plugins done, patched {patched} file(s)')

if __name__ == '__main__':
    main()
