import 'dart:convert';
import 'package:http/http.dart' as http;

import 'env.dart';

class ChatService {
  final String baseUrl = Env.apiBase;

  Future<Map<String, dynamic>> askQuestion(String question) async {
    final url = Uri.parse('$baseUrl/chat');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect: ${response.statusCode}');
    }
  }
}
