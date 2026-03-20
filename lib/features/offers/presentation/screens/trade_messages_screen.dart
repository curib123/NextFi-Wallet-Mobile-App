import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/widgets/empty_state/empty_state.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/services/chat/crypto/chat_envelope_codec.dart';
import 'package:next_fi/core/services/base_url/base_url.dart';
import 'package:next_fi/core/services/auth/auth_service.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';
import 'package:next_fi/core/services/trades/models/trades_models.dart';
import 'package:next_fi/core/services/trades/trades_core_service.dart';

class TradeMessagesScreen extends StatefulWidget {
  const TradeMessagesScreen({super.key, required this.trade});
  final TradeModel trade;

  @override
  State<TradeMessagesScreen> createState() => _TradeMessagesScreenState();
}

class _TradeMessagesScreenState extends State<TradeMessagesScreen> {
  static const String _kTradeSenderKeyId = 'trade.chat.sender_key_id.v1';
  static String _lastSeenKey(String tradeId) => 'trade.chat.last_seen.$tradeId';

  static Future<void> markTradeAsRead(String tradeId, {DateTime? at}) async {
    final stamp = (at ?? DateTime.now()).toUtc().toIso8601String();
    await SecurityStorage.save(_lastSeenKey(tradeId), stamp);
  }

  final _tradesCore = TradesCoreService.I;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _currentUserId;
  String? _senderKeyId;
  Timer? _pollTimer;

  bool get _isParticipant =>
      _currentUserId != null &&
      (_currentUserId == widget.trade.buyerId ||
          _currentUserId == widget.trade.sellerId);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadCurrentUser();
    _startPolling();
  }

  @override
  void dispose() {
    unawaited(markTradeAsRead(widget.trade.id));
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService().currentUser;
      final senderKeyId = await _ensureSenderKeyId();
      if (mounted) {
        setState(() {
          _currentUserId = user.id;
          _senderKeyId = senderKeyId;
        });
      }
      await markTradeAsRead(widget.trade.id);
    } catch (_) {}
  }

  Future<String> _ensureSenderKeyId() async {
    try {
      final existing = await SecurityStorage.read(_kTradeSenderKeyId);
      final normalized = existing?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    } catch (_) {}
    final generated = ChatEnvelopeCodec.generateSenderKeyId();
    try {
      await SecurityStorage.save(_kTradeSenderKeyId, generated);
    } catch (_) {}
    return generated;
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await _tradesCore.getTradeMessages(widget.trade.id);
      final normalized = List<Map<String, dynamic>>.from(msgs)
        ..sort((a, b) {
          DateTime? parse(dynamic v) =>
              v == null ? null : DateTime.tryParse(v.toString());
          final ad =
              parse(a['createdAt'] ?? a['created_at']) ??
              parse(a['updatedAt'] ?? a['updated_at']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd =
              parse(b['createdAt'] ?? b['created_at']) ??
              parse(b['updatedAt'] ?? b['updated_at']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        });
      if (!mounted) return;
      setState(() {
        _messages = normalized;
        _loading = false;
      });
      await markTradeAsRead(
        widget.trade.id,
        at: _latestMessageTime(normalized) ?? DateTime.now(),
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  DateTime? _latestMessageTime(List<Map<String, dynamic>> rows) {
    DateTime? latest;
    for (final row in rows) {
      final raw =
          row['createdAt'] ??
          row['created_at'] ??
          row['updatedAt'] ??
          row['updated_at'];
      final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) latest = parsed;
    }
    return latest;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_isParticipant) {
      showFloatingSnackBar(
        context,
        message: 'Only the two people in this trade can chat here.',
        type: SnackBarType.error,
      );
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final senderKeyId = (_senderKeyId ?? '').trim();
    if (senderKeyId.isEmpty) return;
    final envelope = ChatEnvelopeCodec.encodeText(
      plainText: text,
      senderKeyId: senderKeyId,
    );

    setState(() => _sending = true);
    try {
      await _tradesCore.sendTradeMessage(
        widget.trade.id,
        ciphertext: envelope.ciphertext,
        algorithm: envelope.algorithm,
        senderKeyId: envelope.senderKeyId,
        nonce: envelope.nonce,
        kind: envelope.kind.name.toUpperCase(),
      );
      _msgCtrl.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: 'Failed to send: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : _messages.isEmpty
                ? _EmptyState(colors: colors)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      currentUserId: _currentUserId,
                      colors: colors,
                    ),
                  ),
          ),

          _InputBar(
            controller: _msgCtrl,
            colors: colors,
            sending: _sending,
            enabled: _isParticipant,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor colors) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leadingWidth: 50,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: _ChatTopIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          colors: colors,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade Chat',
            style: AppFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            widget.trade.id.length > 16
                ? '${widget.trade.id.substring(0, 12)}...'
                : widget.trade.id,
            style: AppFonts.sora(fontSize: 9.5, color: colors.textSecondary),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ChatTopIconButton(
            icon: Icons.refresh_rounded,
            colors: colors,
            onTap: () => _loadMessages(),
          ),
        ),
      ],
    );
  }
}

