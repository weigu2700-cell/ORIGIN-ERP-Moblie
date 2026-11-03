import '../core/api.dart';
import '../core/session.dart';

/// 员工聊天 V1 领域模型，字段对齐后端 api.md。ID、seq 一律保持字符串。
int cmpSeq(String a, String b) => BigInt.parse(
  a.isEmpty ? '0' : a,
).compareTo(BigInt.parse(b.isEmpty ? '0' : b));

String _s(Object? v) => v?.toString() ?? '';
DateTime _t(Object? v) => DateTime.tryParse(_s(v))?.toLocal() ?? DateTime.now();

class Contact {
  final String userId, displayName;
  final String? departmentName;
  const Contact(this.userId, this.displayName, [this.departmentName]);
  factory Contact.fromJson(Json j) => Contact(
    _s(j['userId']),
    _s(j['displayName']),
    j['departmentName']?.toString(),
  );
}

class GroupMember extends Contact {
  final String role; // OWNER / ADMIN / MEMBER
  const GroupMember(
    super.userId,
    super.displayName,
    super.departmentName,
    this.role,
  );
  factory GroupMember.fromJson(Json j) => GroupMember(
    _s(j['userId']),
    _s(j['displayName']),
    j['departmentName']?.toString(),
    _s(j['role']),
  );
}

class ChatFile {
  final String id, name, mime;
  final int size;
  const ChatFile(this.id, this.name, this.size, this.mime);
  factory ChatFile.fromJson(Json j) =>
      ChatFile(_s(j['id']), _s(j['name']), asInt(j['size']), _s(j['mime']));
  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isImage => const ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
}

/// 客户端本地的发送/上传状态；服务端消息没有该字段。
enum LocalState { sending, failed, uploading, verifying, rejected }

class ChatMessage {
  final String id, conversationId, clientMessageId, type;
  final String? seq, senderId, text, systemText;
  final ChatFile? file;
  final DateTime createdAt;
  LocalState? local;
  double progress;
  String? reason, uploadId;
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.clientMessageId,
    required this.type,
    this.seq,
    this.senderId,
    this.text,
    this.systemText,
    this.file,
    DateTime? createdAt,
    this.local,
    this.progress = 0,
    this.reason,
    this.uploadId,
  }) : createdAt = createdAt ?? DateTime.now();
  factory ChatMessage.fromJson(Json j) => ChatMessage(
    id: _s(j['id']),
    conversationId: _s(j['conversationId']),
    clientMessageId: _s(j['clientMessageId']),
    type: _s(j['type']),
    seq: _s(j['seq']),
    senderId: j['senderId']?.toString(),
    text: j['text']?.toString(),
    systemText: (j['system'] as Map?)?['description']?.toString(),
    file: j['file'] is Map
        ? ChatFile.fromJson((j['file'] as Map).cast())
        : null,
    createdAt: _t(j['createdAt']),
  );
  bool get isSystem => type == 'SYSTEM';
}

