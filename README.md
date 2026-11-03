<div align="center">
  <img src="./src/static/origin-manufacturing-logo.svg" alt="ORIGIN ERP" width="360" />

  <h1>ORIGIN ERP Mobile</h1>

  <p>为仓库、产线和现场作业设计的多端 ERP 客户端，让关键业务离开电脑也能完成。</p>

  <p>
    <img src="https://img.shields.io/badge/uni--app-3-2b9939?logo=vuedotjs&logoColor=white" alt="uni-app" />
    <img src="https://img.shields.io/badge/Vue-3.4-42b883?logo=vuedotjs&logoColor=white" alt="Vue 3.4" />
    <img src="https://img.shields.io/badge/TypeScript-4.9-3178c6?logo=typescript&logoColor=white" alt="TypeScript 4.9" />
    <img src="https://img.shields.io/badge/Vite-5-646cff?logo=vite&logoColor=white" alt="Vite 5" />
    <img src="https://img.shields.io/badge/vitest-1-6e9f18?logo=vitest&logoColor=white" alt="vitest" />
  </p>
</div>

## 项目简介

ORIGIN ERP Mobile 是原点 ERP 的现场作业端，基于 uni-app、Vue 3 和 TypeScript 构建，与 Web 管理端共享账号、权限和业务数据。项目面向手机、PDA、H5 和小程序场景，重点优化扫码、库存查询、仓库切换和待办处理等高频操作。

配套项目：

