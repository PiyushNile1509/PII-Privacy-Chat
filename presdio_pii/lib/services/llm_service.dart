import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class LLMService {
  static const String geminiApiKey = 'AIzaSyDtNUvXpp63Sjl2GHEmaLtw831zEe8Cuz8'; // Replace with actual API key
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  
  /// Generate fake data for detected PII entities
  static Map<String, String> generateFakeData(List<Map<String, dynamic>> entities) {
    final fakeData = <String, String>{};
    final random = Random();
    
    for (final entity in entities) {
      final entityType = entity['entity_type'] as String;
      final originalText = entity['original_text'] as String;
      
      String fakeValue;
      switch (entityType) {
        case 'PERSON':
          fakeValue = _getFakeName();
          break;
        case 'EMAIL_ADDRESS':
          fakeValue = _getFakeEmail();
          break;
        case 'PHONE_NUMBER':
          fakeValue = _getFakePhone();
          break;
        case 'CREDIT_CARD':
          fakeValue = _getFakeCreditCard();
          break;
        case 'US_SSN':
          fakeValue = _getFakeSSN();
          break;
        case 'DATE_TIME':
          fakeValue = _getFakeDate();
          break;
        case 'LOCATION':
          fakeValue = _getFakeLocation();
          break;
        default:
          fakeValue = 'FAKE_${entityType}_${random.nextInt(1000)}';
      }
      
      fakeData[originalText] = fakeValue;
    }
    
    return fakeData;
  }
  
  /// Replace PII entities with fake data
  static String replaceWithFakeData(String text, List<Map<String, dynamic>> entities) {
    String result = text;
    final fakeData = generateFakeData(entities);
    
    // Sort entities by start position in reverse order to avoid position shifts
    final sortedEntities = List<Map<String, dynamic>>.from(entities);
    sortedEntities.sort((a, b) => (b['start'] as int).compareTo(a['start'] as int));
    
    for (final entity in sortedEntities) {
      final start = entity['start'] as int;
      final end = entity['end'] as int;
      final originalText = text.substring(start, end);
      final fakeValue = fakeData[originalText] ?? '[FAKE]';
      
      result = result.substring(0, start) + fakeValue + result.substring(end);
    }
    
    return result;
  }
  
  /// Send text to LLM and get response
  static Future<String> getLLMResponse(String text) async {
    if (geminiApiKey == 'YOUR_GEMINI_API_KEY') {
      // Fallback response when no API key is configured
      return _generateFallbackResponse(text);
    }
    
    try {
      final response = await http.post(
        Uri.parse('$geminiBaseUrl?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [{'text': text}]
          }]
        }),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] ?? _generateFallbackResponse(text);
          }
        }
      }
      
      throw Exception('Invalid response from Gemini API');
    } catch (e) {
      print('[ERROR] LLM request failed: $e');
      return _generateFallbackResponse(text);
    }
  }
  
  /// Reconstruct response by replacing fake data with original PII
  static String reconstructResponse(String llmResponse, Map<String, String> fakeToOriginalMap) {
    String result = llmResponse;
    
    for (final entry in fakeToOriginalMap.entries) {
      final fakeValue = entry.key;
      final originalValue = entry.value;
      result = result.replaceAll(fakeValue, originalValue);
    }
    
    return result;
  }
  
  // Fake data generators
  static String _getFakeName() {
    final names = ['John Smith', 'Jane Doe', 'Mike Johnson', 'Sarah Wilson', 'David Brown'];
    return names[Random().nextInt(names.length)];
  }
  
  static String _getFakeEmail() {
    final domains = ['example.com', 'test.org', 'sample.net'];
    final users = ['user', 'test', 'demo', 'sample'];
    final user = users[Random().nextInt(users.length)];
    final domain = domains[Random().nextInt(domains.length)];
    return '$user${Random().nextInt(999)}@$domain';
  }
  
  static String _getFakePhone() {
    final random = Random();
    return '555-${random.nextInt(900) + 100}-${random.nextInt(9000) + 1000}';
  }
  
  static String _getFakeCreditCard() {
    return '4532-1234-5678-9012'; // Fake Visa format
  }
  
  static String _getFakeSSN() {
    final random = Random();
    return '${random.nextInt(900) + 100}-${random.nextInt(90) + 10}-${random.nextInt(9000) + 1000}';
  }
  
  static String _getFakeDate() {
    final dates = ['January 15, 2020', 'March 22, 2021', 'July 4, 2019'];
    return dates[Random().nextInt(dates.length)];
  }
  
  static String _getFakeLocation() {
    final locations = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'];
    return locations[Random().nextInt(locations.length)];
  }
  
  static String _generateFallbackResponse(String text) {
    final lower = text.toLowerCase();
    
    if (lower.contains('name') || lower.contains('hello') || lower.contains('hi')) {
      return "Hello! Nice to meet you. Your personal information has been protected. How can I help you today?";
    }
    
    if (lower.contains('email')) {
      return "I see you mentioned an email address. Your contact information has been secured. What would you like to know?";
    }
    
    if (lower.contains('phone')) {
      return "I notice you shared a phone number. It has been anonymized for your security. How can I assist you?";
    }
    
    if (lower.contains('calculate') || lower.contains('add') || lower.contains('sum')) {
      final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.isNotEmpty) {
        final sum = numbers.reduce((a, b) => a + b);
        return "The sum is: $sum";
      }
    }
    
    return "I understand your message. Your privacy has been protected using advanced PII detection. How can I assist you further?";
  }
}