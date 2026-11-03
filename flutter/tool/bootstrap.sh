#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_cmd="$(pwd)/tool/flutterw"
"$flutter_cmd" --version
# 原生工程使用 SDK 当前模板生成，避免手写 Gradle/Xcode 工程与 SDK 不匹配。
# 仅首次初始化；不覆盖已配置签名或已有平台工程。
if [[ ! -d android && ! -d ios ]]; then
  "$flutter_cmd" create --empty --platforms=android,ios --org cn.origin --project-name origin_mobile --no-pub .
fi
python3 tool/configure_platforms.py
"$flutter_cmd" pub get
"$flutter_cmd" --format-dart lib test
"$flutter_cmd" analyze
"$flutter_cmd" test