class _ChatTopIconButton extends StatelessWidget {
  const _ChatTopIconButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: colors.textSecondary, size: 17),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.currentUserId,
    required this.colors,
  });
  final Map<String, dynamic> message;
  final String? currentUserId;
  final AppColor colors;

  String get _kind => (message['kind'] ?? '').toString().trim().toUpperCase();

  String get _senderId {
    final direct =
        (message['senderId'] ??
                message['sender_id'] ??
                message['senderUserId'] ??
                message['sender_user_id'] ??
                message['userId'] ??
                message['user_id'] ??
                message['authorId'] ??
                message['author_id'] ??
                '')
            .toString()
            .trim();
    if (direct.isNotEmpty) return direct;

    final sender = message['sender'];
    if (sender is Map) {
      final nested = (sender['id'] ?? sender['userId'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }

    final user = message['user'];
    if (user is Map) {
      final nested = (user['id'] ?? user['userId'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }

    return '';
  }

  bool get _isSystem {
    if (_kind == 'SYSTEM') return true;
    return _senderId.isEmpty && _text.isNotEmpty;
  }

  bool get _isMe {
    return currentUserId != null && _senderId == currentUserId;
  }

  String _extractText(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return '';
      final looksLikeJson =
          (raw.startsWith('{') && raw.endsWith('}')) ||
          (raw.startsWith('[') && raw.endsWith(']'));
      if (looksLikeJson) {
        try {
          final decoded = jsonDecode(raw);
          final fromJson = _extractText(decoded);
          return fromJson;
        } catch (_) {}
      }
      return raw;
    }
    if (value is Map) {
      for (final key in const [
        'text',
        'message',
        'content',
        'body',
        'ciphertext',
        'plainText',
        'plain_text',
        'note',
        'description',
      ]) {
        final extracted = _extractText(value[key]);
        if (extracted.isNotEmpty) return extracted;
      }
      for (final key in const ['payload', 'data']) {
        final extracted = _extractText(value[key]);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    if (value is List) {
      for (final item in value) {
        final extracted = _extractText(item);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    return value.toString().trim();
  }

  String _withBreakHints(String input) {
    if (input.isEmpty) return input;
    const chunk = 20;
    return input.replaceAllMapped(RegExp(r'\S+'), (m) {
      final token = m.group(0)!;
      if (token.length <= chunk) return token;
      final b = StringBuffer();
      var i = 0;
      while (i < token.length) {
        if (i > 0) b.write('\u200B');
        final end = (i + chunk < token.length) ? i + chunk : token.length;
        b.write(token.substring(i, end));
        i = end;
      }
      return b.toString();
    });
  }

  String get _text {
    final content = _extractText(
      message['content'] ??
          message['message'] ??
          message['body'] ??
          message['text'],
    );
    if (content.isNotEmpty) return content;

    final ciphertext = _extractText(message['ciphertext']);
    if (ciphertext.isEmpty) return '';

    final algorithm = (message['algorithm'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (algorithm == ChatEnvelopeCodec.messageAlgorithm.toUpperCase()) {
      return ChatEnvelopeCodec.decodeText(ciphertext);
    }
    if (algorithm.isNotEmpty && algorithm != 'PLAIN') {
      return '[Encrypted message]';
    }
    return ciphertext;
  }

  String get _timeStr {
    final raw = message['createdAt'] ?? message['created_at'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _extractImageRef(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return '';
      if (raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('uploads/') ||
          raw.startsWith('upload/') ||
          raw.startsWith('media/') ||
          raw.startsWith('/') ||
          raw.contains(r':\')) {
        return raw;
      }
      final looksLikeJson =
          (raw.startsWith('{') && raw.endsWith('}')) ||
          (raw.startsWith('[') && raw.endsWith(']'));
      if (looksLikeJson) {
        try {
          final decoded = jsonDecode(raw);
          return _extractImageRef(decoded);
        } catch (_) {}
      }
      return '';
    }
    if (value is Map) {
      for (final key in const [
        'localImagePath',
        'imageUrl',
        'image_url',
        'image',
        'mediaUrl',
        'media_url',
        'proof',
        'url',
        'proofUrl',
        'proof_url',
        'fileUrl',
        'file_url',
        'attachmentUrl',
        'attachment_url',
        'path',
      ]) {
        final found = _extractImageRef(value[key]);
        if (found.isNotEmpty) return found;
      }
      for (final key in const [
        'proofUrls',
        'fileUrls',
        'images',
        'attachments',
        'files',
        'proofs',
        'data',
        'payload',
      ]) {
        final found = _extractImageRef(value[key]);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    if (value is List) {
      for (final item in value) {
        final found = _extractImageRef(item);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    return '';
  }

  String get _imageRef {
    final direct = _extractImageRef(
      message['localImagePath'] ??
          message['imageUrl'] ??
          message['proofUrl'] ??
          message['fileUrl'] ??
          message['attachmentUrl'],
    );
    if (direct.isNotEmpty) return direct;
    return _extractImageRef(message);
  }

  String _resolveImageRef(String src) {
    final raw = src.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.contains(r':\')) return raw;
    if (raw.startsWith('/')) {
      return '${centralizedBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}$raw';
    }
    if (raw.startsWith('uploads/') ||
        raw.startsWith('upload/') ||
        raw.startsWith('media/')) {
      return '${centralizedBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}/$raw';
    }
    return raw;
  }

  bool get _hasImage => _imageRef.isNotEmpty;
  bool get _isUploadingProof => message['isUploadingProof'] == true;
  bool get _isProofFailed =>
      (message['proofUploadState'] ?? '').toString().toLowerCase() == 'failed';

  bool _looksLikeUrlOnly(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return false;
    final urlOnly = RegExp(
      r'^(https?:\/\/\S+|\/\S+|uploads\/\S+|upload\/\S+|media\/\S+)$',
      caseSensitive: false,
    );
    return urlOnly.hasMatch(raw);
  }

  bool _containsProofUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return false;
    return RegExp(
      r'(https?:\/\/\S+|\/\S+|uploads\/\S+|upload\/\S+|media\/\S+)',
      caseSensitive: false,
    ).hasMatch(raw);
  }

  void _openImageViewer(BuildContext context) {
    final src = _resolveImageRef(_imageRef);
    final isHttp = src.startsWith('http://') || src.startsWith('https://');
    showDialog<void>(
      context: context,
      barrierColor: colors.textPrimary.withValues(alpha: 0.95),
      builder: (context) => Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: isHttp
                      ? Image.network(
                          src,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_rounded,
                            color: colors.onPrimary,
                            size: 42,
                          ),
                        )
                      : Image.file(
                          File(src),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_rounded,
                            color: colors.onPrimary,
                            size: 42,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, AppColor colors) {
    final src = _resolveImageRef(_imageRef);
    final isHttp = src.startsWith('http://') || src.startsWith('https://');
    final image = isHttp
        ? Image.network(
            src,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageError(colors),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _imageLoading(colors);
            },
          )
        : Image.file(
            File(src),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageError(colors),
          );
    return GestureDetector(
      onTap: () => _openImageViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 220, height: 180, child: image),
      ),
    );
  }

  Widget _imageLoading(AppColor colors) => Container(
    color: colors.surface,
    alignment: Alignment.center,
    child: const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _imageError(AppColor colors) => Container(
    color: colors.surface,
    alignment: Alignment.center,
    child: Icon(Icons.broken_image_rounded, color: colors.textSecondary),
  );

  @override
  Widget build(BuildContext context) {
    if (_isSystem) return _SystemMessage(text: _text, colors: colors);

    final isMe = _isMe;
    final sanitizedText = _withBreakHints(_text);
    final hideProofUrlText =
        _hasImage &&
        (_looksLikeUrlOnly(sanitizedText) || _containsProofUrl(sanitizedText));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 16),
          ),
          border: isMe ? null : Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (_hasImage) ...[
              Stack(
                children: [
                  _buildImage(context, colors),
                  if (_isUploadingProof)
                    Positioned.fill(
                      child: Container(
                        color: colors.textPrimary.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_isUploadingProof || _isProofFailed) ...[
                const SizedBox(height: 6),
                Text(
                  _isUploadingProof ? 'Uploading...' : 'Upload failed',
                  style: AppFonts.sora(
                    fontSize: 11,
                    color: isMe
                        ? colors.onPrimary.withValues(alpha: 0.85)
                        : colors.textSecondary,
                  ),
                ),
              ],
              if (_text.isNotEmpty && !hideProofUrlText)
                const SizedBox(height: 8),
            ],
            if (_text.isNotEmpty && !hideProofUrlText)
              Text(
                sanitizedText,
                style: AppFonts.sora(
                  fontSize: 12.5,
                  color: isMe ? colors.onPrimary : colors.textPrimary,
                  height: 1.35,
                ),
                softWrap: true,
              ),
            const SizedBox(height: 4),
            Text(
              _timeStr,
              style: AppFonts.sora(
                fontSize: 9.5,
                color: isMe
                    ? colors.onPrimary.withValues(alpha: 0.7)
                    : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text, required this.colors});
  final String text;
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Divider(color: colors.border, height: 1)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppFonts.sora(fontSize: 10, color: colors.textSecondary),
            softWrap: true,
          ),
        ),
        Expanded(child: Divider(color: colors.border, height: 1)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) => EmptyState.noData(
    context: context,
    title: 'No messages yet',
    message: 'Updates and messages will show up here.',
    compact: true,
    fill: true,
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.colors,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final AppColor colors;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      10,
      8,
      10,
      MediaQuery.of(context).padding.bottom + 8,
    ),
    decoration: BoxDecoration(
      color: colors.background,
      border: Border(top: BorderSide(color: colors.border)),
      boxShadow: [
        BoxShadow(
          color: colors.textPrimary.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppFonts.sora(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write a message...',
                hintStyle: AppFonts.sora(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        const SizedBox(width: 7),

        SizedBox(
          width: 38,
          height: 38,
          child: AppFilledButton(
            onPressed: (sending || !enabled) ? null : onSend,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: colors.primary,
              disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: sending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Icon(Icons.send_rounded, color: colors.onPrimary, size: 18),
          ),
        ),
      ],
    ),
  );
}
