#!/usr/bin/env python3
"""
Simple Python server to run Presidio services locally without Docker
"""

import sys
import subprocess
import threading
from flask import Flask, request, jsonify
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import RecognizerResult, OperatorConfig

# Initialize engines
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

# Analyzer app
analyzer_app = Flask('presidio-analyzer')

@analyzer_app.route('/health')
def analyzer_health():
    return "Presidio Analyzer service is up"

@analyzer_app.route('/analyze', methods=['POST'])
def analyze():
    try:
        data = request.get_json()
        text = data.get('text', '')
        language = data.get('language', 'en')
        entities = data.get('entities')
        score_threshold = data.get('score_threshold', 0.35)
        
        results = analyzer.analyze(
            text=text,
            language=language,
            entities=entities,
            score_threshold=score_threshold
        )
        
        return jsonify([{
            'entity_type': r.entity_type,
            'start': r.start,
            'end': r.end,
            'score': r.score
        } for r in results])
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@analyzer_app.route('/supportedentities')
def supported_entities():
    try:
        language = request.args.get('language', 'en')
        entities = analyzer.get_supported_entities(language)
        return jsonify(entities)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Anonymizer app
anonymizer_app = Flask('presidio-anonymizer')

@anonymizer_app.route('/health')
def anonymizer_health():
    return "Presidio Anonymizer service is up"

@anonymizer_app.route('/anonymize', methods=['POST'])
def anonymize():
    try:
        data = request.get_json()
        text = data.get('text', '')
        analyzer_results = data.get('analyzer_results', [])
        anonymizers_config = data.get('anonymizers', {})
        
        # Convert analyzer results
        results = []
        for result in analyzer_results:
            results.append(RecognizerResult(
                entity_type=result['entity_type'],
                start=result['start'],
                end=result['end'],
                score=result['score']
            ))
        
        # Convert anonymizers config
        operators = {}
        for entity_type, config in anonymizers_config.items():
            operators[entity_type] = OperatorConfig(
                operator_name=config.get('type', 'replace'),
                params=config
            )
        
        # Anonymize
        anonymized_result = anonymizer.anonymize(
            text=text,
            analyzer_results=results,
            operators=operators
        )
        
        return jsonify({
            'text': anonymized_result.text,
            'items': [{
                'start': item.start,
                'end': item.end,
                'entity_type': item.entity_type,
                'text': item.text,
                'operator': item.operator
            } for item in anonymized_result.items]
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@anonymizer_app.route('/anonymizers')
def anonymizers():
    try:
        return jsonify(anonymizer.get_anonymizers())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def run_analyzer():
    analyzer_app.run(host='0.0.0.0', port=3000, debug=False, threaded=True)

def run_anonymizer():
    anonymizer_app.run(host='0.0.0.0', port=3001, debug=False, threaded=True)

if __name__ == '__main__':
    print("Starting Presidio services...")
    print("Analyzer: http://localhost:3000")
    print("Anonymizer: http://localhost:3001")
    
    # Start both services in separate threads
    analyzer_thread = threading.Thread(target=run_analyzer)
    anonymizer_thread = threading.Thread(target=run_anonymizer)
    
    analyzer_thread.daemon = True
    anonymizer_thread.daemon = True
    
    analyzer_thread.start()
    anonymizer_thread.start()
    
    try:
        analyzer_thread.join()
        anonymizer_thread.join()
    except KeyboardInterrupt:
        print("\nShutting down services...")
        sys.exit(0)