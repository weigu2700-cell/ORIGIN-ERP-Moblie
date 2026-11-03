import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// AI 助手：默认进入新对话，历史会话通过左侧抽屉管理。
class AssistantPage extends StatefulWidget {
  final Session session;
  const AssistantPage(this.session, {super.key});
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final scaffold = GlobalKey<ScaffoldState>();
  final chat = GlobalKey<_ChatViewState>();
  final search = TextEditingController();
  int loadSequence = 0, viewSerial = 0;
  List<Json> conversations = [];
  String? activeId; // null 表示尚未创建的新对话
  String title = '新对话';
  bool loading = true, archived = false, readOnly = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    loadList();
  }

  Future<void> loadList() async {
    final ticket = ++loadSequence;
    setState(() => error = null);
    try {
      final rows = await widget.session.api.call('/ai/conversation') as List;
      if (mounted && ticket == loadSequence) {
        setState(
          () => conversations = rows.cast<Json>()
            ..sort(
              (a, b) => '${b['updateTime']}'.compareTo('${a['updateTime']}'),
            ),
        );
      }
    } catch (e) {
      if (mounted && ticket == loadSequence) setState(() => error = e);
    } finally {
      if (mounted && ticket == loadSequence) setState(() => loading = false);
    }
  }

  void select(String? id, {String? name, bool onlyArchived = false}) {
    if (chat.currentState?.busy ?? false) {
      feedback(context, '请先停止当前回答，再切换对话');
      return;
    }
    scaffold.currentState?.closeDrawer();
    setState(() {
      activeId = id;
      viewSerial++;
      title = name ?? '新对话';
      readOnly = onlyArchived;
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Widget drawer(BuildContext context) {
    final visible = conversations
        .where(
          (c) =>
              (c['status'] == 1) == archived &&
              '${c['title'] ?? ''}'.contains(search.text),
        )
        .toList();
    return Drawer(
      backgroundColor: Colors.white,
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '对话',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => select(null),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('新对话'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '搜索会话标题',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('进行中')),
                  ButtonSegment(value: true, label: Text('已归档')),
                ],
                selected: {archived},
                onSelectionChanged: (v) => setState(() => archived = v.first),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : error != null && conversations.isEmpty
                  ? StateNotice(error.toString(), retry: loadList)
                  : RefreshIndicator(
                      onRefresh: loadList,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        children: [
                          if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 48),
                              child: StateNotice('暂无会话'),
                            ),
                          for (var i = 0; i < visible.length; i++) ...[
                            if (i == 0 ||
                                dayGroup(visible[i]['updateTime']) !=
                                    dayGroup(visible[i - 1]['updateTime']))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  14,
                                  20,
                                  4,
                                ),
                                child: Text(
                                  dayGroup(visible[i]['updateTime']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTokens.muted,
                                  ),
                                ),
                              ),
                            ListTile(
                              dense: true,
                              selected: '${visible[i]['id']}' == activeId,
                              selectedTileColor: const Color(0xFFEAF0FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              leading: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                              ),
                              title: Text(
                                '${visible[i]['title'] ?? '新对话'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15),
                              ),
                              onTap: () => select(
                                '${visible[i]['id']}',
                                name: '${visible[i]['title'] ?? '新对话'}',
                                onlyArchived: visible[i]['status'] == 1,
                              ),
                            ).paddedHorizontally(8),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffold,
    drawer: drawer(context),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
      leading: IconButton(
        tooltip: '对话列表',
        icon: const Icon(Icons.menu),
        onPressed: () {
          loadList();
          scaffold.currentState?.openDrawer();
        },
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: '新对话',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => select(null),
        ),
        if (activeId != null)
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'refresh') chat.currentState?.load();
              if (value == 'archive') chat.currentState?.archive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Text('回查历史')),
              if (!readOnly)
                const PopupMenuItem(value: 'archive', child: Text('归档会话')),
            ],
          ),
      ],
    ),
    body: ChatView(
      widget.session,
      key: chat,
      // 稳定的 key：新建会话在首次发送时才创建，期间不能重建视图打断流式回答。
      id: activeId,
      serial: viewSerial,
      onCreated: (id) {
        activeId = id;
        loadList();
      },
      onTitle: (value) => setState(() => title = value),
      onArchived: () {
        setState(() => readOnly = true);
        loadList();
      },
      onActivity: loadList,
    ),
  );
}

