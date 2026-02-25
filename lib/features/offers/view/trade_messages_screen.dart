import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/services/base_url/base_url.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

/// Trade-specific chat and proofs screen.
///
/// Shows all trade messages (system events + user chat) and allows
/// sending messages and uploading payment proofs.
class TradeMessagesScreen extends StatefulWidget {
  const TradeMessagesScreen({super.key, required this.trade});
  final TradeModel trade;

  @override
  State<TradeMessagesScreen> createState() => _TradeMessagesScreenState();
}

class _TradeMessagesScreenState extends State<TradeMessagesScreen> {
  final _tradesCore = TradesCoreService.I;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _localMessages = [];
  bool _loading = true;
  bool _sending = false;
  String? _currentUserId;
  Timer? _pollTimer;
  bool _proofUploading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadCurrentUser();
    _startPolling();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_proofUploading) return;
      _loadMessages(silent: true);
    });
  }

  String _appendLocalImageMessage({
    required String imagePath,
    required String message,
    bool isUploading = false,
    String uploadState = 'uploaded',
  }) {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _localMessages = [
        ..._localMessages,
        {
          'id': id,
          'kind': 'TEXT',
          'senderId': _currentUserId ?? 'local-me',
          'message': message,
          'localImagePath': imagePath,
          'isUploadingProof': isUploading,
          'proofUploadState': uploadState,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      ];
    });
    _scrollToBottom();
    return id;
  }

  void _updateLocalMessage(
    String id, {
    String? message,
    bool? isUploadingProof,
    String? proofUploadState,
  }) {
    setState(() {
      _localMessages = _localMessages.map((m) {
        if ((m['id'] ?? '').toString() != id) return m;
        return {
          ...m,
          if (message != null) 'message': message,
          if (isUploadingProof != null) 'isUploadingProof': isUploadingProof,
          if (proofUploadState != null) 'proofUploadState': proofUploadState,
        };
      }).toList();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService().currentUser;
      if (mounted) setState(() => _currentUserId = user.id);
    } catch (_) {}
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
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
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
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _tradesCore.sendTradeMessage(
        widget.trade.id,
        ciphertext: text,
        algorithm: 'PLAIN',
        senderKeyId: 'plain',
        nonce: 'plain',
        kind: 'TEXT',
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

  Future<void> _uploadProof() async {
    final source = await _showProofSourceSheet();
    if (!mounted || source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source);
    if (!mounted || file == null) return;
    setState(() => _proofUploading = true);
    _pollTimer?.cancel();
    final localProofId = _appendLocalImageMessage(
      imagePath: file.path,
      message: 'Uploading payment proof...',
      isUploading: true,
      uploadState: 'uploading',
    );
    showFloatingSnackBar(
      context,
      message: 'Uploading proof…',
      type: SnackBarType.success,
    );

    try {
      final uploadedProofUrl = await _tradesCore.uploadProof(
        widget.trade.id,
        file: File(file.path),
        type: 'FIAT',
      );
      final proofMsg = 'Payment proof uploaded: ${file.name}';
      final payload = uploadedProofUrl == null || uploadedProofUrl.trim().isEmpty
          ? proofMsg
          : jsonEncode({
              'text': proofMsg,
              'proofUrl': uploadedProofUrl.trim(),
              'proofUrls': [uploadedProofUrl.trim()],
              'imageUrl': uploadedProofUrl.trim(),
            });
      await _tradesCore.sendTradeMessage(
        widget.trade.id,
        ciphertext: payload,
        algorithm: 'PLAIN',
        senderKeyId: 'plain',
        nonce: 'plain',
        kind: 'TEXT',
      );
      if (mounted) {
        _updateLocalMessage(
          localProofId,
          message: proofMsg,
          isUploadingProof: false,
          proofUploadState: 'uploaded',
        );
        showFloatingSnackBar(
          context,
          message: 'Proof uploaded successfully',
          type: SnackBarType.success,
        );
        await _loadMessages(silent: true);
      }
    } catch (e) {
      if (mounted) {
        _updateLocalMessage(
          localProofId,
          message: 'Payment proof upload failed',
          isUploadingProof: false,
          proofUploadState: 'failed',
        );
        showFloatingSnackBar(
          context,
          message: 'Upload failed: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _proofUploading = false);
      _startPolling();
    }
  }

  Future<ImageSource?> _showProofSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProofSourceSheet(colors: AppColor.of(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final allMessages = [..._messages, ..._localMessages]
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
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : allMessages.isEmpty
                ? _EmptyState(colors: colors)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: allMessages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: allMessages[i],
                      currentUserId: _currentUserId,
                      colors: colors,
                    ),
                  ),
          ),

          // Input bar
          _InputBar(
            controller: _msgCtrl,
            colors: colors,
            sending: _sending,
            onSend: _sendMessage,
            onAttach: _uploadProof,
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
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: colors.textPrimary,
          size: 18,
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade Chat',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          Text(
            widget.trade.id.length > 16
                ? '${widget.trade.id.substring(0, 12)}…'
                : widget.trade.id,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
          onPressed: () => _loadMessages(),
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

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
          // If payload is JSON but no user-facing text is extractable,
          // hide the raw JSON envelope instead of showing it in chat bubbles.
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
      return '${centralized_baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}$raw';
    }
    if (raw.startsWith('uploads/') ||
        raw.startsWith('upload/') ||
        raw.startsWith('media/')) {
      return '${centralized_baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}/$raw';
    }
    return raw;
  }

  bool get _hasImage => _imageRef.isNotEmpty;
  bool get _isUploadingProof => message['isUploadingProof'] == true;
  bool get _isProofFailed =>
      (message['proofUploadState'] ?? '').toString().toLowerCase() == 'failed';

  void _openImageViewer(BuildContext context) {
    final src = _resolveImageRef(_imageRef);
    final isHttp = src.startsWith('http://') || src.startsWith('https://');
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
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
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white70,
                            size: 42,
                          ),
                        )
                      : Image.file(
                          File(src),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white70,
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
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
                        color: Colors.black.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.85)
                        : colors.textSecondary,
                  ),
                ),
              ],
              if (_text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (_text.isNotEmpty)
              Text(
                _withBreakHints(_text),
                style: GoogleFonts.sora(
                  fontSize: 14,
                  color: isMe ? Colors.white : colors.textPrimary,
                  height: 1.4,
                ),
                softWrap: true,
              ),
            const SizedBox(height: 4),
            Text(
              _timeStr,
              style: GoogleFonts.sora(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── System message ───────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text, required this.colors});
  final String text;
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Divider(color: colors.border, height: 1)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 11, color: colors.textSecondary),
            softWrap: true,
          ),
        ),
        Expanded(child: Divider(color: colors.border, height: 1)),
      ],
    ),
  );
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 48,
          color: colors.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'No messages yet',
          style: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Trade activity and chat will appear here',
          style: GoogleFonts.sora(
            fontSize: 13,
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.colors,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });
  final TextEditingController controller;
  final AppColor colors;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      12,
      10,
      12,
      MediaQuery.of(context).padding.bottom + 10,
    ),
    decoration: BoxDecoration(
      color: colors.background,
      border: Border(top: BorderSide(color: colors.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: AppOutlinedButton(
            onPressed: onAttach,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Icon(
              Icons.attach_file_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Text field
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.sora(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: GoogleFonts.sora(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        const SizedBox(width: 8),

        SizedBox(
          width: 42,
          height: 42,
          child: AppFilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: colors.primary,
              disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    ),
  );
}

// ─── Proof source picker sheet ────────────────────────────────────────────────

class _ProofSourceSheet extends StatelessWidget {
  const _ProofSourceSheet({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Upload Payment Proof',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a screenshot or photo as evidence of payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          _SourceOption(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            colors: colors,
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 10),
          _SourceOption(
            icon: Icons.camera_alt_rounded,
            label: 'Take a Photo',
            colors: colors,
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: AppOutlinedButton(
              onPressed: () => Navigator.pop(context, null),
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.background,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: AppFilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}
