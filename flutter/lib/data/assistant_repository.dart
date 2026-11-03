import 'package:dio/dio.dart';
import 'package:origin_mobile/core/session.dart';

/// AI 助手（`/ai/*`）：会话、消息、流式回答与待确认动作。
class AssistantRepository {
  final Session session;
  AssistantRepository(this.session);

  Future<List<Json>> conversations() async =>
      (await session.api.call('/ai/conversation') as List).cast<Json>();

  Future<Json> conversation(String id) async =>
      await session.api.call('/ai/conversation/$id') as Json;

  Future<List<Json>> messages(String id) async =>
      (await session.api.call('/ai/message/$id') as List).cast<Json>();

  /// 返回新会话 ID。
  Future<String> create() async {
    final created =
        await session.api.call('/ai/conversation', method: 'POST') as Json;
    return '${created['conversationId']}';
  }

  /// 流式提问；事件沿用服务端 CONTENT / TITLE / ACTION / ERROR。
  Future<void> ask(
    String conversationId,
    String message,
    CancelToken cancel,
    void Function(Json event) onEvent,
  ) => session.api.stream(conversationId, message, cancel, onEvent);

  Future<void> archive(String id) async {
    await session.api.call('/ai/conversation/$id/archive', method: 'PUT');
  }

  Future<void> executeAction(String token) async {
    await session.api.call(
      '/ai/action/${Uri.encodeComponent(token)}/execute',
      method: 'POST',
    );
  }
}
