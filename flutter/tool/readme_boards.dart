// 用真实 Flutter 页面截图排版展板，界面内容不重绘、不增加未实现功能。
import 'dart:io';
import 'dart:ui' as ui;

class BoardSpec {
  final String file, eyebrow, title, description;
  final List<(String, String, String)> screens;
  const BoardSpec(
    this.file,
    this.eyebrow,
    this.title,
    this.description,
    this.screens,
  );
}

const boards = [
  BoardSpec(
    'overview',
    'ORIGIN ERP / MOBILE',
    '制造业务，随手协同',
    '从现场作业到业务查询，让订单、库存与进度连在一起。',
    [
      ('workspace', '工作台', '常用应用 · 待处理业务 · 生产进度'),
      ('order-detail', '生产订单', '核对单据 · 查看进度 · 登记报工'),
      ('assistant-chat', 'AI 助手', '自然语言查询 · Markdown 回答'),
    ],
  ),
  BoardSpec(
    'workspace',
    '01 / WORKSPACE',
    '一个入口，连接每天的工作',
    '应用、业务通知与账户信息，按当前账号权限呈现。',
    [
      ('workspace', '工作台', '分组卡片聚合常用应用与业务进度'),
      ('messages-system', '业务通知', '通知与单据关联，阅读与处理分开'),
      ('apps', '全部应用', '按作业场景分组，支持名称搜索'),
    ],
  ),
  BoardSpec(
    'production',
    '02 / PRODUCTION',
    '从订单到报工，过程清楚可核对',
    '查看生产进度，在订单下登记本次合格量与报废量。',
    [
      ('orders', '生产订单列表', '识别状态与物料，找到当前任务'),
      ('order-detail', '订单详情', '完成进度、状态和关联作业集中呈现'),
      ('report-form', '登记报工', '数量就地校验，保存为报工草稿'),
    ],
  ),
  BoardSpec(
    'inventory',
    '03 / INVENTORY',
    '扫码找物料，库存一目了然',
    '识别只是查询入口；核对物料、仓库与数量后，再办理业务。',
    [
      ('scan', '扫一扫', '相机扫码与手工输入共用一个入口'),
      ('inventory', '库存查询', '物料与仓库筛选，核对可用数量'),
      ('inventory-detail', '库存详情', '在库、预留、可用数量分别展示'),
    ],
  ),
  BoardSpec(
    'assistant',
    '04 / AI ASSISTANT',
    '把问题交给助手，把决定留给人',
    '新建问题、查找历史会话，用自然语言理解当前业务。',
    [
      ('assistant', 'AI 助手入口', '从常用问题开始业务查询'),
      ('assistant-drawer', '历史会话', '在抽屉中查找、切换已有会话'),
      ('assistant-chat', '业务对话', '连续阅读回答，支持复制与继续提问'),
    ],
  ),
  BoardSpec(
    'messaging',
    '06 / MESSAGING',
    '同事沟通，也在同一个 App 里',
    '会话列表、单聊群聊、通讯录与群管理，与业务通知并列在消息页。',
    [
      ('messages', '消息', '系统通知置顶，其后是单聊与群聊'),
      ('chat-group', '群聊', '文字、文件、已读与系统提示'),
      ('chat-info', '群信息', '成员、管理员与群设置'),
    ],
  ),
  BoardSpec('account', '05 / ACCOUNT', '带着组织身份进入工作空间', '组织、账号与权限共用同一条会话边界。', [
    ('login', '组织登录', '组织、账号、密码组成连续表单'),
    ('me', '我的', '账户资料、组织与角色信息'),
    ('messages', '消息入口', '先识别通知类型，再进入具体内容'),
  ]),
];

Future<void> renderReadmeBoards({bool ios = false}) async {
  // README 的主版本使用跨平台截图；iOS 预览保留在独立输出目录。
  if (ios) return;
  final directory = Directory('../docs/design/flutter-current');
  await directory.create(recursive: true);
  final screens = Directory('${directory.path}/screens');
  await screens.create(recursive: true);
  for (final source in Directory(
    'output/preview',
  ).listSync().whereType<File>()) {
    if (source.path.endsWith('.png')) {
      await source.copy('${screens.path}/${source.uri.pathSegments.last}');
    }
  }
  for (final spec in boards) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const width = 1800, height = 1360;
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1800, 1360),
      ui.Paint()..color = const ui.Color(0xFFF0F3F8),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1800, 8),
      ui.Paint()..color = const ui.Color(0xFF2C60E8),
    );
    text(
      canvas,
      spec.eyebrow,
      100,
      52,
      19,
      const ui.Color(0xFF2C60E8),
      width: 1400,
      bold: true,
    );
    text(
      canvas,
      spec.title,
      100,
      88,
      48,
      const ui.Color(0xFF1C2536),
      width: 1500,
      bold: true,
    );
    text(
      canvas,
      spec.description,
      102,
      153,
      22,
      const ui.Color(0xFF536279),
      width: 1520,
    );
    for (var i = 0; i < spec.screens.length; i++) {
      final (file, label, caption) = spec.screens[i];
      final codec = await ui.instantiateImageCodec(
        await File('output/preview/$file.png').readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      final x = 150.0 + i * 530;
      const y = 246.0, phoneWidth = 440.0;
      final phoneHeight = phoneWidth * image.height / image.width;
      text(
        canvas,
        '0${i + 1}  /  $label',
        x,
        207,
        19,
        const ui.Color(0xFF536279),
        width: 450,
        bold: true,
      );
      final frame = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(x - 8, y - 8, phoneWidth + 16, phoneHeight + 16),
        const ui.Radius.circular(28),
      );
      canvas.drawShadow(
        ui.Path()..addRRect(frame),
        const ui.Color(0xFFCCD3E2),
        13,
        false,
      );
      canvas.drawRRect(frame, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      canvas.save();
      canvas.clipRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, y, phoneWidth, phoneHeight),
          const ui.Radius.circular(20),
        ),
      );
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(x, y, phoneWidth, phoneHeight),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();
      text(
        canvas,
        caption,
        x,
        y + phoneHeight + 30,
        19,
        const ui.Color(0xFF536279),
        width: 465,
      );
      image.dispose();
      codec.dispose();
    }
    canvas.drawLine(
      const ui.Offset(100, 1298),
      const ui.Offset(1700, 1298),
      ui.Paint()..color = const ui.Color(0xFFD9DFEA),
    );
    text(
      canvas,
      '原点智造  /  FLUTTER',
      100,
      1320,
      16,
      const ui.Color(0xFF536279),
      width: 700,
      bold: true,
    );
    text(
      canvas,
      '当前代码渲染 · 演示数据 · 2026.11.03',
      1180,
      1320,
      16,
      const ui.Color(0xFF536279),
      width: 520,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width, height);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/${spec.file}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    rendered.dispose();
    picture.dispose();
  }
}

void text(
  ui.Canvas canvas,
  String value,
  double x,
  double y,
  double size,
  ui.Color color, {
  required double width,
  bool bold = false,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'ReadmeFont',
            fontSize: size,
            fontWeight: bold ? ui.FontWeight.w600 : ui.FontWeight.w400,
            height: 1.25,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(value);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(paragraph, ui.Offset(x, y));
  paragraph.dispose();
}
