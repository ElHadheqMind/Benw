import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:provider/provider.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/providers/calendar_provider.dart';
import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/audio_recording_service.dart';
import 'package:benw_edu/services/image_service.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/widgets/benw_message_bubble.dart';
import 'package:benw_edu/providers/settings_provider.dart';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:benw_edu/widgets/glass_container.dart';

enum BenwMode { subject, planner }

class BenwChatSheet extends StatefulWidget {
  final BenwMode mode;

  const BenwChatSheet({super.key, required this.mode});

  @override
  State<BenwChatSheet> createState() => _benwChatSheetState();
}

class _benwChatSheetState extends State<BenwChatSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final BenwEduService _benwService = BenwEduService();
  final AudioRecordingService _audioService = AudioRecordingService();
  final ImageService _imageService = ImageService();
  
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String _lastWords = '';

  late AnimationController _recordingController;

  @override
  void initState() {
    super.initState();
    _recordingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _messages.add(_ChatMessage(
      message: widget.mode == BenwMode.subject
          ? 'Hey! 👋 Tell me what you\'d like to learn about, or ask me any academic question! I\'ll create a beautiful subject summary for you.'
          : 'Hey! 📅 I\'m your Smart Planner. Tell me about your upcoming tests or goals, and I\'ll proactively organize your whole week for you!',
      isUser: false,
    ));

    // Handle Greeting
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Welcome message is added in initState
    });
  }



  void _handleSubjectAgentResult(Map<String, dynamic> result) {
    if (!mounted) return;
    final action = result['action'];
    final data = result['data'];
    final subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);

    if (action == 'general_response') {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(message: data['answer'] as String? ?? 'I am here to help!', isUser: false));
        });
        return;
    }

    if (action == 'list_notes') {
        final date = DateTime.parse(data['date'] as String);
        final subjects = subjectsProvider.getSubjectsForDay(date);
        
        String msg = subjects.isEmpty ? "I couldn't find any subjects for that date." : "Here are your subjects:\n\n";
        for (var n in subjects) { msg += "📌 **${n.title}**\n${n.content}\n\n"; }
        
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(message: msg.trim(), isUser: false));
        });
    } else {
        final subjectData = data as Map<String, dynamic>;
        final subject = subjectsProvider.createSubjectFromBenw(
          title: subjectData['title'] as String? ?? 'Subject Note',
          subjectName: subjectData['subject'] as String? ?? 'General',
          content: subjectData['content'] as String? ?? 'No content extracted.',
        );

        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(
            message: '✨ Created subject: "${subject.title}"\n\n${subject.content}',
            isUser: false,
          ));
        });
    }
  }

  void _handleCalendarAgentResult(Map<String, dynamic> result) {
    if (!mounted) return;
    final action = result['action'];
    final data = result['data'];
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);

    if (action == 'general_response') {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(message: data['answer'] as String? ?? 'I am here to help!', isUser: false));
        });
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        // Focus mode removed
        return;
    }

    if (action == 'list_events') {
        final date = DateTime.parse(data['date'] as String);
        final events = calendarProvider.getEventsForDay(date);
        
        String msg = events.isEmpty ? "You have nothing scheduled for that day." : "Here is your schedule:\n\n";
        for (var e in events) { msg += "📅 **${e.title}** at ${e.formattedTime}\n${e.description}\n\n"; }

        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(message: msg.trim(), isUser: false));
        });
    } else if (action == 'update_event' || action == 'delete_event') {
        final now = DateTime.now();
        int y = data['year'] ?? now.year;
        int m = data['month'] ?? now.month;
        int d = data['day'] ?? now.day;
        int h = data['hour'] ?? 10;
        
        final targetDate = DateTime(y, m, d);
        final events = calendarProvider.getEventsForDay(targetDate);
        final targetEvent = events.where((e) => e.time?.hour == h).firstOrNull;

        if (action == 'delete_event') {
          if (targetEvent != null) {
            calendarProvider.deleteEvent(targetEvent.id);
            setState(() {
              _isLoading = false;
              _messages.add(_ChatMessage(message: "🗑️ Deleted your ${h}:00 session.", isUser: false));
            });
          } else {
            setState(() {
              _isLoading = false;
              _messages.add(_ChatMessage(message: "❓ I couldn't find a session at ${h}:00 to delete.", isUser: false));
            });
          }
        } else {
          // update_event
          if (targetEvent != null) {
            calendarProvider.updateEvent(
              targetEvent.id,
              title: data['title'],
              type: data['type'] != null ? EventType.values.firstWhere((t) => t.name.toLowerCase() == data['type'].toString().toLowerCase().replaceAll('_', ''), orElse: () => EventType.study) : null,
            );
            setState(() {
              _isLoading = false;
              _messages.add(_ChatMessage(message: "✅ Updated your ${h}:00 session to: ${data['title'] ?? targetEvent.title}", isUser: false));
            });
          } else {
            calendarProvider.createEventFromBenw(
              title: data['title'] ?? 'New Session',
              date: targetDate,
              time: TimeOfDay(hour: h, minute: 0),
            );
            setState(() {
              _isLoading = false;
              _messages.add(_ChatMessage(message: "✅ Added new session at ${h}:00: ${data['title']}", isUser: false));
            });
          }
        }
    } else {
        final List<CalendarEvent> scheduledEvents = [];
        final eventList = data is List ? data : [data];
        
        for (final eventData in eventList) {
          final now = DateTime.now();
          DateTime targetDate;
          
          if (eventData['day_offset'] != null) {
            final offset = (eventData['day_offset'] as num).toInt();
            targetDate = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
          } else {
            int y = eventData['year'] ?? now.year;
            int m = eventData['month'] ?? now.month;
            int d = eventData['day'] ?? now.day;
            targetDate = DateTime(y, m, d);
          }

          int h = eventData['hour'] ?? 10;
          int min = eventData['minute'] ?? 0;

          final event = calendarProvider.createEventFromBenw(
            title: eventData['title'] as String? ?? 'Voice Event',
            date: targetDate,
            time: TimeOfDay(hour: h, minute: min),
            description: eventData['description'] as String? ?? '',
          );
          scheduledEvents.add(event);
        }

        setState(() {
          _isLoading = false;
          String responseMsg;
          if (scheduledEvents.length == 1) {
            final event = scheduledEvents.first;
            responseMsg = '✅ Planned:\n📌 ${event.title}\n📅 ${event.formattedDate} at ${event.formattedTime}\n\nAnything else?';
          } else {
            responseMsg = '✅ Planned ${scheduledEvents.length} events for you:\n\n';
            for (final event in scheduledEvents) {
              responseMsg += '• ${event.title} (${event.formattedDate} @ ${event.formattedTime})\n';
            }
          }
          _messages.add(_ChatMessage(message: responseMsg, isUser: false));
        });
    }
  }
  Future<void> _pickAndProcessImage(bool fromCamera) async {
    Navigator.pop(context); // Close the modal bottom sheet
    setState(() => _isLoading = true);
    _scrollToBottom();
    try {
      final imageBytes = await _imageService.pickImageBytes(fromCamera: fromCamera);
      
      if (imageBytes == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      setState(() {
        _messages.add(_ChatMessage(
          message: '📷 Image captured. Sending to Benw for vision analysis...',
          isUser: true,
        ));
      });
      _scrollToBottom();
      
      // Use Benw's multimodal vision capacity to process image directly
      final BenwResponse = await _benwService.processImageIntent(
        imageBytes,
        widget.mode == BenwMode.subject ? 'subject' : 'planner',
        onRouteDecision: (reason) {
          // Handled internally by service status, no need to clutter chat
          log('Benw Routing: $reason');
        }
      );

      if (BenwResponse['action'] != null) {
        if (widget.mode == BenwMode.subject) {
          _handleSubjectAgentResult(BenwResponse);
        } else {
          _handleCalendarAgentResult(BenwResponse);
        }
      } else if (BenwResponse['type'] == 'note') {
        _handleSubjectAgentResult(BenwResponse);
      } else {
        _handleCalendarAgentResult(BenwResponse);
      }
    } catch (e) {
      debugPrint('[VISION] Inference error: $e');
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          message: '❌ Failed to analyze image. Make sure it is clear and contains academic details.',
          isUser: false,
        ));
      });
    }
    _scrollToBottom();
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
                title: const Text('Take Photo', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _pickAndProcessImage(true),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _pickAndProcessImage(false),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(message: text, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final history = _messages.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.message,
    }).toList();

    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final calendarContext = calendarProvider.getWeekText();

    try {
      final result = await _benwService.generateAssistantResponse(
        text,
        chatHistory: history,
        calendarContext: calendarContext,
      );
      
      final parsed = _benwService.parseCalendarActions(result.response);
      
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(message: parsed.cleanedText, isUser: false));
      });

      if (result.agent == 'planner_agent') {
        // If the model used tags instead of JSON action, we can still process them
        for (final action in parsed.actions) {
          _handleCalendarAgentResult({
            'action': action['action'],
            'data': action,
          });
        }
        
        // Also handle the primary JSON action if present
        if (result.action != null && result.action != 'general_response') {
          _handleCalendarAgentResult({
            'action': result.action,
            'data': result.data,
          });
        }
      } else if (result.agent == 'subject_agent') {
        _handleSubjectAgentResult({
          'action': result.action,
          'data': result.data,
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          message: '❌ Sorry, I encountered an error. Please try again.',
          isUser: false,
        ));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.BenwGradient),
                  child: const Center(child: Text('G', style: TextStyle(fontSize: 18, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Benw AI', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      _isLoading ? 'Thinking...' : 'Ready',
                      style: TextStyle(color: AppColors.BenwStart, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.textHint.withValues(alpha: 0.1), height: 1),
          // Messages
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return const BenwMessageBubble(message: '', isUser: false, isLoading: true);
                    }
                    final msg = _messages[index];
                    return Column(
                      crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        BenwMessageBubble(message: msg.message, isUser: msg.isUser, index: index),
                        if (msg.isAudio && msg.audioPath != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, right: 12),
                            child: GestureDetector(
                              onTap: () => _audioService.playLastRecording(),
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                borderRadius: 12,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 18),
                                    SizedBox(width: 4),
                                    Text('Play Recording', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Input area
          Container(
            padding: EdgeInsets.only(left: 20, right: 12, top: 12, bottom: 12 + bottomInset),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.textHint.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) => setState(() {}),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: widget.mode == BenwMode.subject ? 'Ask or learn with Benw...' : 'Ask about your schedule or add session...',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_textController.text.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: AppColors.textHint),
                    onPressed: _showImageOptions,
                  ),
                if (_textController.text.isEmpty)
                  const SizedBox(width: 4),
                _buildActionButton(Icons.send_rounded, _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback? onTap) {
    return Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.BenwGradient),
      child: IconButton(icon: Icon(icon, size: 20), color: Colors.white, onPressed: onTap),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _imageService.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String message;
  final bool isUser;
  final bool isAudio;
  final String? audioPath;

  _ChatMessage({
    required this.message,
    required this.isUser,
    this.isAudio = false,
    this.audioPath,
  });
}
