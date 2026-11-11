import 'package:flutter/material.dart';

import 'memory_store.dart';

// ---------------------------------------------------------------------------
// Colour tokens (match the rest of the app)
// ---------------------------------------------------------------------------
const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

// ---------------------------------------------------------------------------
// MemoryPage — lets the user view and delete what Milos remembers about them.
// ---------------------------------------------------------------------------
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.arabic});
  final bool arabic;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final _store = MemoryStore();
  List<String> _memories = [];
  bool _loading = true;

  String _t(String en, String ar) => widget.arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _store.load();
    if (!mounted) return;
    setState(() {
      _memories = m;
      _loading = false;
    });
  }

  Future<void> _delete(int index) async {
    await _store.delete(index);
    await _load();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Clear all memory?', 'مسح كل الذاكرة؟')),
        content: Text(_t(
          'Milos will forget everything he learned about you. This cannot be undone.',
          'سيتذكر ميلوس من جديد. لا يمكن التراجع عن هذا.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('Clear all', 'مسح الكل'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Text(
          _t("Milos's Memory", 'ذاكرة ميلوس'),
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          if (_memories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: _t('Clear all', 'مسح الكل'),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _memories.isEmpty
              ? _EmptyMemory(arabic: widget.arabic)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        _t(
                          'These are the things Milos has learned about you from your conversations. Swipe left or tap the trash icon to forget something.',
                          'هذه هي الأشياء التي تعلمها ميلوس عنك من محادثاتك. اسحب لليسار أو اضغط على أيقونة الحذف لمسح أي معلومة.',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _memories.length; i++)
                      _MemoryCard(
                        memory: _memories[i],
                        index: i + 1,
                        onDelete: () => _delete(i),
                        arabic: widget.arabic,
                      ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual memory card with swipe-to-delete
// ---------------------------------------------------------------------------
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.index,
    required this.onDelete,
    required this.arabic,
  });

  final String memory;
  final int index;
  final VoidCallback onDelete;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('$index:$memory'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        ),
        onDismissed: (_) => onDelete(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9EFED)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_outlined, size: 16, color: _teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  memory,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _ink,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _muted),
                onPressed: onDelete,
                tooltip: arabic ? 'حذف' : 'Forget this',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-state widget
// ---------------------------------------------------------------------------
class _EmptyMemory extends StatelessWidget {
  const _EmptyMemory({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined, size: 56, color: _teal),
            const SizedBox(height: 16),
            Text(
              arabic ? 'ميلوس لم يتعلم شيئاً بعد' : 'Milos hasn\'t learned anything yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              arabic
                  ? 'تحدث مع ميلوس وسيتذكر تفضيلاتك وعاداتك تلقائياً.'
                  : 'Chat with Milos and he will start remembering your preferences and habits automatically.',
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

