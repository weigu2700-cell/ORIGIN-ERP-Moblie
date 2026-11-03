import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/data/chat/chat_socket.dart';
import 'package:origin_mobile/data/chat/chat_store.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/chat_format.dart';
import 'package:origin_mobile/domain/notification_targets.dart';
import 'package:origin_mobile/ui/cards.dart';
import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/features/messages/chat_widgets.dart';
import 'package:origin_mobile/ui/theme.dart';
import 'package:origin_mobile/features/workspace/workspace.dart'
    show appColor, appIcon;
import 'package:origin_mobile/data/notification_repository.dart';

const _notificationBlue = AppTokens.brand;

/// 消息 Tab：会话列表。「系统通知」固定置顶，其后是员工单聊与群聊；通讯录在此页内。
class MessagesPage extends StatefulWidget {
  final Session session;
  final ChatStore chat;
  const MessagesPage(this.session, this.chat, {super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final notifications = NotificationRepository(widget.session);
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
      final page = await notifications.page(1, 1);
      final count = await notifications.unreadCount();
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

  void startMenu() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTokens.brand),
            title: const Text('发起单聊'),
            subtitle: const Text('与同组织的一位员工'),
            onTap: () {
              Navigator.pop(c);
              context.push('/messages/new?mode=direct');
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined, color: AppTokens.brand),
            title: const Text('创建群聊'),
            subtitle: const Text('3～200 人'),
            onTap: () {
              Navigator.pop(c);
              context.push('/messages/new?mode=group');
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: organizationBar(context, widget.session),
    body: ListenableBuilder(
      listenable: widget.chat,
      builder: (context, _) {
        final chat = widget.chat;
        return RefreshIndicator(
          onRefresh: () async {
            await load();
            if (chat.ready) await chat.sync();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '消息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '通讯录',
                      onPressed: chat.ready
                          ? () => context.push('/messages/contacts')
                          : null,
                      icon: const Icon(Icons.contacts_outlined),
                    ),
                    IconButton.filled(
                      tooltip: '发起聊天',
                      onPressed: chat.ready ? startMenu : null,
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              if (chat.connection == ChatConnection.offline ||
                  chat.connection == ChatConnection.reconnecting)
                Container(
                  color: chat.connection == ChatConnection.offline
                      ? const Color(0xFFF7DCDC)
                      : const Color(0xFFFBF0D9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Text(
                    chat.connection == ChatConnection.offline
                        ? '网络已断开，恢复后自动补拉'
                        : '正在重新连接…',
                    style: const TextStyle(fontSize: 12.5),
                  ),
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
                  child: Column(
                    children: [
                      _ConversationTile(
                        leading: const ChatAvatar(system: true, size: 52),
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
                      for (final c in chat.list)
                        _ConversationTile(
                          leading: ChatAvatar(
                            name: c.name,
                            userId: c.peerUserId ?? '',
                            group: c.isGroup,
                            dissolved: c.dissolved,
                            size: 52,
                          ),
                          title: c.name,
                          tag: c.dissolved ? '已解散' : null,
                          preview: previewOf(
                            c.lastMessage,
                            chat.nameOf,
                            c.isGroup,
                          ),
                          time: listTime(c.activity),
                          unread: c.unreadCount,
                          muted: c.muted,
                          onTap: () => context.push('/messages/chat/${c.id}'),
                        ),
                    ],
                  ),
                ),
              if (chat.disabledReason != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    chat.disabledReason!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTokens.muted,
                      fontSize: 13,
                    ),
                  ),
                )
              else if (chat.ready && chat.list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '还没有聊天，点右上角 + 发起单聊或创建群聊',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTokens.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  final Widget leading;
  final String title, preview, time;
  final String? tag;
  final int unread;
  final bool muted;
  final VoidCallback onTap;
  const _ConversationTile({
    required this.leading,
    required this.title,
    required this.preview,
    required this.time,
    required this.unread,
    required this.onTap,
    this.tag,
    this.muted = false,
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
              isLabelVisible: unread > 0 && !muted,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: const Color(0xFFE5484D),
              child: leading,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (tag != null) ...[
                              const SizedBox(width: 6),
                              StatusPill(tag!, tone: Tone.neutral),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTokens.muted,
                          ),
                        ),
                      ),
                      if (muted) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 15,
                          color: Color(0xFF9AA8B0),
                        ),
                        if (unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB7C3CA),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
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
  late final notifications = NotificationRepository(widget.session);
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
      final data = await notifications.page(next, 20);
      final count = await notifications.unreadCount();
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
      final detail = await notifications.detail(item['id']);
      if (detail['isRead'] != true) {
        await notifications.markRead(item['id']);
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
      await notifications.markAllRead();
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
