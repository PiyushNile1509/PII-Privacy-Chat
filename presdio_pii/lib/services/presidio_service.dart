import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'logging_service.dart';

class PresidioService {
  static const String analyzerBaseUrl = 'http://localhost:3000';
  static const String anonymizerBaseUrl = 'http://localhost:3001';
  
  // Fallback URLs for different environments
  static const List<String> analyzerUrls = [
    'http://10.230.149.111:3000', // Your computer's IP
    'http://10.0.2.2:3000', // Android emulator
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ];
  
  static const List<String> anonymizerUrls = [
    'http://10.230.149.111:3001', // Your computer's IP
    'http://10.0.2.2:3001', // Android emulator
    'http://localhost:3001',
    'http://127.0.0.1:3001',
  ];

  static String? _workingAnalyzerUrl;
  static String? _workingAnonymizerUrl;

  /// Check health of Presidio services
  static Future<Map<String, bool>> checkHealth() async {
    bool analyzerHealthy = false;
    bool anonymizerHealthy = false;

    // Check analyzer health
    for (String url in analyzerUrls) {
      try {
        print('[DEBUG] Trying analyzer: $url');
        final response = await http.get(
          Uri.parse('$url/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          _workingAnalyzerUrl = url;
          analyzerHealthy = true;
          print('[SUCCESS] Analyzer connected: $url');
          break;
        }
      } catch (e) {
        print('[ERROR] Analyzer $url failed: $e');
        continue;
      }
    }

    // Check anonymizer health
    for (String url in anonymizerUrls) {
      try {
        print('[DEBUG] Trying anonymizer: $url');
        final response = await http.get(
          Uri.parse('$url/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          _workingAnonymizerUrl = url;
          anonymizerHealthy = true;
          print('[SUCCESS] Anonymizer connected: $url');
          break;
        }
      } catch (e) {
        print('[ERROR] Anonymizer $url failed: $e');
        continue;
      }
    }

    return {
      'analyzer': analyzerHealthy,
      'anonymizer': anonymizerHealthy,
    };
  }

  /// Analyze text for PII entities
  static Future<List<Map<String, dynamic>>> analyzeText(
    String text, {
    String language = 'en',
    List<String>? entities,
    double scoreThreshold = 0.35,
  }) async {
    if (_workingAnalyzerUrl == null) {
      final health = await checkHealth();
      if (!health['analyzer']!) {
        throw Exception('Presidio Analyzer service is not available');
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_workingAnalyzerUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'language': language,
          'entities': entities,
          'score_threshold': scoreThreshold,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Analyzer failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to analyze text: $e');
    }
  }

  /// Anonymize text using analyzer results
  static Future<String> anonymizeText(
    String text,
    List<Map<String, dynamic>> analyzerResults, {
    Map<String, Map<String, dynamic>>? anonymizers,
  }) async {
    if (_workingAnonymizerUrl == null) {
      final health = await checkHealth();
      if (!health['anonymizer']!) {
        throw Exception('Presidio Anonymizer service is not available');
      }
    }

    // Default anonymizers configuration
    final defaultAnonymizers = anonymizers ?? {
      'PERSON': {'type': 'replace', 'new_value': '[PERSON]'},
      'EMAIL_ADDRESS': {'type': 'replace', 'new_value': '[EMAIL]'},
      'PHONE_NUMBER': {'type': 'replace', 'new_value': '[PHONE]'},
      'CREDIT_CARD': {'type': 'replace', 'new_value': '[CREDIT_CARD]'},
      'US_SSN': {'type': 'replace', 'new_value': '[SSN]'},
      'US_DRIVER_LICENSE': {'type': 'replace', 'new_value': '[DRIVER_LICENSE]'},
      'DATE_TIME': {'type': 'replace', 'new_value': '[DATE]'},
      'LOCATION': {'type': 'replace', 'new_value': '[LOCATION]'},
      'DEFAULT': {'type': 'replace', 'new_value': '[PII]'},
    };

    try {
      final response = await http.post(
        Uri.parse('$_workingAnonymizerUrl/anonymize'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'analyzer_results': analyzerResults,
          'anonymizers': defaultAnonymizers,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['text'] ?? text;
      } else {
        throw Exception('Anonymizer failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to anonymize text: $e');
    }
  }

  /// Complete PII processing pipeline with LLM integration
  static Future<Map<String, dynamic>> processTextWithLLM(
    String text, {
    String language = 'en',
    List<String>? entities,
    double scoreThreshold = 0.35,
  }) async {
    try {
      final startTime = DateTime.now();
      
      // Step 1: Analyze text for PII
      final analyzerResults = await analyzeText(
        text,
        language: language,
        entities: entities,
        scoreThreshold: scoreThreshold,
      );

      // Step 2: Create entities with original text for fake data generation
      final entitiesWithText = analyzerResults.map((result) {
        final start = result['start'] as int;
        final end = result['end'] as int;
        return {
          ...result,
          'original_text': text.substring(start, end),
        };
      }).toList();

      // Step 3: Replace PII with fake data and get mapping
      final replaced = _replaceWithFakeDataAndMap(text, entitiesWithText);
      final textWithFakeData = replaced['text'] as String;
      final fakeToOriginalMap = Map<String, String>.from(replaced['fakeMap'] as Map);
      
      // Step 4: Get LLM response using fake data
      final llmResponse = await _getLLMResponse(textWithFakeData);
      
      // Step 5: Reconstruct response with original PII
      final reconstructedResponse = _reconstructResponseSafely(llmResponse, fakeToOriginalMap);

      // Step 7: Anonymize text for display
      final anonymizedText = await anonymizeText(text, analyzerResults);

      // Step 8: Calculate privacy score
      final privacyScore = _calculatePrivacyScore(text, analyzerResults);
      
      final processingTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      
      // Log to terminal
      _logToTerminal(
        originalText: text,
        llmPrompt: textWithFakeData,
        llmResponse: llmResponse,
        reconstructedResponse: reconstructedResponse,
        detectedEntities: entitiesWithText,
        privacyScore: privacyScore,
        processingTime: processingTime,
        fakeToOriginalMap: fakeToOriginalMap,
      );
      
      // Log to file
      await LoggingService.logPipelineProcess(
        originalText: text,
        llmPrompt: textWithFakeData,
        llmResponse: llmResponse,
        reconstructedResponse: reconstructedResponse,
        detectedEntities: entitiesWithText,
        privacyScore: privacyScore,
        processingTime: processingTime,
        fakeToOriginalMap: fakeToOriginalMap,
      );

      return {
        'original_text': text,
        'anonymized_text': anonymizedText,
        'llm_prompt': textWithFakeData,
        'llm_response': llmResponse,
        'reconstructed_response': reconstructedResponse,
        'analyzer_results': analyzerResults,
        'privacy_score': privacyScore,
        'entities_found': analyzerResults.length,
        'processing_time': processingTime,
        'fake_to_original_map': fakeToOriginalMap,
      };
    } catch (e) {
      throw Exception('PII processing failed: $e');
    }
  }
  
  /// Simple processing without LLM (for testing)
  static Future<Map<String, dynamic>> processText(
    String text, {
    String language = 'en',
    List<String>? entities,
    double scoreThreshold = 0.35,
  }) async {
    try {
      // Step 1: Analyze text for PII
      final analyzerResults = await analyzeText(
        text,
        language: language,
        entities: entities,
        scoreThreshold: scoreThreshold,
      );

      // Step 2: Anonymize text
      final anonymizedText = await anonymizeText(text, analyzerResults);

      // Step 3: Calculate privacy score
      final privacyScore = _calculatePrivacyScore(text, analyzerResults);

      return {
        'original_text': text,
        'anonymized_text': anonymizedText,
        'analyzer_results': analyzerResults,
        'privacy_score': privacyScore,
        'entities_found': analyzerResults.length,
        'processing_time': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      throw Exception('PII processing failed: $e');
    }
  }

  /// Calculate privacy score based on detected entities
  static double _calculatePrivacyScore(String text, List<Map<String, dynamic>> results) {
    if (results.isEmpty) return 100.0;

    double score = 100.0;
    final textLength = text.length;

    for (final result in results) {
      final entityType = result['entity_type'] as String;
      final confidence = (result['score'] as num).toDouble();
      final start = result['start'] as int;
      final end = result['end'] as int;
      final entityLength = end - start;

      // Calculate impact based on entity type, confidence, and coverage
      double impact = 0.0;
      
      switch (entityType) {
        case 'US_SSN':
        case 'CREDIT_CARD':
          impact = 25.0;
          break;
        case 'EMAIL_ADDRESS':
        case 'PHONE_NUMBER':
          impact = 15.0;
          break;
        case 'PERSON':
          impact = 10.0;
          break;
        case 'DATE_TIME':
        case 'LOCATION':
          impact = 5.0;
          break;
        default:
          impact = 8.0;
      }

      // Adjust impact based on confidence and coverage
      final coverageRatio = entityLength / textLength;
      final adjustedImpact = impact * confidence * (1 + coverageRatio);
      
      score -= adjustedImpact;
    }

    return score.clamp(0.0, 100.0).toDouble();
  }

  /// Get supported entities
  static Future<List<String>> getSupportedEntities({String language = 'en'}) async {
    if (_workingAnalyzerUrl == null) {
      final health = await checkHealth();
      if (!health['analyzer']!) {
        throw Exception('Presidio Analyzer service is not available');
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_workingAnalyzerUrl/supportedentities?language=$language'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> entities = json.decode(response.body);
        return entities.cast<String>();
      } else {
        throw Exception('Failed to get supported entities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get supported entities: $e');
    }
  }

  /// Get available anonymizers
  static Future<List<String>> getAvailableAnonymizers() async {
    if (_workingAnonymizerUrl == null) {
      final health = await checkHealth();
      if (!health['anonymizer']!) {
        throw Exception('Presidio Anonymizer service is not available');
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_workingAnonymizerUrl/anonymizers'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> anonymizers = json.decode(response.body);
        return anonymizers.cast<String>();
      } else {
        throw Exception('Failed to get anonymizers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get anonymizers: $e');
    }
  }
  
  // Helper methods for fake data processing
  
  /// Returns a Map with keys: 'text' and 'fakeMap'
  static Map<String, dynamic> _replaceWithFakeDataAndMap(
      String text, List<Map<String, dynamic>> entities) {
    String result = text;
    final fakeToOriginal = <String, String>{};
    final rand = Random();
    
    // Sort entities by start position in reverse order
    final sortedEntities = List<Map<String, dynamic>>.from(entities);
    sortedEntities.sort((a, b) => (b['start'] as int).compareTo(a['start'] as int));
    
    for (final entity in sortedEntities) {
      final start = entity['start'] as int;
      final end = entity['end'] as int;
      
      // Defensive index checks
      if (start < 0 || end > result.length || start >= end) {
        continue; // skip malformed entity
      }
      
      final original = result.substring(start, end);
      final fakeValue = _generateFakeValueForEntity(entity, rand);
      
      result = result.substring(0, start) + fakeValue + result.substring(end);
      fakeToOriginal[fakeValue] = original;
    }
    
    return {
      'text': result,
      'fakeMap': fakeToOriginal,
    };
  }
  
  static String _generateFakeValueForEntity(Map<String, dynamic> entity, Random rand) {
    final entityType = entity['entity_type'] as String;
    final r = rand.nextInt(1000);
    
    switch (entityType) {
      case 'PERSON':
        final names = ['John Smith', 'Jane Doe', 'Mike Johnson', 'Sarah Wilson'];
        return names[r % names.length];
      case 'EMAIL_ADDRESS':
        return 'user$r@example.com';
      case 'PHONE_NUMBER':
        return '555-${(r % 900 + 100).toString().padLeft(3, '0')}-${(r % 9000 + 1000).toString().padLeft(4, '0')}';
      case 'CREDIT_CARD':
        return '4532-1234-5678-9012';
      case 'US_SSN':
        return '${(r % 900 + 100).toString().padLeft(3, '0')}-${(r % 90 + 10).toString().padLeft(2, '0')}-${(r % 9000 + 1000).toString().padLeft(4, '0')}';
      case 'DATE_TIME':
        final dates = ['January 15, 2020', 'March 22, 2021', 'July 4, 2019'];
        return dates[r % dates.length];
      case 'LOCATION':
        final locations = ['New York', 'Los Angeles', 'Chicago'];
        return locations[r % locations.length];
      default:
        return 'FAKE_${entityType}_$r';
    }
  }
  
  static Future<String> _getLLMResponse(String text, {String? apiKey}) async {
    final geminiApiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyDtNUvXpp63Sjl2GHEmaLtw831zEe8Cuz8');
    
    print('[DEBUG] Calling Gemini API with text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    print('[DEBUG] Using API key: ${geminiApiKey.substring(0, 10)}...');
    
    if (geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_API_KEY') {
      try {
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';
        print('[DEBUG] API URL: $url');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'contents': [{
              'parts': [{'text': text}]
            }],
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 1024,
            }
          }),
        ).timeout(Duration(seconds: 15));
        
        print('[DEBUG] Gemini response status: ${response.statusCode}');
        print('[DEBUG] Gemini response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Defensive parsing
          if (data is Map && data.containsKey('candidates')) {
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final first = candidates[0] as Map<String, dynamic>;
              final content = first['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final textPart = parts[0] as Map<String, dynamic>?;
                final resultText = textPart?['text'] as String?;
                if (resultText != null && resultText.isNotEmpty) {
                  print('[SUCCESS] Got Gemini response: ${resultText.substring(0, resultText.length > 100 ? 100 : resultText.length)}...');
                  return resultText;
                }
              }
            }
          }
          print('[WARN] Gemini response parsing failed - no valid text found');
        } else {
          print('[ERROR] Gemini returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('[ERROR] Gemini API failed: $e');
      }
    } else {
      print('[DEBUG] No valid API key provided, using fallback');
    }
    return _getFallbackResponse(text);
  }
  
  static String _getFallbackResponse(String text) {
    print('[DEBUG] Using fallback response for: $text');
    final lower = text.toLowerCase();
    
    if (lower.contains('name') || lower.contains('hello') || lower.contains('hi')) {
      return "Hello! Nice to meet you. How can I help you today?";
    }
    
    if (lower.contains('email')) {
      return "I see you mentioned an email address. What would you like to know?";
    }
    
    if (lower.contains('phone')) {
      return "I notice you shared a phone number. How can I assist you?";
    }
    
    if (lower.contains('calculate') || lower.contains('add') || lower.contains('sum')) {
      final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.isNotEmpty) {
        final sum = numbers.reduce((a, b) => a + b);
        return "The sum is: $sum";
      }
    }
    
    return "I understand your message. How can I assist you further?";
  }
  
  /// Reconstructs by replacing exact fake tokens with original values safely
  static String _reconstructResponseSafely(String llmResponse, Map<String, String> fakeToOriginalMap) {
    String result = llmResponse;
    // Replace longer fake strings first to avoid partial replacements
    final entries = fakeToOriginalMap.entries.toList();
    entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    
    for (final entry in entries) {
      final fake = RegExp(RegExp.escape(entry.key));
      result = result.replaceAll(fake, entry.value);
    }
    return result;
  }  
  /// Log pipeline process to terminal
  static void _logToTerminal({
    required String originalText,
    required String llmPrompt,
    required String llmResponse,
    required String reconstructedResponse,
    required List<Map<String, dynamic>> detectedEntities,
    required double privacyScore,
    required double processingTime,
    required Map<String, String> fakeToOriginalMap,
  }) {
    final separator = '=' * 80;
    print('\n$separator');
    print('PRESIDIO PIPELINE EXECUTION');
    print('Timestamp: ${DateTime.now().toIso8601String()}');
    print('Processing Time: ${processingTime}s');
    print('Privacy Score: ${privacyScore.toStringAsFixed(2)}%');
    print(separator);
    
    print('\n1. ORIGINAL TEXT RECEIVED:');
    print('-' * 40);
    print(originalText);
    
    print('\n2. DETECTED PII ENTITIES:');
    print('-' * 40);
    if (detectedEntities.isNotEmpty) {
      for (int i = 0; i < detectedEntities.length; i++) {
        final entity = detectedEntities[i];
        print('Entity ${i + 1}:');
        print('  Type: ${entity['entity_type']}');
        print('  Position: ${entity['start']}-${entity['end']}');
        print('  Confidence: ${(entity['score'] * 100).toStringAsFixed(1)}%');
        if (entity['original_text'] != null) {
          print('  Original Value: "${entity['original_text']}"');
        }
      }
    } else {
      print('No PII entities detected.');
    }
    
    if (fakeToOriginalMap.isNotEmpty) {
      print('\n3. FAKE DATA MAPPING:');
      print('-' * 40);
      fakeToOriginalMap.forEach((fake, original) {
        print('  "$original" → "$fake"');
      });
    }
    
    print('\n4. LLM PROMPT (WITH FAKE DATA):');
    print('-' * 40);
    print(llmPrompt);
    
    print('\n5. LLM RESPONSE:');
    print('-' * 40);
    print(llmResponse);
    
    print('\n6. RECONSTRUCTED RESPONSE (WITH ORIGINAL PII):');
    print('-' * 40);
    print(reconstructedResponse);
    
    print('\n$separator\n');
  }
}