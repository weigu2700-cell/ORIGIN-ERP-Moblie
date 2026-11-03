# 原点智造移动工作空间 · V1 设计交付

2026-11-03。用于评审与新对话交接，**尚未获用户确认，不是正式 App**。

产品定位：面向生产与仓储人员的轻量移动工作台，统一应用、业务通知、生产作业和 AI 助手。参考飞书的工作空间组织方式与成熟仓储/ERP 的任务执行流程，避免把桌面管理系统缩小到手机。

## 阅读顺序

1. [新对话交接](HANDOFF.md)：已确认事项、当前状态、下一步及工作区保护事项。
2. [业务需求](BUSINESS_REQUIREMENTS.md)：角色、范围、业务流程、接口边界与验收标准。
3. [设计说明](design-spec.md)：参考依据、导航、视觉规范、交互和待评审问题。
4. [交互设计稿](index.html)：15 个页面，支持尺寸、字体和部分状态切换。

## 查看设计

直接用浏览器打开 `index.html` 即可；无需安装依赖。也可在本目录启动静态服务：

```sh
python3 -m http.server 6190 --bind 127.0.0.1
```

打开 `http://127.0.0.1:6190/#messages` 查看修正后的消息列表，`#workspace` 查看工作台。电脑端左栏切换页面，右栏查看说明与状态，顶部支持 320/390/430 三种尺寸。

六组静态展板位于 `exports/`：

| 文件 | 内容 |
| --- | --- |
| [board-workspace.png](exports/board-workspace.png) | 工作台、消息列表、全部应用 |
| [board-production.png](exports/board-production.png) | 生产任务、订单详情、报工表单 |
| [board-operations.png](exports/board-operations.png) | 库存、领料核对、成品入库 |
| [board-ai.png](exports/board-ai.png) | AI 会话列表、对话详情、我的 |
| [board-focus.png](exports/board-focus.png) | 工作台与生产订单双页概览 |
| [board-login.png](exports/board-login.png) | 登录与账户组织集成 |

`exports/` 另含 15 张单页 PNG，以及 320 宽、1.5 倍字体的消息页。图片展示首屏，完整页面请在原型内滚动。

## 演示边界

所有组织、人员、单据、数量、日期和角标都是样例。没有连接业务服务、数据库、摄像头或模型。原型按钮部分用于展示确认弹窗和流程语义，不能据此判断接口已实现。搜索/筛选、消息已读、归档、真实审批与设备适配仍需正式开发；具体见交接与需求文档。

本轮只修改设计与说明文件，没有继续 uni-app 功能开发或创建 Flutter 工程，没有提交或推送这些设计草稿。
