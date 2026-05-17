import 'dart:convert';

class Quiz {
  final String title;
  final List<QuizQuestion> questions;

  Quiz({
    required this.title,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      title: json['title'] ?? 'Study Quiz',
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // Handle different possible JSON formats from LLM
    final rawOptions = json['options'] ?? json['choices'] ?? [];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString()).toList();
    }

    int parsedCorrectIndex = 0;
    final rawCorrect = json['correctIndex'] ?? json['correct_index'] ?? json['answer'];
    if (rawCorrect is int) {
      parsedCorrectIndex = rawCorrect;
    } else if (rawCorrect is String) {
      // If LLM provides "A", "B", etc.
      final charCode = rawCorrect.toUpperCase().codeUnitAt(0);
      if (charCode >= 65 && charCode <= 70) { // A-F
        parsedCorrectIndex = charCode - 65;
      } else {
        parsedCorrectIndex = int.tryParse(rawCorrect) ?? 0;
      }
    }

    return QuizQuestion(
      question: json['question'] ?? '',
      options: parsedOptions,
      correctIndex: parsedCorrectIndex,
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }
}
