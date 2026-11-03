import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:origin_mobile/data/chat/chat_socket.dart';
import 'package:origin_mobile/data/chat/chat_store.dart';
import 'package:origin_mobile/domain/chat.dart';
import 'package:origin_mobile/domain/chat_format.dart';
import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/ui/theme.dart';
import 'package:origin_mobile/features/messages/chat_widgets.dart';

/// 单聊/群聊页：历史、实时消息、未读分割线、发送与附件。
class ChatPage extends StatefulWidget {
  final ChatStore chat;
  final String id;
  const ChatPage(this.chat, this.id, {super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  String? entryUnread;
  bool loadingOlder = false, hasNew = false, failed = false;
  int lastCount = 0;
  ChatStore get chat => widget.chat;
  Conversation? get conv => chat.conversations[widget.id];

  @override
  void initState() {
    super.initState();
    final c = conv;
    if (c != null && c.unreadCount > 0) {
      entryUnread = (BigInt.parse(c.lastReadSeq) + BigInt.one).toString();
    }
    chat.addListener(onChat);
    scroll.addListener(onScroll);
    input.addListener(() => setState(() {}));
    open();
  }

  Future<void> open() async {
    // initState 内不能通知监听者（会在构建期触发重建），让出一个微任务。
    await Future<void>.value();
    if (!mounted) return;
    try {
      await chat.open(widget.id);
    } catch (e) {
      if (mounted) setState(() => failed = true);
      if (mounted) feedback(context, chatErrorText(e));
    }
  }

  void onChat() {
    final n = chat.timelines[widget.id]?.length ?? 0;
    if (n > lastCount && scroll.hasClients && scroll.offset > 140) {
      hasNew = true;
    }
    lastCount = n;
    // 被移出或退出：返回列表。
    if (chat.conversations[widget.id] == null &&
        chat.ready &&
        mounted &&
        !failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
    }
    if (mounted) setState(() {});
  }

  void onScroll() {
    if (!scroll.hasClients) return;
    if (scroll.offset <= 140 && hasNew) setState(() => hasNew = false);
    if (scroll.position.extentAfter < 200) older();
  }

  Future<void> older() async {
    if (loadingOlder || chat.hasOlder[widget.id] != true) return;
    setState(() => loadingOlder = true);
    try {
      await chat.loadOlder(widget.id);
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  @override
  void dispose() {
    chat.removeListener(onChat);
    chat.close();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = input.text;
    final max = chat.config?.textMaxChars ?? 4000;
    if (text.trim().isEmpty) return;
    if (text.runes.length > max) {
      feedback(context, '单条消息最多 $max 个字符');
      return;
    }
    input.clear();
    await chat.sendText(widget.id, text);
  }

  Future<void> pick(FileType type) async {
    Navigator.of(context).maybePop();
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: type,
      );
    } catch (e) {
      if (mounted) feedback(context, '无法打开文件选择器：$e');
      return;
    }
    if (result == null) return;
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await chat.sendFile(widget.id, File(path), f.name, _mime(f.extension));
      } catch (e) {
        if (mounted) feedback(context, chatErrorText(e));
      }
    }
  }

  String _mime(String? ext) => switch ((ext ?? '').toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };

  void attachSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '发送文件或图片（单文件 ≤ ${(chat.config?.maxFileBytes ?? 50000000) ~/ 1000000} MB）',
              style: const TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: AppTokens.brand),
            title: const Text('相册'),
            subtitle: const Text('选择图片'),
            onTap: () => pick(FileType.image),
          ),
          ListTile(
            leading: const Icon(
              Icons.description_outlined,
              color: AppTokens.brand,
            ),
            title: const Text('文件'),
            subtitle: const Text('Excel、Word、PDF、压缩包等'),
            onTap: () => pick(FileType.any),
          ),
        ],
      ),
    ),
  );

  Future<void> download(ChatFile f) async {
    try {
      final bytes = await chat.download(f.id);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${f.name}';
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    }
  }

  Future<void> preview(ChatFile f) async {
    try {
      final bytes = await chat.download(f.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                f.name,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  errorBuilder: (_, _, _) => const Text(
                    '无法预览该图片，可返回后下载查看',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) feedback(context, chatErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = conv;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: failed
            ? StateNotice(
                '会话加载失败',
                retry: () {
                  setState(() => failed = false);
                  open();
                },
              )
            : const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final items = chat.timelines[widget.id] ?? const <ChatMessage>[];
    final rows = buildRows(items, entryUnread).reversed.toList();
    final sub = c.isGroup
        ? '${c.memberCount} 人${c.muted ? ' · 已静音' : ''}'
        : chat.contactCache[c.peerUserId]?.departmentName ?? '';
    final offline = chat.connection == ChatConnection.offline;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 0,
        title: Column(
          children: [
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTokens.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: c.isGroup ? '群信息' : '聊天信息',
            onPressed: () => context.push('/messages/chat/${c.id}/info'),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.connection != ChatConnection.online &&
              chat.connection != ChatConnection.idle)
            Container(
              width: double.infinity,
              color: offline
                  ? const Color(0xFFF7DCDC)
                  : const Color(0xFFFBF0D9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                offline ? '网络已断开，恢复后自动补拉；发送失败的消息可重试' : '正在重新连接…',
                style: TextStyle(
                  fontSize: 12.5,
                  color: offline
                      ? const Color(0xFF8A2F2F)
                      : const Color(0xFF8A5D0B),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  itemCount: rows.length + 1,
                  itemBuilder: (context, i) {
                    if (i == rows.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: chat.hasOlder[c.id] == true
                              ? (loadingOlder
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: older,
                                        child: const Text('查看更早的消息'),
                                      ))
                              : Text(
                                  items.isEmpty ? '还没有消息，发送第一条吧' : '没有更早的消息了',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTokens.muted,
                                  ),
                                ),
                        ),
                      );
                    }
                    final row = rows[i];
                    return switch (row) {
                      DayRow() => Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTokens.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            row.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTokens.muted,
                            ),
                          ),
                        ),
                      ),
                      UnreadRow() => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '以下为新消息',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTokens.brand,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      MessageRow(:final message) => MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        mine: message.senderId == chat.myId,
                        showName: c.isGroup,
                        senderName: chat.nameOf(message.senderId),
                        onRetry: () => chat.retry(c.id, message),
                        onDiscard: () => chat.discard(c.id, message),
                        onCancel: () => chat.cancelUpload(c.id, message),
                        onDownload: message.file == null
                            ? null
                            : () => download(message.file!),
                        onPreview: message.file == null
                            ? null
                            : () => preview(message.file!),
                      ),
                    };
                  },
                ),
                if (hasNew)
                  Positioned(
                    right: 16,
                    bottom: 10,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () {
                        scroll.animateTo(
                          0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                        setState(() => hasNew = false);
                      },
                      icon: const Icon(Icons.arrow_downward, size: 16),
                      label: const Text('有新消息'),
                    ),
                  ),
              ],
            ),
          ),
          if (c.dissolved)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppTokens.muted),
                    SizedBox(width: 6),
                    Text(
                      '该群已解散，仅可查看历史消息',
                      style: TextStyle(color: AppTokens.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTokens.line)),
              ),
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                8,
                8 + MediaQuery.paddingOf(context).bottom * 0,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: attachSheet,
                      icon: const Icon(Icons.add_circle_outline, size: 26),
                      tooltip: '发送文件或图片',
                    ),
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: offline ? '网络已断开，发送后会标记失败' : '输入消息',
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: input.text.trim().isEmpty ? null : send,
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: '发送',
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
