<div align="center">
  <img src="./src/static/origin-manufacturing-logo.svg" alt="ORIGIN ERP" width="360" />

  <h1>ORIGIN ERP Mobile</h1>

  <p>为仓库、产线和现场作业设计的多端 ERP 客户端，让关键业务离开电脑也能完成。</p>

  <p>
    <img src="https://img.shields.io/badge/uni--app-3-2b9939?logo=vuedotjs&logoColor=white" alt="uni-app" />
    <img src="https://img.shields.io/badge/Vue-3.4-42b883?logo=vuedotjs&logoColor=white" alt="Vue 3.4" />
    <img src="https://img.shields.io/badge/TypeScript-4.9-3178c6?logo=typescript&logoColor=white" alt="TypeScript 4.9" />
    <img src="https://img.shields.io/badge/Vite-5-646cff?logo=vite&logoColor=white" alt="Vite 5" />
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
- **实时业务概览**：已接入待生产领料、待销售出库和生产中订单数量，并预留采购入库摘要。
- **完整会话管理**：统一保存 JWT、加载用户与权限，在 401 时清理登录态并返回登录页。
- **统一请求体验**：集中处理响应解包、查询参数、超时、断网、业务异常和 Toast 提示。
- **移动端库存体验**：支持物料关键字搜索、仓库筛选、分页加载、下拉刷新、扫码查询和库存详情。

## 当前能力

| 功能       | 状态   | 说明                                   |
| ---------- | ------ | -------------------------------------- |
| 登录与会话 | 已完成 | JWT 登录、会话恢复、退出及 401 处理    |
| 用户与权限 | 已完成 | 用户资料、角色、权限加载和快捷入口控制 |
| 移动工作台 | 已完成 | 业务摘要、待办、快捷功能、仓库切换     |
| 库存查询   | 已完成 | 搜索、仓库过滤、分页、扫码、库存详情   |
| 生产领料   | 接入中 | 工作台入口和业务上下文已预留           |
| 采购入库   | 接入中 | 将对接审核、上架与批次信息             |
| 销售出库   | 接入中 | 将对接确认、完成与取消流程             |
| 成品入库   | 规划中 | 将复用生产订单和当前仓库上下文         |

## 技术栈

| 分类     | 技术                                    |
| -------- | --------------------------------------- |
| 跨端框架 | uni-app 3                               |
| 核心框架 | Vue 3.4、Composition API                |
| 开发语言 | TypeScript 4.9                          |
| 构建工具 | Vite 5                                  |
| 状态管理 | Pinia 2                                 |
| UI 组件  | Wot Design Uni                          |
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

其他平台脚本可在 `package.json` 中查看。主要生产产物位于：

```text
dist/build/h5
dist/build/mp-weixin
dist/build/app
```

## 项目结构

```text
src/
├── api/              # 登录、用户、仓库、库存和工作台接口
├── apps/
│   └── inventory/    # 库存列表与详情业务包
├── config/           # API 地址和请求超时配置
├── constants/        # 本地存储键等常量
├── pages/
│   ├── login/        # 登录页
│   ├── workbench/    # 权限工作台
│   ├── profile/      # 个人中心
│   └── feature/      # 待接入业务的统一承接页
├── static/           # Logo、背景和 TabBar 图标
├── stores/           # 用户会话和工作台状态
├── types/            # 请求响应与业务类型
├── utils/            # Token 与统一请求封装
├── App.vue           # 应用入口和全局样式
├── main.ts           # Vue 与 Pinia 初始化
├── pages.json        # 页面路由和 TabBar
├── manifest.json     # App 与小程序平台配置
└── uni.scss          # uni-app 全局样式变量
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

## 开发规范

- 页面使用 Vue 3 Composition API 和 TypeScript。
- 业务请求集中放在 `src/api`，页面不直接调用 `uni.request`。
- 平台差异优先使用 uni-app 条件编译处理。
- 所有接口 ID 使用字符串，避免雪花 ID 精度丢失。
- 新业务入口必须配置权限编码，并处理无权限、空数据、加载和失败状态。
- 真机功能应至少验证网络、扫码、返回导航和安全区适配。
- 提交前执行 `npm run type-check`，并构建目标发布平台。

## 参与贡献

1. Fork 仓库并创建功能分支：`git checkout -b feature/your-feature`
2. 完成功能并执行类型检查及目标平台构建
3. 使用清晰的提交信息，例如：`feat: add purchase inbound workflow`
4. 推送分支并创建 Pull Request，注明验证的平台和设备

问题与建议请提交到 [GitHub Issues](https://github.com/weigu2700-cell/ORIGIN-ERP-Moblie/issues)。
