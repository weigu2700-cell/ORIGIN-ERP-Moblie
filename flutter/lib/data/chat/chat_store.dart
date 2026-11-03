import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:origin_mobile/domain/chat.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/data/chat/chat_api.dart';
import 'package:origin_mobile/data/chat/chat_socket.dart';
import 'package:origin_mobile/core/session.dart';

String _uuid() {
  final r = Random.secure();
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${'89ab'[r.nextInt(4)]}${h(3)}-${h(12)}';
}

String chatErrorText(Object error) {
  if (error is ApiFailure) {
    const map = {
      'VERSION_CONFLICT': '群信息已被他人修改，已刷新，请确认后重试',
      'GROUP_NOT_WRITABLE': '该群已解散，无法发送或修改',
      'OWNER_TRANSFER_REQUIRED': '群主需要先转让群主才能退出',
      'MEMBER_ALREADY_PRESENT': '所选成员已在群中',
      'IDEMPOTENCY_CONFLICT': '相同发送标识对应不同内容，请重新发送',
      'FILE_TOO_LARGE': '文件超过大小上限',
      'FILE_TYPE_NOT_ALLOWED': '不支持该文件类型',
      'RATE_LIMITED': '发送太快了，请稍后再试',
      'QUOTA_EXCEEDED': '存储配额已满，请联系管理员',
      'IM_NOT_ENABLED': '聊天功能尚未对你开放',
      'GROUP_ROLE_REQUIRED': '你没有权限执行该操作',
    };
    return map[error.error] ?? error.message;
  }
  return error.toString();
}

/// 员工聊天状态：会话、时间线、实时事件、发送与上传、群管理。
/// 每个登录会话一个实例；身份变化时整个应用重建，旧实例随之 dispose。
class ChatStore extends ChangeNotifier {
  final Session session;
  final ChatApi api;
  ChatStore(this.session, {ChatApi? api}) : api = api ?? HttpChatApi(session);

  final conversations = <String, Conversation>{};
  final timelines = <String, List<ChatMessage>>{};
  final hasOlder = <String, bool>{};
  final members = <String, List<GroupMember>>{};
  final contactCache = <String, Contact>{};
  String? activeId;
  ChatConnection connection = ChatConnection.idle;
  ChatConfig? config;
  bool ready = false;
  String? disabledReason, revokedNotice;
  int _snapshotUnread = 0;

  String _cursor = '0';
  bool _disposed = false;
  ChatSocket? _socket;
  StreamSubscription<ChatEvent>? _push;
  Future<void>? _syncing;
  final _seen = <String>[];
  final _buffer = <String, ChatEvent>{};
  final _cancels = <String, CancelToken>{};

  String get myId => '${session.profile['id'] ?? ''}';
  List<Conversation> get list =>
      conversations.values.toList()
        ..sort((a, b) => b.activity.compareTo(a.activity));
  Conversation? get active => activeId == null ? null : conversations[activeId];
  int get unreadTotal => !ready
      ? _snapshotUnread
      : conversations.values
            .where((c) => !c.muted)
            .fold(0, (n, c) => n + c.unreadCount);
  String nameOf(String? id) => id == null
      ? '系统'
      : id == myId
      ? '我'
      : contactCache[id]?.displayName ?? '同事';

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // —— 初始化与实时 ——
  Future<void> bootstrap() async {
    if (ready || _bootstrapping) return;
    _bootstrapping = true;
    try {
      disabledReason = null;
      config = await api.config();
      final snap = await api.snapshot();
      conversations
        ..clear()
        ..addEntries(snap.records.map((c) => MapEntry(c.id, c)));
      _snapshotUnread = snap.unread;
      _cursor = snap.syncEventSeq;
      ready = true;
      notifyListeners();
      unawaited(_loadPeers());
      _startRealtime();
    } catch (e) {
      disabledReason =
          e is ApiFailure && (e.error == 'IM_NOT_ENABLED' || e.code == 403)
          ? '聊天功能尚未对你开放，请联系管理员'
          : chatErrorText(e);
      notifyListeners();
    } finally {
      _bootstrapping = false;
    }
  }

  bool _bootstrapping = false;

  Future<void> _loadPeers() async {
    try {
      for (final c in await api.contacts()) {
        contactCache[c.userId] = c;
      }
      notifyListeners();
    } catch (_) {
      /* 联系人失败不影响会话 */
    }
  }

  /// 后端要求 clientId 为 UUID，且同一安装实例保持稳定（重连时替换旧连接）。
  Future<String> _clientId() async {
    const storage = FlutterSecureStorage();
    const key = 'origin.chat.client_id';
    try {
      final saved = await storage.read(key: key);
      if (saved != null && saved.length == 36) return saved;
      final created = _uuid();
      await storage.write(key: key, value: created);
      return created;
    } catch (_) {
      return _uuid();
    }
  }

