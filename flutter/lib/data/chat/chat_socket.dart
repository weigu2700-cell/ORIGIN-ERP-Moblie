import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:origin_mobile/domain/chat.dart';
import 'package:origin_mobile/data/chat/chat_api.dart';

enum ChatConnection { idle, connecting, online, reconnecting, offline }

/// 聊天 WebSocket：REST 换取一次性票据 → 连接 → SESSION.READY 后补拉。
/// 断线指数退避并重新取票；超过 idleTimeout 没有任何帧则主动重连。
class ChatSocket {
  final ChatApi api;
  final String baseUrl;
  final Future<String> Function() clientId;
  final void Function(ChatConnection) onState;
  final void Function() onReady;
  final void Function(ChatEvent) onEvent;
  ChatSocket({
    required this.api,
    required this.baseUrl,
    required this.clientId,
    required this.onState,
    required this.onReady,
    required this.onEvent,
  });

  WebSocket? _socket;
  Timer? _retry, _heartbeat, _watchdog;
  bool _stopped = true;
  int _attempt = 0, _generation = 0;
  static const _terminal = {1000, 1008, 4401, 4403, 4409};

  Uri _uri(String path) {
    final base = Uri.parse(baseUrl);
    final target = Uri.parse(path.startsWith('/') ? path : '/$path');
    // 只连接当前 API 服务器，不接受任意目标。
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: target.path,
      query: target.query,
    );
  }

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _attempt = 0;
    unawaited(_connect());
  }

  /// 应用回到前台或网络恢复时调用。
  void resume() {
    if (_stopped || _socket?.readyState == WebSocket.open || _retry != null) {
      return;
    }
    _attempt = 0;
    unawaited(_connect());
  }

  void stop() {
    _stopped = true;
    _generation++;
    _clear();
    _socket?.close(1000);
    _socket = null;
    onState(ChatConnection.idle);
  }

  void _clear() {
    _retry?.cancel();
    _heartbeat?.cancel();
    _watchdog?.cancel();
    _retry = _heartbeat = _watchdog = null;
  }

  void _schedule() {
    if (_stopped || _retry != null) return;
    onState(ChatConnection.reconnecting);
    final delay = Duration(seconds: min(30, 1 << min(_attempt, 5)));
    _attempt++;
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(_connect());
    });
  }

  Future<void> _connect() async {
    if (_stopped) return;
    final mine = ++_generation;
    _clear();
    _socket?.close();
    onState(
      _attempt == 0 ? ChatConnection.connecting : ChatConnection.reconnecting,
    );
    try {
      final ticket = await api.issueTicket(await clientId());
      if (_stopped || mine != _generation) return;
      final ws = await WebSocket.connect(_uri(ticket.path).toString());
      if (_stopped || mine != _generation) {
        await ws.close();
        return;
      }
      _socket = ws;
      void arm() {
        _watchdog?.cancel();
        _watchdog = Timer(Duration(seconds: ticket.idle), () => ws.close());
      }

      arm();
      ws.listen(
        (data) {
          arm();
          Map<String, dynamic> frame;
          try {
            frame = jsonDecode('$data') as Map<String, dynamic>;
          } catch (_) {
            return;
          }
          if (frame['type'] == 'SESSION.READY') {
            _attempt = 0;
            onState(ChatConnection.online);
            onReady();
            _heartbeat = Timer.periodic(Duration(seconds: ticket.heartbeat), (
              _,
            ) {
              if (ws.readyState == WebSocket.open) {
                ws.add(
                  jsonEncode({
                    'type': 'PING',
                    'nonce': '${DateTime.now().microsecondsSinceEpoch}',
                  }),
                );
              }
            });
            return;
          }
          if (frame['type'] == 'PONG' || frame['type'] == 'PROTOCOL.ERROR') {
            return;
          }
          if (frame['eventId'] != null) onEvent(ChatEvent.fromJson(frame));
        },
        onDone: () {
          if (mine != _generation) return;
          _clear();
          _socket = null;
          if (_stopped) return;
          if (_terminal.contains(ws.closeCode)) {
            onState(ChatConnection.offline);
            return;
          }
          _schedule();
        },
        onError: (_) => ws.close(),
        cancelOnError: true,
      );
    } catch (_) {
      if (!_stopped && mine == _generation) _schedule();
    }
  }
}
