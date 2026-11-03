# 移动端开发与集成参考

产品定位、能力范围与首次启动入口见 [README](../README.md)。本文面向需要联调、扩展功能和维护部署的开发者，命令均从仓库根目录执行。

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