extension on Widget {
  Widget paddedHorizontally(double value) => Padding(
    padding: EdgeInsets.symmetric(horizontal: value),
    child: this,
  );
}

String dayGroup(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '历史会话';
  final now = DateTime.now();
  final difference = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  return difference == 0
      ? '今天'
      : difference == 1
      ? '昨天'
      : '更早';
}

const _starters = ['查询库存不足的物料', '有哪些待审批的采购订单？', '生产订单的执行进度'];

class ChatView extends StatefulWidget {
  final Session session;
  final String? id;
  final int serial;
  final ValueChanged<String> onCreated, onTitle;
  final VoidCallback onArchived, onActivity;
  const ChatView(
    this.session, {
    super.key,
    required this.id,
    required this.serial,
    required this.onCreated,
    required this.onTitle,
    required this.onArchived,
    required this.onActivity,
  });
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  final input = TextEditingController(), scroll = ScrollController();
  int loadSequence = 0;
  List<Json> messages = [];
  List<Json> actions = [];
  Json conversation = {};
  String? cid;
  Object? error;
  bool loading = false, sending = false, recover = false, acting = false;
  CancelToken? streaming;
  int turn = 0;
  bool get busy => sending || acting;
  @override
  void initState() {
    super.initState();
    cid = widget.id;
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(sessionChanged);
    if (cid != null) load();
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.serial != widget.serial) reset();
  }

  /// 切换到另一个会话或新对话：取消旧流并清空状态。
  void reset() {
    turn++;
    streaming?.cancel();
    streaming = null;
    loadSequence++;
    setState(() {
      cid = widget.id;
      messages = [];
      actions = [];
      conversation = {};
      error = null;
      loading = false;
      sending = false;
      recover = false;
      acting = false;
      input.clear();
    });
    if (cid != null) load();
  }

  void sessionChanged() {
    stop();
    actions.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && sending) stop();
  }

  Future<void> load() async {
    final id = cid;
    if (id == null) return;
    final ticket = ++loadSequence;
    if (sending) return;
    setState(() {
      loading = true;
      error = null;
      actions = [];
    });
    try {
      final detail =
          await widget.session.api.call('/ai/conversation/$id') as Json;
      final history = await widget.session.api.call('/ai/message/$id') as List;
      if (mounted && ticket == loadSequence) {
        setState(() {
          conversation = detail;
          messages = history.cast<Json>();
          recover = false;
        });
        widget.onTitle('${detail['title'] ?? '新对话'}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (mounted && ticket == loadSequence) setState(() => error = e);
    } finally {
      if (mounted && ticket == loadSequence) setState(() => loading = false);
    }
  }

  void stop() {
    turn++;
    streaming?.cancel();
    streaming = null;
    if (mounted) {
      setState(() {
        if (sending) {
          recover = true;
          error = '已停止。请先回查历史，再继续发送。';
        }
        sending = false;
        actions = [];
      });
    }
  }

  Future<void> send([String? preset]) async {
    final text = (preset ?? input.text).trim();
    if (text.isEmpty || sending || recover || conversation['status'] == 1) {
      return;
    }
    final ticket = ++turn;
    final generation = widget.session.api.generation;
    final response = <String, dynamic>{'role': 'assistant', 'content': ''};
    final client = CancelToken();
    streaming = client;
    setState(() {
      sending = true;
      error = null;
      actions = [];
      messages.add({'role': 'user', 'content': text});
      messages.add(response);
      input.clear();
    });
    try {
      if (cid == null) {
        // 新对话在第一次发送时才在服务端创建，避免产生空会话。
        final created =
            await widget.session.api.call('/ai/conversation', method: 'POST')
                as Json;
        widget.session.api.check(generation);
        if (!mounted || ticket != turn) return;
        cid = '${created['conversationId']}';
        widget.onCreated(cid!);
      }
      await widget.session.api.stream(cid!, text, client, (event) {
        if (!mounted || ticket != turn) return;
        setState(() {
          switch (event['type']) {
            case 'CONTENT':
              response['content'] =
                  '${response['content']}${event['content'] ?? ''}';
            case 'TITLE':
              conversation['title'] = event['content'];
              widget.onTitle('${event['content']}');
            case 'ACTION':
              final action = jsonDecode(event['content'] as String) as Json;
              actions.add(action);
            default:
              throw const ApiFailure('未知 AI 事件，请回查历史');
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients && scroll.position.extentAfter < 180) {
            scroll.jumpTo(scroll.position.maxScrollExtent);
          }
        });
      });
      widget.session.api.check(generation);
      widget.onActivity();
    } catch (e) {
      if (mounted && ticket == turn) {
        setState(() {
          recover = cid != null;
          actions = [];
          error = cid == null ? '新对话创建失败，请重试。' : '响应中断或发送结果未知，请回查历史后继续。';
          if (cid == null) {
            messages.removeRange(messages.length - 2, messages.length);
            input.text = text;
          }
        });
      }
    } finally {
      client.cancel();
      if (mounted && ticket == turn) setState(() => sending = false);
    }
  }

  Future<void> archive() async {
    final id = cid;
    if (id == null || sending || acting) return;
    setState(() => acting = true);
    final ticket = widget.session.api.generation;
    try {
      if (!await confirm(context, '归档会话', '归档后此会话只读，新问题请新建对话。') || !mounted) {
        return;
      }
      widget.session.api.check(ticket);
      await widget.session.api.call(
        '/ai/conversation/$id/archive',
        method: 'PUT',
      );
      if (mounted) {
        await load();
        widget.onArchived();
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> execute(Json action) async {
    if (acting || sending || recover) return;
    setState(() => acting = true);
    final ticket = widget.session.api.generation;
    try {
      if (action['actionType'] != 'APPROVE_PURCHASE_ORDER' ||
          !widget.session.can('purchase:order:approve')) {
        throw const ApiFailure('不支持此动作或没有采购审核权限');
      }
      final expires = DateTime.tryParse('${action['expireTime']}');
      if (expires == null || !expires.isAfter(DateTime.now())) {
        throw const ApiFailure('提案已过期，请重新查询');
      }
      if (!await confirm(
            context,
            '${action['title']}',
            '单据 ${action['bizNo']}\n${action['description']}',
          ) ||
          !mounted) {
        return;
      }
      widget.session.api.check(ticket);
      if (!widget.session.can('purchase:order:approve')) {
        throw const ApiFailure('权限已变化');
      }
      await widget.session.api.call(
        '/ai/action/${Uri.encodeComponent(action['token'].toString())}/execute',
        method: 'POST',
      );
      if (mounted) {
        setState(() => actions.remove(action));
        feedback(context, '操作已执行，请核对业务单据');
      }
    } catch (e) {
      if (mounted) {
        setState(() => actions.remove(action));
        feedback(context, e);
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  void dispose() {
    turn++;
    streaming?.cancel();
    widget.session.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Widget message(Json m) {
    final mine = m['role'] == 'user';
    final text = '${m['content']}';
    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppTokens.brand),
              const SizedBox(width: 6),
              const Text(
                '原点助手',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (text.isEmpty && sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            )
          else
            MarkdownBody(data: text, selectable: true),
          if (text.isNotEmpty)
            IconButton(
              tooltip: '复制回答',
              visualDensity: VisualDensity.compact,
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          MaterialBanner(
            content: Text(error.toString()),
            actions: [
              if (cid != null)
                TextButton(
                  onPressed: sending ? null : load,
                  child: const Text('回查历史'),
                ),
            ],
          ),
        Expanded(
          child: messages.isEmpty && !loading
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 36,
                          color: AppTokens.brand,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '有什么可以帮你？',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '查询当前组织的库存与单据，辅助处理待办',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTokens.muted),
                        ),
                        const SizedBox(height: 20),
                        for (final text in _starters)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ActionChip(
                              label: Text(text),
                              onPressed: sending || recover
                                  ? null
                                  : () => send(text),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    for (final m in messages) message(m),
                    for (final action in actions)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${action['title']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '单据 ${action['bizNo']}\n${action['description']}',
                              ),
                              Text('有效期：${action['expireTime']}'),
                              TextButton(
                                onPressed: acting || sending || recover
                                    ? null
                                    : () => execute(action),
                                child: const Text('核对并确认'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (conversation['status'] == 1)
          const Padding(padding: EdgeInsets.all(20), child: Text('此会话已归档，只可阅读'))
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !loading && !recover && !acting,
                    decoration: const InputDecoration(hintText: '输入业务问题…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: sending ? '停止生成' : '发送',
                  onPressed: sending
                      ? stop
                      : loading || recover || acting
                      ? null
                      : () => send(),
                  icon: Icon(sending ? Icons.stop : Icons.arrow_upward),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
