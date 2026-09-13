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
    <img src="https://img.shields.io/badge/tests-64%20passed-brightgreen" alt="64 tests passed" />
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
- **统一请求体验**：集中处理响应解包、查询参数、超时、断网、业务异常和 Toast 提示。
- **离线/弱网恢复**：网络断开时显示横幅提示，写入操作不自动重试，冲突状态明确可识别。
- **通用列表模板**：可复用的 `useListState` 组合式函数，统一 loading/empty/error/分页状态。

## 当前能力

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| 登录与会话 | ✅ 已完成 | JWT 登录、会话恢复、退出及 401 处理 |
| 用户与权限 | ✅ 已完成 | 用户资料、角色、权限加载和快捷入口控制 |
| 移动工作台 | ✅ 已完成 | 业务摘要、待办、快捷功能、仓库切换 |
| 库存查询 | ✅ 已完成 | 搜索、仓库过滤、分页、扫码、库存详情 |
| 采购入库 | ✅ 已完成 | 列表搜索/扫码/分页、详情、上架操作 |
| 生产领料 | ✅ 已完成 | 列表搜索/扫码/分页、详情、确认领料 |
| 成品入库 | ✅ 已完成 | 列表搜索/分页、详情、合格/报废汇总、确认入库 |
| 销售出库 | ✅ 已完成 | 列表搜索/扫码/分页、详情物料明细、确认出库 |
| 生产订单 | ✅ 已完成 | 待生产/生产中双Tab、进度条、开始/完成操作 |
| 销售订单 | ✅ 已完成 | 列表搜索/分页、详情物料明细（只读） |
| 离线提示 | ✅ 已完成 | 网络断开横幅组件，所有业务页集成 |

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
│  user · workbench                                     │
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

| 分类 | 技术 |
| --- | --- |
| 跨端框架 | uni-app 3 |
| 核心框架 | Vue 3.4、Composition API |
| 开发语言 | TypeScript 4.9 |
| 构建工具 | Vite 5 |
| 状态管理 | Pinia 2 |
| UI 组件 | Wot Design Uni |
| 测试框架 | vitest + @vue/test-utils |
| 代码规范 | ESLint + Prettier |
| 平台能力 | `uni.request`、扫码、存储、页面生命周期 |
| 样式 | Sass、uni.scss |

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

| 平台 | 默认地址 | 说明 |
| --- | --- | --- |
| H5 开发 | `/api` | Vite 代理到 `API_PROXY_TARGET`，并移除 `/api` 前缀 |
| H5 生产 | `VITE_API_BASE_URL` 或 `/api` | 使用完整 API 地址，或由部署服务器配置反向代理 |
| App / 小程序 | `VITE_NATIVE_API_BASE_URL` | 必须是设备可以直接访问的完整地址 |

> 真机中的 `localhost` 指向手机或 PDA 自身。请改用后端电脑的局域网 IP，并确保设备、电脑和防火墙允许互相访问。

生产 App 和小程序应使用 HTTPS。微信小程序还需要配置 request 合法域名，并在 `src/manifest.json` 中填写自己的 AppID。

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `npm run dev:h5` | 启动 H5 开发环境 |
| `npm run dev:mp-weixin` | 构建并监听微信小程序 |
| `npm run dev:app` | 构建并监听 App 资源 |
| `npm run type-check` | 执行 Vue 与 TypeScript 类型检查 |
| `npm run build:h5` | 构建生产 H5 |
| `npm run build:mp-weixin` | 构建生产微信小程序 |
| `npm run build:app` | 构建生产 App 资源 |
| `npm run lint` | 运行 ESLint 检查 |
| `npm run lint:fix` | 自动修复 ESLint 问题 |
| `npm run format` | Prettier 格式化代码 |
| `npm run test:run` | 运行单元测试 |
| `npm run test:coverage` | 运行测试并生成覆盖率报告 |

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
│   ├── auth/               # 登录、Token 刷新
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
│   ├── sales-outbound/     # 销售出库列表与确认
│   └── sales-order/        # 销售订单列表与详情
├── config/                 # API 地址和请求超时配置
├── constants/              # 能力配置、领域枚举、存储键
├── core/                   # 核心基础设施
│   ├── api/                # 错误模型、请求序列号
│   ├── auth/               # 权限注册表、会话守卫
│   └── connectivity/       # 网络连接检测
├── pages/
│   ├── login/              # 登录页
│   ├── workbench/          # 权限工作台
│   ├── profile/            # 个人中心
│   └── feature/            # 扫码承接页
├── shared/                 # 共享层
│   ├── composables/        # useListState 等通用组合式函数
│   ├── components/         # OfflineBanner 等通用组件
│   └── types/              # AsyncState 等共享类型
├── static/                 # Logo、背景和 TabBar 图标
├── stores/                 # Pinia 状态（用户、工作台）
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
import { post } from "@/utils/request";

const result = await post<{ token: string }>(
  "/auth/login",
  {
    username: "admin",
    password: "******",
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

| 状态 | 含义 | UI 表现 |
| --- | --- | --- |
| `idle` | 尚未请求 | 无内容 |
| `loading` | 首次加载中 | 加载提示 |
| `ready` | 数据就绪 | 列表 / 详情 / 空状态 |
| `error` | 请求失败 | 错误信息 + 重试按钮 |

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