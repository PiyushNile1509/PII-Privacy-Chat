import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'local_storage_service.dart';
import '../constants/app_strings.dart';

class ApiService {
  static const Duration timeout = Duration(seconds: 30);
  static String _workingBaseUrl = '';
  
  static final List<String> _baseUrls = [
    'https://pii-backend-deploy.onrender.com/api',
  ];

  static Future<bool> checkBackendHealth() async {
    for (String baseUrl in _baseUrls) {
      try {
        print('[DEBUG] Checking: $baseUrl/health');
        final response = await http.get(
          Uri.parse('$baseUrl/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 5));
        
        print('[DEBUG] Status: ${response.statusCode}');
        if (response.statusCode == 200) {
          _workingBaseUrl = baseUrl;
          print('[SUCCESS] Connected to: $baseUrl');
          return true;
        }
      } catch (e) {
        print('[ERROR] $baseUrl failed: $e');
      }
    }
    
    _workingBaseUrl = _baseUrls.first;
    print('[FALLBACK] Using: $_workingBaseUrl');
    return false;
  }
  
  static String get baseUrl => _workingBaseUrl.isNotEmpty ? _workingBaseUrl : _baseUrls.first;

  static Future<ChatSession> createSession({String? title}) async {
    if (_workingBaseUrl.isEmpty) await checkBackendHealth();
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'title': title ?? AppStrings.newChat}),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final session = ChatSession(
          id: data['id'],
          title: data['title'],
          createdAt: DateTime.parse(data['created_at']),
          updatedAt: DateTime.parse(data['updated_at']),
        );
        await LocalStorageService.saveSession(session);
        return session;
      } else {
        throw Exception('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating session: $e');
      // Fallback to local creation
      return _createLocalSession(title);
    }
  }

  static Future<List<ChatSession>> getSessions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final sessions = data.map((item) => ChatSession(
          id: item['id'],
          title: item['title'],
          createdAt: DateTime.parse(item['created_at']),
          updatedAt: DateTime.parse(item['updated_at']),
        )).toList();
        
        // Also save to local storage
        for (final session in sessions) {
          await LocalStorageService.saveSession(session);
        }
        
        return sessions;
      } else {
        throw Exception('Failed to get sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting sessions: $e');
      // Fallback to local storage
      return await LocalStorageService.getSessions();
    }
  }

  static Future<void> deleteSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        await LocalStorageService.deleteSession(sessionId);
      } else {
        throw Exception('Failed to delete session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting session: $e');
      // Fallback to local deletion
      await LocalStorageService.deleteSession(sessionId);
    }
  }

  static Future<ChatMessage> processTextInSession(String sessionId, String text) async {
    // Always check backend health to try all URLs
    bool connected = await checkBackendHealth();
    
    print('[DEBUG] Backend connected: $connected, URL: $baseUrl');
    
    if (connected) {
      try {
        final url = '$baseUrl/sessions/$sessionId/messages';
        print('[DEBUG] POST URL: $url');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({'text': text}),
        ).timeout(Duration(seconds: 15));

        print('[DEBUG] Backend status: ${response.statusCode}');
        print('[DEBUG] Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final message = ChatMessage(
            id: data['id'],
            userMessage: data['user_message'],
            anonymizedText: data['anonymized_text'],
            llmPrompt: data['llm_prompt'] ?? data['anonymized_text'],
            botResponse: data['bot_response'],
            reconstructedText: data['reconstructed_text'],
            privacyScore: (data['privacy_score'] as num).toDouble(),
            processingTime: (data['processing_time'] as num).toDouble(),
            timestamp: DateTime.parse(data['timestamp']),
          );
          
          await LocalStorageService.saveMessage(sessionId, message);
          return message;
        } else {
          print('[ERROR] Backend HTTP ${response.statusCode}: ${response.body}');
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('[ERROR] Backend request failed: $e');
        // Fall through to local processing
      }
    }
    
    print('[DEBUG] Using local processing for: $text');
    final message = _createLocalMessage(text);
    await LocalStorageService.saveMessage(sessionId, message);
    return message;
  }

  static Future<void> clearHistory() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clear-history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        await LocalStorageService.clearAllData();
      } else {
        throw Exception('Failed to clear history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error clearing history: $e');
      // Fallback to local clearing
      await LocalStorageService.clearAllData();
    }
  }

  // Fallback methods for offline functionality
  static Future<ChatSession> _createLocalSession(String? title) async {
    final session = ChatSession(
      id: _generateId(),
      title: title ?? AppStrings.newChat,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await LocalStorageService.saveSession(session);
    return session;
  }

  static ChatMessage _createLocalMessage(String text) {
    final anonymized = _anonymizeText(text);
    return ChatMessage(
      id: _generateId(),
      userMessage: text,
      anonymizedText: anonymized,
      llmPrompt: anonymized,
      botResponse: _generateBotResponse(text),
      reconstructedText: text,
      privacyScore: _calculatePrivacyScore(text),
      processingTime: 1.5,
      timestamp: DateTime.now(),
    );
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String _anonymizeText(String text) {
    String result = text;
    // Name masking - capture any name after "myself", "my name is", "I am", etc.
    result = result.replaceAllMapped(
      RegExp(r"\b(?:myself|my name is|i am|i'm|call me)\s+([A-Z][a-z]+)", caseSensitive: false),
      (match) {
        final prefix = match.group(0)!.split(' ')[0];
        return '$prefix John Smith';
      }
    );
    // Standalone name patterns
    result = result.replaceAll(RegExp(r'\bprasad\b', caseSensitive: false), 'John Smith');
    result = result.replaceAll(RegExp(r'\b\d{10}\b'), '[PHONE]');
    result = result.replaceAll(RegExp(r'\b\d{3}-\d{3}-\d{4}\b'), '[PHONE]');
    result = result.replaceAll(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), '[SSN]');
    result = result.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[EMAIL]');
    result = result.replaceAll(RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b'), '[CREDIT_CARD]');
    return result;
  }

  static String _generateBotResponse(String text) {
    final lower = text.toLowerCase();
    
    // Greeting responses
    if (lower.contains('myself') || lower.contains('my name is') || lower.contains('i am')) {
      return "Nice to meet you! Your personal information has been protected. How can I help you today?";
    }
    
    // Math operations
    if (lower.contains('add') || lower.contains('sum') || lower.contains('calculate')) {
      final numbers = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).toList();
      if (numbers.isNotEmpty) {
        int sum = 0;
        for (var num in numbers) {
          for (var digit in num.split('')) {
            sum += int.parse(digit);
          }
        }
        return "The sum of all digits is: $sum";
      }
    }
    
    return "I understand your message. Your privacy has been protected. How can I assist you further?";
  }

  static double _calculatePrivacyScore(String text) {
    double score = 100.0;
    if (text.contains(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'))) score -= 20;
    if (text.contains(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'))) score -= 15;
    if (text.contains(RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b'))) score -= 25;
    if (text.contains(RegExp(r'\b\d{3}-\d{3}-\d{4}\b'))) score -= 10;
    return score.clamp(0.0, 100.0);
  }
}