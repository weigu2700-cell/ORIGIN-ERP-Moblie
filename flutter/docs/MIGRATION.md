# 迁移说明与验收记录

日期：2026-11-03。

## 当前实施决策

用户本次明确要求 Flutter 重构。使用交付包的 V1 蓝白 token 与「消息/工作台/AI 助手/我的」作为实现基线，不把历史文档里“等下一轮评审”作为本轮停止条件，也不声称 V1 已逐页视觉验收。保留旧 uni-app 并行供业务核对，不恢复 stash、不修改后端/管理端、不提交或发布。

本次实现以现场生产与仓储人员为主要用户，主要动作是找到单据、核对仓库/物料/数量，再明确执行。工作台组织统计与个人任务分开；通知已读与业务完成分开；报工草稿、审批、完成和实际入库分开。

## 设计与状态合同

品牌 `#2C60E8`、正文 `#1C2536`、辅助 `#536279`、画布 `#F5F6F9`、分隔 `#E7EAF0`；页面20、间距12、圆角12。复用 AppBar、NavigationBar、表单、确认弹窗、列表与 StateNotice。系统组件提供焦点和读屏基础；图标操作有 tooltip，状态同时显示文字。320 宽应用入口切为三列，详情字段窄容器改纵排；字体随系统，表单允许键盘下滚动。

| 状态 | 行为与恢复 |
| --- | --- |
| 加载 | 进度指示，不用假零值 |
| 无数据 | 提示调整条件或新建会话 |
| 查询失败 | 错误说明与重试，保留输入 |
| 无权限 | 本地入口过滤，Repository 再检查；服务端最终鉴权 |
| 组织不可用 | 解释门禁，退出切组织 |
| 提交中 | 禁止重复操作，保留目标 |
| 结果未知 | 不自动重放；详情回查、表单转关联记录核对 |
| AI 中断/停止 | 保留部分内容，先回查历史再发送 |
| 已归档 | 只读，不展示可发送编辑器 |
| 身份变化 | 关闭普通 HTTP、停止 AI、销毁旧栈/弹窗/表单 |
| 相机失败 | 手工/粘贴/外接输入，取消不回填 |

动效使用系统页面/组件默认行为，没有额外循环或弹跳。主操作为当前状态第一个允许动作，其余用描边按钮。采购仓库信息弹窗先验证再进入执行确认。

## 真实契约来源

- `src/api/system/auth.ts`、`src/stores/user.ts`、`src/utils/request.ts`：身份/组织、响应包裹、401、权限。
- `src/api/production/`、`src/core/production/documents.ts`：生产状态、领料 query ID、报工和成品入库。
- `src/api/inventory/`、`src/api/master/warehouse.ts`、采购/销售接口及类型：字段、仓库分页和查询条件。
- 管理端 `src/api/ai/ai.ts` 和服务端 AI Controller：会话、历史、SSE、归档与待确认动作。
- 服务端 `eip/controller/NotificationController.java`、`NotificationPageDto`、`NotificationVo`：真实收件箱、已读、分页和数量。
- 设计包 HANDOFF、BUSINESS_REQUIREMENTS、design-spec 和 workspace 导出截图；其中演示内容不作为生产数据。

架构参考 [Flutter 官方架构指南](https://docs.flutter.dev/app-architecture/guide)，平台插件能力参考 [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) 与 [mobile_scanner](https://pub.dev/packages/mobile_scanner)。未复制新的第三方视觉方案，沿用本地交付稿。

## 验证记录

- 已执行：17 个 Dart 文件通过 Tree-sitter 语法解析（不等同 Dart 类型分析）；bootstrap shell 语法检查、平台配置 Python 编译检查、原生配置临时样例与重复执行检查通过。
- 已编写、未执行：数量精度、SSE UTF8/CR/LF 分片、组织门禁、迟到响应隔离、领料真实请求形状、状态变化阻断、320/390/430 门禁大字体布局测试。
- SDK：PATH 和常见目录没有 Flutter/Dart；官方/镜像索引返回404，源码下载尝试未取得完整可运行工具链。
- iOS：`xcode-select -p` 指向 `/Library/Developer/CommandLineTools`，当前不是完整 Xcode。
- 未执行：Flutter analyzer/test、两端编译、真实接口、相机/后台/键盘、截图比对与真机验收。不可记录为通过。

## 后续验收重点

两账号同 ID 不同组织、退出时进行中的请求/SSE/确认、登录401、multi 门禁、无权限、库存失败不为0；订单→领料→草稿报工→审批→完成→成品入库；采购上架、销售出库；离线/超时后回查而不重复执行；AI 历史/归档/停止/动作过期/权限变化；相机拒绝与长编码/前导零；小屏和200%字体、键盘、Android系统返回与iOS手势。
