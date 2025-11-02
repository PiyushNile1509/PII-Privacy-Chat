class ChatMessage {
  final String id;
  final String userMessage;
  final String anonymizedText;
  final String llmPrompt;
  final String botResponse;
  final String reconstructedText;
  final double privacyScore;
  final double processingTime;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.userMessage,
    required this.anonymizedText,
    required this.llmPrompt,
    required this.botResponse,
    required this.reconstructedText,
    required this.privacyScore,
    required this.processingTime,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] Received JSON keys: ${json.keys}');
    print('[DEBUG] bot_response from JSON: ${json['bot_response']}');
    print('[DEBUG] reconstructed_text from JSON: ${json['reconstructed_text']}');
    
    final botResp = json['botResponse'] ?? json['bot_response'] ?? '';
    final reconText = json['reconstructedText'] ?? json['reconstructed_text'] ?? '';
    
    print('[DEBUG] Final botResponse: ${botResp.toString().substring(0, botResp.toString().length > 50 ? 50 : botResp.toString().length)}');
    print('[DEBUG] Final reconstructedText: ${reconText.toString().substring(0, reconText.toString().length > 50 ? 50 : reconText.toString().length)}');
    
    return ChatMessage(
      id: json['id'] ?? '',
      userMessage: json['userMessage'] ?? json['user_message'] ?? '',
      anonymizedText: json['anonymizedText'] ?? json['anonymized_text'] ?? '',
      llmPrompt: json['llmPrompt'] ?? json['llm_prompt'] ?? json['anonymizedText'] ?? json['anonymized_text'] ?? '',
      botResponse: botResp,
      reconstructedText: reconText,
      privacyScore: (json['privacyScore'] ?? json['privacy_score'] ?? 0.0).toDouble(),
      processingTime: (json['processingTime'] ?? json['processing_time'] ?? 0.0).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userMessage': userMessage,
      'anonymizedText': anonymizedText,
      'llmPrompt': llmPrompt,
      'botResponse': botResponse,
      'reconstructedText': reconstructedText,
      'privacyScore': privacyScore,
      'processingTime': processingTime,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}