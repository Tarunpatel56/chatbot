import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

class ChatService {
  final _client = http.Client();

  Future<bool> health() async {
    final res = await _client.get(Uri.parse('${Env.apiBase}/health'));
    return res.statusCode == 200;
  }

  Future<ChatReply> ask(String question) async {
    final url = Uri.parse('${Env.apiBase}/chat');
    final res = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question, 'temperature': 0.2}),
    );

    if (res.statusCode != 200) {
      throw Exception('Backend error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatReply.fromJson(data);
  }

  void dispose() {
    _client.close();
  }
}

class ChatReply {
  final String answer;
  final List<String> sources;

  ChatReply({required this.answer, required this.sources});

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      answer: json['answer'] ?? '',
      sources: (json['sources'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