- [ORIGIN ERP 后端](https://github.com/weigu2700-cell/ORIGIN-ERP-BackEnd)
- [ORIGIN ERP Web](https://github.com/weigu2700-cell/ORIGIN-ERP--FrontEnd)

## 项目亮点

- **一套代码，多端运行**：支持 H5、App、微信小程序及 uni-app 提供的其他平台构建目标。
- **现场作业优先**：围绕仓库、扫码、领料、入库和出库设计移动交互，减少复杂表单和层级跳转。
- **权限感知工作台**：根据当前用户权限动态展示快捷入口和业务待办，管理员自动兼容完整能力。
- **仓库上下文**：支持切换并持久化当前仓库，库存与后续作业自动携带仓库条件。
- **完整会话管理**：统一保存 JWT、加载用户与权限，在 401 时清理登录态并返回登录页。
- **组织选择与安全切换**：核验组织编码，记住最近成功登录的组织；工作台和个人中心展示当前组织，切换时退出重登、取消旧请求并清空原组织仓库及业务摘要。
- **单屏登录**：组织、账号、密码及登录按钮放在同一视口，较矮屏幕收起装饰区域，核验错误就地展示。
- **统一请求体验**：集中处理响应解包、查询参数、超时、断网、业务异常和 Toast 提示。
- **离线/弱网恢复**：网络断开时显示横幅提示，写入操作不自动重试，冲突状态明确可识别。
- **通用列表模板**：可复用的 `useListState` 组合式函数，统一 loading/empty/error/分页状态。

## 当前能力

| 功能       | 状态      | 说明                                                          |
| ---------- | --------- | ------------------------------------------------------------- |
| 登录与会话 | ✅ 已完成 | 组织核验、JWT 登录、会话恢复、退出切换、旧响应隔离及 401 处理 |
| 用户与权限 | ✅ 已完成 | 用户资料、角色、权限加载和快捷入口控制                        |
| 移动工作台 | ✅ 已完成 | 业务摘要、待办、快捷功能、仓库切换                            |
| 库存查询   | ✅ 已完成 | 搜索、仓库过滤、分页、扫码、库存详情                          |
| 采购入库   | ✅ 已完成 | 列表搜索/扫码/分页、详情、上架操作                            |
| 生产领料   | ✅ 已完成 | 列表搜索/扫码/分页、详情、确认领料                            |
| 生产报工   | ✅ 已完成 | 生产订单登记、数量校验、列表/详情、审批/取消/完成/驳回        |
| 成品入库   | ✅ 已完成 | 真实入库单查询、仓库过滤、审批与执行入库                      |
| 销售出库   | ✅ 已完成 | 列表搜索/扫码/分页、详情物料明细、确认出库                    |
| 生产订单   | ✅ 已完成 | 待生产/生产中双Tab、进度条、开始/完成操作                     |
| 销售订单   | ✅ 已完成 | 列表搜索/分页、详情物料明细（只读）                           |
| 离线提示   | ✅ 已完成 | 网络断开横幅组件，所有业务页集成                              |

生产作业的状态、权限、数量及弱网处理见 [移动端生产闭环](docs/production-mobile.md)。

以上业务能力适用于后端已开放业务的组织。当前后端 multi 模式仍返回 `businessAvailable=false`，移动端展示真实组织、基础身份和“当前组织暂未开放业务”，业务页面被守卫拦截；不能把上述功能表理解为多租户正式业务已经开放。

## 组织登录与切换

客户端通过配套后端 `GET /auth/tenant/context` 识别运行模式，不另外配置组织列表：

| 场景           | 操作与行为                                                                                |
| -------------- | ----------------------------------------------------------------------------------------- |
| single 单企业  | 自动选择后端默认组织，输入原账号和密码登录                                                |
| multi 首次登录 | 输入管理员提供的组织编码，核验名称后提交账号和密码                                        |
| 最近组织       | 本地保留最多 5 个成功登录的编码与名称，通过组织输入框内的下拉入口选择；不提供公开企业目录 |
| 切换组织       | 在工作台或个人中心点击当前组织，选择目标并确认退出，再重新登录；未提交内容不会保留        |
| 加载或核验失败 | 组织字段内显示原因，点击“重试”或“核验”重新检查                                            |
| 业务尚未开放   | 停留组织主页，可重新检查状态、查看基础身份或切换组织，不展示虚构业务数量                  |

组织核验调用 `POST /auth/tenant/resolve`，登录提交 `tenantCode`、`username`、`password`，登录后通过 `GET /auth/tenant/session` 获取实际组织和 `businessAvailable`。旧后端缺少这些接口时应先升级后端。

默认账号由数据库初始化方式决定：旧单企业开发 seed 为 `admin` / `OriginDev@123`，仅用于执行过该 seed 的开发库；Flyway 新租户使用开通时指定的管理员用户名与密码，没有统一默认账号。初始化顺序见 [后端部署说明](https://github.com/weigu2700-cell/ORIGIN-ERP-BackEnd#组织与多租户)。

切换会话会取消旧 `uni.request`，拦截旧组织晚到的成功或 401 响应，清空权限、当前仓库与工作台内存状态。组织名称只是显示信息，实际授权以服务端签发的组织 JWT 为准。

## 扫码查询

工作台、服务目录和业务列表共用扫码页，支持库存、采购入库、生产领料、销售出库、生产订单和销售订单查询。App/小程序使用原生扫码，H5 使用本地相机识别（HTTPS 或 localhost），并提供手工输入、粘贴和 PDA 回车输入。

识别后核对编码再查询，取消不改变原筛选；退出或识别完成会释放 H5 相机。支持纯物料/单据编码，链接和 JSON 二维码会给出明确提示。扫码不自动提交业务操作。

详见 [扫码功能与真机验收清单](docs/scan-acceptance.md)。

## 架构

```text
┌─────────────────────────────────────────────────────┐
│  Pages (列表 / 详情 / 操作)                            │
│  inventory · purchase-in-stock · production-picking   │
│  production-inbound · sales-outbound                  │
│  production-order · sales-order                       │
├─────────────────────────────────────────────────────┤
│  Shared Composables & Components                      │
│  useListState · OfflineBanner                         │
├─────────────────────────────────────────────────────┤
│  Core Layer                                           │
│  auth (SessionGuard · PermissionRegistry)              │
│  api (errors · request-sequence)                      │
│  connectivity (useConnectivity)                        │
├─────────────────────────────────────────────────────┤
│  Stores (Pinia)                                       │
│  user · organization · workbench                      │
├─────────────────────────────────────────────────────┤
│  API Layer + Types                                    │
│  auth · inventory · purchase · production · sales     │
└─────────────────────────────────────────────────────┘
```

### 设计原则

- **页面只编排，状态机决定按钮**：每个详情页只根据单据当前状态渲染可用操作，不硬编码业务流程。
- **读取可重试，写入不盲提**：读接口失败展示重试入口；写操作先查单据最新状态，冲突时禁止重试。
- **离线可见，在线可操作**：所有页面在网络断开时给出明确提示，但不阻塞浏览已加载数据。

## 技术栈

| 分类     | 技术                                    |
| -------- | --------------------------------------- |
| 跨端框架 | uni-app 3                               |
| 核心框架 | Vue 3.4、Composition API                |
| 开发语言 | TypeScript 4.9                          |
| 构建工具 | Vite 5                                  |
| 状态管理 | Pinia 2                                 |
| UI 组件  | Wot Design Uni                          |
| 测试框架 | vitest + @vue/test-utils                |
| 代码规范 | ESLint + Prettier                       |
| 平台能力 | `uni.request`、扫码、存储、页面生命周期 |
| 样式     | Sass、uni.scss                          |

## 快速开始

### 环境要求

- Node.js 18+
- npm 9+
- 已启动的 [ORIGIN ERP 后端](https://github.com/weigu2700-cell/ORIGIN-ERP-BackEnd)
- 微信小程序开发需安装微信开发者工具
- App 真机运行与打包建议使用 HBuilderX，并准备 DCloud AppID 和签名

### 安装依赖

```bash
git clone https://github.com/weigu2700-cell/ORIGIN-ERP-Moblie.git
cd ORIGIN-ERP-Moblie

npm ci
```

### 启动开发环境

```bash
# H5
npm run dev:h5

# 微信小程序
npm run dev:mp-weixin

# App 编译资源
npm run dev:app
```

H5 默认运行在 <http://localhost:5173>。微信开发者工具应导入 `dist/dev/mp-weixin`。

## 后端地址配置

建议在项目根目录创建仅用于本机的 `.env.development.local`，并确保不要将真实地址或敏感信息提交到仓库：

```dotenv
# H5 开发代理目标
API_PROXY_TARGET=http://localhost:8080

# App / 小程序访问的完整地址
VITE_NATIVE_API_BASE_URL=http://192.168.1.100:8080
```

各平台请求方式：

| 平台         | 默认地址                      | 说明                                               |
| ------------ | ----------------------------- | -------------------------------------------------- |
| H5 开发      | `/api`                        | Vite 代理到 `API_PROXY_TARGET`，并移除 `/api` 前缀 |
| H5 生产      | `VITE_API_BASE_URL` 或 `/api` | 使用完整 API 地址，或由部署服务器配置反向代理      |
| App / 小程序 | `VITE_NATIVE_API_BASE_URL`    | 必须是设备可以直接访问的完整地址                   |

> 真机中的 `localhost` 指向手机或 PDA 自身。请改用后端电脑的局域网 IP，并确保设备、电脑和防火墙允许互相访问。

生产 App 和小程序应使用 HTTPS。微信小程序还需要配置 request 合法域名，并在 `src/manifest.json` 中填写自己的 AppID。

## 常用命令

| 命令                      | 说明                            |
| ------------------------- | ------------------------------- |
| `npm run dev:h5`          | 启动 H5 开发环境                |
| `npm run dev:mp-weixin`   | 构建并监听微信小程序            |
| `npm run dev:app`         | 构建并监听 App 资源             |
| `npm run type-check`      | 执行 Vue 与 TypeScript 类型检查 |
| `npm run build:h5`        | 构建生产 H5                     |
| `npm run build:mp-weixin` | 构建生产微信小程序              |
| `npm run build:app`       | 构建生产 App 资源               |
| `npm run lint`            | 运行 ESLint 检查                |
| `npm run lint:fix`        | 自动修复 ESLint 问题            |
| `npm run format`          | Prettier 格式化代码             |
| `npm run test:run`        | 运行单元测试                    |
| `npm run test:coverage`   | 运行测试并生成覆盖率报告        |

其他平台脚本可在 `package.json` 中查看。主要生产产物位于：

```text
dist/build/h5
dist/build/mp-weixin
dist/build/app
```

## 项目结构

```text
src/
├── api/                    # 按领域划分的 API 接口
│   ├── system/             # 登录、组织配置/核验、当前会话与用户权限
│   ├── inventory/          # 库存查询与扫码
│   ├── production/         # 生产订单、领料、成品入库接口
│   ├── purchase/           # 采购入库接口
│   └── sales/              # 销售订单、出库接口
├── apps/                   # 业务页面模块
│   ├── inventory/          # 库存列表与详情
│   ├── purchase-in-stock/  # 采购入库列表与上架
│   ├── production-picking/ # 生产领料列表与确认
│   ├── production-inbound/ # 成品入库列表与确认
│   ├── production-order/   # 生产订单列表与操作
│   ├── production-report/  # 报工登记、列表、详情与审批
│   ├── sales-outbound/     # 销售出库列表与确认
│   └── sales-order/        # 销售订单列表与详情
├── config/                 # API 地址和请求超时配置
├── components/organization/ # 组织选择、切换与未开放状态
├── constants/              # 能力配置、领域枚举、存储键
├── core/                   # 核心基础设施
│   ├── api/                # 错误模型、请求序列号
│   ├── auth/               # 权限注册表、会话守卫
│   └── connectivity/       # 网络连接检测
├── pages/
│   ├── login/              # 登录页
│   ├── workbench/          # 权限工作台
│   ├── profile/            # 个人中心
│   ├── feature/            # 功能目录
│   └── scan/               # 扫码与手工输入承接页
├── shared/                 # 共享层
│   ├── composables/        # useListState 等通用组合式函数
│   ├── components/         # OfflineBanner 等通用组件
│   └── types/              # AsyncState 等共享类型
├── static/                 # Logo、背景和 TabBar 图标
├── stores/                 # Pinia 状态（用户、组织、工作台）
├── types/                  # 业务类型定义
│   ├── api.ts              # 统一响应、错误类型、ID 类型
│   ├── inventory/          # 库存类型
│   ├── production/         # 生产类型
│   ├── purchase/           # 采购类型
│   └── sales/              # 销售类型
├── utils/                  # Token 与统一请求封装
├── __tests__/              # 单元测试
├── App.vue                 # 应用入口和全局样式
├── main.ts                 # Vue 与 Pinia 初始化
├── pages.json              # 页面路由和 TabBar
├── manifest.json           # App 与小程序平台配置
└── uni.scss                # uni-app 全局样式变量
```

## 请求约定

后端统一返回：

```json
{
  "code": 200,
  "msg": "请求成功",
  "data": {}
}
```

业务代码通过统一请求方法访问 API：

```ts
import { post } from '@/utils/request';

const result = await post<{ token: string }>(
  '/auth/login',
  {
    tenantCode: 'company-a',
    username: 'your-account',
    password: '******',
  },
  { auth: false },
);
```

请求层会自动附加：

```http
Authorization: Bearer <token>
```

## 状态模型

所有异步数据遵循统一的 `AsyncStatus` 模型：

| 状态      | 含义       | UI 表现              |
| --------- | ---------- | -------------------- |
| `idle`    | 尚未请求   | 无内容               |
| `loading` | 首次加载中 | 加载提示             |
| `ready`   | 数据就绪   | 列表 / 详情 / 空状态 |
| `error`   | 请求失败   | 错误信息 + 重试按钮  |

列表页使用 `useListState` 组合式函数，额外支持分页、刷新、加载更多等能力。每个业务页面必须覆盖 loading / empty / error / success 四种状态。

## 权限体系

权限码统一在 `src/core/auth/permission-registry.ts` 注册，格式为 `领域:子域:动作`（例如 `purchase:in:stock:list`），与后端 `@PreAuthorize` 注解一致。入口按 `list` 权限控制可见性，操作按钮按动作权限独立控制。

## 测试

```bash
# 运行全部单元测试
npm run test:run

# 生成覆盖率报告
npm run test:coverage
```

测试覆盖范围：

- 请求序列号管理与旧请求覆盖保护
- 权限判断（hasPermission / hasAllPermissions / hasAnyPermission）
- HTTP 错误分类与可重试性判断
- useListState 列表状态管理（分页、刷新、空状态、错误恢复）
- useRequestSequence 请求序列追踪与 AbortController
- 连通性检测与弱网下写操作重试规则
- 组织核验顺序、single 默认组织与同用户 ID 的组织会话切换
- 旧组织晚到的 200/401、用户/权限数据隔离及仓库上下文清理
- 生产作业权限、状态流转、数量校验与防重复提交

最近一次验证（2026-11-03）：117 项单元测试、类型检查和 H5 生产构建通过；H5 登录在 320×568、320×640、390×844、430×932 四种视口下测量无页面滚动溢出，三个输入框和登录按钮均可见，包含组织核验错误状态。App/小程序的软键盘、安全区及系统字体仍需按目标设备真机验收，H5 截图不替代原生端验收。

## 开发规范

- 页面使用 Vue 3 Composition API 和 TypeScript。
- 业务请求集中放在 `src/api`，页面不直接调用 `uni.request`。
- 平台差异优先使用 uni-app 条件编译处理。
- 所有接口 ID 使用字符串（`EntityId = string`），避免雪花 ID 精度丢失。
- 新业务入口必须配置权限编码，并处理无权限、空数据、加载和失败状态。
- 每个页面必须覆盖 loading / empty / error / offline / forbidden / success 六种状态。
- 写操作不可重复提交，失败不丢输入，不产生"假成功"。
- 提交前执行 `npm run lint` 和 `npm run test:run`，并构建目标发布平台。
- 提交信息使用中文，遵循约定式提交格式：`feat(阶段): 具体描述`。

## 参与贡献

1. Fork 仓库并创建功能分支：`git checkout -b feat/your-feature`
2. 完成功能并运行 `npm run lint` 和 `npm run test:run`
3. 使用中文提交信息，例如：`feat(M2): 新增采购入库列表/详情/上架闭环`
4. 推送分支并创建 Pull Request，注明验证的平台和设备

问题与建议请提交到 [GitHub Issues](https://github.com/weigu2700-cell/ORIGIN-ERP-Moblie/issues)。