  void _startRealtime() {
    final pushed = api.pushed;
    if (pushed != null) {
      connection = ChatConnection.online;
      _push = pushed.listen(applyEvent);
      return;
    }
    _socket = ChatSocket(
      api: api,
      baseUrl: session.api.baseUrl,
      clientId: _clientId,
      onState: (s) {
        connection = s;
        notifyListeners();
      },
      onReady: () => unawaited(sync()),
      onEvent: applyEvent,
    )..start();
  }

  /// 应用回到前台：补拉事件并恢复连接。
  void resume() {
    _socket?.resume();
    if (ready) unawaited(sync());
  }

  bool _remembered(String id) {
    if (_seen.contains(id)) return true;
    _seen.add(id);
    if (_seen.length > 400) _seen.removeRange(0, _seen.length - 400);
    return false;
  }

  /// 按 eventSeq 顺序推进：有缺口先缓存再补拉，不直接把游标设成收到的最大值。
  void applyEvent(ChatEvent e) {
    if (cmpSeq(e.seq, _cursor) <= 0 || _remembered(e.id)) return;
    if (cmpSeq(e.seq, (BigInt.parse(_cursor) + BigInt.one).toString()) > 0) {
      _buffer[e.seq] = e;
      unawaited(sync());
      return;
    }
    _handle(e);
    _cursor = e.seq;
    _drain();
  }

  void _drain() {
    for (;;) {
      final next = _buffer.remove(
        (BigInt.parse(_cursor) + BigInt.one).toString(),
      );
      if (next == null) return;
      _handle(next);
      _cursor = next.seq;
    }
  }

  Future<void> sync() => _syncing ??= () async {
    try {
      for (;;) {
        final page = await api.syncEvents(_cursor);
        for (final e in page.records) {
          if (cmpSeq(e.seq, _cursor) <= 0 || _remembered(e.id)) continue;
          _handle(e);
          _cursor = e.seq;
        }
        _drain();
        if (!page.hasMore) break;
      }
    } on ApiFailure catch (e) {
      if (e.code == 410) {
        ready = false;
        await bootstrap();
      }
    } catch (_) {
      /* 下次前台/重连再补 */
    } finally {
      _syncing = null;
    }
  }();

  void _handle(ChatEvent e) {
    final id = e.conversationId;
    switch (e.type) {
      case 'MESSAGE.CREATED':
        final m =
            e.payload['__message'] as ChatMessage? ??
            (e.payload['message'] is Map
                ? ChatMessage.fromJson((e.payload['message'] as Map).cast())
                : null);
        if (m == null || id == null) return;
        if (conversations.containsKey(id) && timelines.containsKey(id)) {
          _mergeServer(id, [m]);
        }
        if (!conversations.containsKey(id)) {
          api
              .conversation(id)
              .then((c) {
                conversations[id] = c;
                notifyListeners();
              })
              .catchError((_) {});
        }
        if (id == activeId && m.senderId != myId) unawaited(markRead(id));
      case 'CONVERSATION.UPDATED':
        final c =
            e.payload['__conversation'] as Conversation? ??
            (e.payload['conversation'] is Map
                ? Conversation.fromJson(
                    (e.payload['conversation'] as Map).cast(),
                  )
                : null);
        if (c == null) return;
        final old = conversations[c.id];
        if (old == null) {
          conversations[c.id] = c;
        } else if (!identical(old, c)) {
          old.merge(c);
        }
        if (c.id == activeId && (conversations[c.id]?.unreadCount ?? 0) > 0) {
          unawaited(markRead(c.id));
        }
      case 'MEMBER.CHANGED':
        if (id != null) {
          members.remove(id);
          if (id == activeId) unawaited(loadMembers(id));
        }
      case 'CONVERSATION.REVOKED':
        if (id != null) {
          conversations.remove(id);
          timelines.remove(id);
          members.remove(id);
          if (activeId == id) {
            activeId = null;
            revokedNotice = '你已不在该会话中';
          }
        }
      case 'READ.UPDATED':
        final c = id == null ? null : conversations[id];
        if (c != null) {
          c.lastReadSeq = '${e.payload['lastReadSeq'] ?? c.lastReadSeq}';
          c.unreadCount = asInt(e.payload['unreadCount']);
        }
    }
    notifyListeners();
  }

  void _mergeServer(String id, List<ChatMessage> incoming) {
    final current = timelines[id] ?? [];
    final server = {
      for (final m in current.where((m) => m.local == null)) m.id: m,
    };
    for (final m in incoming) {
      server[m.id] = m;
    }
    final clientIds = incoming.map((m) => m.clientMessageId).toSet();
    final locals = current.where(
      (m) => m.local != null && !clientIds.contains(m.clientMessageId),
    );
    timelines[id] = [
      ...server.values.toList()..sort((a, b) => cmpSeq(a.seq!, b.seq!)),
      ...locals,
    ];
  }

