import 'chat.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String clock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

int _dayDiff(DateTime d, DateTime now) => DateTime(
  now.year,
  now.month,
  now.day,
).difference(DateTime(d.year, d.month, d.day)).inDays;

/// 会话列表时间：今天显示时分，昨天、同年日期、跨年完整日期。
String listTime(DateTime d, [DateTime? now]) {
  now ??= DateTime.now();
  final diff = _dayDiff(d, now);
  if (diff == 0) return clock(d);
  if (diff == 1) return '昨天';
  return d.year == now.year
      ? '${d.month}月${d.day}日'
      : '${d.year}/${d.month}/${d.day}';
}

/// 聊天区日期分隔标签。
String dayLabel(DateTime d, [DateTime? now]) {
  now ??= DateTime.now();
  final diff = _dayDiff(d, now);
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  const week = '一二三四五六日';
  return d.year == now.year
      ? '${d.month}月${d.day}日 周${week[d.weekday - 1]}'
      : '${d.year}年${d.month}月${d.day}日';
}

String fmtBytes(int n) => n >= 1000000
    ? '${(n / 1000000).toStringAsFixed(1)} MB'
    : n >= 1000
    ? '${(n / 1000).round()} KB'
    : '$n B';

/// 会话预览：群聊带发送者；图片、文件有占位。
String previewOf(ChatMessage? m, String Function(String?) nameOf, bool group) {
  if (m == null) return '暂无消息';
  final body = switch (m.type) {
    'TEXT' => m.text ?? '',
    'IMAGE' => '[图片]',
    'FILE' => '[文件] ${m.file?.name ?? ''}',
    _ => m.systemText ?? '',
  };
  return group && !m.isSystem && m.senderId != null
      ? '${nameOf(m.senderId)}：$body'
      : body;
}

/// 时间线行：日期分隔、未读分割线、消息。
sealed class ChatRow {}

class DayRow extends ChatRow {
  final String label;
  DayRow(this.label);
}

class UnreadRow extends ChatRow {}

class MessageRow extends ChatRow {
  final ChatMessage message;
  MessageRow(this.message);
}

List<ChatRow> buildRows(
  List<ChatMessage> items,
  String? unreadFromSeq, [
  DateTime? now,
]) {
  final rows = <ChatRow>[];
  var prev = '';
  var marked = false;
  for (final m in items) {
    final label = dayLabel(m.createdAt, now);
    if (label != prev) {
      rows.add(DayRow(label));
      prev = label;
    }
    if (!marked &&
        unreadFromSeq != null &&
        m.local == null &&
        cmpSeq(m.seq!, unreadFromSeq) >= 0) {
      rows.add(UnreadRow());
      marked = true;
    }
    rows.add(MessageRow(m));
  }
  return rows;
}
