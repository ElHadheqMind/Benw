import 'dart:async';
import 'package:flutter/material.dart';
import 'package:benw_edu/models/companion_message.dart';
import 'package:benw_edu/services/companion_service.dart';
import 'package:benw_edu/theme/app_theme.dart';

/// The always-visible floating companion avatar.
/// Listens to CompanionService and shows an unread badge + pulse animation
/// when new messages arrive. Tap to open the CompanionChatSheet.
class FloatingCompanionBubble extends StatefulWidget {
  const FloatingCompanionBubble({super.key});

  @override
  State<FloatingCompanionBubble> createState() =>
      FloatingCompanionBubbleState();
}

// Public state so HomeScreen can hold GlobalKey<FloatingCompanionBubbleState>
// and call openChat() programmatically (e.g. when user taps a notification).
class FloatingCompanionBubbleState extends State<FloatingCompanionBubble>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnim;
  late Animation<double> _bounceAnim;

  final CompanionService _companion = CompanionService();
  final List<CompanionMessage> _messages = [];
  int _unreadCount = 0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();

    // Idle pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bounce on new message
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.25)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.25, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
    ]).animate(_bounceController);

    // Subscribe to companion messages
    _companion.messageStream.listen(_onNewMessage);
  }

  void _onNewMessage(CompanionMessage msg) {
    if (msg.type == CompanionMessageType.clearHistory) {
      setState(() {
        _messages.clear();
        _unreadCount = 0;
      });
      return;
    }
    setState(() {
      _messages.add(msg);
      if (!_isOpen) {
        _unreadCount++;
        _bounceController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  /// Public entry-point so HomeScreen can open the chat via GlobalKey
  /// (e.g. when the user taps a Benw notification).
  void openChat() => _openChat();

  void _openChat() {
    setState(() {
      _isOpen = true;
      _unreadCount = 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // IMPORTANT: Never use Colors.transparent here.
      // BackdropFilter inside a transparent modal makes Impeller allocate
      // an unbounded texture (~16M px) → SIGSEGV in JNISurfaceTextu thread.
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CompanionChatSheet(
        messages: List.from(_messages),
        onClose: () {
          setState(() => _isOpen = false);
          Navigator.pop(ctx);
        },
        onSendMessage: (text, replyingTo) async {
          // Get Benw's response
          final BenwReply = await _companion.handleUserReply(
            text: text,
            replyingTo: replyingTo ??
                CompanionMessage.Benw(
                  text: '',
                  type: CompanionMessageType.BenwResponse,
                ),
            history: _messages,
          );
          return BenwReply;
        },
        allMessages: _messages,
      ),
    ).then((_) => setState(() => _isOpen = false));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _bounceController]),
      builder: (context, child) {
        final scale = _bounceController.isAnimating
            ? _bounceAnim.value
            : (_unreadCount > 0 ? _pulseAnim.value : 1.0);

        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _openChat,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.BenwGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.BenwStart.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Avatar
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        color: Colors.white, size: 26),
                  ],
                ),
              ),
              // Unread badge
              if (_unreadCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Inline CompanionChatSheet — full messenger-style UI
// ────────────────────────────────────────────────────────────────────────────

class CompanionChatSheet extends StatefulWidget {
  final List<CompanionMessage> messages;
  final List<CompanionMessage> allMessages;
  final VoidCallback onClose;
  final Future<CompanionMessage> Function(String, CompanionMessage?) onSendMessage;

  const CompanionChatSheet({
    required this.messages,
    required this.allMessages,
    required this.onClose,
    required this.onSendMessage,
  });

  @override
  State<CompanionChatSheet> createState() => _CompanionChatSheetState();
}

class _CompanionChatSheetState extends State<CompanionChatSheet> {
  late List<CompanionMessage> _messages;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  CompanionMessage? _lastBenwMessage;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
    if (_messages.isNotEmpty) {
      _lastBenwMessage = _messages.lastWhere(
        (m) => !m.isUser,
        orElse: () => _messages.last,
      );
    }
  }

  @override
  void dispose() {
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

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();

    setState(() {
      _messages.add(CompanionMessage.user(
        text: text,
        linkedEventId: _lastBenwMessage?.linkedEventId,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    final reply = await widget.onSendMessage(text, _lastBenwMessage);

    setState(() {
      _messages.add(reply);
      _lastBenwMessage = reply;
      _isTyping = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            _buildHeader(),
            const Divider(height: 1, color: AppColors.glassBorder),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_isTyping && i == _messages.length) {
                    return const _TypingBubble();
                  }
                  return _MessageRow(
                    message: _messages[i],
                    onQuickReply: _send,
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          // Drag handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.BenwGradient,
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.BenwGradientHorizontal
                                  .createShader(b),
                          child: const Text(
                            'Benw Companion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Active · Watching your schedule',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.2), width: 1),
              ),
              child: TextField(
                controller: _input,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15),
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Reply to Benw...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: _send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_input.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.BenwGradient,
              ),
              child: const Center(
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual message row ────────────────────────────────────────────────────

class _MessageRow extends StatelessWidget {
  final CompanionMessage message;
  final void Function(String) onQuickReply;

  const _MessageRow({required this.message, required this.onQuickReply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isUser) ...[
                _benwAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(child: _buildBubble(context)),
              if (message.isUser) const SizedBox(width: 8),
            ],
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: message.isUser ? 0 : 48,
              right: message.isUser ? 8 : 0,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textHint),
            ),
          ),

          // Quick reply chips (only on Benw messages)
          if (!message.isUser && message.quickReplies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.quickReplies
                    .map((r) => _QuickReplyChip(
                          label: r,
                          onTap: () => onQuickReply(r),
                        ))
                    .toList(),
              ),
            ),

          // Calendar Suggestion Cards
          if (!message.isUser && message.calendarSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Column(
                children: message.calendarSuggestions
                    .map((s) => _CalendarSuggestionCard(suggestion: s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final isWalk = message.type == CompanionMessageType.walkReminder;

    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isWalk
            ? const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isWalk
            ? null
            : (message.isUser
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.surfaceLight),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(message.isUser ? 20 : 4),
          bottomRight: Radius.circular(message.isUser ? 4 : 20),
        ),
        border: Border.all(
          color: message.isUser
              ? AppColors.accent.withValues(alpha: 0.25)
              : AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: isWalk ? Colors.white : AppColors.textPrimary,
          fontWeight: isWalk ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Calendar Suggestion Card ─────────────────────────────────────────────────

class _CalendarSuggestionCard extends StatefulWidget {
  final Map<String, dynamic> suggestion;
  const _CalendarSuggestionCard({required this.suggestion});

  @override
  State<_CalendarSuggestionCard> createState() => _CalendarSuggestionCardState();
}

class _CalendarSuggestionCardState extends State<_CalendarSuggestionCard> {
  bool _applied = false;

  void _apply() {
    if (_applied) return;
    CompanionService().applyCalendarAction(widget.suggestion);
    setState(() => _applied = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Event added: ${widget.suggestion['title']}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.BenwStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final action = s['action'] as String? ?? 'add_block';
    final title = s['title'] as String? ?? 'Untitled';
    final hour = s['hour'] ?? 0;
    final minute = s['minute'] ?? 0;
    final dayOffset = s['day_offset'] ?? 0;
    
    final dayLabel = dayOffset == 0 ? 'Today' : (dayOffset == 1 ? 'Tomorrow' : 'In $dayOffset days');
    final timeLabel = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.BenwStart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action == 'reschedule' ? Icons.event_repeat_rounded : Icons.event_available_rounded,
                  color: AppColors.BenwStart,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action == 'reschedule' ? 'Reschedule Request' : 'New Study Block',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint),
                    ),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.calendar_today_rounded, dayLabel),
              const SizedBox(width: 8),
              _infoChip(Icons.access_time_rounded, timeLabel),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applied ? null : _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: _applied ? AppColors.textHint : AppColors.BenwStart,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(_applied ? 'Added to Calendar' : 'Confirm & Add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Benw avatar ──────────────────────────────────────────────────────────────

class _benwAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.BenwGradient,
      ),
      child: const Center(
        child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
      ),
    );
  }
}

// ── Quick reply chip ──────────────────────────────────────────────────────────

class _QuickReplyChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickReplyChip({required this.label, required this.onTap});

  @override
  State<_QuickReplyChip> createState() => _QuickReplyChipState();
}

class _QuickReplyChipState extends State<_QuickReplyChip> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _tapped = true);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: _tapped ? AppColors.BenwGradient : null,
          color: _tapped ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _tapped
                ? Colors.transparent
                : AppColors.accent.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _tapped ? Colors.white : AppColors.accent,
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator bubble ───────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _benwAvatar(),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final delay = i * 0.3;
                    final t = (_ctrl.value - delay).clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.3 + t * 0.7),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
