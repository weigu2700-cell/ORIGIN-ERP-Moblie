# 原点智造 Flutter 移动端

Android + iOS 的迁移工程，位于旧移动仓库的 `flutter/`。旧 uni-app `src/` 和构建入口保留供业务核对。

## 当前验证状态

- Flutter 3.47.9 / Dart 3.13.7 已安装，SDK 归档 SHA-256 校验通过。
- Android/iOS 原生宿主已生成，依赖已解析并保存 `pubspec.lock`。
- 静态分析通过；22 项契约、身份隔离和页面测试通过；另有工作台截图渲染检查。
- Android ARM64 调试包构建正在验证；iOS 缺少完整 Xcode，尚未构建。
- 未做真实服务器联调、相机/扫描头真机测试和生产发布验收，当前不能替代旧 App 上线。

## 工具链和运行

本机 SDK 位于 `/Users/guwei/Program/origin-erp/.tooling/flutter`，Android SDK 位于同级 `android-sdk/`；项目脚本会自动定位，不需要先改全局 PATH。其他机器可设置 `FLUTTER_ROOT` 或将 Flutter 加入 PATH。建议使用 `.flutter-version` 指定的版本。

```bash
cd /Users/guwei/Program/origin-erp/origin-erp-mobile/flutter
./tool/flutterw --version
./tool/bootstrap.sh
./tool/flutterw run --dart-define=API_BASE_URL=https://your-server.example/api
```

`API_BASE_URL` 必须是手机可访问的完整服务器地址，包含实际 API 前缀。未配置时登录显示配置错误，不连接演示服务器。不要用手机的 `localhost` 指代开发电脑。默认使用 HTTPS；HTTP 调试需要明确配置 debug 网络例外。

脚本把 Pub 缓存放在工作区 `.tooling/pub-cache`，默认使用 Flutter 中文文档列出的 CFUG 镜像。可通过 `PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL` 覆盖。Gradle 构建建议设置 `GRADLE_USER_HOME` 指向工作区 `.tooling/gradle`。

```bash
./tool/flutterw --format-dart lib test tool/preview_test.dart
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw test tool/preview_test.dart
GRADLE_USER_HOME=/Users/guwei/Program/origin-erp/.tooling/gradle ./tool/flutterw build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=https://your-server.example/api
```

当前原生模板目标为 Android API 24+、iOS 15+；Android 编译/目标 API 为36，生产设备清单仍需验收。包标识 `cn.origin.origin_mobile` 是本地开发标识；生产标识、签名及分发方式尚未配置。Debug 包不是生产签名包。

首次 bootstrap 只在 Android/iOS 宿主都不存在时生成官方模板，不覆盖已有宿主；随后补充相机、网络权限、显示名称、Android 禁止备份和 iOS Keychain entitlement。后续运行可重复检查配置。

## 已实现的源码范围

- 身份：single 默认组织、multi 编码解析、登录/恢复、权限、组织业务门禁、安全存储、切组织退出重登。
- 消息：真实收件箱、未读筛选/数量、详情、单条/全部已读、分页及已核对的业务类型跳转。
- 工作台：按权限展示应用和组织级业务统计，不把组织数据称为个人待办。
- 库存：编码搜索、仓库筛选、分页、详情和扫码回填；仓库按 `ENABLE` 枚举名查询并加载分页。
- 生产订单：列表/详情、下达/开始/完成/取消、关联领料/报工/成品入库。
- 领料：审批、扫码核对物料，再明确确认执行；不自动按扫码结果过账。
- 报工：从生产中订单登记草稿，四位小数精确校验，审批/驳回/取消/完成；未保存返回确认与未知结果回查。
- 出入库：成品入库审批/执行、采购审核/仓库库位批次上架、销售出库确认/执行/取消及销售订单查询。
- AI：独立列表/详情、标题搜索、进行中/归档、历史、新建、UTF-8 SSE、停止、复制和服务端 ACTION 确认。
- 我的：账户、角色、组织与退出。

## 结构与业务约束

`core/` 管理 API、错误、身份与安全存储；`domain/` 保存业务契约、状态/权限、数量和仓库规则；`features/` 实现页面和局部状态；`ui/` 提供 token、状态、字段与确认组件。

四个主入口有独立 Navigator，切页保留查询/详情。身份边界替换整个 Navigator 并关闭旧 HTTP 与 AI 流。JWT 按服务器地址隔离存储，不保存密码；安全存储操作串行，防止退出后慢写入恢复旧凭据。

ID 使用字符串；数量按字符串提交，并用 BigInt 万分位比较。写操作前查询最新状态并明确确认；未知结果不自动重放。报工完成生成入库单，只有真实入库执行增加库存。领料接口为 `POST /prd/picking/confirm?id=...`；成品入库筛选使用枚举名称。

## 仍需验证和补齐

- 真实 API、精确岗位权限、生产闭环、库存变化与弱网/后台恢复联调。
- Android/iOS 真机相机拒绝、前导零/长编码、外接扫码、返回手势、键盘、读屏及200%字体。厂商扫描头尚未适配。
- 通知目前通过 REST 刷新，未接 WebSocket。未知业务类型保留通知正文，不猜测跳转。
- AI 当前用可选择文本渲染；Markdown 表格、业务链接和会话服务端分页仍待实现。
- 新增报工/AI 创建的服务端请求幂等需要后端支持，当前未知结果锁定不等同于后端幂等。
- 多语言 ARB、最近组织记录、通知设置、岗位常用项配置和个人待办聚合待补齐；首版不支持离线制单与自动过账。

视觉检查输出在 `output/workspace-flutter-390.png`，使用明确的测试夹具，不代表生产数据。迁移依据与验收记录见 `docs/MIGRATION.md`。
