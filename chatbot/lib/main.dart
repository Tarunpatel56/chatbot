import 'package:flutter/material.dart';
import 'chat_service.dart';

void main() => runApp(const GaleApp());

class GaleApp extends StatelessWidget {
  const GaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gale Encyclopedia Chat',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const ChatPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _service = ChatService();
  final _messages = <_Message>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Message(role: Role.user, text: q));
      _ctrl.clear();
      _loading = true;
      _error = null;
    });

    try {
      final reply = await _service.ask(q);
      setState(() {
        _messages.add(_Message(role: Role.assistant, text: reply.answer, sources: reply.sources));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gale Encyclopedia Chat'),
        actions: [
          IconButton(
            tooltip: 'Check backend',
            icon: const Icon(Icons.health_and_safety),
            onPressed: () async {
              final ok = await _service.health();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Backend OK' : 'Backend unreachable')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = _messages[i];
                final align = m.role == Role.user ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                final color  = m.role == Role.user ? Colors.blue[50] : Colors.grey[100];

                return Column(
                  crossAxisAlignment: align,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: SelectableText(m.text),
                    ),
                    if (m.sources.isNotEmpty && m.role == Role.assistant)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Sources: ${m.sources.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask something from the Gale Encyclopedia…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ask'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum Role { user, assistant }

class _Message {
  final Role role;
  final String text;
  final List<String> sources;
  _Message({required this.role, required this.text, this.sources = const []});
}
