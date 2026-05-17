import 'package:flutter/material.dart';
import 'package:benw_edu/models/subject.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SubjectCard extends StatefulWidget {
  final Subject subject;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int index;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    this.onLongPress,
    this.index = 0,
  });

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Staggered entrance animation
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
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
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: _isHovered
                ? Matrix4.diagonal3Values(1.03, 1.03, 1.0)
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.subject.accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.subject.accentColor.withValues(alpha: _isHovered ? 0.15 : 0.05),
                    blurRadius: _isHovered ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accent strip at top
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.subject.accentColor,
                          widget.subject.accentColor.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.subject.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.subject.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Y${widget.subject.year} S${widget.subject.semester}',
                                style: TextStyle(
                                  color: widget.subject.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.subject.content,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                                fontSize: 12,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(widget.subject.createdAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

