import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_store.dart';
import 'groq_keys_page.dart';
import 'groq_service.dart';
import 'task.dart';
import 'task_store.dart';

// ---------------------------------------------------------------------------
// Colour tokens (match the rest of the app)
// ---------------------------------------------------------------------------
const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

// ---------------------------------------------------------------------------
// System prompt sent to the AI on every session.
// Instructs it to extract tasks and return JSON when ready.
// ---------------------------------------------------------------------------
const _systemPrompt = '''
You are Milos — a wise, warm old man who has seen it all and is now here to help. You speak with gentle patience, a touch of dry humour, and the calm authority of someone who has earned it. You are like that grandfather who always knows what needs to be done.

Your job is to have a natural, friendly conversation with the user in whatever language they write to you (Arabic, Moroccan Darija, or English), understand their plans and intentions, and help them turn them into tasks. Always reply in the same language the user writes in.

Personality:
- Warm, patient, slightly old-fashioned but wise.
- Use occasional expressions like "my friend", "yak", "listen to me, my son/daughter", "in my day…" (but don't overdo it).
- Never rush. If something is unclear, ask gently like an elder would.
- When things go wrong, be forgiving and kind — "No problem, let's fix it together."

IMPORTANT RULES:
1. Converse naturally and warmly in the user's language. Ask clarifying questions if something is unclear (date, time, priority, etc.).
2. When you have gathered enough information for one or more tasks, output a special JSON block EXACTLY like this (no markdown code fences, just the raw marker):
   <<TASKS_JSON>>
   [{"title":"...","remindAt":"2024-11-10T09:00:00","remindUntil":"2024-11-10T10:00:00","importance":"normal","scheduleMode":"range","repeat":"none","customRepeatEvery":1,"customRepeatUnit":"days","superReminderIntervalMinutes":15}]
   <<END_TASKS_JSON>>
3. importance must be one of: normal, necessary, superNecessary
4. scheduleMode must be one of: range (time window), fixed (single point in time)
5. repeat must be one of: none, daily, weekly, monthly, custom. If the user mentions doing something regularly, every day, daily, every week, every month, every X days, set repeat accordingly (and customRepeatEvery/customRepeatUnit for custom intervals).
6. customRepeatUnit must be one of: days, weeks, months
7. All dates must be ISO 8601 format. Use the user's local context (today is: REPLACE_TODAY).
8. After outputting the JSON, ask the user to approve the tasks in your warm old-man voice.
9. If the user refuses or says something is wrong, apologise gently and ask what needs to be fixed — the way a kind grandfather would. Never get frustrated.
10. Never output the JSON unless you are confident you have enough data to populate ALL required fields. If unsure, ask first.
11. Keep answers concise but human. Do not add unsolicited advice.
12. When the user approves the tasks, do NOT output <<TASKS_JSON>> again. Just say a warm, brief word of encouragement or confirmation.
''';

