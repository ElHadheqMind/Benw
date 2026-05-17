import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/models/subject.dart';
import 'package:benw_edu/widgets/subject_card.dart';
import 'package:benw_edu/screens/notes/subject_detail_screen.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class SubjectsListScreen extends StatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  State<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends State<SubjectsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubjectName = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubjectsProvider>(
      builder: (context, subjectsProvider, child) {
        final allSubjects = subjectsProvider.subjects;
        final subjectNames = ['All', ...subjectsProvider.subjectNames];
        
        // Filter by selected subject if not 'All'
        final filteredSubjects = _selectedSubjectName == 'All' 
            ? allSubjects 
            : allSubjects.where((n) => n.subjectName == _selectedSubjectName).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              _buildSearchAndFilters(subjectsProvider, subjectNames),
              Expanded(
                child: allSubjects.isEmpty && subjectsProvider.searchQuery.isEmpty
                    ? _buildEmptyState(context)
                    : filteredSubjects.isEmpty
                        ? _buildNoResultsState(context)
                        : _buildGroupedList(filteredSubjects),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 90), // Offset from nav bar
            child: FloatingActionButton(
              onPressed: () => _showAddSubjectDialog(context),
              backgroundColor: AppColors.BenwStart,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(SubjectsProvider provider, List<String> subjectNames) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search subjects...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                border: InputBorder.none,
                icon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                suffixIcon: provider.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Subject Chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subjectNames.length,
              itemBuilder: (context, index) {
                final name = subjectNames[index];
                final isSelected = _selectedSubjectName == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedSubjectName = name);
                    },
                    backgroundColor: AppColors.surfaceLight,
                    selectedColor: AppColors.BenwStart.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.BenwStart,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.BenwStart : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.BenwStart.withValues(alpha: 0.5) : Colors.white10,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Subject> subjects) {
    // Group subjects by subjectName
    final Map<String, List<Subject>> grouped = {};
    for (var subject in subjects) {
      if (!grouped.containsKey(subject.subjectName)) {
        grouped[subject.subjectName] = [];
      }
      grouped[subject.subjectName]!.add(subject);
    }

    final sortedSubjectNames = grouped.keys.toList()..sort();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        for (final name in sortedSubjectNames) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.BenwStart,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${grouped[name]!.length})',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final groupItems = grouped[name]!;
                  if (index * 2 >= groupItems.length) return null;
                  
                  final leftItem = groupItems[index * 2];
                  final rightItem = (index * 2 + 1 < groupItems.length) 
                      ? groupItems[index * 2 + 1] 
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SubjectCard(
                            subject: leftItem,
                            index: index * 2,
                            onTap: () => _openSubject(context, leftItem.id),
                            onLongPress: () => _deleteSubject(context, leftItem.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: rightItem != null
                              ? SubjectCard(
                                  subject: rightItem,
                                  index: index * 2 + 1,
                                  onTap: () => _openSubject(context, rightItem.id),
                                  onLongPress: () => _deleteSubject(context, rightItem.id),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  );
                },
                childCount: (grouped[name]!.length / 2).ceil(),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No subjects found',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.BenwStart.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: AppColors.BenwStart,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No subjects yet',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a subject\nor ask Benw to generate one',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  void _openSubject(BuildContext context, String subjectId) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SubjectDetailScreen(subjectId: subjectId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _deleteSubject(BuildContext context, String subjectId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Subject'),
        content: const Text('Are you sure you want to delete this subject?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<SubjectsProvider>(context, listen: false)
                  .deleteSubject(subjectId);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final titleController = TextEditingController();
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    int selectedYear = 1;
    int selectedSemester = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add New Subject', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title (e.g. Advanced Calculus)'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Subject Name (e.g. Math)'),
                ),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Brief Description'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Year', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                          DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            items: [1, 2, 3, 4, 5].map((y) => DropdownMenuItem(value: y, child: Text('$y Year'))).toList(),
                            onChanged: (val) => setDialogState(() => selectedYear = val!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Semester', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                          DropdownButton<int>(
                            value: selectedSemester,
                            isExpanded: true,
                            items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Sem $s'))).toList(),
                            onChanged: (val) => setDialogState(() => selectedSemester = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.BenwStart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  final provider = Provider.of<SubjectsProvider>(context, listen: false);
                  provider.addSubject(Subject(
                    id: const Uuid().v4(),
                    title: titleController.text,
                    subjectName: nameController.text.isEmpty ? 'General' : nameController.text,
                    content: contentController.text,
                    year: selectedYear,
                    semester: selectedSemester,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

