import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benw_edu/providers/calendar_provider.dart';
import 'package:benw_edu/providers/settings_provider.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/companion_service.dart';
import 'package:benw_edu/services/background_service_manager.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/widgets/glass_container.dart';
import 'package:benw_edu/widgets/model_selector_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CompanionService _companion = CompanionService();
  final BackgroundServiceManager _bgService = BackgroundServiceManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Benw Companion'),
                  const SizedBox(height: 16),
                  _buildCompanionSection(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle('AI Engine'),
                  const SizedBox(height: 16),
                  _buildModelStatus(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Study Stats'),
                  const SizedBox(height: 16),
                  _buildStudyStats(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Data Management'),
                  const SizedBox(height: 16),
                  _buildDataManagement(context),
                  const SizedBox(height: 40),
                  _buildInfoCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.dopamineStart,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  // ── Companion Section ───────────────────────────────────────────────────────

  Widget _buildCompanionSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return GlassContainer(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // Header banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.dopamineStart.withValues(alpha: 0.15),
                      AppColors.dopamineEnd.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.dopamineGradient,
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Benw Companion',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            settings.companionEnabled
                                ? '🟢 Active · Watching your schedule'
                                : '⚫ Paused · Bubble hidden',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle rows
              _companionToggle(
                icon: Icons.smart_toy_rounded,
                title: 'Enable Companion',
                subtitle: 'Show floating bubble & get check-ins',
                value: settings.companionEnabled,
                onChanged: (v) async {
                  await settings.setCompanionEnabled(v);
                  if (v) {
                    _companion.start();
                    await _bgService.startService();
                  } else {
                    _companion.stop();
                    await _bgService.stopService();
                  }
                },
                color: AppColors.dopamineStart,
              ),
              const Divider(height: 1, color: AppColors.glassBorder),

              _companionToggle(
                icon: Icons.notifications_active_rounded,
                title: 'Block Notifications',
                subtitle: 'Push alerts when calendar blocks end',
                value: settings.notificationsEnabled,
                onChanged: (v) async {
                  await settings.setNotificationsEnabled(v);
                  _companion.notificationsEnabled = v;
                },
                color: AppColors.dopamineMid,
                enabled: settings.companionEnabled,
              ),
              const Divider(height: 1, color: AppColors.glassBorder),

              _companionToggle(
                icon: Icons.directions_walk_rounded,
                title: 'Walk Reminders',
                subtitle: 'Alert after 60 min of continuous study',
                value: settings.walkRemindersEnabled,
                onChanged: (v) async {
                  await settings.setWalkRemindersEnabled(v);
                  _companion.walkRemindersEnabled = v;
                },
                color: AppColors.dopamineEnd,
                enabled: settings.companionEnabled,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _companionToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required Color color,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        value: value,
        onChanged: enabled ? (v) => onChanged(v) : null,
        activeColor: color,
        activeTrackColor: color.withValues(alpha: 0.3),
        inactiveThumbColor: AppColors.textHint,
        inactiveTrackColor: AppColors.surfaceLight,
      ),
    );
  }

  // ── Model Status ────────────────────────────────────────────────────────────

  Widget _buildModelStatus() {
    final benw = BenwEduService();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.dopamineGradient,
                ),
                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benw 4 E2B (LiteRT)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String>(
                      valueListenable: benw.activeModelName,
                      builder: (_, name, __) => Text(
                        'Status: $name',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: benw.isInitialized
                      ? AppColors.dopamineMid
                      : AppColors.xpGold,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ModelSelectorSheet(),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.dopamineStart,
                ),
                child: const Text('CHANGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: benw.isDownloading,
            builder: (context, downloading, child) {
              if (!downloading) {
                return const Text(
                  'All AI processing runs locally on your device. No data is ever sent to the cloud.',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11, height: 1.4),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Downloading Model...', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: benw.downloadProgress,
                        builder: (context, progress, _) => Text('$progress%', style: const TextStyle(color: AppColors.dopamineMid, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: benw.downloadProgress,
                    builder: (context, progress, _) => LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.dopamineMid),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Please keep the app open. This may take a few minutes.', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Study Stats ─────────────────────────────────────────────────────────────

  Widget _buildStudyStats(BuildContext context) {
    return Consumer2<CalendarProvider, SubjectsProvider>(
      builder: (context, calendar, materials, _) {
        return GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _statRow('Study Blocks Today',
                  '${calendar.getEventsForDay(DateTime.now()).length}',
                  Icons.event_note_rounded),
              const Divider(color: Colors.white10, height: 24),
              _statRow('Total Subjects',
                  '${materials.subjects.length}',
                  Icons.folder_rounded),
              const Divider(color: Colors.white10, height: 24),
              _statRow('RAG Knowledge Chunks',
                  '${materials.subjects.length * 3}',
                  Icons.hub_rounded),
              const Divider(color: Colors.white10, height: 24),
              _statRow('Categories',
                  '${materials.subjectNames.length}',
                  Icons.category_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.dopamineStart, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.w500,
        )),
        const Spacer(),
        Text(value, style: const TextStyle(
          color: AppColors.dopamineMid, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }

  // ── Data Management ─────────────────────────────────────────────────────────

  Widget _buildDataManagement(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.streakFire),
            title: const Text(
              'Clear All Study Materials',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Removes all uploaded documents and RAG data',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            onTap: () => _confirmClearMaterials(context),
          ),
        ],
      ),
    );
  }

  void _confirmClearMaterials(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Materials?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will delete all uploaded study documents and their RAG chunks. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = Provider.of<SubjectsProvider>(context, listen: false);
              for (final m in provider.subjects.toList()) {
                provider.deleteSubject(m.id);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.streakFire),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Info Card ───────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.dopamineStart.withValues(alpha: 0.1),
            AppColors.dopamineMid.withValues(alpha: 0.1),
            AppColors.dopamineEnd.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dopamineStart.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.dopamineStart),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Benw Education Services runs 100% offline. All AI processing, study materials, and personal data stay on your device.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

