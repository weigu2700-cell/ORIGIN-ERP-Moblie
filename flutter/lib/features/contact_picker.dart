import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/chat_store.dart';
import '../domain/chat.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'chat_widgets.dart';

enum PickMode { direct, group, add }

/// 选择同事：单聊（点击即进入）、建群（多选 + 群名称）、添加成员。
class ContactPickerPage extends StatefulWidget {
  final ChatStore chat;
  final PickMode mode;
  final String? conversationId, preselect;
  const ContactPickerPage(
    this.chat,
    this.mode, {
    super.key,
    this.conversationId,
    this.preselect,
  });
  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  final search = TextEditingController();
  List<Contact> people = [];
  final selected = <String>[];
  bool loading = true, busy = false, naming = false;
  final name = TextEditingController();
  ChatStore get chat => widget.chat;
  bool get adding => widget.mode == PickMode.add;
  bool get multi => widget.mode != PickMode.direct;
  Set<String> get existing => {
    for (final m
        in chat.members[widget.conversationId] ?? const <GroupMember>[])
      m.userId,
  };
  int get need => adding ? 1 : 2;
  int get limit => adding ? 50 : (chat.config?.maxGroupMembers ?? 200) - 1;

  @override
  void initState() {
    super.initState();
    if (widget.preselect != null) selected.add(widget.preselect!);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      people = await chat.api.contacts(keyword: search.text.trim());
      for (final c in people) {
        chat.contactCache[c.userId] = c;
      }
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> tap(Contact c) async {
    if (adding && existing.contains(c.userId)) return;
    if (!multi) {
      setState(() => busy = true);
      try {
        final id = await chat.startDirect(c.userId);
        if (mounted) context.go('/messages/chat/$id');
      } catch (e) {
        if (mounted) feedback(context, chatErrorText(e));
      } finally {
        if (mounted) setState(() => busy = false);
      }
      return;
    }
    setState(() {
      if (selected.contains(c.userId)) {
        selected.remove(c.userId);
      } else if (selected.length < limit) {
        selected.add(c.userId);
      } else {
        feedback(context, '最多选择 $limit 人');
      }
    });
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (adding) {
        await chat.addMembers(widget.conversationId!, selected);
        if (mounted) {
          feedback(context, '已添加成员');
          context.pop();
        }
      } else {
        final id = await chat.createGroup(name.text.trim(), selected);
        if (mounted) {
          feedback(context, '群聊已创建');
          context.go('/messages/chat/$id');
        }
      }
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (naming) return nameStep();
    final depts = <String, List<Contact>>{};
    for (final p in people) {
      (depts[p.departmentName ?? '未分配部门'] ??= []).add(p);
    }
    final title = adding
        ? '添加成员'
        : widget.mode == PickMode.direct
        ? '发起单聊'
        : '创建群聊';
    final ready = selected.length >= need && selected.length <= limit;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(title),
            if (multi)
              Text(
                '已选 ${selected.length} 人${adding ? '' : ' · 至少选 2 人'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTokens.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (multi)
            TextButton(
              onPressed: !ready || busy
                  ? null
                  : (adding ? submit : () => setState(() => naming = true)),
              child: Text(adding ? '添加' : '下一步'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索姓名或部门',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onSubmitted: (_) => load(),
            ),
          ),
          if (multi && selected.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final id in selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(chat.nameOf(id)),
                        onDeleted: () => setState(() => selected.remove(id)),
                      ),
                    ),
                ],
              ),
            ),
          if (!adding && selected.length == 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                '再选 1 人即可创建群聊；仅 2 人请使用单聊',
                style: TextStyle(fontSize: 12, color: Color(0xFFD98A1B)),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : people.isEmpty
                ? const StateNotice('没有匹配的同事')
                : ListView(
                    children: [
                      for (final entry in depts.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTokens.muted,
                            ),
                          ),
                        ),
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              for (final p in entry.value)
                                ListTile(
                                  enabled:
                                      !(adding && existing.contains(p.userId)),
                                  leading: ChatAvatar(
                                    name: p.displayName,
                                    userId: p.userId,
                                    size: 40,
                                  ),
                                  title: Text(p.displayName),
                                  subtitle: Text(
                                    adding && existing.contains(p.userId)
                                        ? '已在群中'
                                        : (p.departmentName ?? ''),
                                  ),
                                  trailing: !multi
                                      ? const Icon(
                                          Icons.chevron_right,
                                          color: AppTokens.muted,
                                        )
                                      : Icon(
                                          selected.contains(p.userId)
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: selected.contains(p.userId)
                                              ? AppTokens.brand
                                              : const Color(0xFFB7C3CA),
                                        ),
                                  onTap: busy ? null : () => tap(p),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget nameStep() => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => setState(() => naming = false)),
      title: const Text('群聊信息'),
      actions: [
        ListenableBuilder(
          listenable: name,
          builder: (_, _) => TextButton(
            onPressed: name.text.trim().isEmpty || busy ? null : submit,
            child: const Text('创建'),
          ),
        ),
      ],
    ),
    body: ListView(
      children: [
        const SizedBox(height: 18),
        const Center(child: ChatAvatar(group: true, size: 76)),
        const SizedBox(height: 18),
        GroupCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: name,
              maxLength: 64,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '群名称',
                hintText: '例如：装配一组（1～64 字）',
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            '成员（${selected.length + 1}/${chat.config?.maxGroupMembers ?? 200}）',
            style: const TextStyle(fontSize: 12, color: AppTokens.muted),
          ),
        ),
        GroupCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final id in [chat.myId, ...selected])
                  SizedBox(
                    width: 62,
                    child: Column(
                      children: [
                        ChatAvatar(
                          name: chat.nameOf(id) == '我' ? '我' : chat.nameOf(id),
                          userId: id,
                          size: 46,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          id == chat.myId ? '我（群主）' : chat.nameOf(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Text(
            '你将成为群主。新成员只能看到加入之后的消息。',
            style: TextStyle(fontSize: 12, color: AppTokens.muted),
          ),
        ),
      ],
    ),
  );
}

/// 通讯录：按部门分组，点击进入单聊。
class ContactsPage extends StatefulWidget {
  final ChatStore chat;
  const ContactsPage(this.chat, {super.key});
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final search = TextEditingController();
  List<Contact> people = [];
  bool loading = true;
  ChatStore get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      people = await chat.api.contacts(keyword: search.text.trim());
      for (final c in people) {
        chat.contactCache[c.userId] = c;
      }
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depts = <String, List<Contact>>{};
    for (final p in people) {
      (depts[p.departmentName ?? '未分配部门'] ??= []).add(p);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('通讯录')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索姓名或部门',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onSubmitted: (_) => load(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : people.isEmpty
                ? const StateNotice('没有匹配的同事')
                : ListView(
                    children: [
                      for (final entry in depts.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTokens.muted,
                            ),
                          ),
                        ),
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              for (final p in entry.value)
                                ListTile(
                                  leading: ChatAvatar(
                                    name: p.displayName,
                                    userId: p.userId,
                                    size: 40,
                                  ),
                                  title: Text(p.displayName),
                                  subtitle: Text(p.departmentName ?? ''),
                                  trailing: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: AppTokens.brand,
                                  ),
                                  onTap: () async {
                                    try {
                                      final id = await chat.startDirect(
                                        p.userId,
                                      );
                                      if (context.mounted)
                                        context.go('/messages/chat/$id');
                                    } catch (e) {
                                      if (context.mounted)
                                        feedback(context, chatErrorText(e));
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
