import 'package:flutter/material.dart';
import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/theme/app_theme.dart';

class EventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;
  final int index;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onDismissed,
    this.index = 0,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
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
        return SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.event.color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Time indicator
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.event.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (widget.event.description.isNotEmpty)
                      Text(
                        widget.event.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Time badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.event.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.event.formattedTime,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.event.color,
                        fontSize: 13,
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
