import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'pii_dependency_analyzer.dart';
import 'presidio_service.dart';

class PIIService {
  static const String baseUrl = 'https://pii-backend-deploy.onrender.com/api';
  static const List<String> fallbackUrls = [
    'https://pii-backend-deploy.onrender.com/api',
  ];
  
  static Future<ChatMessage> processMessage(String sessionId, String text) async {
    try {
      // First try Presidio-based processing
      return await _processWithPresidio(sessionId, text);
    } catch (e) {
      print('[DEBUG] Presidio processing failed: $e');
      // Fallback to legacy backend processing
      return await _processWithBackend(sessionId, text);
    }
  }
  
  static Future<ChatMessage> _processWithPresidio(String sessionId, String text) async {
    print('[DEBUG] Processing with Presidio for session: $sessionId');
    
    // Check Presidio health
    final health = await PresidioService.checkHealth();
    if (!health['analyzer']! || !health['anonymizer']!) {
      throw Exception('Presidio services not available');
    }
    
    // Process text with Presidio and LLM integration
    final presidioResult = await PresidioService.processTextWithLLM(text);
    
    // Create message object with complete pipeline results
    final message = ChatMessage(
      id: _generateId(),
      userMessage: text,
      anonymizedText: presidioResult['anonymized_text'],
      llmPrompt: presidioResult['llm_prompt'],
      botResponse: presidioResult['llm_response'],
      reconstructedText: presidioResult['reconstructed_response'],
      privacyScore: presidioResult['privacy_score'],
      processingTime: presidioResult['processing_time'],
      timestamp: DateTime.now(),
    );
    
    print('[SUCCESS] Processed with Presidio + LLM - Privacy Score: ${message.privacyScore}');
    print('[DEBUG] Original: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    print('[DEBUG] Fake Data: ${presidioResult['llm_prompt'].toString().substring(0, presidioResult['llm_prompt'].toString().length > 50 ? 50 : presidioResult['llm_prompt'].toString().length)}...');
    print('[DEBUG] LLM Response: ${presidioResult['llm_response'].toString().substring(0, presidioResult['llm_response'].toString().length > 50 ? 50 : presidioResult['llm_response'].toString().length)}...');
    print('[DEBUG] Reconstructed: ${presidioResult['reconstructed_response'].toString().substring(0, presidioResult['reconstructed_response'].toString().length > 50 ? 50 : presidioResult['reconstructed_response'].toString().length)}...');
    
    return message;
  }
  
  static Future<ChatMessage> _processWithBackend(String sessionId, String text) async {
    // First analyze PII dependencies locally
    final analysis = PIIDependencyAnalyzer.analyzeQuery(text);
    print('PII Analysis: ${analysis['hasDependentPII'] ? 'Has dependent PII' : 'No dependent PII'}');
    
    try {
      print('[DEBUG] Connecting to backend for session: $sessionId');
      String? workingUrl;
      http.Response? response;
      
      // Try all URLs
      for (final url in fallbackUrls) {
        try {
          print('[DEBUG] Trying: $url');
          response = await http.post(
            Uri.parse('$url/sessions/$sessionId/messages'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'pii_analysis': analysis,
            }),
          ).timeout(Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            workingUrl = url;
            print('[SUCCESS] Connected to: $url');
            break;
          }
        } catch (e) {
          print('[ERROR] $url failed: $e');
          continue;
        }
      }
      
      if (response == null || workingUrl == null) {
        throw Exception('All backend URLs failed');
      }

      print('[DEBUG] Backend status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final message = ChatMessage(
          id: data['id'],
          userMessage: data['user_message'],
          anonymizedText: data['anonymized_text'] ?? analysis['maskedQuery'],
          llmPrompt: data['llm_prompt'] ?? analysis['maskedQuery'],
          botResponse: data['bot_response'],
          reconstructedText: data['reconstructed_text'],
          privacyScore: (data['privacy_score'] as num?)?.toDouble() ?? analysis['privacyScore'],
          processingTime: (data['processing_time'] as num).toDouble(),
          timestamp: DateTime.parse(data['timestamp']),
        );
        
        return message;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Backend failed: $e');
      return await processLocally(text, analysis);
    }
  }
  
  static Future<ChatMessage> processLocally(String text, [Map<String, dynamic>? analysis]) async {
    analysis ??= PIIDependencyAnalyzer.analyzeQuery(text);
    
    print('[DEBUG] ProcessLocally called for: $text');
    
    // Generate local response without backend dependency
    final anonymized = analysis['maskedQuery'] as String;
    final botResponse = await _generateBotResponse(anonymized);
    
    return ChatMessage(
      id: _generateId(),
      userMessage: text,
      anonymizedText: anonymized,
      llmPrompt: anonymized,
      botResponse: botResponse,
      reconstructedText: text,
      privacyScore: analysis['privacyScore'],
      processingTime: 1.0,
      timestamp: DateTime.now(),
    );
  }
  
  static Future<String> _generateLocalResponse(String originalText, Map<String, dynamic> analysis) async {
    final maskedText = analysis['maskedQuery'] as String;
    final hasDependentPII = analysis['hasDependentPII'] as bool;
    final hasNonDependentPII = analysis['hasNonDependentPII'] as bool;
    
    String contextPrompt = '';
    if (hasDependentPII && hasNonDependentPII) {
      contextPrompt = 'Note: Some personal information has been masked for privacy, but data needed for computation has been preserved. ';
    } else if (hasNonDependentPII) {
      contextPrompt = 'Note: Personal information has been masked for privacy protection. ';
    } else if (hasDependentPII) {
      contextPrompt = 'Note: Data needed for computation has been preserved. ';
    }
    
    return await _callGeminiAPI(contextPrompt + maskedText);
  }
  
  static Future<String> _callGeminiAPI(String text) async {
    print('[ERROR] Local Gemini should not be called - backend should handle this');
    return 'ERROR: Backend connection failed. Local processing disabled.';
  }
  
  static String _getFallbackResponse(String text) {
    return 'Backend connection failed. Please check your connection.';
  }
  
  static String _getResponseForQuery(String text) {
    // Remove hardcoded responses - this should call LLM API
    return 'Please integrate with actual LLM API (Gemini) using your API key to get real responses for: $text';
  }
  
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  static Future<String> _generateBotResponse(String anonymizedText) async {
    // Call Gemini API for actual LLM response
    try {
      const apiKey = 'AIzaSyDtNUvXpp63Sjl2GHEmaLtw831zEe8Cuz8';
      print('[DEBUG] Calling Gemini 2.0 Flash with text: $anonymizedText');
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [{'text': anonymizedText}]
          }]
        }),
      ).timeout(Duration(seconds: 15));
      
      print('[DEBUG] Gemini API response: ${response.statusCode}');
      print('[DEBUG] Gemini API body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final result = parts[0]['text'] as String?;
            if (result != null && result.isNotEmpty) {
              print('[SUCCESS] Got Gemini response: $result');
              return result;
            }
          }
        }
      }
      print('[ERROR] Gemini API failed or returned empty response');
    } catch (e) {
      print('[ERROR] Gemini API failed: $e');
    }
    
    return _getLocalFallbackResponse(anonymizedText);
  }
  
  static String _getLocalFallbackResponse(String text) {
    final lower = text.toLowerCase();
    
    
    if (lower.contains('calculate') || lower.contains('add') || lower.contains('sum')) {
      final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.isNotEmpty) {
        int sum = numbers.reduce((a, b) => a + b);
        return "The sum is: $sum";
      }
    }
    
    return "I understand your message. How can I assist you further?";
  }
}