#!/usr/bin/env bash
# 提交前的本地检查：格式、静态分析、单元与页面测试。CI 运行同样的步骤。
set -euo pipefail
cd "$(dirname "$0")/.."
./tool/flutterw --format-dart --set-exit-if-changed lib test tool
./tool/flutterw analyze
./tool/flutterw test
