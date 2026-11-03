# 当前 Flutter 界面展示

更新日期：2026-11-03。基于当前移动端代码生成，替代仓库首页曾引用的旧 V1 HTML 原型展板。

这些图片是**当前 Flutter 页面渲染结果的展示排版**。界面内容来自应用组件，业务数据来自 `flutter/test/support/fakes.dart`；没有连接生产服务，也没有添加应用尚不存在的入口。手机外围的标题、分组、阴影与说明属于 README 展板排版，不属于应用界面。

## 展板

所有展板均为 1800 × 1360 PNG，可直接在 GitHub README 中使用。

| 文件 | 内容 |
| --- | --- |
| [overview.png](overview.png) | 首页总览：工作台、生产订单、AI 对话 |
| [workspace.png](workspace.png) | 工作台、业务通知、全部应用 |
| [production.png](production.png) | 生产订单列表、订单详情、登记报工 |
| [inventory.png](inventory.png) | 扫一扫、库存查询、库存详情 |
| [assistant.png](assistant.png) | AI 助手入口、历史会话抽屉、业务对话 |
| [account.png](account.png) | 组织登录、账户资料、消息入口 |

[单页高清图](screens/)覆盖15个页面，尺寸为780 × 1688（390 × 844逻辑像素的2倍渲染）。扫码页的相机通道由测试桩提供，图中的扫码取景区域不是实际相机画面。

## 重新生成

从 `flutter/` 目录运行：

```bash
./tool/flutterw test --no-pub tool/preview_test.dart --reporter expanded
```

页面顺序与采集脚本位于 `flutter/tool/preview_test.dart`，展板尺寸、文案和排版位于 `flutter/tool/readme_boards.dart`。生成器使用 Flutter 自身的 Canvas 排版，无需再安装图像处理库。

默认从 macOS 读取中文黑体；其他机器通过 `PREVIEW_FONT=/绝对路径/中文字体.ttf` 指定字体。字体仅在本机加载，不随仓库分发。预览为标题样式补入中文字体，避免 Flutter 测试默认字体生成方框；生产应用默认主题不受影响。

生成后会同时更新本目录的展板和 `screens/` 下的单页图；临时图片仍保留在 `flutter/output/preview/`。每次页面变更后重新生成并检查图片，避免展示图与代码漂移。

## 本次检查

- 当前页面逐个渲染并导出成功。
- 已检查六张展板的标题、中文字体、边距、画面完整性和演示数据标记。
- README 引用使用仓库相对路径，图片存于可提交的 `docs/`，不依赖被忽略的 `flutter/output/`。
- 这是展示图检查，不代替业务接口联调、真机相机、键盘和 iOS 系统行为验收。
