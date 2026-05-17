import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../theme/app_theme.dart';
import 'package:benw_edu/widgets/benw_markdown.dart';

class InteractiveQuizWidget extends StatefulWidget {
  final Quiz quiz;
  final VoidCallback? onComplete;

  const InteractiveQuizWidget({
    super.key,
    required this.quiz,
    this.onComplete,
  });

  @override
  State<InteractiveQuizWidget> createState() => _InteractiveQuizWidgetState();
}

class _InteractiveQuizWidgetState extends State<InteractiveQuizWidget> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _isAnswered = false;
  bool _isFinished = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _submitAnswer(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswered = true;
      if (index == widget.quiz.questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentIndex++;
          _selectedAnswerIndex = null;
          _isAnswered = false;
        });
        _animationController.forward();
      });
    } else {
      setState(() {
        _isFinished = true;
      });
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return _buildResults();
    }

    final question = widget.quiz.questions[_currentIndex];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.BenwStart.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.BenwStart.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'QUESTION ${_currentIndex + 1}/${widget.quiz.questions.length}',
                    style: const TextStyle(
                      color: AppColors.BenwStart,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            BenwMarkdown(
              question.question,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 24),
            ...List.generate(
              question.options.length,
              (index) => _buildOption(index, question.options[index], question.correctIndex),
            ),
            if (_isAnswered) ...[
              const SizedBox(height: 24),
              if (question.explanation != null && question.explanation!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.BenwMid.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.BenwMid),
                          SizedBox(width: 8),
                          Text('EXPLANATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.BenwMid)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      BenwMarkdown(
                        question.explanation!,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.BenwStart,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentIndex < widget.quiz.questions.length - 1 ? 'NEXT QUESTION' : 'SEE RESULTS',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, String text, int correctIndex) {
    bool isSelected = _selectedAnswerIndex == index;
    bool isCorrect = index == correctIndex;
    
    Color borderColor = Colors.transparent;
    Color bgColor = AppColors.surfaceLight;
    Widget? icon;

    if (_isAnswered) {
      if (isCorrect) {
        borderColor = AppColors.BenwStart;
        bgColor = AppColors.BenwStart.withValues(alpha: 0.1);
        icon = const Icon(Icons.check_circle_rounded, color: AppColors.BenwStart, size: 20);
      } else if (isSelected) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.1);
        icon = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
      }
    } else {
      if (isSelected) {
        borderColor = AppColors.BenwMid;
        bgColor = AppColors.BenwMid.withValues(alpha: 0.1);
      }
    }

    return GestureDetector(
      onTap: () => _submitAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor != Colors.transparent ? borderColor : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
                child: BenwMarkdown(
                  text,
                  style: TextStyle(
                    color: _isAnswered && isCorrect ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected || (_isAnswered && isCorrect) ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
            ),
            if (icon != null) icon,
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    double percentage = (_score / widget.quiz.questions.length) * 100;
    String message = percentage >= 80 ? 'Mastery Achieved!' : percentage >= 50 ? 'Good Effort!' : 'Keep Studying!';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.BenwStart.withValues(alpha: 0.1),
            ),
            child: Icon(
              percentage >= 80 ? Icons.workspace_premium_rounded : Icons.psychology_rounded,
              size: 48,
              color: AppColors.BenwStart,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.quiz.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('SCORE', '$_score/${widget.quiz.questions.length}'),
              const SizedBox(width: 40),
              _buildStat('ACCURACY', '${percentage.toInt()}%'),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.BenwGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.BenwMid.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _score = 0;
                    _selectedAnswerIndex = null;
                    _isAnswered = false;
                    _isFinished = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('RETRY QUIZ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textHint, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}
