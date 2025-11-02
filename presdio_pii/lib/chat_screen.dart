import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';
  import '../services/pii_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/message_bubble.dart';
import 'message_details_screen.dart';
import 'constants/app_strings.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionUpdate;
  
  const ChatScreen({super.key, this.sessionId, this.onSessionUpdate});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    if (_currentSessionId != null) {
      _loadSessionMessages();
    }
  }

  Future<void> _loadSessionMessages() async {
    if (_currentSessionId == null) return;
    
    final messages = await LocalStorageService.getSessionMessages(_currentSessionId!);
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _isLoading = true;
    });

    try {
      ChatMessage? message;
      
      // Try with existing session first
      if (_currentSessionId != null) {
        try {
          message = await PIIService.processMessage(_currentSessionId!, text);
        } catch (e) {
          // Reset session on any error and try creating new one
          _currentSessionId = null;
        }
      }
      
      // Create new session if needed
      if (message == null) {
        try {
          final title = text.length > 50 ? '${text.substring(0, 50)}...' : text;
          final session = await ApiService.createSession(title: title);
          _currentSessionId = session.id;
          message = await PIIService.processMessage(_currentSessionId!, text);
        } catch (e) {
          throw Exception('Failed to create session: ${e.toString()}');
        }
      }
      
      // Save message to database
      if (_currentSessionId != null) {
        await LocalStorageService.saveMessage(_currentSessionId!, message!);
        print('[DEBUG] Saved message to database for session: $_currentSessionId');
      }
      
      setState(() {
        _messages.add(message!);
        _isLoading = false;
      });
      
      // Update session title if this is the first message
      if (_messages.length == 1 && _currentSessionId != null) {
        final title = text.length > 50 ? '${text.substring(0, 50)}...' : text;
        final sessions = await LocalStorageService.getSessions();
        final sessionIndex = sessions.indexWhere((s) => s.id == _currentSessionId);
        if (sessionIndex != -1) {
          final updatedSession = ChatSession(
            id: sessions[sessionIndex].id,
            title: title,
            createdAt: sessions[sessionIndex].createdAt,
            updatedAt: DateTime.now(),
          );
          await LocalStorageService.updateSession(updatedSession);
        }
      }
      
      widget.onSessionUpdate?.call();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2F2F2F),
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Text(AppStrings.connectionIssueTitle, style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              AppStrings.connectionIssueMessage,
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.buttonOk, style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showMessageDetails(ChatMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageDetailsScreen(message: message),
      ),
    );
  }





  Widget _buildProcessStep(String label, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color : Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? color : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF212121),
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 24),
                        Text(
                          AppStrings.privacyProtectionTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          AppStrings.protectionStepsMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          AppStrings.protectionStepsEmoji,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return MessageBubble(
                        message: message,
                        onTap: () => _showMessageDetails(message),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2F2F2F),
                border: Border(top: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1)),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppStrings.processingMessage,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildProcessStep(AppStrings.stepDetect, Colors.orange, true),
                                const Text(' → ', style: TextStyle(color: Colors.grey)),
                                _buildProcessStep(AppStrings.stepMask, Colors.blue, true),
                                const Text(' → ', style: TextStyle(color: Colors.grey)),
                                _buildProcessStep(AppStrings.stepProcess, Colors.green, true),
                                const Text(' → ', style: TextStyle(color: Colors.grey)),
                                _buildProcessStep(AppStrings.stepRespond, Colors.purple, false),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2F2F2F),
              border: Border(top: BorderSide(color: Color(0xFF404040), width: 1)),
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppStrings.messageInputHint,
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF404040)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF404040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: const Color(0xFF404040),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}