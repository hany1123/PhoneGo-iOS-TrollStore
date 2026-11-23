#!/bin/bash
# PhoneGo iOS —— 直接用 xcrun clang 编译 Mach-O App + ldid 伪签 + 打包 IPA
# 在 GitHub Actions macOS runner 上运行。不依赖 Theos application.mk 约定。
set -e

echo "=== 环境 ==="
xcode-select -p
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "SDK=$SDK"

OUT="$PWD/out"
APP="$OUT/PhoneGo.app"
rm -rf "$OUT" "$APP"
mkdir -p "$APP"

echo "=== 编译 Objective-C 源文件 ==="
SRCS=$(find src -maxdepth 1 -name '*.m' | sort | tr '\n' ' ')
echo "源文件: $SRCS"

xcrun --sdk iphoneos clang \
  -arch arm64 \
  -isysroot "$SDK" \
  -miphoneos-version-min=14.0 \
  -fobjc-arc \
  -O2 \
  -Wno-deprecated-declarations \
  -Wno-undeclared-selector \
  -Wno-objc-method-access \
  -Wno-unused-variable \
  -Wno-pointer-to-int-cast \
  -Wno-int-to-pointer-cast \
  -Wno-objc-method-access \
  -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
  -Wl,-undefined,dynamic_lookup \
  $SRCS \
  -o "$APP/PhoneGo"

echo "=== 编译产物 ==="
file "$APP/PhoneGo"
ls -lh "$APP/PhoneGo"

echo "=== 写入 Info.plist + 图标资源 ==="
cp src/Info.plist "$APP/Info.plist"
if [ -d Resources ]; then
  cp -R Resources/*.png "$APP/" 2>/dev/null || true
  echo "--- 图标资源 ---"
  ls -1 "$APP"/*.png 2>/dev/null || echo "警告: 无图标"
fi

echo "=== ldid 伪签（带 entitlements） ==="
ldid -Sentitlements/PhoneGo.entitlements "$APP/PhoneGo"
echo "--- 签名后的 entitlements ---"
ldid -e "$APP/PhoneGo" | head -40

echo "=== 打包 IPA（标准结构：zip 根必须有 Payload/ 目录） ==="
rm -rf Payload
mkdir -p Payload
cp -R "$APP" Payload/
# 从项目根目录打包，保留 Payload/ 前缀（TrollStore 必需）
zip -qry "$OUT/PhoneGo.ipa" Payload
V=$(date +%Y%m%d)
cp "$OUT/PhoneGo.ipa" "$OUT/PhoneGo_${V}.ipa"
ls -lh "$OUT"/*.ipa
echo "=== 完成 ==="