class Conversation {
  final String id, type; // DIRECT / GROUP
  String name, status, lastSeq, lastReadSeq;
  String? ownerId, myRole, peerUserId;
  int version, memberCount, unreadCount;
  bool muted;
  ChatMessage? lastMessage;
  DateTime updatedAt;
  Conversation({
    required this.id,
    required this.type,
    required this.name,
    this.status = 'ACTIVE',
    this.ownerId,
    this.myRole,
    this.peerUserId,
    this.version = 1,
    this.memberCount = 2,
    this.unreadCount = 0,
    this.lastSeq = '0',
    this.lastReadSeq = '0',
    this.muted = false,
    this.lastMessage,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
  factory Conversation.fromJson(Json j) => Conversation(
    id: _s(j['id']),
    type: _s(j['type']),
    name: _s(j['name']),
    status: j['status']?.toString() ?? 'ACTIVE',
    ownerId: j['ownerId']?.toString(),
    myRole: j['myRole']?.toString(),
    peerUserId: j['peerUserId']?.toString(),
    version: asInt(j['version']),
    memberCount: asInt(j['memberCount']),
    unreadCount: asInt(j['unreadCount']),
    lastSeq: _s(j['lastSeq']).isEmpty ? '0' : _s(j['lastSeq']),
    lastReadSeq: _s(j['lastReadSeq']).isEmpty ? '0' : _s(j['lastReadSeq']),
    muted: j['muted'] == true,
    lastMessage: j['lastMessage'] is Map
        ? ChatMessage.fromJson((j['lastMessage'] as Map).cast())
        : null,
    updatedAt: _t(j['updatedAt']),
  );
  void merge(Conversation o) {
    name = o.name;
    status = o.status;
    ownerId = o.ownerId ?? ownerId;
    myRole = o.myRole ?? myRole;
    peerUserId = o.peerUserId ?? peerUserId;
    version = o.version;
    memberCount = o.memberCount;
    unreadCount = o.unreadCount;
    lastSeq = o.lastSeq;
    lastReadSeq = o.lastReadSeq;
    muted = o.muted;
    lastMessage = o.lastMessage ?? lastMessage;
    updatedAt = o.updatedAt;
  }

  Conversation clone() => Conversation(
    id: id,
    type: type,
    name: name,
    status: status,
    ownerId: ownerId,
    myRole: myRole,
    peerUserId: peerUserId,
    version: version,
    memberCount: memberCount,
    unreadCount: unreadCount,
    lastSeq: lastSeq,
    lastReadSeq: lastReadSeq,
    muted: muted,
    lastMessage: lastMessage,
    updatedAt: updatedAt,
  );

  bool get isGroup => type == 'GROUP';
  bool get dissolved => status == 'DISSOLVED';
  bool get canManage => !dissolved && (myRole == 'OWNER' || myRole == 'ADMIN');
  DateTime get activity => lastMessage?.createdAt ?? updatedAt;
}

class ChatEvent {
  final String id, seq, type;
  final String? conversationId;
  final Json payload;
  const ChatEvent(
    this.id,
    this.seq,
    this.type,
    this.conversationId,
    this.payload,
  );
  factory ChatEvent.fromJson(Json j) => ChatEvent(
    _s(j['eventId']),
    _s(j['eventSeq']),
    _s(j['type']),
    j['conversationId']?.toString(),
    ((j['payload'] as Map?) ?? const {}).cast<String, dynamic>(),
  );
}

class UploadReservation {
  final String uploadId, url;
  final Map<String, String> headers;
  const UploadReservation(this.uploadId, this.url, this.headers);
  factory UploadReservation.fromJson(Json j) => UploadReservation(
    _s(j['uploadId']),
    _s(j['uploadUrl']),
    ((j['requiredHeaders'] as Map?) ?? const {}).map(
      (k, v) => MapEntry('$k', '$v'),
    ),
  );
}

class UploadState {
  final String status;
  final ChatFile? file;
  final String? rejection;
  const UploadState(this.status, this.file, this.rejection);
  factory UploadState.fromJson(Json j) => UploadState(
    _s(j['status']),
    j['file'] is Map ? ChatFile.fromJson((j['file'] as Map).cast()) : null,
    j['rejectionReason']?.toString(),
  );
}

class ChatConfig {
  final int maxFileBytes, maxGroupMembers, textMaxChars;
  final List<String> extensions;
  const ChatConfig(
    this.maxFileBytes,
    this.maxGroupMembers,
    this.textMaxChars,
    this.extensions,
  );
  factory ChatConfig.fromJson(Json j) => ChatConfig(
    asInt(j['maxFileBytes']) == 0 ? 50000000 : asInt(j['maxFileBytes']),
    asInt(j['maxGroupMembers']) == 0 ? 200 : asInt(j['maxGroupMembers']),
    asInt(j['textMaxChars']) == 0 ? 4000 : asInt(j['textMaxChars']),
    ((j['allowedExtensions'] as List?) ?? const [])
        .map((e) => '$e'.toLowerCase())
        .toList(),
  );
}
