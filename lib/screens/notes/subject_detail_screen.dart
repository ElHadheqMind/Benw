import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:benw_edu/services/file_service.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/rag_service.dart';
import 'package:benw_edu/models/quiz_model.dart';
import 'package:benw_edu/widgets/interactive_quiz_widget.dart';
import 'dart:convert';
import 'package:benw_edu/models/subject.dart';
import 'package:benw_edu/widgets/benw_markdown.dart';

enum ChatMessageType { text, quiz }

class ChatMessage {
  final String role;
  final String? content;
  final ChatMessageType type;
  final Quiz? quiz;

  ChatMessage({
    required this.role,
    this.content,
    this.type = ChatMessageType.text,
    this.quiz,
  });
}

class SubjectDetailScreen extends StatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _chatMessages = [];
  bool _isAsking = false;
  final RagService _ragService = RagService();
  final BenwEduService _benwService = BenwEduService();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _askBenw(String question, String subjectContent) async {
    if (question.trim().isEmpty) return;
    
    setState(() {
      _chatMessages.add(ChatMessage(role: 'user', content: question));
      _isAsking = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      // Retrieve context from RAG
      final context = await _ragService.retrieveContext(question);
      
      final prompt = '''You are a professional academic assistant. Answer the user's question about their subject based on the following context. Provide a concise response. No humor. No emojis.
Context:
$subjectContent
$context

User Question: $question
Answer:''';

      final response = await _benwService.generateTextResponse(prompt);

      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(role: 'Benw', content: response));
          _isAsking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(role: 'Benw', content: 'Sorry, I had trouble answering that. Error: $e'));
          _isAsking = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _generateQuiz(String subjectTitle, String subjectContent) async {
    if (_isAsking) return;
    
    setState(() {
      _isAsking = true;
    });
    _scrollToBottom();

    try {
      // Retrieve specialized context for quiz generation
      final context = await _ragService.retrieveContext(subjectTitle);
      
      // Truncate content to avoid hitting context limits
      final truncatedContent = subjectContent.length > 1500 ? subjectContent.substring(0, 1500) + "..." : subjectContent;

      final prompt = '''Create a 3-question multiple choice quiz about the subject: $subjectTitle.
Respond ONLY with strict JSON in the following format:
{
  "title": "$subjectTitle Quiz",
  "questions": [
    {
      "question": "The question text here",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0,
      "explanation": "Why this answer is correct"
    }
  ]
}

Use the following content for accuracy:
$truncatedContent
$context

QUIZ JSON:''';

      final response = await _benwService.generateTextResponse(prompt);

      // Try to parse the JSON
      Quiz? quiz;
      try {
        String cleanJson = response.trim();
        if (cleanJson.contains('```json')) {
          cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
        } else if (cleanJson.contains('{')) {
          cleanJson = cleanJson.substring(cleanJson.indexOf('{'));
          final lastBrace = cleanJson.lastIndexOf('}');
          if (lastBrace != -1) cleanJson = cleanJson.substring(0, lastBrace + 1);
        }
        
        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        quiz = Quiz.fromJson(decoded);
      } catch (e) {
        debugPrint('Failed to parse quiz JSON: $e');
      }

      if (mounted) {
        setState(() {
          if (quiz != null) {
            _chatMessages.add(ChatMessage(
              role: 'Benw',
              type: ChatMessageType.quiz,
              quiz: quiz,
            ));
          } else {
            // Fallback to text display if parsing failed
            _chatMessages.add(ChatMessage(
              role: 'Benw',
              content: '### 📝 STUDY QUIZ FOR: $subjectTitle\n\n$response'
            ));
          }
          _isAsking = false;
        });
        
        // Wait for the UI to update with the new message before scrolling
        Future.delayed(const Duration(milliseconds: 200), () => _scrollToBottom());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(
            role: 'Benw', 
            content: 'I had trouble generating the quiz. Let\'s try again with a shorter section of your subject! Error: $e'
          ));
          _isAsking = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubjectsProvider>(
      builder: (context, subjectsProvider, child) {
        final subject = subjectsProvider.subjects
            .where((n) => n.id == widget.subjectId)
            .firstOrNull;

        if (subject == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: Text('Subject not found')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Focus the chat text field
            },
            backgroundColor: AppColors.BenwStart,
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            label: const Text('ASK Benw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.background,
                floating: true,
                pinned: true,
                expandedHeight: 120,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.attach_file_rounded, size: 20),
                    ),
                    onPressed: () async {
                      final file = await FileService().pickDocument();
                      if (file != null) {
                        await subjectsProvider.addAttachmentToSubject(subject.id, file);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                    onPressed: () {
                      subjectsProvider.deleteSubject(widget.subjectId);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          subject.accentColor.withValues(alpha: 0.15),
                          AppColors.background,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: subject.accentColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(subject.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: subject.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Year ${subject.year} • Sem ${subject.semester}',
                            style: TextStyle(color: subject.accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      subject.title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subject.subjectName.toUpperCase(),
                      style: TextStyle(color: AppColors.BenwStart, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 24),
                    // Attachments Section
                    if (subject.attachments.isNotEmpty) ...[
                       const Text('ATTACHMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 1.2)),
                       const SizedBox(height: 12),
                       SizedBox(
                         height: 40,
                         child: ListView.builder(
                           scrollDirection: Axis.horizontal,
                           itemCount: subject.attachments.length,
                           itemBuilder: (context, index) {
                             return Container(
                               margin: const EdgeInsets.only(right: 8),
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               decoration: BoxDecoration(
                                 color: AppColors.surfaceLight,
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: subject.accentColor.withValues(alpha: 0.2)),
                               ),
                               child: Row(
                                 children: [
                                   Icon(Icons.description_rounded, size: 14, color: subject.accentColor),
                                   const SizedBox(width: 6),
                                   Text(subject.attachments[index], style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                 ],
                               ),
                             );
                           },
                         ),
                       ),
                       const SizedBox(height: 24),
                    ],
                    // Content
                    BenwMarkdown(
                      subject.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.8,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 32),
                    // Action Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _generateQuiz(subject.title, subject.content),
                        icon: const Icon(Icons.psychology_rounded, size: 20),
                        label: const Text('GENERATE STUDY QUIZ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.BenwStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                          shadowColor: AppColors.BenwStart.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Chat Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.BenwStart),
                              const SizedBox(width: 8),
                              const Text('ASK ABOUT THIS SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.BenwStart)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_chatMessages.isEmpty)
                            const Text('Ask me anything about the content above or the attached documents!', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                          for (var msg in _chatMessages)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: msg.role == 'user' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(msg.role == 'user' ? 'YOU' : 'Benw', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textHint)),
                                  const SizedBox(height: 4),
                                  if (msg.type == ChatMessageType.quiz && msg.quiz != null)
                                    InteractiveQuizWidget(quiz: msg.quiz!)
                                  else if (msg.content != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: msg.role == 'user' ? AppColors.BenwStart.withValues(alpha: 0.1) : AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: BenwMarkdown(
                                          msg.content!,
                                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          if (_isAsking) const LinearProgressIndicator(minHeight: 2, color: AppColors.BenwStart, backgroundColor: Colors.transparent),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _chatController,
                            onSubmitted: (val) => _askBenw(val, subject.content),
                            decoration: InputDecoration(
                              hintText: 'Ask a question...',
                              hintStyle: const TextStyle(color: AppColors.textHint),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send_rounded, color: AppColors.BenwStart),
                                onPressed: () => _askBenw(_chatController.text, subject.content),
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


