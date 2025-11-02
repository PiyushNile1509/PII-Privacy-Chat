import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class LoggingService {
  static String? _logFilePath;
  
  /// Initialize logging service and get log file path
  static Future<String> initializeLogging() async {
    if (_logFilePath != null) return _logFilePath!;
    
    try {
      // Get app documents directory
      final directory = Directory.current;
      final logsDir = Directory(path.join(directory.path, 'logs'));
      
      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      // Create log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      _logFilePath = path.join(logsDir.path, 'presidio_pipeline_$timestamp.log');
      
      // Write initial log entry
      await _writeToFile('=== Presidio Pipeline Logging Started ===\n');
      await _writeToFile('Timestamp: ${DateTime.now().toIso8601String()}\n');
      await _writeToFile('Log File: $_logFilePath\n\n');
      
      return _logFilePath!;
    } catch (e) {
      print('[ERROR] Failed to initialize logging: $e');
      // Fallback to current directory
      _logFilePath = path.join(Directory.current.path, 'presidio_pipeline.log');
      return _logFilePath!;
    }
  }
  
  /// Log the complete pipeline process
  static Future<void> logPipelineProcess({
    required String originalText,
    required String llmPrompt,
    required String llmResponse,
    required String reconstructedResponse,
    required List<Map<String, dynamic>> detectedEntities,
    required double privacyScore,
    required double processingTime,
    Map<String, String>? fakeToOriginalMap,
  }) async {
    try {
      await initializeLogging();
      
      final timestamp = DateTime.now().toIso8601String();
      final separator = '=' * 80;
      
      final logEntry = StringBuffer();
      logEntry.writeln(separator);
      logEntry.writeln('PRESIDIO PIPELINE EXECUTION');
      logEntry.writeln('Timestamp: $timestamp');
      logEntry.writeln('Processing Time: ${processingTime}s');
      logEntry.writeln('Privacy Score: ${privacyScore.toStringAsFixed(2)}%');
      logEntry.writeln(separator);
      
      // Original Text
      logEntry.writeln('\n1. ORIGINAL TEXT RECEIVED:');
      logEntry.writeln('-' * 40);
      logEntry.writeln(originalText);
      
      // Detected Entities
      logEntry.writeln('\n2. DETECTED PII ENTITIES:');
      logEntry.writeln('-' * 40);
      if (detectedEntities.isNotEmpty) {
        for (int i = 0; i < detectedEntities.length; i++) {
          final entity = detectedEntities[i];
          logEntry.writeln('Entity ${i + 1}:');
          logEntry.writeln('  Type: ${entity['entity_type']}');
          logEntry.writeln('  Position: ${entity['start']}-${entity['end']}');
          logEntry.writeln('  Confidence: ${(entity['score'] * 100).toStringAsFixed(1)}%');
          if (entity['original_text'] != null) {
            logEntry.writeln('  Original Value: "${entity['original_text']}"');
          }
        }
      } else {
        logEntry.writeln('No PII entities detected.');
      }
      
      // Fake Data Mapping
      if (fakeToOriginalMap != null && fakeToOriginalMap.isNotEmpty) {
        logEntry.writeln('\n3. FAKE DATA MAPPING:');
        logEntry.writeln('-' * 40);
        fakeToOriginalMap.forEach((fake, original) {
          logEntry.writeln('  "$original" → "$fake"');
        });
      }
      
      // LLM Prompt
      logEntry.writeln('\n4. LLM PROMPT (WITH FAKE DATA):');
      logEntry.writeln('-' * 40);
      logEntry.writeln(llmPrompt);
      
      // LLM Response
      logEntry.writeln('\n5. LLM RESPONSE:');
      logEntry.writeln('-' * 40);
      logEntry.writeln(llmResponse);
      
      // Reconstructed Response
      logEntry.writeln('\n6. RECONSTRUCTED RESPONSE (WITH ORIGINAL PII):');
      logEntry.writeln('-' * 40);
      logEntry.writeln(reconstructedResponse);
      
      logEntry.writeln('\n$separator\n');
      
      await _writeToFile(logEntry.toString());
      
      print('[LOG] Pipeline process logged to: $_logFilePath');
      
    } catch (e) {
      print('[ERROR] Failed to log pipeline process: $e');
    }
  }
  
  /// Log error messages
  static Future<void> logError(String error, {String? context}) async {
    try {
      await initializeLogging();
      
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = StringBuffer();
      
      logEntry.writeln('ERROR [$timestamp]');
      if (context != null) {
        logEntry.writeln('Context: $context');
      }
      logEntry.writeln('Error: $error');
      logEntry.writeln('-' * 40);
      
      await _writeToFile(logEntry.toString());
      
    } catch (e) {
      print('[ERROR] Failed to log error: $e');
    }
  }
  
  /// Write content to log file
  static Future<void> _writeToFile(String content) async {
    try {
      final file = File(_logFilePath!);
      await file.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      print('[ERROR] Failed to write to log file: $e');
    }
  }
  
  /// Get current log file path
  static String? getLogFilePath() => _logFilePath;
  
  /// Read log file content
  static Future<String> readLogFile() async {
    try {
      await initializeLogging();
      final file = File(_logFilePath!);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'Log file not found.';
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
  
  /// Clear log file
  static Future<void> clearLogs() async {
    try {
      await initializeLogging();
      final file = File(_logFilePath!);
      if (await file.exists()) {
        await file.writeAsString('');
        await _writeToFile('=== Log Cleared at ${DateTime.now().toIso8601String()} ===\n\n');
      }
    } catch (e) {
      print('[ERROR] Failed to clear logs: $e');
    }
  }
}