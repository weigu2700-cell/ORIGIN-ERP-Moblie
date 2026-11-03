# 原点智造移动端

Android + iOS 的移动作业 App（Flutter），连接原点智造 ERP 服务端。工程位于 [`flutter/`](flutter/README.md)。

原 uni-app 版本已从本分支移除，历史提交中仍可查阅。

## 快速开始

```bash
cd flutter
./tool/flutterw run --dart-define=API_BASE_URL=http://localhost:8080
```

`API_BASE_URL` 是服务端地址，不带 `/api` 前缀；真机需使用电脑的局域网地址。完整的工具链、验证状态与已知缺口见 [flutter/README.md](flutter/README.md)。

## 文档

- [Flutter 重构方案](docs/flutter-rebuild-plan.md)
- [设计与交接文档](docs/design/mobile-workspace-v1/HANDOFF.md)
- [迁移说明与验收记录](flutter/docs/MIGRATION.md)
- [补齐移动端权限的 SQL](docs/sql/mobile-permissions.sql)
- 业务验收参考：[生产闭环](docs/production-mobile.md)、[扫码验收](docs/scan-acceptance.md)（部分描述基于旧版，核对后使用）
