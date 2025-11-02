import 'package:flutter/material.dart';
import 'services/pii_dependency_analyzer.dart';

class PIITestScreen extends StatefulWidget {
  const PIITestScreen({super.key});

  @override
  State<PIITestScreen> createState() => _PIITestScreenState();
}

class _PIITestScreenState extends State<PIITestScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _analysisResult;
  
  final List<String> _testCases = [
    "My name is Prasad and my phone number is 7418529635. Tell me the addition of it.",
    "My name is Prasad and my phone number is 7418529635.",
    "Hi, I'm John and my email is john@example.com. Can you help me?",
    "Calculate the sum of digits in my phone 9876543210.",
    "My name is Alice, phone 5551234567, email alice@test.com. Add the phone digits.",
  ];

  void _analyzeText() {
    if (_controller.text.trim().isEmpty) return;
    
    final result = PIIDependencyAnalyzer.analyzeQuery(_controller.text);
    setState(() {
      _analysisResult = result;
    });
  }

  void _loadTestCase(String testCase) {
    _controller.text = testCase;
    _analyzeText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PII Dependency Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Cases:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: _testCases.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(
                        _testCases[index],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _loadTestCase(_testCases[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your text:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type your message here...',
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _analyzeText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Analyze PII'),
              ),
            ),
            const SizedBox(height: 16),
            if (_analysisResult != null) ...[
              const Text(
                'Analysis Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildResultRow('Original Query', _analysisResult!['originalQuery']),
                          const SizedBox(height: 8),
                          _buildResultRow('Masked Query', _analysisResult!['maskedQuery']),
                          const SizedBox(height: 8),
                          _buildResultRow('Privacy Score', '${(_analysisResult!['privacyScore'] * 100).toStringAsFixed(1)}%'),
                          const SizedBox(height: 16),
                          
                          if (_analysisResult!['hasDependentPII'] == true) ...[
                            const Text(
                              'Dependent PII (Kept for computation):',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const SizedBox(height: 4),
                            ..._buildEntityList(_analysisResult!['dependentEntities']),
                            const SizedBox(height: 8),
                          ],
                          
                          if (_analysisResult!['hasNonDependentPII'] == true) ...[
                            const Text(
                              'Non-Dependent PII (Masked for privacy):',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            const SizedBox(height: 4),
                            ..._buildEntityList(_analysisResult!['nonDependentEntities']),
                            const SizedBox(height: 8),
                          ],
                          
                          if (_analysisResult!['hasDependentPII'] == false && _analysisResult!['hasNonDependentPII'] == false) ...[
                            const Text(
                              'No PII detected in this query.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Explanation:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(_getExplanation()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEntityList(List<dynamic> entities) {
    return entities.map<Widget>((entity) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 4),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: entity['isDependent'] == true ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text('${entity['type'].toUpperCase()}: ${entity['value']}'),
          ],
        ),
      );
    }).toList();
  }

  String _getExplanation() {
    if (_analysisResult == null) return '';
    
    final hasDep = _analysisResult!['hasDependentPII'] == true;
    final hasNonDep = _analysisResult!['hasNonDependentPII'] == true;
    
    if (hasDep && hasNonDep) {
      return 'This query contains both dependent and non-dependent PII. The system masks non-essential personal information (like names) for privacy while preserving data needed for computation (like phone numbers for mathematical operations).';
    } else if (hasDep) {
      return 'This query contains dependent PII that is necessary for computation. The system preserves this data to provide accurate results while maintaining functionality.';
    } else if (hasNonDep) {
      return 'This query contains non-dependent PII that can be safely masked. The system protects your privacy by replacing personal information with generic placeholders.';
    } else {
      return 'No personal information detected in this query. The system processes it normally without any privacy concerns.';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}