// ---------------------------------------------------------------------------
// AiChatPage – entry point
// ---------------------------------------------------------------------------
class AiChatPage extends StatefulWidget {
  /// [addTasksCallback] is called when the user approves AI-generated tasks.
  const AiChatPage({super.key, required this.addTasksCallback});
  final Future<void> Function(List<Task> tasks) addTasksCallback;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _store = ChatStore();
  final List<ChatSession> _sessions = [];
  ChatSession? _active;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<ChatSession> sessions = [];
    try {
      sessions = await _store
          .loadSessions()
          .timeout(const Duration(seconds: 5));
      for (final session in sessions) {
        if (!groqModels.containsKey(session.model)) {
          session.model = defaultGroqModel;
        }
      }
    } catch (_) {
      // A storage failure must not block access to the chat screen.
    }
    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(sessions);
      _loading = false;
    });
  }

  Future<void> _newChat() async {
    final session = ChatSession(
      id: _store.nextId(_sessions),
      title: 'New chat',
      model: defaultGroqModel,
      createdAt: DateTime.now(),
      messages: [],
    );
    _sessions.insert(0, session);
    await _store.saveSessions(_sessions);
    if (mounted) setState(() => _active = session);
  }

  Future<void> _openApiKeys() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const GroqKeysPage()),
  );

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('Delete "${session.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_active?.id == session.id) setState(() => _active = null);
    await _store.deleteSession(_sessions, session.id);
    if (mounted) setState(() {});
  }

  Future<void> _onMessageAdded(ChatSession session) async {
    // Auto-update title from first user message.
    if (session.messages.length == 1 && session.messages.first.role == 'user') {
      final firstMsg = session.messages.first.content;
      session.title = firstMsg.length > 40
          ? '${firstMsg.substring(0, 37)}...'
          : firstMsg;
    }
    await _store.saveSessions(_sessions);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Milos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        leading: _active != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                onPressed: () => setState(() => _active = null),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: _ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _muted),
            tooltip: 'API keys',
            onPressed: _openApiKeys,
          ),
          if (_active == null)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: _teal),
              tooltip: 'New chat',
              onPressed: _newChat,
            ),
          if (_active != null)
            _ModelSelector(
              selected: _active!.model,
              onChanged: (m) {
                setState(() => _active!.model = m);
                _store.saveSessions(_sessions);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _active != null
              ? _ChatView(
                  key: ValueKey(_active!.id),
                  session: _active!,
                  onMessageAdded: () => _onMessageAdded(_active!),
                  addTasksCallback: widget.addTasksCallback,
                )
              : _SessionList(
                  sessions: _sessions,
                  onSelect: (s) => setState(() => _active = s),
                  onDelete: _deleteSession,
                  onNew: _newChat,
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session list screen
// ---------------------------------------------------------------------------
class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.onSelect,
    required this.onDelete,
    required this.onNew,
  });

  final List<ChatSession> sessions;
  final ValueChanged<ChatSession> onSelect;
  final ValueChanged<ChatSession> onDelete;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 52, color: _teal),
            const SizedBox(height: 16),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Milos is waiting. Start a conversation.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final lastMsg = session.messages.isNotEmpty
            ? session.messages.last.content
            : 'No messages yet';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(session),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: _teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _muted),
                      onPressed: () => onDelete(session),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chat view – the actual conversation UI
// ---------------------------------------------------------------------------
class _ChatView extends StatefulWidget {
  const _ChatView({
    super.key,
    required this.session,
    required this.onMessageAdded,
    required this.addTasksCallback,
  });

