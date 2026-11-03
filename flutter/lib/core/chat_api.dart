import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/chat.dart';
import 'api.dart';
import 'session.dart';

typedef Snapshot = ({
  List<Conversation> records,
  String syncEventSeq,
  int unread,
});
typedef HistoryPage = ({List<ChatMessage> records, bool hasMore});
typedef SendResult = ChatMessage;
typedef WsTicket = ({String path, int heartbeat, int idle});

/// 后端聊天能力；真实实现走 REST，Mock 用于接口上线前联调界面。
abstract class ChatApi {
  Future<ChatConfig> config();
  Future<List<Contact>> contacts({String? keyword});
  Future<Conversation> createDirect(String peerUserId);
  Future<Snapshot> snapshot();
  Future<Conversation> conversation(String id);
  Future<void> setMuted(String id, bool muted);
  Future<SendResult> send(
    String id, {
    required String clientMessageId,
    required String type,
    String? text,
    String? fileId,
  });
  Future<HistoryPage> history(String id, {String? beforeSeq, int limit = 30});
  Future<ChatMessage?> byClientId(String clientMessageId);
  Future<({String lastReadSeq, int unreadCount})> markRead(
    String id,
    String throughSeq,
  );
  Future<Conversation> createGroup(
    String clientRequestId,
    String name,
    List<String> memberIds,
  );
  Future<Conversation> rename(String id, String name, int version);
  Future<List<GroupMember>> members(String id);
  Future<Conversation> addMembers(String id, List<String> ids, int version);
  Future<Conversation> removeMember(String id, String userId, int version);
  Future<Conversation> setRole(
    String id,
    String userId,
    String role,
    int version,
  );
  Future<Conversation> transfer(String id, String newOwnerId, int version);
  Future<void> leave(String id, int version);
  Future<Conversation> dissolve(String id, int version);
  Future<UploadReservation> reserveUpload({
    required String clientUploadId,
    required String conversationId,
    required String name,
    required int size,
    required String mime,
    required String sha256,
  });
  Future<void> putFile(
    UploadReservation reservation,
    File file,
    int length, {
    required void Function(double) onProgress,
    CancelToken? cancel,
  });
  Future<UploadState> complete(String uploadId);
  Future<UploadState> uploadStatus(String uploadId);
  Future<void> cancelUpload(String uploadId);
  Future<List<int>> download(String fileId);
  Future<WsTicket> issueTicket(String clientId);
  Future<({List<ChatEvent> records, bool hasMore})> syncEvents(String afterSeq);

  /// 仅 Mock 提供：服务端推送；真实实现通过 WebSocket。
  Stream<ChatEvent>? get pushed => null;
}

class HttpChatApi implements ChatApi {
  final Session session;
  HttpChatApi(this.session);
  ApiClient get _api => session.api;
  Future<Json> _obj(
    String path, {
    String method = 'GET',
    Json query = const {},
    dynamic body,
  }) async =>
      (await _api.call(path, method: method, query: query, body: body)) as Json;

  @override
  Stream<ChatEvent>? get pushed => null;
  @override
  Future<ChatConfig> config() async =>
      ChatConfig.fromJson(await _obj('/im/config'));
  @override
  Future<List<Contact>> contacts({String? keyword}) async {
    final page = await _obj(
      '/im/contacts',
      query: {'keyword': keyword, 'limit': 100},
    );
    return (page['records'] as List)
        .map((e) => Contact.fromJson((e as Map).cast()))
        .toList();
  }

  @override
  Future<Conversation> createDirect(String peerUserId) async =>
      Conversation.fromJson(
        await _obj(
          '/im/conversations/direct',
          method: 'POST',
          body: {'peerUserId': peerUserId},
        ),
      )..peerUserId = peerUserId;
  @override
  Future<Snapshot> snapshot() async {
    var page = await _obj('/im/conversations', query: {'limit': 100});
    final all = <Conversation>[
      ...(page['records'] as List).map(
        (e) => Conversation.fromJson((e as Map).cast()),
      ),
    ];
    while (page['hasMore'] == true && page['nextCursor'] != null) {
      page = await _obj(
        '/im/conversations',
        query: {
          'snapshotToken': page['snapshotToken'],
          'cursor': page['nextCursor'],
          'limit': 100,
        },
      );
      all.addAll(
        (page['records'] as List).map(
          (e) => Conversation.fromJson((e as Map).cast()),
        ),
      );
    }
    return (
      records: all,
      syncEventSeq: '${page['syncEventSeq']}',
      unread: asInt(page['totalUnreadCount']),
    );
  }

  @override
  Future<Conversation> conversation(String id) async =>
      Conversation.fromJson(await _obj('/im/conversations/$id'));
  @override
  Future<void> setMuted(String id, bool muted) => _api.call(
    '/im/conversations/$id/preferences',
    method: 'PUT',
    body: {'muted': muted},
  );
  @override
  Future<SendResult> send(
    String id, {
    required String clientMessageId,
    required String type,
    String? text,
    String? fileId,
  }) async {
    final r = await _obj(
      '/im/conversations/$id/messages',
      method: 'POST',
      body: {
        'clientMessageId': clientMessageId,
        'type': type,
        if (text != null) 'text': text,
        if (fileId != null) 'fileId': fileId,
      },
    );
    return ChatMessage.fromJson((r['message'] as Map).cast());
  }

  @override
  Future<HistoryPage> history(
    String id, {
    String? beforeSeq,
    int limit = 30,
  }) async {
    final r = await _obj(
      '/im/conversations/$id/messages',
      query: {'beforeSeq': beforeSeq, 'limit': limit},
    );
    return (
      records: (r['records'] as List)
          .map((e) => ChatMessage.fromJson((e as Map).cast()))
          .toList(),
      hasMore: r['hasMore'] == true,
    );
  }

