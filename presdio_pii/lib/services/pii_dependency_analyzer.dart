import 'dart:convert';

enum PIIType {
  name,
  phone,
  email,
  address,
  ssn,
  creditCard,
  unknown
}

class PIIEntity {
  final String value;
  final PIIType type;
  final int startIndex;
  final int endIndex;
  final bool isDependent;

  PIIEntity({
    required this.value,
    required this.type,
    required this.startIndex,
    required this.endIndex,
    required this.isDependent,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'type': type.name,
    'startIndex': startIndex,
    'endIndex': endIndex,
    'isDependent': isDependent,
  };
}

class PIIDependencyAnalyzer {
  static final Map<String, RegExp> _piiPatterns = {
    'phone': RegExp(r'\b\d{10}\b|\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b'),
    'email': RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'),
    'name': RegExp(r"(?:myself|my name is|i am|i'm|call me)\s+([A-Za-z]+)", caseSensitive: false),
    'ssn': RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    'creditCard': RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
  };

  static final List<String> _computationKeywords = [
    'add', 'addition', 'sum', 'calculate', 'multiply', 'divide', 'subtract',
    'total', 'count', 'average', 'mean', 'percentage', 'compute', 'math',
    'arithmetic', 'operation', 'result', 'answer', 'solve'
  ];

  static final List<String> _contextualKeywords = [
    'tell me', 'what is', 'how much', 'find', 'get', 'show', 'display'
  ];

  static List<PIIEntity> detectPII(String text) {
    List<PIIEntity> entities = [];
    
    // Detect names (improved pattern with 'myself')
    final namePattern = RegExp(r"(?:myself|my name is|i am|i'm|call me|hi,?\s+i'm)\s+([A-Za-z]+(?:\s+[A-Za-z]+)?)", caseSensitive: false);
    namePattern.allMatches(text).forEach((match) {
      final value = match.group(1)!;
      entities.add(PIIEntity(
        value: value,
        type: PIIType.name,
        startIndex: match.start + match.group(0)!.indexOf(value),
        endIndex: match.start + match.group(0)!.indexOf(value) + value.length,
        isDependent: false,
      ));
    });
    
    // Detect phones
    final phonePattern = RegExp(r'\b\d{10}\b');
    phonePattern.allMatches(text).forEach((match) {
      final value = match.group(0)!;
      final isDependent = _isDependentPII(text, value, 'phone');
      entities.add(PIIEntity(
        value: value,
        type: PIIType.phone,
        startIndex: match.start,
        endIndex: match.end,
        isDependent: isDependent,
      ));
    });
    
    // Detect emails
    final emailPattern = RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b');
    emailPattern.allMatches(text).forEach((match) {
      final value = match.group(0)!;
      entities.add(PIIEntity(
        value: value,
        type: PIIType.email,
        startIndex: match.start,
        endIndex: match.end,
        isDependent: false,
      ));
    });
    
    // Detect detailed addresses (only mask if detailed)
    final detailedAddressPattern = RegExp(r'\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Dr|Boulevard|Blvd)\b', caseSensitive: false);
    detailedAddressPattern.allMatches(text).forEach((match) {
      final value = match.group(0)!;
      entities.add(PIIEntity(
        value: value,
        type: PIIType.address,
        startIndex: match.start,
        endIndex: match.end,
        isDependent: false,
      ));
    });

    return entities;
  }

  static bool _isDependentPII(String text, String piiValue, String piiType) {
    final lowerText = text.toLowerCase();
    
    // For phone numbers, check if computation keywords appear after the phone
    if (piiType == 'phone') {
      final phoneIndex = text.indexOf(piiValue);
      if (phoneIndex != -1) {
        final afterPhone = text.substring(phoneIndex + piiValue.length).toLowerCase();
        return _computationKeywords.any((keyword) => afterPhone.contains(keyword));
      }
    }
    
    // All other PII types are non-dependent
    return false;
  }

  static PIIType _stringToPIIType(String type) {
    switch (type) {
      case 'phone': return PIIType.phone;
      case 'email': return PIIType.email;
      case 'name': return PIIType.name;
      case 'ssn': return PIIType.ssn;
      case 'creditCard': return PIIType.creditCard;
      default: return PIIType.unknown;
    }
  }

  static String maskNonDependentPII(String text, List<PIIEntity> entities) {
    String maskedText = text;
    
    // Sort entities by start index in descending order to avoid index shifting
    entities.sort((a, b) => b.startIndex.compareTo(a.startIndex));
    
    for (var entity in entities) {
      if (!entity.isDependent) {
        String mask = _generateMask(entity.type, entity.value);
        maskedText = maskedText.replaceRange(
          entity.startIndex, 
          entity.endIndex, 
          mask
        );
      }
    }
    
    return maskedText;
  }

  static String _generateMask(PIIType type, String originalValue) {
    switch (type) {
      case PIIType.name:
        return _generateFakeName();
      case PIIType.phone:
        return _generateFakePhone();
      case PIIType.email:
        return _generateFakeEmail();
      case PIIType.address:
        return '[ADDRESS]';
      case PIIType.ssn:
        return '[SSN]';
      case PIIType.creditCard:
        return '[CREDIT_CARD]';
      default:
        return '[PII]';
    }
  }
  
  static String _generateFakeName() {
    final names = ['John', 'Alice', 'Bob', 'Sarah', 'Mike', 'Emma'];
    return names[(DateTime.now().millisecondsSinceEpoch % names.length)];
  }
  
  static String _generateFakePhone() {
    return '${5550000000 + (DateTime.now().millisecondsSinceEpoch % 10000)}';
  }
  
  static String _generateFakeEmail() {
    final domains = ['example.com', 'test.com', 'demo.org'];
    final users = ['user', 'test', 'demo', 'sample'];
    final user = users[(DateTime.now().millisecondsSinceEpoch % users.length)];
    final domain = domains[(DateTime.now().millisecondsSinceEpoch % domains.length)];
    return '$user@$domain';
  }

  static Map<String, dynamic> analyzeQuery(String query) {
    final entities = detectPII(query);
    final maskedQuery = maskNonDependentPII(query, entities);
    
    final dependentEntities = entities.where((e) => e.isDependent).toList();
    final nonDependentEntities = entities.where((e) => !e.isDependent).toList();
    
    return {
      'originalQuery': query,
      'maskedQuery': maskedQuery,
      'allEntities': entities.map((e) => e.toJson()).toList(),
      'dependentEntities': dependentEntities.map((e) => e.toJson()).toList(),
      'nonDependentEntities': nonDependentEntities.map((e) => e.toJson()).toList(),
      'hasDependentPII': dependentEntities.isNotEmpty,
      'hasNonDependentPII': nonDependentEntities.isNotEmpty,
      'privacyScore': _calculatePrivacyScore(entities),
    };
  }

  static double _calculatePrivacyScore(List<PIIEntity> entities) {
    if (entities.isEmpty) return 1.0;
    
    final maskedCount = entities.where((e) => !e.isDependent).length;
    return maskedCount / entities.length;
  }
}