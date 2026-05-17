import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Fully standalone overlay bubble — zero external service dependencies.
/// Receives messages only via FlutterOverlayWindow.overlayListener.
///
/// IMPORTANT: No BackdropFilter / Colors.transparent anywhere in this widget.
/// A transparent overlay surface causes Impeller to allocate an unbounded GPU
/// texture (~16M px) which crashes the JNI surface texture thread (SIGSEGV).
class OverlayCompanionBubble extends StatefulWidget {
  const OverlayCompanionBubble({super.key});
  @override
  State<OverlayCompanionBubble> createState() => _OverlayCompanionBubbleState();
}

class _OverlayCompanionBubbleState extends State<OverlayCompanionBubble> {
  final List<_ChatMsg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isExpanded = false;
  StreamSubscription? _sub;

  static const _bg = Color(0xFF0F0F1A);
  static const _surface = Color(0xFF1A1A2E);
  static const _purple = Color(0xFF7C3AED);
  static const _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
          final text = data['text'] as String? ?? '';
          final replies = (data['quick_replies'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (text.isNotEmpty) {
            setState(() => _messages.add(_ChatMsg(text: text, isUser: false, quickReplies: replies)));
            if (!_isExpanded) _expandBriefly();
            _scrollToBottom();
          }
        } else if (data['type'] == 'open_chat') {
          _openFull();
        }
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _expandBriefly() async {
    setState(() => _isExpanded = true);
    try {
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 320, true);
    } catch (_) {}
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isExpanded) _collapse();
    });
  }

  Future<void> _openFull() async {
    setState(() => _isExpanded = true);
    try {
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, WindowSize.fullCover, true);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    } catch (_) {}
  }

  Future<void> _collapse() async {
    setState(() => _isExpanded = false);
    try {
      await FlutterOverlayWindow.resizeOverlay(200, 200, true);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    } catch (_) {}
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _input.clear();
    setState(() => _messages.add(_ChatMsg(text: trimmed, isUser: true)));
    _scrollToBottom();
    // Signal the main app to handle the reply via SharedPreferences / overlay data
    FlutterOverlayWindow.shareData({'type': 'user_message', 'text': trimmed})
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return _isExpanded ? _buildChat() : _buildBubble();
  }

  Widget _buildBubble() {
    return GestureDetector(
      onTap: _openFull,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Solid gradient — no transparency so Impeller has bounded surface
          gradient: LinearGradient(
            colors: [_purple, _indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Color(0x887C3AED), blurRadius: 16, spreadRadius: 2)
          ],
        ),
        child: Stack(children: [
          const Center(
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
          ),
          if (_messages.isNotEmpty)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFEF4444)),
                child: Center(
                  child: Text(
                    _messages.length > 9 ? '9+' : '${_messages.length}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildChat() {
    return SafeArea(
      child: Container(
        // Solid opaque background — transparent would crash Impeller
        color: _bg,
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            color: _surface,
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_purple, _indigo]),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Benw Companion',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text('Active · Tap to open full chat',
                          style: TextStyle(
                              color: Color(0xFF10B981), fontSize: 11)),
                    ]),
              ),
              // Open in main app
              TextButton(
                onPressed: () {
                  FlutterOverlayWindow.shareData({'type': 'open_in_app'})
                      .catchError((_) {});
                  _collapse();
                },
                style: TextButton.styleFrom(
                  backgroundColor: _purple.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Open App',
                    style: TextStyle(color: _purple, fontSize: 11)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: _collapse,
              ),
            ]),
          ),

          // ── Messages ────────────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Your AI companion messages appear here',
                        style: TextStyle(color: Colors.white38),
                        textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.text,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4)),
                              if (!msg.isUser && msg.quickReplies.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: msg.quickReplies.map((reply) {
                                    return GestureDetector(
                                      onTap: () => _sendMessage(reply),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _purple.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: _purple.withOpacity(0.3)),
                                        ),
                                        child: Text(reply,
                                            style: const TextStyle(
                                                color: Color(0xFFA78BFA),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Input bar ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: _surface,
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: _purple.withOpacity(0.3), width: 1),
                  ),
                  child: TextField(
                    controller: _input,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Message Benw...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _sendMessage(_input.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [_purple, _indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final List<String> quickReplies;
  _ChatMsg({required this.text, required this.isUser, this.quickReplies = const []});
}
