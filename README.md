# 原点智造移动端

原点智造 ERP 的 Android / iOS 移动作业 App，使用 Flutter 开发。面向仓库、生产和审核人员：在手机上查询库存、扫码找料、处理领料、报工、入库与出库，并通过 AI 助手查询业务数据。服务端为 [ORIGIN ERP 后端](https://github.com/weigu2700-cell/ORIGIN-ERP-BackEnd)，移动端与 Web 管理端共用同一套账号、权限与单据规则。

> 当前状态：功能与界面已完成首版，已用真实后端做过只读联调；写操作、真机相机、弱网与发布流程尚未验收，**不能直接用于生产**。详见下文「验证状态」。

## 功能

| 模块 | 说明 |
| --- | --- |
| 登录与组织 | 单企业直接登录，多组织先解析组织编码；业务未开放的组织会被拦截；切换组织即退出重登并清理所有旧状态 |
| 消息 | 会话列表 + 「系统通知」聊天式详情；未读数、全部已读、跳转到对应业务单据 |
| 工作台 | 常用应用入口、待处理业务、进行中的生产；按权限显示 |
| 扫一扫 | 全屏相机取景，支持手工输入、粘贴、外接扫码枪；只返回编码，不自动出入库 |
| 库存 | 编码搜索、仓库筛选、分页；可用 / 预留 / 在库一目了然 |
| 生产 | 生产订单（下达、开工、完成、取消）、领料（审批、扫码核对物料、确认）、报工（草稿、审批、完成）、成品入库 |
| 采购与销售 | 采购入库（审核、上架）、销售出库（确认、执行、取消）、销售订单查询 |
| AI 助手 | 默认进入新对话，左侧抽屉管理历史会话；流式回答、停止、归档、需用户确认的业务动作 |
| 我的 | 账号、角色、所属组织、切换组织与退出 |

界面遵循 iOS 设计语言：分组圆角卡片、大标题、侧滑返回；iOS 底部导航为悬浮毛玻璃并避让灵动岛与 Home 指示条，Android 使用标准导航栏。设计稿与业务需求见 [docs/design/mobile-workspace-v1](docs/design/mobile-workspace-v1/)。

## 快速开始

需要 Flutter 3.47（见 `flutter/.flutter-version`）。Android 需要 Android SDK，iOS / macOS 需要完整 Xcode。

```bash
cd flutter
./tool/flutterw run --dart-define=API_BASE_URL=http://localhost:8080
```

`API_BASE_URL` 是服务端地址，不带 `/api` 前缀，编译时写入，修改后需重新启动（热重载不生效）。不同运行环境使用的地址：

| 运行环境 | 地址 |
| --- | --- |
| iOS 模拟器 / macOS | `http://localhost:8080` |
| Android 模拟器 | `http://10.0.2.2:8080` |
| 真机 | `http://<电脑局域网 IP>:8080`，手机与电脑在同一网络 |

未配置地址时登录页提示配置错误，不会连接任何演示服务器。Debug 构建允许明文 HTTP，生产环境必须使用 HTTPS。

`tool/flutterw` 会优先使用 `FLUTTER_ROOT`，其次是工作区 `.tooling/flutter`，最后是 PATH 中的 `flutter`；Pub 缓存默认使用国内镜像，可用 `PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL` 覆盖。

## 开发

```bash
cd flutter
./tool/flutterw --format-dart lib test tool   # 格式化
./tool/flutterw analyze                       # 静态分析
./tool/flutterw test                          # 单元与页面测试
./tool/flutterw test tool/preview_test.dart   # 渲染各页面截图到 output/preview/
PREVIEW_IOS=1 ./tool/flutterw test tool/preview_test.dart   # 模拟灵动岛安全区
```

连接真实后端做只读契约自检（需要后端已启动，账号自备）：

```bash
LIVE_URL=http://localhost:8080 LIVE_USER=<账号> LIVE_PASS=<密码> ./tool/flutterw test tool/live_check.dart
```

构建示例：

```bash
./tool/flutterw build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://10.0.2.2:8080
./tool/flutterw build macos --debug --dart-define=API_BASE_URL=http://localhost:8080
```

### 目录结构

```text
flutter/lib/
  core/       API 客户端、请求取消、会话与安全存储
  domain/     单据定义、权限与状态、数量精度、仓库规则
  features/   登录、消息、工作台、库存与单据、报工、扫码、AI 助手
  ui/         主题与设计 token、通用卡片、状态与确认组件
flutter/test/ 契约、身份隔离、页面与布局测试
flutter/tool/ 运行脚本、平台配置、预览与联调自检
docs/         设计稿与业务需求、权限补齐 SQL
```

### 关键约定

- **身份边界**：组织或用户变化时替换整个导航栈，取消进行中的 HTTP 与 AI 流，并忽略迟到的响应；JWT 按服务器地址隔离存储，不保存密码。
- **权限**：入口按精确权限码过滤，Repository 再校验，服务端最终鉴权。组织业务未开放时不请求业务接口。
- **数据精度**：ID 一律字符串；数量按字符串提交，用整数万分位比较，最多四位小数；服务端的 Long（如分页总数）可能以字符串返回，用 `asInt` 解析。
- **写操作**：执行前回查最新状态并明确确认；结果未知时锁定并引导回查单据，不自动重放。报工完成生成入库单，只有成品入库执行才增加库存；扫码只用于核对，不自动过账。
- **AI**：沿用服务端 `CONTENT / TITLE / ACTION / ERROR` 的 SSE 事件；新对话在首次发送时才创建；动作需用户确认并重新校验权限。

## 后端依赖

使用的主要接口（均无 `/api` 前缀）：`/auth/tenant/context`、`/auth/tenant/resolve`、`/auth/login`、`/auth/tenant/session`、`/system/user/current`、`/system/permission`、`/master/warehouse`、`/inventory/material-stock`、`/prd/order`、`/prd/picking`、`/prd/report`、`/inv/finish-warehousing`、`/purchase/in/stock`、`/sales/delivery`、`/sales/order`、`/sys/notification`、`/ai/conversation`、`/ai/message`、`/ai/action`。

部分开发库缺少领料、报工、成品入库的细分权限码，导致这三项返回 403。可用 [docs/sql/mobile-permissions.sql](docs/sql/mobile-permissions.sql) 补齐并授予 `admin` 角色（可重复执行，执行前请先核对数据库）。

## 验证状态

- 已验证：静态分析无错误；22 项自动化测试（契约、身份隔离、页面与窄屏大字体布局）；对真实后端的只读联调（登录、库存、生产订单、销售、通知、AI 会话列表）；Android ARM64 与 macOS 调试包可构建。
- 尚未验证：所有写操作的真实联调；Android / iOS 真机的相机、扫码枪、返回手势、键盘与 200% 字体；iOS 构建与毛玻璃实际效果；弱网、后台恢复；发布签名与分发。
- 已知缺口：厂商 PDA 扫描头未适配；通知通过刷新获取，未接 WebSocket；AI 回答的 Markdown 表格与业务链接未做；报工、AI 创建的请求幂等需要后端支持；多语言、最近组织记录、通知设置、离线制单暂不支持。
- 包标识 `cn.origin.origin_mobile` 仅为本地开发标识；生产标识、签名与分发方式未配置。
