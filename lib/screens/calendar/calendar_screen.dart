import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:benw_edu/providers/calendar_provider.dart';
import 'package:benw_edu/widgets/event_card.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/screens/chat/benw_chat_sheet.dart';

enum CalendarViewMode { list, timetable, weekly }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimController;
  final ScrollController _timelineScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  CalendarViewMode _viewMode = CalendarViewMode.list;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _verticalScrollController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _scrollToCurrentHour() {
    if (!_timelineScrollController.hasClients) return;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (currentHour >= 6) {
      const slotWidth = 50.0;
      double offset = (currentHour - 6).toDouble() * slotWidth;
      
      if (_viewMode == CalendarViewMode.weekly) {
        offset += 50.0; // labelWidth
      }
      
      final screenWidth = MediaQuery.of(context).size.width;
      offset -= (screenWidth / 2) - (slotWidth / 2);
      
      if (offset < 0) offset = 0;
      if (offset > _timelineScrollController.position.maxScrollExtent) {
        offset = _timelineScrollController.position.maxScrollExtent;
      }
      
      _timelineScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    if (_viewMode == CalendarViewMode.weekly && _verticalScrollController.hasClients) {
      final weekdayIndex = now.weekday - 1; // 0 for Monday, 6 for Sunday
      const rowHeight = 40.0;
      double vOffset = weekdayIndex * rowHeight;
      
      // Center vertically in the 230px height available (260 total - 30 header)
      vOffset -= (230.0 / 2) - (rowHeight / 2);
      
      if (vOffset < 0) vOffset = 0;
      if (vOffset > _verticalScrollController.position.maxScrollExtent) {
        vOffset = _verticalScrollController.position.maxScrollExtent;
      }
      
      _verticalScrollController.animateTo(
        vOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openBenwPlanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BenwChatSheet(mode: BenwMode.planner),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final focusedDay = calendarProvider.focusedDay;
    final selectedDay = calendarProvider.selectedDay;
    final eventsForDay = calendarProvider.getEventsForDay(selectedDay);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Calendar widget
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textHint.withValues(alpha: 0.1),
                ),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: focusedDay,
                selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                onDaySelected: (selected, focused) {
                  calendarProvider.setSelectedDay(selected);
                  calendarProvider.setFocusedDay(focused);
                },
                onPageChanged: (focused) {
                  calendarProvider.setFocusedDay(focused);
                },
                eventLoader: (day) =>
                    calendarProvider.getEventsForDay(day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      Theme.of(context).textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                  leftChevronIcon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textPrimary,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textPrimary,
                  ),
                  headerPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle:
                      Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                  weekendStyle:
                      Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textHint.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.all(4),
                  defaultTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  weekendTextStyle: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  selectedDecoration: const BoxDecoration(
                    gradient: AppColors.BenwGradient,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.BenwStart,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  markersMaxCount: 3,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                ),
              ),
            ),
          ),

          // Day header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: AppColors.BenwGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isToday(selectedDay)
                        ? 'Today'
                        : DateFormat('EEEE, MMM d').format(selectedDay),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  _buildViewModeToggle(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${eventsForDay.length} session${eventsForDay.length != 1 ? 's' : ''}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // View content (List or Timetable)
          if (eventsForDay.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyDayState(context),
            )
          else if (_viewMode == CalendarViewMode.list)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return EventCard(
                      event: eventsForDay[index],
                      index: index,
                      onTap: () => _showEventDetail(
                          context, eventsForDay[index]),
                    );
                  },
                  childCount: eventsForDay.length,
                ),
              ),
            )
          else if (_viewMode == CalendarViewMode.timetable)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
              sliver: SliverToBoxAdapter(
                child: _buildDayTimetable(eventsForDay),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
              sliver: SliverToBoxAdapter(
                child: _buildWeeklyTimetable(calendarProvider),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildBenwCentralButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBenwCentralButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100), // Adjusted for floating nav bar
      child: GestureDetector(
        onTap: _openBenwPlanner,
        child: AnimatedBuilder(
          animation: _fabAnimController,
          builder: (context, child) {
            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.BenwGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.BenwStart.withValues(alpha: 0.4 * _fabAnimController.value),
                    blurRadius: 15 * _fabAnimController.value,
                    spreadRadius: 2 * _fabAnimController.value,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 30),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  Widget _buildViewModeToggle() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildToggleItem(
            icon: Icons.list_rounded,
            isSelected: _viewMode == CalendarViewMode.list,
            onTap: () => setState(() => _viewMode = CalendarViewMode.list),
          ),
          _buildToggleItem(
            icon: Icons.view_week_rounded,
            isSelected: _viewMode == CalendarViewMode.weekly,
            onTap: () {
              setState(() => _viewMode = CalendarViewMode.weekly);
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.accent : AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildDayTimetable(List<CalendarEvent> events) {
    const slotWidth = 55.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textHint.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Hours
            Row(
              children: List.generate(18, (index) {
                final hour = index + 6;
                return Container(
                  width: slotWidth,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(left: BorderSide(color: AppColors.textHint.withValues(alpha: 0.1))),
                  ),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                );
              }),
            ),
            // Row: Events
            Container(
              height: 100,
              child: Row(
                children: List.generate(18, (index) {
                  final hour = index + 6;
                  final hourEvents = events.where((CalendarEvent e) => e.time?.hour == hour).toList();
                  return Container(
                    width: slotWidth,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: AppColors.textHint.withValues(alpha: 0.05))),
                    ),
                    child: Stack(
                      children: hourEvents.map((event) {
                        return Positioned(
                          top: 8, bottom: 8, left: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _showEventDetail(context, event),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    event.color.withValues(alpha: 0.3),
                                    event.color.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: event.color.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(event.icon, size: 14, color: event.color),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: event.color),
                                  ),
                                  Text(
                                    event.formattedTime,
                                    style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList().cast<Widget>(),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTimetable(CalendarProvider provider) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    const labelWidth = 50.0;
    const slotWidth = 50.0;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textHint.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Hours
            Row(
              children: [
                Container(width: labelWidth, height: 30, color: AppColors.surfaceLight),
                ...List.generate(18, (index) {
                  final hour = index + 6;
                  return Container(
                    width: slotWidth,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      border: Border(left: BorderSide(color: AppColors.textHint.withValues(alpha: 0.1))),
                    ),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  );
                }),
              ],
            ),
            // Rows: Days
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: days.map((day) {
                    final dayEvents = provider.getEventsForDay(day);
                    final isSelected = isSameDay(day, provider.selectedDay);
                    
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.textHint.withValues(alpha: 0.05))),
                        color: isSelected ? AppColors.accent.withValues(alpha: 0.05) : null,
                      ),
                      child: Row(
                        children: [
                          // Day Label
                          GestureDetector(
                            onTap: () => provider.setSelectedDay(day),
                            child: Container(
                              width: labelWidth,
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('E').format(day),
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.accent : AppColors.textHint
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d').format(day),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSelected ? AppColors.accent : AppColors.textHint
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Hours Slots
                          ...List.generate(18, (index) {
                            final hour = index + 6;
                            final hourEvents = dayEvents.where((e) => e.time?.hour == hour).toList();
                            return Container(
                              width: slotWidth,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: AppColors.textHint.withValues(alpha: 0.05))),
                              ),
                              child: Stack(
                                children: hourEvents.map((e) {
                                  final CalendarEvent event = e;
                                  return Positioned(
                                    top: 4, bottom: 4, left: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => _showEventDetail(context, event),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: event.color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: event.color.withValues(alpha: 0.3)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(event.icon, size: 10, color: event.color),
                                            const SizedBox(height: 2),
                                            Text(
                                              event.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: event.color),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList().cast<Widget>(),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDayState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.BenwStart.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 28,
                color: AppColors.BenwStart,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No study sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap G to ask Benw to\nplan your study session',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetail(BuildContext context, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
          final subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
          
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Event Type Selector
                Text(
                  'Event Type',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.textHint.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EventType>(
                      value: event.type,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      items: EventType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.name.substring(0, 1).toUpperCase() + type.name.substring(1),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (EventType? newType) {
                        if (newType != null) {
                          calendarProvider.updateEvent(event.id, type: newType);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lesson Selector (only if type is Study)
                if (event.type == EventType.study) ...[
                  Text(
                    'Associated Subject',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textHint.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: event.subjectId,
                        hint: const Text('Select a subject', style: TextStyle(color: AppColors.textHint)),
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No subject linked', style: TextStyle(color: AppColors.textPrimary)),
                          ),
                          ...subjectsProvider.subjects.map((subject) {
                            return DropdownMenuItem(
                              value: subject.id,
                              child: Text(
                                subject.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            );
                          }),
                        ],
                        onChanged: (newSubjectId) {
                          calendarProvider.updateEvent(event.id, subjectId: newSubjectId);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildDetailRow(context, Icons.access_time_rounded,
                    'Time', event.formattedTime),
                const SizedBox(height: 12),
                _buildDetailRow(context, Icons.calendar_today_rounded,
                    'Date', DateFormat('EEEE, MMM d, yyyy').format(event.date)),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(context, Icons.description_rounded,
                      'Details', event.description),
                ],
                if (event.subjectId != null) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final linkedSubject = subjectsProvider.subjects.firstWhere((n) => n.id == event.subjectId, orElse: () => subjectsProvider.subjects.first);
                    return _buildDetailRow(context, Icons.book_rounded,
                        'Linked Subject', linkedSubject.title);
                  }),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Provider.of<CalendarProvider>(context, listen: false)
                          .deleteEvent(event.id);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Delete Session'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: GptMarkdown(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