  @override
  Future<ChatMessage?> byClientId(String clientMessageId) async {
    try {
      return ChatMessage.fromJson(
        await _obj(
          '/im/messages/by-client-id',
          query: {'clientMessageId': clientMessageId},
        ),
      );
    } on ApiFailure {
      return null; // 404：尚未提交
    }
  }

  @override
  Future<({String lastReadSeq, int unreadCount})> markRead(
    String id,
    String throughSeq,
  ) async {
    final r = await _obj(
      '/im/conversations/$id/read',
      method: 'PUT',
      body: {'throughSeq': throughSeq},
    );
    return (
      lastReadSeq: '${r['lastReadSeq']}',
      unreadCount: asInt(r['unreadCount']),
    );
  }

  @override
  Future<Conversation> createGroup(
    String clientRequestId,
    String name,
    List<String> memberIds,
  ) async => Conversation.fromJson(
    await _obj(
      '/im/groups',
      method: 'POST',
      body: {
        'clientRequestId': clientRequestId,
        'name': name,
        'memberIds': memberIds,
      },
    ),
  );
  @override
  Future<Conversation> rename(String id, String name, int version) async =>
      Conversation.fromJson(
        await _obj(
          '/im/groups/$id',
          method: 'PUT',
          body: {'name': name, 'expectedVersion': version},
        ),
      );
  @override
  Future<List<GroupMember>> members(String id) async {
    final r = await _obj('/im/groups/$id/members', query: {'limit': 100});
    return (r['records'] as List)
        .map((e) => GroupMember.fromJson((e as Map).cast()))
        .toList();
  }

  @override
  Future<Conversation> addMembers(
    String id,
    List<String> ids,
    int version,
  ) async => Conversation.fromJson(
    await _obj(
      '/im/groups/$id/members',
      method: 'POST',
      body: {'memberIds': ids, 'expectedVersion': version},
    ),
  );
  @override
  Future<Conversation> removeMember(
    String id,
    String userId,
    int version,
  ) async => Conversation.fromJson(
    await _obj(
      '/im/groups/$id/members/$userId',
      method: 'DELETE',
      query: {'expectedVersion': version},
    ),
  );
  @override
  Future<Conversation> setRole(
    String id,
    String userId,
    String role,
    int version,
  ) async => Conversation.fromJson(
    await _obj(
      '/im/groups/$id/members/$userId/role',
      method: 'PUT',
      body: {'role': role, 'expectedVersion': version},
    ),
  );
  @override
  Future<Conversation> transfer(
    String id,
    String newOwnerId,
    int version,
  ) async => Conversation.fromJson(
    await _obj(
      '/im/groups/$id/transfer',
      method: 'POST',
      body: {'newOwnerId': newOwnerId, 'expectedVersion': version},
    ),
  );
  @override
  Future<void> leave(String id, int version) => _api.call(
    '/im/groups/$id/leave',
    method: 'POST',
    body: {'expectedVersion': version},
  );
  @override
  Future<Conversation> dissolve(String id, int version) async =>
      Conversation.fromJson(
        await _obj(
          '/im/groups/$id/dissolve',
          method: 'POST',
          body: {'expectedVersion': version},
        ),
      );
  @override
  Future<UploadReservation> reserveUpload({
    required String clientUploadId,
    required String conversationId,
    required String name,
    required int size,
    required String mime,
    required String sha256,
  }) async => UploadReservation.fromJson(
    await _obj(
      '/im/uploads',
      method: 'POST',
      body: {
        'clientUploadId': clientUploadId,
        'conversationId': conversationId,
        'name': name,
        'size': size,
        'mime': mime,
        'sha256': sha256,
      },
    ),
  );
  @override
  Future<void> putFile(
    UploadReservation reservation,
    File file,
    int length, {
    required void Function(double) onProgress,
    CancelToken? cancel,
  }) => _api.putSigned(
    reservation.url,
    reservation.headers,
    file.openRead(),
    length,
    onProgress: (sent, total) => onProgress(total > 0 ? sent / total : 0),
    cancel: cancel,
  );
  @override
  Future<UploadState> complete(String uploadId) async => UploadState.fromJson(
    await _obj('/im/uploads/$uploadId/complete', method: 'POST'),
  );
  @override
  Future<UploadState> uploadStatus(String uploadId) async =>
      UploadState.fromJson(await _obj('/im/uploads/$uploadId'));
  @override
  Future<void> cancelUpload(String uploadId) =>
      _api.call('/im/uploads/$uploadId', method: 'DELETE');
  @override
  Future<List<int>> download(String fileId) =>
      _api.downloadBytes('/im/files/$fileId/content');
  @override
  Future<WsTicket> issueTicket(String clientId) async {
    final r = await _obj(
      '/im/ws-tickets',
      method: 'POST',
      body: {'clientId': clientId},
    );
    return (
      path: '${r['websocketPath']}',
      heartbeat: asInt(r['heartbeatSeconds']) == 0
          ? 30
          : asInt(r['heartbeatSeconds']),
      idle: asInt(r['idleTimeoutSeconds']) == 0
          ? 90
          : asInt(r['idleTimeoutSeconds']),
    );
  }

  @override
  Future<({List<ChatEvent> records, bool hasMore})> syncEvents(
    String afterSeq,
  ) async {
    final r = await _obj(
      '/im/sync/events',
      query: {'afterEventSeq': afterSeq, 'limit': 100},
    );
    return (
      records: (r['records'] as List)
          .map((e) => ChatEvent.fromJson((e as Map).cast()))
          .toList(),
      hasMore: r['hasMore'] == true,
    );
  }
}
