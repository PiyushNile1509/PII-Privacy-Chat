import 'package:flutter/material.dart';
import 'services/presidio_service.dart';

class PresidioTestScreen extends StatefulWidget {
  const PresidioTestScreen({super.key});

  @override
  State<PresidioTestScreen> createState() => _PresidioTestScreenState();
}

class _PresidioTestScreenState extends State<PresidioTestScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;
  Map<String, bool> _serviceHealth = {};

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _textController.text = "Hi, my name is John Doe. My email is john.doe@example.com and my phone is 555-123-4567.";
  }

  Future<void> _checkHealth() async {
    try {
      final health = await PresidioService.checkHealth();
      setState(() {
        _serviceHealth = health;
      });
    } catch (e) {
      setState(() {
        _error = 'Health check failed: $e';
      });
    }
  }

  Future<void> _processText() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await PresidioService.processTextWithLLM(_textController.text.trim());
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildHealthStatus() {
    return Card(
      color: const Color(0xFF2F2F2F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Health',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _serviceHealth['analyzer'] == true ? Icons.check_circle : Icons.error,
                  color: _serviceHealth['analyzer'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analyzer: ${_serviceHealth['analyzer'] == true ? 'Running' : 'Offline'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _serviceHealth['anonymizer'] == true ? Icons.check_circle : Icons.error,
                  color: _serviceHealth['anonymizer'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Anonymizer: ${_serviceHealth['anonymizer'] == true ? 'Running' : 'Offline'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _checkHealth,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh Health'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFF2F2F2F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processing Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // Privacy Score
            Row(
              children: [
                const Icon(Icons.security, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Privacy Score: ${_result!['privacy_score'].toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _result!['privacy_score'] > 80 ? Colors.green : 
                           _result!['privacy_score'] > 60 ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Entities Found
            Row(
              children: [
                const Icon(Icons.visibility, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Entities Found: ${_result!['entities_found']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Original Text
            const Text(
              'Original Text:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!['original_text'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            
            // LLM Prompt (with fake data)
            const Text(
              'LLM Prompt (with fake data):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!['llm_prompt'] ?? _result!['anonymized_text'],
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 16),
            
            // LLM Response
            const Text(
              'LLM Response:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!['llm_response'] ?? 'No LLM response',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
            const SizedBox(height: 16),
            
            // Reconstructed Response
            const Text(
              'Reconstructed Response (with original PII):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!['reconstructed_response'] ?? _result!['llm_response'] ?? 'No response',
                style: const TextStyle(color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            
            // Detected Entities
            if (_result!['analyzer_results'].isNotEmpty) ...[
              const Text(
                'Detected Entities:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ...(_result!['analyzer_results'] as List).map((entity) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entity['entity_type'],
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Score: ${(entity['score'] * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        title: const Text('Presidio Integration Test'),
        backgroundColor: const Color(0xFF2F2F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthStatus(),
            const SizedBox(height: 16),
            
            Card(
              color: const Color(0xFF2F2F2F),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Text Processing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter text with PII to test...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF404040)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF404040)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF404040),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...'),
                                ],
                              )
                            : const Text('Process with Presidio'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            _buildResultCard(),
          ],
        ),
      ),
    );
  }
}