import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benw_edu/providers/calendar_provider.dart';
import 'package:benw_edu/providers/settings_provider.dart';
import 'package:benw_edu/screens/calendar/calendar_screen.dart';
import 'package:benw_edu/screens/notes/subjects_list_screen.dart';
import 'package:benw_edu/screens/vision/camera_assistant_screen.dart';
import 'package:benw_edu/screens/settings_screen.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/services/companion_service.dart';
import 'package:benw_edu/services/background_service_manager.dart';
import 'package:benw_edu/widgets/floating_companion_bubble.dart';

// NOTE: flutter_overlay_window removed — it caused SIGSEGV crashes via
// Impeller's transparent surface texture overflow. Companion chat is
// in-app only. Notification tap → SharedPreferences flag → openChat().

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _fabAnimController;
  final CompanionService _companion = CompanionService();

  /// Key to programmatically open the bubble chat from a notification tap
  final GlobalKey<FloatingCompanionBubbleState> _bubbleKey =
      GlobalKey<FloatingCompanionBubbleState>();

  final List<Widget> _screens = const [
    CalendarScreen(),
    SubjectsListScreen(),
    CameraAssistantScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calendar = Provider.of<CalendarProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      // Wire CompanionService callbacks
      _companion.getEventsCallback = () {
        final today = DateTime.now();
        return calendar.getEventsForDay(today);
      };

      _companion.getWeekCalendarCallback = () => calendar.getWeekText();

      _companion.addEventCallback = (event) {
        calendar.addEvent(event);
      };

      _companion.addEventOnDayCallback = ({
        required int dayOffset,
        required String title,
        required type,
        required int hour,
        int minute = 0,
        String description = '',
      }) {
        return calendar.addEventOnDay(
          dayOffset: dayOffset,
          title: title,
          type: type,
          hour: hour,
          minute: minute,
          description: description,
        );
      };

      _companion.rescheduleEventCallback = (id, newHour, newMinute) {
        calendar.rescheduleEvent(id, newHour, newMinute);
      };

      _companion.notificationsEnabled = settings.notificationsEnabled;
      _companion.walkRemindersEnabled = settings.walkRemindersEnabled;

      _persistEventsForBackground(calendar);

      if (settings.companionEnabled) {
        _companion.start();
        BackgroundServiceManager().startService();

        Future.delayed(const Duration(seconds: 5), () {
          _companion.startDemo();
        });
      }

      // Check if notification was tapped while app was closed / in background
      _checkPendingChatOpen();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — open chat if notification was tapped
      _checkPendingChatOpen();
    }
  }

  /// Opens the companion chat if a notification was tapped.
  /// The flag is set by NotificationService / background service.
  Future<void> _checkPendingChatOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldOpen = prefs.getBool('pending_open_chat') ?? false;
    if (shouldOpen && mounted) {
      await prefs.setBool('pending_open_chat', false);
      await Future.delayed(const Duration(milliseconds: 400));
      _bubbleKey.currentState?.openChat();
    }
  }

  void _persistEventsForBackground(CalendarProvider calendar) {
    final today = DateTime.now();
    final events = calendar.getEventsForDay(today);
    final serialized = events
        .where((e) => e.endTime != null)
        .map((e) => {
              'id': e.id,
              'title': e.title,
              'eventType': e.type.name,
              'endHour': e.endTime!.hour.toString(),
              'endMinute': e.endTime!.minute.toString(),
            })
        .toList();
    BackgroundServiceManager.persistEventsForBackground(serialized);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabAnimController.dispose();
    _companion.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.dopamineGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Benw Education',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: AppColors.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Gradient fade at bottom for nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.0),
                      AppColors.background.withValues(alpha: 0.9),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nav Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: _buildFloatingNavBar(),
          ),
          // ── In-app Companion Chat Bubble ──────────────────────────────────
          Positioned(
            bottom: 108,
            right: 20,
            child: FloatingCompanionBubble(key: _bubbleKey),
          ),
          // Demo trigger button
          Positioned(
            bottom: 108,
            left: 20,
            child: FloatingActionButton.small(
              onPressed: () => _companion.triggerDemoStep(),
              backgroundColor: AppColors.BenwStart.withOpacity(0.8),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.calendar_month_rounded, 'Planner'),
          _buildNavItem(1, Icons.folder_rounded, 'Subjects'),
          _buildNavItem(2, Icons.document_scanner_rounded, 'Vision'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.dopamineStart.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.dopamineStart : AppColors.textHint,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.dopamineStart,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
