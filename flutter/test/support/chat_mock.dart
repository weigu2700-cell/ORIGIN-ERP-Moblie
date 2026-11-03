import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/data/chat/chat_api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/chat.dart';

/// 测试用内存聊天后端（仅测试使用，应用代码只走真实接口）。
/// 行为贴近 api.md：幂等 clientMessageId、expectedVersion 冲突、解散只读、上传检查流程。
class MockChatApi implements ChatApi {
  static const me = '80001';
  final Duration delay;
  MockChatApi({this.delay = const Duration(milliseconds: 80)}) {
    _seed();
  }

  static const _people = [
    ['80001', '顾威', '技术部'],
    ['80002', '李敏', '装配车间'],
    ['80003', '王强', '仓储部'],
    ['80004', '陈晨', '生产计划'],
    ['80005', '周杰', '采购部'],
    ['80006', '赵琳', '装配车间'],
    ['80007', '孙浩', '质检部'],
    ['80008', '吴雪', '销售部'],
    ['80010', '林悦', '仓储部'],
  ];
  final _contacts = [for (final p in _people) Contact(p[0], p[1], p[2])];
  final _rooms = <String, _Room>{};
  final _clientIndex = <String, ChatMessage>{};
  final _uploads = <String, _Up>{};
  final _push = StreamController<ChatEvent>.broadcast();
  int _id = 900000, _event = 1800;
  String _nextId() => '${++_id}';
  String _name(String id) =>
      _contacts.where((c) => c.userId == id).firstOrNull?.displayName ?? '未知员工';
  Future<T> _wait<T>(T v) => Future.delayed(delay, () => v);

  @override
  Stream<ChatEvent>? get pushed => _push.stream;

  Never _fail(int code, String error, String message) =>
      throw ApiFailure(message, code: code, error: error);

  void _emit(String type, String? conv, Json payload) =>
      _push.add(ChatEvent(_nextId(), '${++_event}', type, conv, payload));

  _Room _room(String id) {
    final r = _rooms[id];
    if (r == null || r.members.every((m) => m.$1 != me)) {
      _fail(404, 'RESOURCE_NOT_FOUND', '资源不存在');
    }
    return r;
  }

  ChatMessage _add(
    _Room r,
    String? sender, {
    String type = 'TEXT',
    String? text,
    ChatFile? file,
    String? system,
    String? cid,
    DateTime? at,
  }) {
    final seq = '${int.parse(r.conv.lastSeq) + 1}';
    final m = ChatMessage(
      id: _nextId(),
      conversationId: r.conv.id,
      clientMessageId: cid ?? _nextId(),
      type: type,
      seq: seq,
      senderId: sender,
      text: text,
      systemText: system,
      file: file,
      createdAt: at ?? DateTime.now(),
    );
    r.messages.add(m);
    r.conv
      ..lastSeq = seq
      ..lastMessage = m
      ..updatedAt = m.createdAt;
    if (sender != me && type != 'SYSTEM') r.conv.unreadCount += 1;
    if (sender == me) r.conv.lastReadSeq = seq;
    _clientIndex['$sender:${m.clientMessageId}'] = m;
    _push.add(
      ChatEvent(_nextId(), '${++_event}', 'MESSAGE.CREATED', r.conv.id, {
        '__message': m,
      }),
    );
    _emitConv(r);
    return m;
  }

  void _emitConv(_Room r) => _push.add(
    ChatEvent(_nextId(), '${++_event}', 'CONVERSATION.UPDATED', r.conv.id, {
      '__conversation': r.conv,
    }),
  );

  _Room _make(
    String id,
    String type,
    String name,
    List<(String, String)> members, {
    String? peer,
    String? owner,
    String role = 'MEMBER',
    int version = 1,
    String status = 'ACTIVE',
    bool muted = false,
  }) {
    final r = _Room(
      Conversation(
        id: id,
        type: type,
        name: name,
        peerUserId: peer,
        ownerId: owner,
        myRole: type == 'GROUP' ? role : null,
        version: version,
        status: status,
        muted: muted,
        memberCount: members.length,
      ),
      members,
    );
    _rooms[id] = r;
    return r;
  }

