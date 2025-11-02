import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'constants/app_strings.dart';

class MessageDetailsScreen extends StatelessWidget {
  final ChatMessage message;

  const MessageDetailsScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      appBar: AppBar(
        title: const Text(AppStrings.messageDetailsTitle, style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2F2F2F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildTextSection(
              context,
              AppStrings.originalMessage,
              message.userMessage,
              Icons.message,
            ),
            const SizedBox(height: 16),
            _buildTextSection(
              context,
              AppStrings.anonymizedText,
              message.llmPrompt,
              Icons.send,
            ),
            const SizedBox(height: 16),
            _buildTextSection(
              context,
              AppStrings.aiResponse,
              message.botResponse,
              Icons.smart_toy,
            ),
            const SizedBox(height: 16),
            _buildTextSection(
              context,
              AppStrings.reconstructedText,
              message.reconstructedText,
              Icons.restore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: const Color(0xFF2F2F2F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: _getScoreColor(message.privacyScore),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.privacyScoreWithValue(message.privacyScore),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(message.privacyScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  AppStrings.processingTimeWithValue(message.processingTime),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Timestamp: ${DateFormat('MMM dd, yyyy HH:mm').format(message.timestamp)}',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection(BuildContext context, String title, String content, IconData icon) {
    return Card(
      color: const Color(0xFF2F2F2F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AppStrings.copiedToClipboard),
                        duration: Duration(seconds: 1),
                        backgroundColor: Color(0xFF404040),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: (title == AppStrings.aiResponse || title == AppStrings.reconstructedText) 
                ? MarkdownBody(
                    data: content.isEmpty ? AppStrings.noContentAvailable : content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 14),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                      code: const TextStyle(color: Colors.greenAccent, backgroundColor: Colors.black26),
                      codeblockDecoration: const BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      blockquote: const TextStyle(color: Colors.grey),
                      h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  )
                : Text(
                    content.isEmpty ? AppStrings.noContentAvailable : content,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}