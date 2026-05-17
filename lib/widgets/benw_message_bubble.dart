import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/widgets/benw_markdown.dart';

class BenwMessageBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final bool isLoading;
  final int index;
  final Uint8List? imageBytes;
  final String? thought;

  const BenwMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isLoading = false,
    this.index = 0,
    this.imageBytes,
    this.thought,
  });

  @override
  State<BenwMessageBubble> createState() => _benwMessageBubbleState();
}

class _benwMessageBubbleState extends State<BenwMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          alignment:
              widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isUser) ...[
              // Benw avatar
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.BenwGradient,
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.isUser
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
                    bottomRight: Radius.circular(widget.isUser ? 4 : 18),
                  ),
                  border: Border.all(
                    color: widget.isUser
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : AppColors.textHint.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: widget.isLoading
                    ? _buildTypingIndicator()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.imageBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  widget.imageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          if (widget.thought != null && widget.thought!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.BenwStart.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.BenwStart.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.psychology_outlined, size: 12, color: AppColors.BenwMid),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        widget.thought!,
                                        style: const TextStyle(
                                          color: AppColors.BenwMid,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.message.isNotEmpty)
                            BenwMarkdown(
                              widget.message,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.5,
                                  ),
                            ),
                        ],
                      ),
              ),
            ),
            if (widget.isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 48,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return _TypingDot(delay: i * 200);
        }),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                AppColors.textSecondary.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