  void _seed() {
    DateTime ago(int m) => DateTime.now().subtract(Duration(minutes: m));
    final g1 = _make(
      '110001',
      'GROUP',
      '装配一组',
      [
        ('80002', 'OWNER'),
        (me, 'MEMBER'),
        ('80006', 'MEMBER'),
        ('80007', 'ADMIN'),
      ],
      owner: '80002',
      version: 3,
    );
    _add(g1, null, type: 'SYSTEM', system: '李敏 创建了群聊', at: ago(1500));
    _add(g1, '80002', text: '今天的装配排产已经定了，大家看一下。', at: ago(1480));
    _add(g1, '80006', text: '收到，A 线 3 号工位缺一批轴承，仓库能补吗？', at: ago(1470));
    _add(g1, me, text: '我去跟仓库确认，十点前给你回复。', at: ago(1460));
    _add(
      g1,
      '80002',
      type: 'FILE',
      file: const ChatFile(
        '700001',
        '装配排产-11月.xlsx',
        24681,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      at: ago(90),
    );
    _add(
      g1,
      '80002',
      type: 'IMAGE',
      file: const ChatFile('700002', '3号工位现场.jpg', 812345, 'image/jpeg'),
      at: ago(70),
    );
    _add(g1, '80006', text: '看到了，现场确实少两托盘，先按图里的物料编码补。', at: ago(66));
    _add(g1, '80002', text: '工单资料已补齐', at: ago(63));
    g1.conv
      ..lastReadSeq = '6'
      ..unreadCount = 2;
    final d1 = _make('110002', 'DIRECT', '王强', [
      (me, 'MEMBER'),
      ('80003', 'MEMBER'),
    ], peer: '80003');
    _add(d1, me, text: '王强，今天的成品入库单能在下午处理吗？', at: ago(40));
    _add(d1, '80003', text: '好的，下午三点前入库', at: ago(32));
    d1.conv
      ..lastReadSeq = '2'
      ..unreadCount = 0;
    final g2 = _make(
      '110003',
      'GROUP',
      '仓储协同',
      [
        (me, 'OWNER'),
        ('80003', 'ADMIN'),
        ('80010', 'MEMBER'),
        ('80004', 'MEMBER'),
        ('80005', 'MEMBER'),
      ],
      owner: me,
      role: 'OWNER',
      version: 7,
      muted: true,
    );
    _add(g2, null, type: 'SYSTEM', system: '你创建了群聊', at: ago(3000));
    _add(g2, '80003', text: '原料仓今早到货 36 件，已上架。', at: ago(120));
    g2.conv
      ..lastReadSeq = '1'
      ..unreadCount = 1;
    final g3 = _make(
      '110005',
      'GROUP',
      '采购审批沟通',
      [('80005', 'OWNER'), (me, 'MEMBER'), ('80008', 'MEMBER')],
      owner: '80005',
      version: 5,
      status: 'DISSOLVED',
    );
    _add(g3, '80005', text: 'PO202609110008 的价格差异大家看一下。', at: ago(5000));
    _add(g3, null, type: 'SYSTEM', system: '群主已解散该群聊，仅可查看历史', at: ago(4990));
    g3.conv
      ..lastReadSeq = '2'
      ..unreadCount = 0;
  }

  @override
  Future<ChatConfig> config() => _wait(
    const ChatConfig(50000000, 200, 4000, [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
      'docx',
      'xlsx',
      'pptx',
      'txt',
      'csv',
      'zip',
    ]),
  );
  @override
  Future<List<Contact>> contacts({String? keyword}) {
    final k = (keyword ?? '').trim();
    return _wait(
      _contacts
          .where(
            (c) =>
                c.userId != me &&
                (k.isEmpty ||
                    '${c.displayName}${c.departmentName}'.contains(k)),
          )
          .toList(),
    );
  }

  @override
  Future<Conversation> createDirect(String peer) {
    var r = _rooms.values
        .where((e) => e.conv.type == 'DIRECT' && e.conv.peerUserId == peer)
        .firstOrNull;
    r ??= _make(_nextId(), 'DIRECT', _name(peer), [
      (me, 'MEMBER'),
      (peer, 'MEMBER'),
    ], peer: peer);
    return _wait(r.conv.clone());
  }

  @override
  Future<Snapshot> snapshot() {
    final rows = _rooms.values
        .where((r) => r.members.any((m) => m.$1 == me))
        .map((r) => r.conv)
        .toList();
    return _wait((
      records: [for (final c in rows) c.clone()],
      syncEventSeq: '$_event',
      unread: rows.where((c) => !c.muted).fold(0, (n, c) => n + c.unreadCount),
    ));
  }

  @override
  Future<Conversation> conversation(String id) => _wait(_room(id).conv.clone());
  @override
  Future<void> setMuted(String id, bool muted) async {
    final r = _room(id);
    r.conv.muted = muted;
    _emitConv(r);
  }

  @override
  Future<SendResult> send(
    String id, {
    required String clientMessageId,
    required String type,
    String? text,
    String? fileId,
  }) async {
    final r = _room(id);
    if (r.conv.dissolved) _fail(409, 'GROUP_NOT_WRITABLE', '该群已解散');
    final existed = _clientIndex['$me:$clientMessageId'];
    if (existed != null) {
      if ((existed.text ?? '') != (text ?? '')) {
        _fail(409, 'IDEMPOTENCY_CONFLICT', '相同发送标识对应不同内容');
      }
      return existed;
    }
    ChatFile? file;
    if (type != 'TEXT') {
      final up = _uploads.values.where((u) => u.file.id == fileId).firstOrNull;
      if (up == null || up.status != 'READY') {
        _fail(409, 'FILE_NOT_READY', '文件尚未通过检查');
      }
      file = up.file;
    }
    final m = _add(
      r,
      me,
      type: type,
      text: text,
      file: file,
      cid: clientMessageId,
    );
    if (text != null) {
      final peer = r.conv.type == 'DIRECT'
          ? r.conv.peerUserId
          : r.members.firstWhere((x) => x.$1 != me).$1;
      Timer(const Duration(milliseconds: 1800), () {
        if (!r.conv.dissolved && peer != null) {
          _add(
            r,
            peer,
            text: '收到：${text.length > 20 ? text.substring(0, 20) : text}',
          );
        }
      });
    }
    return _wait(m);
  }

  @override
  Future<HistoryPage> history(String id, {String? beforeSeq, int limit = 30}) {
    final r = _room(id);
    var rows = r.messages.toList();
    if (beforeSeq != null) {
      rows = rows.where((m) => cmpSeq(m.seq!, beforeSeq) < 0).toList();
    }
    final page = rows.length > limit ? rows.sublist(rows.length - limit) : rows;
    return _wait((records: page, hasMore: rows.length > limit));
  }

  @override
  Future<ChatMessage?> byClientId(String clientMessageId) =>
      _wait(_clientIndex['$me:$clientMessageId']);
  @override
  Future<({String lastReadSeq, int unreadCount})> markRead(
    String id,
    String throughSeq,
  ) async {
    final r = _room(id);
    final through = cmpSeq(throughSeq, r.conv.lastSeq) > 0
        ? r.conv.lastSeq
        : throughSeq;
    if (cmpSeq(through, r.conv.lastReadSeq) > 0) r.conv.lastReadSeq = through;
    r.conv.unreadCount = r.messages
        .where(
          (m) =>
              cmpSeq(m.seq!, r.conv.lastReadSeq) > 0 &&
              m.senderId != me &&
              !m.isSystem,
        )
        .length;
    _push.add(
      ChatEvent(_nextId(), '${++_event}', 'READ.UPDATED', id, {
        'lastReadSeq': r.conv.lastReadSeq,
        'unreadCount': r.conv.unreadCount,
      }),
    );
    return (lastReadSeq: r.conv.lastReadSeq, unreadCount: r.conv.unreadCount);
  }

  @override
  Future<Conversation> createGroup(
    String requestId,
    String name,
    List<String> memberIds,
  ) {
    final r = _make(
      _nextId(),
      'GROUP',
      name,
      [(me, 'OWNER'), for (final m in memberIds) (m, 'MEMBER')],
      owner: me,
      role: 'OWNER',
    );
    _add(r, null, type: 'SYSTEM', system: '你创建了群聊');
    r.conv.lastReadSeq = r.conv.lastSeq;
    return _wait(r.conv.clone());
  }

  void _version(_Room r, int expected) {
    if (r.conv.version != expected) {
      _fail(409, 'VERSION_CONFLICT', '群信息已被他人修改，请刷新');
    }
    if (r.conv.dissolved) _fail(409, 'GROUP_NOT_WRITABLE', '该群已解散');
  }

  Conversation _bump(_Room r) {
    r.conv
      ..version += 1
      ..memberCount = r.members.length;
    _emitConv(r);
    return r.conv.clone();
  }

  @override
  Future<Conversation> rename(String id, String name, int version) async {
    final r = _room(id);
    _version(r, version);
    r.conv.name = name;
    return _bump(r);
  }

  @override
  Future<List<GroupMember>> members(String id) {
    final r = _room(id);
    return _wait([
      for (final m in r.members)
        GroupMember(
          m.$1,
          _name(m.$1),
          _contacts.where((c) => c.userId == m.$1).firstOrNull?.departmentName,
          m.$2,
        ),
    ]);
  }

  @override
  Future<Conversation> addMembers(
    String id,
    List<String> ids,
    int version,
  ) async {
    final r = _room(id);
    _version(r, version);
    if (ids.any((i) => r.members.any((m) => m.$1 == i))) {
      _fail(409, 'MEMBER_ALREADY_PRESENT', '成员已在群中');
    }
    r.members.addAll([for (final i in ids) (i, 'MEMBER')]);
    _add(
      r,
      null,
      type: 'SYSTEM',
      system: '你邀请 ${ids.map(_name).join('、')} 加入了群聊',
    );
    return _bump(r);
  }

  @override
  Future<Conversation> removeMember(
    String id,
    String userId,
    int version,
  ) async {
    final r = _room(id);
    _version(r, version);
    r.members.removeWhere((m) => m.$1 == userId);
    _add(r, null, type: 'SYSTEM', system: '${_name(userId)} 被移出了群聊');
    return _bump(r);
  }

  @override
  Future<Conversation> setRole(
    String id,
    String userId,
    String role,
    int version,
  ) async {
    final r = _room(id);
    _version(r, version);
    final i = r.members.indexWhere((m) => m.$1 == userId);
    if (i >= 0) r.members[i] = (userId, role);
    return _bump(r);
  }

  @override
  Future<Conversation> transfer(
    String id,
    String newOwnerId,
    int version,
  ) async {
    final r = _room(id);
    _version(r, version);
    for (var i = 0; i < r.members.length; i++) {
      if (r.members[i].$1 == me) r.members[i] = (me, 'ADMIN');
      if (r.members[i].$1 == newOwnerId) r.members[i] = (newOwnerId, 'OWNER');
    }
    r.conv
      ..ownerId = newOwnerId
      ..myRole = 'ADMIN';
    _add(r, null, type: 'SYSTEM', system: '你将群主转让给 ${_name(newOwnerId)}');
    return _bump(r);
  }

  @override
  Future<void> leave(String id, int version) async {
    final r = _room(id);
    if (r.conv.myRole == 'OWNER') {
      _fail(409, 'OWNER_TRANSFER_REQUIRED', '请先转让群主');
    }
    r.members.removeWhere((m) => m.$1 == me);
    _emit('CONVERSATION.REVOKED', id, {'reason': 'LEFT'});
  }

  @override
  Future<Conversation> dissolve(String id, int version) async {
    final r = _room(id);
    _version(r, version);
    r.conv.status = 'DISSOLVED';
    _add(r, null, type: 'SYSTEM', system: '群主已解散该群聊，仅可查看历史');
    return _bump(r);
  }

  @override
  Future<UploadReservation> reserveUpload({
    required String clientUploadId,
    required String conversationId,
    required String name,
    required int size,
    required String mime,
    required String sha256,
  }) {
    _room(conversationId);
    final id = _nextId();
    _uploads[id] = _Up(ChatFile(_nextId(), name, size, mime));
    return _wait(
      UploadReservation(id, 'mock://upload/$id', {'Content-Type': mime}),
    );
  }

  @override
  Future<void> putFile(
    UploadReservation reservation,
    File file,
    int length, {
    required void Function(double) onProgress,
    CancelToken? cancel,
  }) async {
    for (final p in [0.25, 0.55, 0.85, 1.0]) {
      if (cancel?.isCancelled ?? false) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: 'cancel',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 220));
      onProgress(p);
    }
  }

  @override
  Future<UploadState> complete(String uploadId) async {
    final up = _uploads[uploadId]!;
    up.status = 'VERIFYING';
    final reject = RegExp(
      r'受限|virus|\.exe$',
      caseSensitive: false,
    ).hasMatch(up.file.name);
    Timer(const Duration(milliseconds: 1200), () {
      if (up.status != 'VERIFYING') return;
      up.status = reject ? 'REJECTED' : 'READY';
      up.reason = reject ? '未通过安全检查，已拦截' : null;
    });
    return const UploadState('VERIFYING', null, null);
  }

  @override
  Future<UploadState> uploadStatus(String uploadId) {
    final up = _uploads[uploadId]!;
    return _wait(
      UploadState(up.status, up.status == 'READY' ? up.file : null, up.reason),
    );
  }

  @override
  Future<void> cancelUpload(String uploadId) async =>
      _uploads[uploadId]?.status = 'CANCELLED';
  @override
  Future<List<int>> download(String fileId) =>
      _wait('mock file content'.codeUnits);
  @override
  Future<WsTicket> issueTicket(String clientId) =>
      _wait((path: '/ws/chat?ticket=mock', heartbeat: 30, idle: 90));
  @override
  Future<({List<ChatEvent> records, bool hasMore})> syncEvents(
    String afterSeq,
  ) => _wait((records: const <ChatEvent>[], hasMore: false));
}

class _Room {
  final Conversation conv;
  final List<(String, String)> members;
  final messages = <ChatMessage>[];
  _Room(this.conv, this.members);
}

class _Up {
  final ChatFile file;
  String status = 'INITIATED';
  String? reason;
  _Up(this.file);
}
