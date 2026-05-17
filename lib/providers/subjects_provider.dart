import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:benw_edu/models/subject.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/services/rag_service.dart';
import 'package:benw_edu/services/file_service.dart';
import 'dart:io';

class SubjectsProvider extends ChangeNotifier {
  final List<Subject> _subjects = [];
  final _uuid = const Uuid();
  final _ragService = RagService();
  String _searchQuery = '';

  List<Subject> get subjects {
    if (_searchQuery.isEmpty) return List.unmodifiable(_subjects);
    return _subjects.where((subject) {
      return subject.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             subject.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             subject.subjectName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String get searchQuery => _searchQuery;

  List<String> get subjectNames {
    final s = _subjects.map((n) => n.subjectName).toSet().toList();
    s.sort();
    return s;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  SubjectsProvider() {
    // Add some sample subjects
    _subjects.addAll([
      Subject(
        id: _uuid.v4(),
        title: 'Math: Calculus Fundamentals 📐',
        subjectName: 'Math',
        year: 1,
        semester: 2,
        content:
            'Key topics to review for the midterm:\n\n• Limits and Continuity\n• Power Rule, Product Rule, and Quotient Rule\n• Chain Rule for composite functions\n• Basic integration and the Fundamental Theorem of Calculus\n\nRemember to practice at least 5 problems for each rule!',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        accentColor: AppColors.noteAccents[0],
        attachments: ['calculus_advanced_integration.txt'],
      ),
      Subject(
        id: _uuid.v4(),
        title: 'Physics: Newton\'s Second Law 🍎',
        subjectName: 'Physics',
        year: 2,
        semester: 1,
        content:
            'Experiment Notes:\n\nFormula: F = ma (Force = Mass × Acceleration)\n\n• If force increases, acceleration increases (proportional)\n• If mass increases, acceleration decreases (inversely proportional)\n\nPractical examples: Pushing a car vs. pushing a bike with the same force.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        accentColor: AppColors.noteAccents[2],
        attachments: ['physics_quantum.txt'],
      ),
      Subject(
        id: _uuid.v4(),
        title: 'English: Essay Structure Tips ✍️',
        subjectName: 'English',
        year: 1,
        semester: 1,
        content:
            'Standard 5-paragraph essay format:\n\n1. Introduction (Hook, Background, Thesis)\n2. Body Paragraph 1 (Evidence & Analysis)\n3. Body Paragraph 2 (Evidence & Analysis)\n4. Body Paragraph 3 (Evidence & Analysis)\n5. Conclusion (Restate Thesis, Final Thoughts)\n\nAlways use transition words like "Furthermore", "In contrast", and "Consequently".',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        accentColor: AppColors.noteAccents[4],
      ),
    ]);
    
    _initRag();
  }

  /// Lazily syncs existing subjects to RAG in the background.
  /// Does NOT block startup — RAG will fall back to in-memory if model isn't ready.
  Future<void> _initRag() async {
    for (var subject in _subjects) {
      _syncToRag(subject);
    }
  }

  void _syncToRag(Subject subject) {
    final attachmentsInfo = subject.attachments.isNotEmpty 
        ? "\nAttached Files: ${subject.attachments.join(', ')}" 
        : "";
    final chunk = "Subject: ${subject.subjectName} (Year ${subject.year}, Sem ${subject.semester})\nSubject created on ${subject.createdAt.toIso8601String()}:\nTitle: ${subject.title}\nContent: ${subject.content}$attachmentsInfo";
    _ragService.upsertDocument(subject.id, chunk);
  }

  List<Subject> getSubjectsForDay(DateTime day) {
    return _subjects.where((subject) {
      return subject.createdAt.year == day.year &&
          subject.createdAt.month == day.month &&
          subject.createdAt.day == day.day;
    }).toList();
  }

  void addSubject(Subject subject) {
    _subjects.insert(0, subject);
    _syncToRag(subject);
    notifyListeners();
  }

  void updateSubject(String id, {String? title, String? content, String? subjectName, int? year, int? semester}) {
    final index = _subjects.indexWhere((n) => n.id == id);
    if (index != -1) {
      _subjects[index] = _subjects[index].copyWith(
        title: title, 
        content: content, 
        subjectName: subjectName,
        year: year,
        semester: semester,
      );
      _syncToRag(_subjects[index]);
      notifyListeners();
    }
  }

  void deleteSubject(String id) {
    _subjects.removeWhere((n) => n.id == id);
    _ragService.deleteDocument(id);
    notifyListeners();
  }

  Future<void> addAttachmentToSubject(String subjectId, File file) async {
    final index = _subjects.indexWhere((n) => n.id == subjectId);
    if (index != -1) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final currentAttachments = List<String>.from(_subjects[index].attachments);
      if (!currentAttachments.contains(fileName)) {
        currentAttachments.add(fileName);
        _subjects[index] = _subjects[index].copyWith(attachments: currentAttachments);
        
        // Also index the content of the file in RAG if possible
        final extractedText = await FileService().extractText(file);
        if (extractedText.isNotEmpty) {
          final chunkId = "${subjectId}_attach_${currentAttachments.length}";
          _ragService.upsertDocument(chunkId, "Document for Subject ${_subjects[index].title}:\n$extractedText");
        }
        
        _syncToRag(_subjects[index]);
        notifyListeners();
      }
    }
  }

  Subject createSubjectFromBenw({
    required String title,
    required String content,
    String subjectName = 'General',
    int year = 1,
    int semester = 1,
    Color? color,
  }) {
    final subject = Subject(
      id: _uuid.v4(),
      title: title,
      content: content,
      subjectName: subjectName,
      year: year,
      semester: semester,
      createdAt: DateTime.now(),
      accentColor: color,
    );
    addSubject(subject);
    return subject;
  }
}

