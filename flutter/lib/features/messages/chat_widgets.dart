import 'package:flutter/material.dart';

import 'package:origin_mobile/domain/chat.dart';
import 'package:origin_mobile/domain/chat_format.dart';
import 'package:origin_mobile/ui/cards.dart';
import 'package:origin_mobile/ui/theme.dart';

const _palette = [
  Color(0xFF3C7C9C),
  Color(0xFF2A8C6A),
  Color(0xFFD99A2B),
  Color(0xFF8B67C7),
  Color(0xFFC44F4F),
  Color(0xFF3B6FB5),
  Color(0xFF5A8A3C),
];

/// 用户为姓名后两字 + 稳定色；群为统一图标；系统通知为铃铛。
class ChatAvatar extends StatelessWidget {
  final String name, userId;
  final double size;
  final bool group, system, dissolved;
  const ChatAvatar({
    super.key,
    this.name = '',
    this.userId = '',
    this.size = 44,
    this.group = false,
    this.system = false,
    this.dissolved = false,
  });
  @override
  Widget build(BuildContext context) {
    final tail = userId.length >= 2
        ? userId.substring(userId.length - 2)
        : userId;
    final color =
        _palette[(int.tryParse(tail) ?? name.length) % _palette.length];
    return Opacity(
      opacity: dissolved ? 0.55 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: group || system
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3C7C9C), AppTokens.brandDeep],
                )
              : null,
          color: group || system ? null : color,
        ),
        child: group || system
            ? Icon(
                group ? Icons.groups : Icons.notifications_active,
                color: Colors.white,
                size: size * 0.55,
              )
            : Text(
                name.isEmpty
                    ? '?'
                    : (name.length > 2
                          ? name.substring(name.length - 2)
                          : name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

Color _extColor(String ext) => switch (ext) {
  'xlsx' || 'csv' => const Color(0xFF2A8C6A),
  'pdf' => const Color(0xFFC44F4F),
  'docx' => const Color(0xFF3B6FB5),
  'zip' => const Color(0xFF8B67C7),
  'jpg' || 'jpeg' || 'png' || 'webp' => AppTokens.accent,
  _ => const Color(0xFF6F7F89),
};

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine, showName;
  final String senderName;
  final VoidCallback? onRetry, onDiscard, onCancel, onDownload, onPreview;
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.showName,
    required this.senderName,
    this.onRetry,
    this.onDiscard,
    this.onCancel,
    this.onDownload,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: AppTokens.brand.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            m.systemText ?? '',
            style: const TextStyle(fontSize: 12, color: AppTokens.muted),
          ),
        ),
      );
    }
    final failed = m.local == LocalState.failed;
    final content = switch (m.type) {
      'TEXT' => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: failed
              ? const Color(0xFFF3D6D6)
              : mine
              ? AppTokens.brand
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 14 : 4),
            topRight: Radius.circular(mine ? 4 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
        ),
        child: SelectableText(
          m.text ?? '',
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: failed
                ? const Color(0xFF7A2B2B)
                : mine
                ? Colors.white
                : AppTokens.ink,
          ),
        ),
      ),
      'IMAGE' => _image(),
      _ => _file(),
    };
    final status = switch (m.local) {
      LocalState.sending => const Text(
        '发送中…',
        style: TextStyle(fontSize: 11, color: AppTokens.muted),
      ),
      LocalState.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 13, color: Color(0xFFC44F4F)),
          const SizedBox(width: 3),
          Text(
            m.reason ?? '发送失败',
            style: const TextStyle(fontSize: 11, color: Color(0xFFC44F4F)),
          ),
          if (m.type == 'TEXT' && onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                '重试',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTokens.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDiscard,
            child: const Text(
              '删除',
              style: TextStyle(fontSize: 11, color: AppTokens.muted),
            ),
          ),
        ],
      ),
      _ => Text(
        clock(m.createdAt),
        style: const TextStyle(fontSize: 11, color: AppTokens.muted),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            ChatAvatar(name: senderName, userId: m.senderId ?? '', size: 36),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showName && !mine)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 3),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.muted,
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: m.local == LocalState.sending ? 0.7 : 1,
                    child: content,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
                    child: status,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    final f = message.file;
    return GestureDetector(
      onTap: message.local == null ? onPreview : null,
      child: Container(
        width: 210,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FB3C4), Color(0xFFD99A2B)],
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.image_outlined,
                size: 42,
                color: Colors.white70,
              ),
            ),
            if (message.local == LocalState.uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTokens.brandDeep.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${(message.progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Text(
                '${f?.name ?? ''} · ${fmtBytes(f?.size ?? 0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _file() {
    final f = message.file!;
    final local = message.local;
    final color = _extColor(f.ext);
    final sub = switch (local) {
      LocalState.uploading => Text(
        '${fmtBytes(f.size)} · 上传中 ${(message.progress * 100).round()}%',
        style: const TextStyle(fontSize: 12, color: AppTokens.muted),
      ),
      LocalState.verifying => const Text(
        '正在安全检查…',
        style: TextStyle(fontSize: 12, color: AppTokens.accent),
      ),
      LocalState.rejected => Text(
        message.reason ?? '文件未通过检查',
        style: const TextStyle(fontSize: 12, color: Color(0xFFC44F4F)),
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmtBytes(f.size),
            style: const TextStyle(fontSize: 12, color: AppTokens.muted),
          ),
          if (local == null)
            const Text(
              ' · 已通过检查',
              style: TextStyle(fontSize: 12, color: Color(0xFF2A8C6A)),
            ),
        ],
      ),
    };
    return GestureDetector(
      onTap: local == null ? onDownload : null,
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: local == LocalState.rejected
                ? const Color(0xFFE8C4C4)
                : AppTokens.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                f.ext.length > 4
                    ? f.ext.substring(0, 4).toUpperCase()
                    : f.ext.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  sub,
                  if (local == LocalState.uploading)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ProgressBar(message.progress),
                    ),
                  if (local == LocalState.verifying)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          color: AppTokens.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (local == LocalState.uploading || local == LocalState.verifying)
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                tooltip: '取消上传',
              )
            else if (local == LocalState.rejected)
              IconButton(
                onPressed: onDiscard,
                icon: const Icon(Icons.close, size: 18),
                tooltip: '移除',
              )
            else if (local == null)
              const Icon(
                Icons.download_outlined,
                color: AppTokens.brand,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
