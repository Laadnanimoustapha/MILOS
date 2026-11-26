import 'auth_service.dart';

// ---------------------------------------------------------------------------
// AI chat service – proxies requests through the MILOS Rust server.
// No API keys are stored on the user's phone.
// ---------------------------------------------------------------------------

/// Available AI models the user can choose from.
const groqModels = <String, String>{
  'openai/gpt-oss-20b': 'GPT-OSS 20B (fast)',
  'openai/gpt-oss-120b': 'GPT-OSS 120B',
  'qwen/qwen3.8-27b': 'Qwen 3.8 27B',
  'allam-2-7b': 'ALLaM 2 7B (Arabic)',
};

const defaultGroqModel = 'openai/gpt-oss-20b';

Future<String> groqChat({
  required String model,
  required List<Map<String, String>> messages,
  String? currentDatetime,
  List<String> memories = const [],
}) async {
  try {
    return await ApiClient.aiChat(
      model: model,
      messages: messages,
      currentDatetime: currentDatetime,
      memories: memories,
    );
  } on ApiException catch (e) {
    throw GroqException(e.message);
  }
}

class GroqException implements Exception {
  const GroqException(this.message);
  final String message;
  @override
  String toString() => message;
}
