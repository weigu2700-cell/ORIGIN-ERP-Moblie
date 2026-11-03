import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/chat_store.dart';
import '../domain/chat.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'chat_widgets.dart';

/// 群信息 / 单聊信息：成员、群名、静音、退出与解散；群主与管理员可管理成员。
class ChatInfoPage extends StatefulWidget {
  final ChatStore chat;
  final String id;
  const ChatInfoPage(this.chat, this.id, {super.key});
  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  ChatStore get chat => widget.chat;
  Conversation? get conv => chat.conversations[widget.id];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    chat.addListener(refresh);
    if (conv?.isGroup ?? false) {
      chat.loadMembers(widget.id).catchError((_) {});
    }
  }

  void refresh() {
    if (!mounted) return;
    if (conv == null && context.canPop()) {
      // 退出或被移出：回到列表。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/messages');
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    chat.removeListener(refresh);
    super.dispose();
  }

  Future<void> run(Future<void> Function() task, String ok) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (mounted) feedback(context, ok);
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmThen(
    String title,
    String text,
    String ok,
    Future<void> Function() task,
    String done,
  ) async {
    final c = conv;
    if (c == null) return;
    if (!await confirm(
          context,
          title,
          '$text\n\n提交携带群版本 v${c.version}，冲突时提示刷新后重试。',
        ) ||
        !mounted)
      return;
    await run(task, done);
  }

  Future<void> rename() async {
    final c = conv!;
    final controller = TextEditingController(text: c.name);
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('修改群名称'),
        content: TextField(
          controller: controller,
          maxLength: 64,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await run(() => chat.rename(c.id, value), '群名已更新');
  }

  Future<void> memberActions(GroupMember m) async {
    final c = conv!;
    final owner = c.myRole == 'OWNER';
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                m.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            if (owner) ...[
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppTokens.brand,
                ),
                title: Text(m.role == 'ADMIN' ? '取消管理员' : '设为管理员'),
                onTap: () => Navigator.pop(s, 'role'),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppTokens.brand),
                title: const Text('转让群主'),
                subtitle: const Text('你将变为管理员'),
                onTap: () => Navigator.pop(s, 'transfer'),
              ),
            ],
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Color(0xFFC44F4F),
              ),
              title: const Text(
                '移出群聊',
                style: TextStyle(color: Color(0xFFC44F4F)),
              ),
              subtitle: const Text('对方立即失去该群历史与文件访问权'),
              onTap: () => Navigator.pop(s, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'role':
        await run(
          () => chat.setRole(
            c.id,
            m.userId,
            m.role == 'ADMIN' ? 'MEMBER' : 'ADMIN',
          ),
          m.role == 'ADMIN' ? '已取消管理员' : '已设为管理员',
        );
      case 'transfer':
        await confirmThen(
          '转让群主',
          '转让后你变为管理员，${m.displayName} 将拥有解散群聊和任免管理员的权限。',
          '确认',
          () => chat.transfer(c.id, m.userId),
          '群主已转让',
        );
      case 'remove':
        await confirmThen(
          '移出成员',
          '移出后 ${m.displayName} 将立即失去该群历史与文件的访问权；已下载到设备的内容无法收回。',
          '确认',
          () => chat.removeMember(c.id, m.userId),
          '已移出成员',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = conv;
    if (c == null) return Scaffold(appBar: AppBar());
    final list = chat.members[c.id] ?? const <GroupMember>[];
    final peer = chat.contactCache[c.peerUserId];
    final mine = c.myRole;
    bool canActOn(GroupMember m) =>
        !c.dissolved &&
        m.userId != chat.myId &&
        (mine == 'OWNER' || (mine == 'ADMIN' && m.role == 'MEMBER'));
    return Scaffold(
      appBar: AppBar(
        title: Text(c.isGroup ? '群聊信息（${c.memberCount}）' : '聊天信息'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                ChatAvatar(
                  name: c.name,
                  userId: c.peerUserId ?? '',
                  size: 72,
                  group: c.isGroup,
                  dissolved: c.dissolved,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: c.canManage ? rename : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c.canManage)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppTokens.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.isGroup
                      ? (c.dissolved ? '已解散（只读）' : '群版本 v${c.version}')
                      : (peer?.departmentName ?? ''),
                  style: const TextStyle(fontSize: 12, color: AppTokens.muted),
                ),
              ],
            ),
          ),
          if (c.isGroup) ...[
            GroupCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 12,
                  children: [
                    for (final m in list)
                      SizedBox(
                        width: 62,
                        child: GestureDetector(
                          onTap: canActOn(m) ? () => memberActions(m) : null,
                          child: Column(
                            children: [
                              ChatAvatar(
                                name: m.displayName,
                                userId: m.userId,
                                size: 46,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (c.canManage)
                      SizedBox(
                        width: 62,
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/messages/chat/${c.id}/add'),
                          child: Column(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: const Color(0xFFB7C3CA),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppTokens.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('添加', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (c.canManage)
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Text(
                  '点击成员可设置管理员、转让群主或移出',
                  style: TextStyle(fontSize: 12, color: AppTokens.muted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Text(
                  c.dissolved ? '群已解散，成员不可再变更' : '仅群主和管理员可以管理成员',
                  style: const TextStyle(fontSize: 12, color: AppTokens.muted),
                ),
              ),
          ],
          const SizedBox(height: 14),
          GroupCard(
            child: SwitchListTile(
              value: c.muted,
              title: const Text('消息免打扰'),
              subtitle: const Text(
                '静音只影响提醒，仍会累计未读',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: busy
                  ? null
                  : (v) => run(
                      () => chat.setMuted(c.id, v),
                      v ? '已开启免打扰' : '已关闭免打扰',
                    ),
            ),
          ),
          if (!c.isGroup)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GroupCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.groups_outlined,
                    color: AppTokens.brand,
                  ),
                  title: Text('与 ${c.name} 一起建群'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/messages/new?mode=group&with=${c.peerUserId}',
                  ),
                ),
              ),
            ),
          if (c.isGroup)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: c.dissolved
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        '解散后成员只能查看历史，不能发送、下载新文件',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTokens.muted),
                      ),
                    )
                  : GroupCard(
                      child: Column(
                        children: [
                          if (mine == 'OWNER')
                            ListTile(
                              title: const Center(
                                child: Text(
                                  '解散群聊',
                                  style: TextStyle(
                                    color: Color(0xFFC44F4F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              onTap: () => confirmThen(
                                '解散群聊',
                                '解散后全部成员只能查看历史，不能再发送消息或下载新文件；此操作不可撤销。',
                                '解散',
                                () => chat.dissolve(c.id),
                                '群聊已解散',
                              ),
                            )
                          else
                            ListTile(
                              title: const Center(
                                child: Text(
                                  '退出群聊',
                                  style: TextStyle(
                                    color: Color(0xFFC44F4F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              onTap: () => confirmThen(
                                '退出群聊',
                                '退出后你将无法再查看该群历史，重新加入也只能看到加入之后的消息。',
                                '退出',
                                () => chat.leave(c.id),
                                '已退出群聊',
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