  // —— 会话与历史 ——
  Future<void> open(String id) async {
    activeId = id;
    revokedNotice = null;
    notifyListeners();
    if (!timelines.containsKey(id)) {
      final page = await api.history(id);
      _mergeServer(id, page.records);
      hasOlder[id] = page.hasMore;
    }
    if (conversations[id]?.isGroup ?? false) {
      unawaited(loadMembers(id).catchError((_) {}));
    }
    notifyListeners();
    await markRead(id);
  }

  void close() {
    activeId = null;
    // 多由页面 dispose 触发，此时组件树已锁定，下一个微任务再通知。
    scheduleMicrotask(() {
      if (activeId == null) notifyListeners();
    });
  }

  Future<void> loadOlder(String id) async {
    final first = (timelines[id] ?? [])
        .where((m) => m.local == null)
        .firstOrNull;
    if (first == null || hasOlder[id] != true) return;
    final page = await api.history(id, beforeSeq: first.seq);
    _mergeServer(id, page.records);
    hasOlder[id] = page.hasMore;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final c = conversations[id];
    if (c == null || c.unreadCount == 0) return;
    try {
      final r = await api.markRead(id, c.lastSeq);
      c
        ..lastReadSeq = r.lastReadSeq
        ..unreadCount = r.unreadCount;
      notifyListeners();
    } catch (_) {
      /* 下次进入或收到消息再上报 */
    }
  }

  Future<void> loadMembers(String id) async {
    final list = await api.members(id);
    members[id] = list;
    for (final m in list) {
      contactCache[m.userId] = m;
    }
    notifyListeners();
  }

  // —— 发送 ——
  ChatMessage _pushLocal(
    String id, {
    String type = 'TEXT',
    String? text,
    ChatFile? file,
    LocalState state = LocalState.sending,
  }) {
    final m = ChatMessage(
      id: 'local-${_uuid()}',
      conversationId: id,
      clientMessageId: _uuid(),
      type: type,
      senderId: myId,
      text: text,
      file: file,
      local: state,
    );
    (timelines[id] ??= []).add(m);
    notifyListeners();
    return m;
  }

  void _dropLocal(String id, ChatMessage m) {
    timelines[id]?.removeWhere((x) => identical(x, m));
    notifyListeners();
  }

  Future<void> _deliver(
    ChatMessage local, {
    required String type,
    String? text,
    String? fileId,
  }) async {
    final id = local.conversationId;
    local.local = LocalState.sending;
    notifyListeners();
    try {
      final m = await api.send(
        id,
        clientMessageId: local.clientMessageId,
        type: type,
        text: text,
        fileId: fileId,
      );
      _dropLocal(id, local);
      _mergeServer(id, [m]);
      final c = conversations[id];
      if (c != null && cmpSeq(m.seq!, c.lastSeq) >= 0) {
        c
          ..lastSeq = m.seq!
          ..lastMessage = m;
      }
      notifyListeners();
    } catch (e) {
      // 结果未知（网络/超时）：先用原 clientMessageId 回查，未查到才标记失败待重试。
      if (e is ApiFailure && e.code == null || e is! ApiFailure) {
        final found = await api
            .byClientId(local.clientMessageId)
            .catchError((_) => null);
        if (found != null) {
          _dropLocal(id, local);
          _mergeServer(id, [found]);
          notifyListeners();
          return;
        }
      }
      local
        ..local = LocalState.failed
        ..reason = chatErrorText(e);
      notifyListeners();
    }
  }

  Future<void> sendText(String id, String text) {
    final t = text.trim();
    if (t.isEmpty) return Future.value();
    return _deliver(
      _pushLocal(id, text: t),
      type: 'TEXT',
      text: t,
    );
  }

  Future<void> retry(String id, ChatMessage m) {
    if (m.local != LocalState.failed || m.type != 'TEXT') return Future.value();
    return _deliver(m, type: 'TEXT', text: m.text);
  }

  void discard(String id, ChatMessage m) => _dropLocal(id, m);

  /// 返回错误文案表示未发起上传（本地预检失败）。
  String? precheck(String name, int size) {
    final cfg = config;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (cfg != null && size > cfg.maxFileBytes) {
      return '文件超过 ${cfg.maxFileBytes ~/ 1000000} MB 上限';
    }
    if (size == 0) return '文件为空';
    if (cfg != null &&
        cfg.extensions.isNotEmpty &&
        !cfg.extensions.contains(ext)) {
      return '不支持 .$ext 类型的文件';
    }
    return null;
  }