  final ChatSession session;
  final VoidCallback onMessageAdded;
  final Future<void> Function(List<Task> tasks) addTasksCallback;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  // Pending tasks parsed from AI response waiting for user approval.
  List<Map<String, dynamic>>? _pendingTasks;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
      _pendingTasks = null;
    });

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    widget.session.messages.add(userMsg);
    widget.onMessageAdded();
    _scrollToBottom();

    // Build message history for the API (system + all messages).
    final today = _todayString();
    final systemContent = _systemPrompt.replaceFirst('REPLACE_TODAY', today);
    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemContent},
      ...widget.session.messages.map((m) => m.toApiMap()),
    ];

    try {
      final reply = await groqChat(
        model: widget.session.model,
        messages: apiMessages,
      );

      // Always strip JSON block from stored/displayed reply, even if parsing fails.
      final cleanReply = reply
          .replaceAll(RegExp(r'<<TASKS_JSON>>.*?<<END_TASKS_JSON>>', dotAll: true), '')
          .trim();
      final extracted = _extractTasks(reply);

      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: cleanReply.isEmpty ? '(tasks generated below)' : cleanReply,
        timestamp: DateTime.now(),
      );
      widget.session.messages.add(assistantMsg);
      widget.onMessageAdded();

      if (extracted != null && mounted) {
        setState(() => _pendingTasks = extracted);
      }
    } on GroqException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  List<Map<String, dynamic>>? _extractTasks(String reply) {
    // Use regex so surrounding whitespace/newlines around markers are tolerated.
    final m = RegExp(
      r'<<TASKS_JSON>>\s*([\s\S]*?)\s*<<END_TASKS_JSON>>',
      dotAll: true,
    ).firstMatch(reply);
    if (m == null) return null;
    try {
      final jsonStr = m.group(1)!.trim();
      final list = jsonDecode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _approveTasks() async {
    if (_pendingTasks == null) return;
    final taskStore = TaskStore();
    final existing = await taskStore.load();
    int nextId = existing.isEmpty
        ? 1
        : existing.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

    final tasks = <Task>[];
    for (final raw in _pendingTasks!) {
      try {
        final task = Task(
          id: nextId++,
          title: raw['title'] as String,
          remindAt: DateTime.parse(raw['remindAt'] as String),
          remindUntil: DateTime.parse(raw['remindUntil'] as String),
          importance: TaskImportance.values.firstWhere(
            (v) => v.name == raw['importance'],
            orElse: () => TaskImportance.normal,
          ),
          scheduleMode: TaskScheduleMode.values.firstWhere(
            (v) => v.name == raw['scheduleMode'],
            orElse: () => TaskScheduleMode.range,
          ),
          repeat: TaskRepeat.values.firstWhere(
            (v) => v.name == raw['repeat'],
            orElse: () => TaskRepeat.none,
          ),
          customRepeatEvery: (raw['customRepeatEvery'] as num?)?.toInt() ?? 1,
          customRepeatUnit: TaskRepeatUnit.values.firstWhere(
            (v) => v.name == raw['customRepeatUnit'],
            orElse: () => TaskRepeatUnit.days,
          ),
          superReminderIntervalMinutes:
              (raw['superReminderIntervalMinutes'] as num?)?.toInt() ?? 15,
          steps: (raw['steps'] as List<dynamic>?)?.cast<String>() ?? const [],
        );
        tasks.add(task);
      } catch (_) {
        // Skip malformed tasks silently.
      }
    }

    if (tasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not parse any valid tasks.')),
        );
      }
      return;
    }

    await widget.addTasksCallback(tasks);
    setState(() => _pendingTasks = null);

    // Let AI know tasks were approved.
    final confirmMsg = ChatMessage(
      role: 'user',
      content: '[System] User approved the tasks. They have been added.',
      timestamp: DateTime.now(),
    );
    widget.session.messages.add(confirmMsg);

    final apiMessages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _systemPrompt.replaceFirst('REPLACE_TODAY', _todayString()),
      },
      ...widget.session.messages.map((m) => m.toApiMap()),
    ];

    setState(() => _sending = true);
    try {
      final reply = await groqChat(
        model: widget.session.model,
        messages: apiMessages,
      );
      final cleanReply = reply
          .replaceAll(RegExp(r'<<TASKS_JSON>>.*<<END_TASKS_JSON>>', dotAll: true), '')
          .trim();
      if (cleanReply.isNotEmpty) {
        widget.session.messages.add(ChatMessage(
          role: 'assistant',
          content: cleanReply,
          timestamp: DateTime.now(),
        ));
        widget.onMessageAdded();
      }
    } catch (_) {
      // Don't block on confirmation reply failure.
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tasks.length} task${tasks.length > 1 ? 's' : ''} added!'),
          backgroundColor: _teal,
        ),
      );
    }
  }

  Future<void> _rejectTasks() async {
    setState(() => _pendingTasks = null);

    // Send a "what went wrong" follow-up.
    final rejectMsg = ChatMessage(
      role: 'user',
      content: '[System] User rejected the tasks. Please ask what went wrong.',
      timestamp: DateTime.now(),
    );
    widget.session.messages.add(rejectMsg);

    final apiMessages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _systemPrompt.replaceFirst('REPLACE_TODAY', _todayString()),
      },
      ...widget.session.messages.map((m) => m.toApiMap()),
    ];

    setState(() => _sending = true);
    try {
      final reply = await groqChat(
        model: widget.session.model,
        messages: apiMessages,
      );
      final cleanReply = reply
          .replaceAll(RegExp(r'<<TASKS_JSON>>.*<<END_TASKS_JSON>>', dotAll: true), '')
          .trim();
      if (cleanReply.isNotEmpty) {
        widget.session.messages.add(ChatMessage(
          role: 'assistant',
          content: cleanReply,
          timestamp: DateTime.now(),
        ));
        widget.onMessageAdded();
      }
    } catch (_) {
      // Ignore.
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Strip JSON blocks; also hide messages that become empty after stripping
    // (handles old sessions saved before the JSON-stripping fix).
    final stripRe = RegExp(r'<<TASKS_JSON>>.*?<<END_TASKS_JSON>>', dotAll: true);
    final messages = widget.session.messages
        .where((m) =>
          !m.content.startsWith('[System]') &&
          m.content.replaceAll(stripRe, '').trim().isNotEmpty)
        .toList();

    return Column(
      children: [
        // Message list.
        Expanded(
          child: messages.isEmpty
              ? _EmptyChat(onSuggestionTap: (s) {
                  _controller.text = s;
                  _send();
                })
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const _TypingIndicator();
                    }
                    final msg = messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MessageBubble(message: msg),
                    );
                  },
                ),
        ),

        // Pending task approval panel.
        if (_pendingTasks != null)
          _TaskApprovalPanel(
            tasks: _pendingTasks!,
            onApprove: _approveTasks,
            onReject: _rejectTasks,
          ),

        // Error.
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB54141), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

        // Input bar.
        _InputBar(
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFE8F5F2),
            child: Icon(Icons.elderly_rounded, size: 15, color: _teal),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: message.content));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _teal : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFFE9EFED)),
              ),
              child: Text(
                message.content.replaceAll(RegExp(r'<<TASKS_JSON>>.*?<<END_TASKS_JSON>>', dotAll: true), '').trim(),
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : _ink,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFDDF2ED),
            child: Icon(Icons.person_outline_rounded, size: 14, color: _teal),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator (3 animated dots)
