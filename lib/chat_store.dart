import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Chat storage – persists chat sessions and messages in shared_preferences.
// Pure Dart, no extra deps, manual JSON encode/decode.
// ---------------------------------------------------------------------------

class ChatMessage {
  const ChatMessage({
    required this.role,  // 'user' | 'assistant'
    required this.content,
    required this.timestamp,
  });

  final String role;
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    role: j['role'] as String,
    content: j['content'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
  );

  /// Groq API-compatible map (only role + content).
  Map<String, String> toApiMap() => {'role': role, 'content': content};
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.model,
    required this.createdAt,
    required this.messages,
  });

  final int id;
  String title;
  String model;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'model': model,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
    id: j['id'] as int,
    title: j['title'] as String,
    model: j['model'] as String? ?? 'llama-3.3-70b-versatile',
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    messages: (j['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class ChatStore {
  static const _sessionsKey = 'milos.chat.sessions.v1';

  Future<List<ChatSession>> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> deleteSession(List<ChatSession> sessions, int id) async {
    sessions.removeWhere((s) => s.id == id);
    await saveSessions(sessions);
  }

  int nextId(List<ChatSession> sessions) =>
      sessions.isEmpty ? 1 : sessions.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
}
