import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  final String message;
  final int? code;
  final bool unknownResult;

  /// 聊天等模块的领域错误码（响应 data.error），如 VERSION_CONFLICT。
  final String? error;
  const ApiFailure(
    this.message, {
    this.code,
    this.unknownResult = false,
    this.error,
  });
  @override
  String toString() => message;
}

class SessionChanged extends ApiFailure {
  const SessionChanged() : super('身份已改变，请重新打开页面');
}

/// Dio 负责连接、JSON、超时与取消；这里只保留本项目的身份和响应契约。
class ApiClient {
  final String baseUrl;
  final Dio _dio;
  final _requests = <CancelToken>{};
  String? token;
  int generation = 0;
  void Function()? onUnauthorized;
  ApiClient(this.baseUrl, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            ),
          );

  void boundary([String? nextToken]) {
    generation++;
    token = nextToken;
    for (final request in _requests.toList()) {
      request.cancel('session changed');
    }
    _requests.clear();
  }

  /// 区分超时、证书和连接被拒，并带上目标地址，避免所有网络错误都显示同一句话。
  String connectionMessage(DioException error) {
    final target = Uri.tryParse(baseUrl);
    final where = target == null ? baseUrl : '${target.host}:${target.port}';
    final reason = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => '连接超时',
      DioExceptionType.badCertificate => '证书不受信任',
      DioExceptionType.badResponse =>
        'HTTP ${error.response?.statusCode ?? ''}',
      _ => '${error.error ?? error.message ?? '连接被拒绝'}',
    };
    return '无法连接服务器 $where（$reason）。请检查地址、网络和是否允许 HTTP';
  }

  void check(int ticket) {
    if (ticket != generation) throw const SessionChanged();
  }

  Uri uri(String path, Map<String, dynamic> query) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty) {
      throw const ApiFailure('请使用 --dart-define=API_BASE_URL 配置服务器绝对地址');
    }
    return Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null && entry.value.toString().isNotEmpty)
            entry.key: entry.value.toString(),
      },
    );
  }

  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic> query = const {},
    dynamic body,
    bool auth = true,
  }) async {
    final ticket = generation;
    final write = method != 'GET';
    final cancel = CancelToken();
    _requests.add(cancel);
    try {
      final response = await _dio.requestUri<dynamic>(
        uri(path, query),
        data: body,
        cancelToken: cancel,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          headers: {
            if (auth && token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      check(ticket);
      final payload = response.data;
      final status = response.statusCode ?? 0;
      final code = payload is Map ? payload['code'] : null;
      if (auth && (status == 401 || code == 401)) {
        onUnauthorized?.call();
        throw const ApiFailure('登录已失效，请重新登录', code: 401);
      }
      if (status < 200 || status >= 300 || code != 200) {
        throw ApiFailure(
          payload is Map ? (payload['msg'] ?? '请求失败').toString() : '服务响应异常',
          code: code is int ? code : status,
          unknownResult: write && status >= 500,
          error: payload is Map && payload['data'] is Map
              ? (payload['data'] as Map)['error']?.toString()
              : null,
        );
      }
      if (payload is! Map || !payload.containsKey('data')) {
        throw ApiFailure('服务响应缺少 data', unknownResult: write);
      }
      return payload['data'];
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      check(ticket);
      final unknown = write && error.type != DioExceptionType.connectionTimeout;
      throw ApiFailure(
        unknown ? '执行结果未知，请先回查单据，勿重复提交' : connectionMessage(error),
        unknownResult: unknown,
      );
    } finally {
      _requests.remove(cancel);
    }
  }

  /// 签名 URL 直传：不带应用 JWT，只带服务端返回的请求头。
  Future<void> putSigned(
    String url,
    Map<String, String> headers,
    Stream<List<int>> data,
    int length, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    final ticket = generation;
    final token = cancel ?? CancelToken();
    _requests.add(token);
    try {
      final response = await Dio(BaseOptions(validateStatus: (_) => true))
          .putUri<dynamic>(
            Uri.parse(url),
            data: data,
            cancelToken: token,
            onSendProgress: onProgress,
            options: Options(headers: {...headers, 'Content-Length': length}),
          );
      check(ticket);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiFailure('文件上传失败（HTTP $status）', code: status);
      }
    } on DioException catch (error) {
      check(ticket);
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiFailure(connectionMessage(error));
    } finally {
      _requests.remove(token);
    }
  }

  /// 鉴权下载二进制内容（聊天附件）。
  Future<List<int>> downloadBytes(String path) async {
    final ticket = generation;
    final cancel = CancelToken();
    _requests.add(cancel);
    try {
      final response = await _dio.requestUri<List<int>>(
        uri(path, const {}),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      check(ticket);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiFailure('下载失败（HTTP $status）', code: status);
      }
      return response.data ?? const [];
    } on DioException catch (error) {
      check(ticket);
      throw ApiFailure(connectionMessage(error));
    } finally {
      _requests.remove(cancel);
    }
  }

  Future<void> stream(
    String id,
    String message,
    CancelToken cancel,
    void Function(Map<String, dynamic>) onEvent,
  ) async {
    final ticket = generation;
    _requests.add(cancel);
    try {
      final response = await _dio.postUri<ResponseBody>(
        uri('/ai/assistant/chat/stream', {}),
        data: {'conversationId': id, 'message': message},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      check(ticket);
      if (response.statusCode == 401) {
        onUnauthorized?.call();
        throw const ApiFailure('登录已失效', code: 401);
      }
      if (response.statusCode != 200 ||
          response.headers
                  .value('content-type')
                  ?.startsWith('text/event-stream') !=
              true) {
        throw const ApiFailure('AI 响应异常，请回查历史');
      }
      await for (final payload in decodeSse(
        response.data!.stream.timeout(const Duration(seconds: 60)),
      )) {
        check(ticket);
        if (payload == '[DONE]') break;
        final event = jsonDecode(payload) as Map<String, dynamic>;
        if (event['type'] == 'ERROR') {
          throw ApiFailure(event['content']?.toString() ?? 'AI 响应失败');
        }
        onEvent(event);
      }
    } finally {
      _requests.remove(cancel);
    }
  }
}

/// 解析后端 POST SSE 帧；不自动重发问题，避免重复生成或执行动作。
Stream<String> decodeSse(Stream<List<int>> bytes) async* {
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield data.join('\n');
        data.clear();
      }
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
  if (data.isNotEmpty) yield data.join('\n');
}

/// 服务端 Long 以字符串返回分页总数、未读数，这里统一容忍数字与数字字符串。
int asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