// ---------------------------------------------------------------------------
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 36),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EFED)),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Row(
              children: List.generate(3, (i) {
                final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Task approval panel
// ---------------------------------------------------------------------------
class _TaskApprovalPanel extends StatelessWidget {
  const _TaskApprovalPanel({
    required this.tasks,
    required this.onApprove,
    required this.onReject,
  });

  final List<Map<String, dynamic>> tasks;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4EDE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded, size: 16, color: _teal),
                const SizedBox(width: 6),
                Text(
                  '${tasks.length} task${tasks.length > 1 ? 's' : ''} to add',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),
          ...tasks.map((t) => _TaskPreviewRow(task: t)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE9EFED)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _muted,
                      side: const BorderSide(color: Color(0xFFCDD8D5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Not right'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add tasks'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final title = task['title'] as String? ?? 'Untitled';
    final remindAt = task['remindAt'] as String? ?? '';
    DateTime? dt;
    try {
      dt = DateTime.parse(remindAt);
    } catch (_) {}

    final importanceRaw = task['importance'] as String? ?? 'normal';
    final importance = TaskImportance.values.firstWhere(
      (v) => v.name == importanceRaw,
      orElse: () => TaskImportance.normal,
    );
    const importanceColors = {
      TaskImportance.normal: _teal,
      TaskImportance.necessary: Color(0xFF3988A0),
      TaskImportance.superNecessary: Color(0xFFC36E36),
    };
    const importanceLabels = {
      TaskImportance.normal: 'NORMAL',
      TaskImportance.necessary: 'NECESSARY',
      TaskImportance.superNecessary: 'SUPER NECESSARY',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: _teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (dt != null)
            Text(
              '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          const SizedBox(width: 6),
          Text(
            importanceLabels[importance]!,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: importanceColors[importance],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 10,
        top: 10,
        bottom: MediaQuery.viewInsetsOf(context).bottom > 0 ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EFED))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: const InputDecoration(
                  hintText: 'Tell me what you want to do…',
                  hintStyle: TextStyle(fontSize: 14, color: _muted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _teal,
                    ),
                  ),
                )
              : Material(
                  color: _teal,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onSend,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Empty chat with quick suggestions
// ---------------------------------------------------------------------------
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestionTap});
  final ValueChanged<String> onSuggestionTap;

  static const _suggestions = [
    'I need to call the doctor tomorrow morning',
    'Remind me to submit the report on Friday afternoon',
    'غدا عندي موعد عند الطبيب الساعة 10',
    'نهار الجمعة كيجي خويا من السفر',
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.elderly_rounded, size: 56, color: _teal),
        const SizedBox(height: 14),
        const Text(
          'Milos is here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tell me what you have planned, my friend.\nI\'ll take care of the rest.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions.map((s) => _SuggestionChip(
            text: s,
            onTap: () => onSuggestionTap(s),
          )).toList(),
        ),
      ],
    ),
  );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4EDE8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: _ink),
        textDirection: TextDirection.rtl,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Model selector dropdown in AppBar
// ---------------------------------------------------------------------------
class _ModelSelector extends StatelessWidget {
  const _ModelSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'AI Model',
    icon: const Icon(Icons.tune_rounded, size: 20, color: _muted),
    onSelected: onChanged,
    itemBuilder: (_) => groqModels.entries.map((e) => PopupMenuItem(
      value: e.key,
      child: Row(
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 14,
            color: selected == e.key ? _teal : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(e.value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    )).toList(),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
