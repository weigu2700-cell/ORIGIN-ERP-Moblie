import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../domain/notification_targets.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'workspace.dart' show appColor, appIcon;

const _notificationBlue = AppTokens.brand;

/// 消息 Tab：会话列表。目前只有一个「系统通知」会话，后续可在此追加其他会话。
class MessagesPage extends StatefulWidget {
  final Session session;
  const MessagesPage(this.session, {super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  Json? latest;
  int unread = 0, sequence = 0;
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++sequence;
    setState(() => error = null);
    try {
      final page =
          await widget.session.api.call(
                '/sys/notification',
                query: {'pageNum': 1, 'pageSize': 1},
              )
              as Json;
      final count = await widget.session.api.call(
        '/sys/notification/unread/count',
      );
      if (!mounted || ticket != sequence) return;
      final rows = (page['records'] as List).cast<Json>();
      setState(() {
        latest = rows.isEmpty ? null : rows.first;
        unread = asInt(count);
      });
    } catch (e) {
      if (mounted && ticket == sequence) setState(() => error = e);
    } finally {
      if (mounted && ticket == sequence) setState(() => loading = false);
    }
  }

  Future<void> openSystem() async {
    await context.push('/messages/system');
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: organizationBar(context, widget.session),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('消息', style: Theme.of(context).textTheme.titleLarge),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (error != null && latest == null)
            StateNotice(error.toString(), retry: load)
          else
            Container(
              color: Colors.white,
              child: _ConversationTile(
                title: '系统通知',
                preview: latest == null
                    ? '暂无通知'
                    : '${latest!['title'] ?? ''}：${latest!['content'] ?? ''}',
                time: latest == null
                    ? ''
                    : notificationTime(context, latest!['createTime']),
                unread: unread,
                onTap: openSystem,
              ),
            ),
        ],
      ),
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  final String title, preview, time;
  final int unread;
  final VoidCallback onTap;
  const _ConversationTile({
    required this.title,
    required this.preview,
    required this.time,
    required this.unread,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title，${unread > 0 ? '$unread 条未读，' : ''}$preview',
    button: true,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: const Color(0xFFE5484D),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3C7C9C), AppTokens.brandDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 「系统通知」会话：通知按时间自下而上排列，最新在底部。
class SystemNotificationsPage extends StatefulWidget {
  final Session session;
  const SystemNotificationsPage(this.session, {super.key});
  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  List<Json> rows = []; // 最新在前，配合 reverse 列表显示为最新在底部
  int page = 0, total = 0, unread = 0, sequence = 0;
  bool loading = true, more = false, busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    if (append && more) return;
    final ticket = ++sequence;
    final next = append ? page + 1 : 1;
    setState(() {
      if (append) more = true;
      error = null;
    });
    try {
      final data =
          await widget.session.api.call(
                '/sys/notification',
                query: {'pageNum': next, 'pageSize': 20},
              )
              as Json;
      final count = await widget.session.api.call(
        '/sys/notification/unread/count',
      );
      if (!mounted || ticket != sequence) return;
      final items = (data['records'] as List).cast<Json>();
      setState(() {
        rows = append ? [...rows, ...items] : items;
        page = next;
        total = asInt(data['total']);
        unread = asInt(count);
      });
    } catch (e) {
      if (mounted && ticket == sequence) setState(() => error = e);
    } finally {
      if (mounted && ticket == sequence) {
        setState(() {
          loading = false;
          more = false;
        });
      }
    }
  }

  Future<void> read(Json item) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final detail =
          await widget.session.api.call('/sys/notification/${item['id']}')
              as Json;
      if (detail['isRead'] != true) {
        await widget.session.api.call(
          '/sys/notification/${item['id']}/readed',
          method: 'PUT',
        );
        if (mounted && item['isRead'] != true) {
          setState(() {
            item['isRead'] = true;
            if (unread > 0) unread--;
          });
        }
      }
      if (!mounted) return;
      final target = notificationTarget(detail['businessType']?.toString());
      final open = await showAdaptiveDialog<bool>(
        context: context,
        builder: (c) => AlertDialog.adaptive(
          title: Text('${detail['title']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${detail['content'] ?? ''}'),
                if (detail['businessNo'] != null)
                  Text('\n业务单据：${detail['businessNo']}'),
                const SizedBox(height: 16),
                const Text('阅读通知不会执行审批或改变业务状态。请到对应业务列表核对单据。'),
              ],
            ),
          ),
          actions: [
            adaptiveAction(c, '关闭', () => Navigator.pop(c)),
            if (target != null && detail['businessId'] != null)
              adaptiveAction(
                c,
                '查看业务单据',
                () => Navigator.pop(c, true),
                primary: true,
              ),
          ],
        ),
      );
      if (open == true && mounted && target != null) {
        await context.push('/workspace/${target.key}/${detail['businessId']}');
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> allRead() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.session.api.call(
        '/sys/notification/all/readed',
        method: 'PUT',
      );
      if (mounted) {
        setState(() {
          for (final row in rows) {
            row['isRead'] = true;
          }
          unread = 0;
        });
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('系统通知'),
      actions: [
        TextButton(
          onPressed: busy || unread == 0 ? null : allRead,
          child: const Text('全部已读'),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator.adaptive())
        : error != null && rows.isEmpty
        ? StateNotice(error.toString(), retry: load)
        : rows.isEmpty
        ? const StateNotice('暂无通知')
        : ListView(
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _NotificationBubble(
                  rows[i],
                  onTap: busy ? null : () => read(rows[i]),
                ),
                if (i == rows.length - 1 ||
                    dayLabel(rows[i]['createTime']) !=
                        dayLabel(rows[i + 1]['createTime']))
                  _DayDivider(dayLabel(rows[i]['createTime'])),
              ],
              if (rows.length < total)
                Center(
                  child: TextButton(
                    onPressed: more ? null : () => load(append: true),
                    child: Text(more ? '加载中…' : '查看更早的通知'),
                  ),
                ),
            ],
          ),
  );
}

class _DayDivider extends StatelessWidget {
  final String label;
  const _DayDivider(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD9E3E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTokens.muted),
        ),
      ),
    ),
  );
}

class _NotificationBubble extends StatelessWidget {
  final Json item;
  final VoidCallback? onTap;
  const _NotificationBubble(this.item, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    final target = notificationTarget(item['businessType']?.toString());
    final color = target == null ? _notificationBlue : appColor(target.key);
    final read = item['isRead'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              target == null ? Icons.notifications_none : appIcon(target.key),
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${item['title']}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: read
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!read) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE5484D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['content'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Color(0xFF3A465A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (target != null) ...[
                              StatusTag(target.title, color: color),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _clock(context, item['createTime']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(BuildContext context, dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '';
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true);
}

String dayLabel(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return '今天';
  if (days == 1) return '昨天';
  final week = '一二三四五六日'[date.weekday - 1];
  return date.year == now.year
      ? '${date.month}月${date.day}日 周$week'
      : '${date.year}年${date.month}月${date.day}日';
}

String notificationTime(BuildContext context, dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return _clock(context, value);
  if (days == 1) return '昨天';
  return date.year == now.year
      ? '${date.month}/${date.day}'
      : '${date.year}/${date.month}/${date.day}';
}
