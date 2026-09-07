# Smart ERP 移动端

基于 uni-app、Vue 3、TypeScript、Vite，复用现有 smart-erp-server，与 Web 端共用账号、权限和业务数据。

## 当前进度

已完成项目初始化和第 3 步请求封装：项目标识、三端命令、环境配置、H5 开发代理、统一请求入口和启动页。
Token 状态管理、Pinia、登录、工作台及业务页面按后续阶段实现。启动页不代表后端已连接。
保留原有依赖版本；Vant 自动注册已从构建配置移除，页面使用 uni-app 基础组件。

## 启动

```sh
npm ci
npm run dev:h5
npm run dev:mp-weixin
npm run dev:app
```

H5 默认端口 5173，以终端输出地址为准。微信开发者工具导入 `dist/dev/mp-weixin`，并在 `src/manifest.json` 填入自己的微信 AppID。
App 命令生成编译资源，真机运行及安装包制作需要 HBuilderX 和自己的 DCloud AppID / 签名配置；编译成功不等于已完成真机适配。

```sh
npm run type-check
npm run build:h5
npm run build:mp-weixin
npm run build:app
```

产物分别位于 `dist/build/h5`、`dist/build/mp-weixin`、`dist/build/app`。

## 共用后端配置

已对照工作区 `smart-erp-server` 的 LoginController、Result 和 JwtAuthenticationFilter：

- 登录：`POST /auth/login`。
- 响应：`{ code, msg, data }`，业务成功码为 `200`，登录返回 `data.token`。
- 鉴权：`Authorization: Bearer <token>`。
- 后端已检查的 application.yaml 未指定 HTTP 端口，开发配置先使用 Spring Boot 默认 `8080`；如实际启动覆盖端口，请同步修改。

在项目根目录新建 `.env.development.local` 覆盖本机配置（已被 Git 忽略）：

```dotenv
API_PROXY_TARGET=http://localhost:8080
VITE_NATIVE_API_BASE_URL=http://192.168.1.100:8080
```

真机地址需换成运行后端电脑的实际局域网 IP，手机/PDA 与电脑位于同一网络，后端端口可访问。真机上的 localhost 是设备自身。
H5 使用 `/api`，Vite 将 `/api/auth/login` 转发成后端 `/auth/login`。App、小程序使用完整后端地址，不经过 Vite 代理。
环境变量修改后重启开发服务；`VITE_` 配置会进入客户端，不能存放密钥。

生产 H5 需要服务器为 `/api` 配置反向代理并去掉该前缀，或在 `.env.production.local` 中改为完整 API 地址并配置 CORS。
生产 App / 小程序需要填写 `VITE_NATIVE_API_BASE_URL` 的真实 HTTPS 地址；微信还需配置 request 合法域名并启用域名校验。当前尚未配置发布身份及生产域名。

## 当前文件

```text
src/
  api/system/auth.ts     登录接口
  config/env.ts          统一 API 地址和超时配置，供后续 request 使用
  constants/storage.ts   本地存储键名
  pages/index/index.vue  初始化启动页
  pages/login/login.vue  登录页面
  stores/user.ts         用户会话状态
  static/                静态资源
  types/api.ts           后端响应和请求参数类型
  types/system/auth.ts   登录参数和响应类型
  utils/auth.ts          Token 本地存取
  utils/request.ts       请求、鉴权头、错误与业务响应处理
  App.vue                应用入口及全局样式
  main.ts                Vue 应用创建
  pages.json             页面路由
  manifest.json          平台配置
  uni.scss               uni-app 样式变量
```

请求示例：

```ts
import { post } from "@/utils/request";

const result = await post<{ token: string }>("/auth/login", {
  username: "admin",
  password: "******",
}, { auth: false });
```

泛型表示后端 `Result.data` 的类型。请求层自动附加已有 Token，并统一处理业务错误、HTTP 错误、超时、断网和 401。

登录态、Pinia 与登录页已接入。下一阶段实现工作台。