  Future<void> sendFile(String id, File file, String name, String mime) async {
    final size = await file.length();
    final problem = precheck(name, size);
    if (problem != null) throw ApiFailure(problem);
    final ext = name.split('.').last.toLowerCase();
    final image = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    final type = image ? 'IMAGE' : 'FILE';
    final local = _pushLocal(
      id,
      type: type,
      file: ChatFile('', name, size, mime),
      state: LocalState.uploading,
    );
    final cancel = CancelToken();
    _cancels[local.id] = cancel;
    try {
      final digest = (await sha256.bind(file.openRead()).first).toString();
      final reservation = await api.reserveUpload(
        clientUploadId: _uuid(),
        conversationId: id,
        name: name,
        size: size,
        mime: mime,
        sha256: digest,
      );
      local.uploadId = reservation.uploadId;
      await api.putFile(
        reservation,
        file,
        size,
        cancel: cancel,
        onProgress: (p) {
          local.progress = p;
          notifyListeners();
        },
      );
      local.local = LocalState.verifying;
      notifyListeners();
      await api.complete(reservation.uploadId);
      var status = await api.uploadStatus(reservation.uploadId);
      for (final wait in const [2, 5, 10, 10, 10, 10]) {
        if (status.status != 'VERIFYING' && status.status != 'INITIATED') break;
        await Future<void>.delayed(Duration(milliseconds: wait * 1000));
        if (cancel.isCancelled) return;
        status = await api.uploadStatus(reservation.uploadId);
      }
      if (status.status == 'READY' && status.file != null) {
        await _deliver(local, type: type, fileId: status.file!.id);
      } else if (status.status == 'REJECTED' || status.status == 'EXPIRED') {
        local
          ..local = LocalState.rejected
          ..reason = status.rejection ?? '文件未通过检查';
        notifyListeners();
      } else if (status.status != 'CANCELLED') {
        local
          ..local = LocalState.failed
          ..reason = '检查超时，请稍后重新发送';
        notifyListeners();
      }
    } catch (e) {
      if (cancel.isCancelled) return;
      local
        ..local = LocalState.failed
        ..reason = chatErrorText(e);
      notifyListeners();
    } finally {
      _cancels.remove(local.id);
    }
  }

  Future<void> cancelUpload(String id, ChatMessage m) async {
    _cancels.remove(m.id)?.cancel('用户取消');
    _dropLocal(id, m);
    if (m.uploadId != null) {
      await api.cancelUpload(m.uploadId!).catchError((_) {});
    }
  }

  Future<List<int>> download(String fileId) => api.download(fileId);

  // —— 创建会话与群管理 ——
  Future<String> startDirect(String peerUserId) async {
    final c = await api.createDirect(peerUserId);
    c.peerUserId ??= peerUserId;
    _upsert(c);
    await open(c.id);
    return c.id;
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final c = await api.createGroup(_uuid(), name, memberIds);
    _upsert(c);
    await open(c.id);
    return c.id;
  }

  void _upsert(Conversation c) {
    final old = conversations[c.id];
    if (old == null) {
      conversations[c.id] = c;
    } else if (!identical(old, c)) {
      old.merge(c);
    }
    notifyListeners();
  }

  Future<T?> _group<T>(String id, Future<T> Function(int version) run) async {
    final c = conversations[id];
    if (c == null) return null;
    try {
      final r = await run(c.version);
      if (r is Conversation) _upsert(r);
      members.remove(id);
      if (activeId == id) await loadMembers(id).catchError((_) {});
      return r;
    } on ApiFailure catch (e) {
      if (e.error == 'VERSION_CONFLICT') {
        await api.conversation(id).then(_upsert).catchError((_) {});
        await loadMembers(id).catchError((_) {});
      }
      rethrow;
    }
  }

  Future<void> rename(String id, String name) =>
      _group(id, (v) => api.rename(id, name, v));
  Future<void> addMembers(String id, List<String> ids) =>
      _group(id, (v) => api.addMembers(id, ids, v));
  Future<void> removeMember(String id, String userId) =>
      _group(id, (v) => api.removeMember(id, userId, v));
  Future<void> setRole(String id, String userId, String role) =>
      _group(id, (v) => api.setRole(id, userId, role, v));
  Future<void> transfer(String id, String newOwnerId) =>
      _group(id, (v) => api.transfer(id, newOwnerId, v));
  Future<void> dissolve(String id) => _group(id, (v) => api.dissolve(id, v));

  Future<void> leave(String id) async {
    final c = conversations[id];
    if (c == null) return;
    await api.leave(id, c.version);
    conversations.remove(id);
    timelines.remove(id);
    members.remove(id);
    if (activeId == id) activeId = null;
    notifyListeners();
  }

  Future<void> setMuted(String id, bool muted) async {
    await api.setMuted(id, muted);
    conversations[id]?.muted = muted;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _socket?.stop();
    unawaited(_push?.cancel());
    for (final c in _cancels.values) {
      c.cancel('dispose');
    }
    super.dispose();
  }
}
