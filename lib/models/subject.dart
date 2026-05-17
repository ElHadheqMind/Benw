import 'package:flutter/material.dart';
import 'package:benw_edu/theme/app_theme.dart';

class Subject {
  final String id;
  final String title;
  final String content;
  final String subjectName; // renamed from 'subject' to avoid conflict with class name
  final int year;
  final int semester;
  final DateTime createdAt;
  final Color accentColor;
  final List<String> attachments;

  Subject({
    required this.id,
    required this.title,
    required this.content,
    this.subjectName = 'General',
    this.year = 1,
    this.semester = 1,
    required this.createdAt,
    Color? accentColor,
    this.attachments = const [],
  }) : accentColor = accentColor ??
            AppColors.noteAccents[
                title.hashCode.abs() % AppColors.noteAccents.length];

  Subject copyWith({
    String? title,
    String? content,
    String? subjectName,
    int? year,
    int? semester,
    Color? accentColor,
    List<String>? attachments,
  }) {
    return Subject(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      subjectName: subjectName ?? this.subjectName,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      createdAt: createdAt,
      accentColor: accentColor ?? this.accentColor,
      attachments: attachments ?? this.attachments,
    );
  }
}

