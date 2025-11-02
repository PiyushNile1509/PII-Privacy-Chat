import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestConnection extends StatefulWidget {
  @override
  _TestConnectionState createState() => _TestConnectionState();
}

class _TestConnectionState extends State<TestConnection> {
  String status = 'Testing...';

  @override
  void initState() {
    super.initState();
    testConnection();
  }

  Future<void> testConnection() async {
    final urls = [
      'http://127.0.0.1:5000/api/health',
      'http://10.0.2.2:5000/api/health',
      'http://localhost:5000/api/health',
    ];

    for (String url in urls) {
      try {
        print('Testing: $url');
        final response = await http.get(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          setState(() {
            status = 'SUCCESS: $url\nResponse: ${response.body}';
          });
          return;
        }
      } catch (e) {
        print('Failed $url: $e');
      }
    }
    
    setState(() {
      status = 'All connections failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connection Test')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(status, textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: testConnection,
                child: Text('Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}