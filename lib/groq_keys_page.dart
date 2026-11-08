import 'package:flutter/material.dart';

import 'groq_service.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _paper = Color(0xFFF5F8F7);

class GroqKeysPage extends StatefulWidget {
  const GroqKeysPage({super.key});

  @override
  State<GroqKeysPage> createState() => _GroqKeysPageState();
}

class _GroqKeysPageState extends State<GroqKeysPage> {
  final _controllers = <TextEditingController>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final keys = await GroqKeyStore.load();
    if (!mounted) return;
    for (final key in keys) {
      _controllers.add(TextEditingController(text: key));
    }
    while (_controllers.length < 3) {
      _controllers.add(TextEditingController());
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await GroqKeyStore.save(_controllers.map((controller) => controller.text).toList());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the API keys: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      title: const Text('Groq API keys'),
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 0,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _teal))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Add at least one key. If a key is rate-limited or fails, Milos automatically tries the next one.',
                style: TextStyle(color: Color(0xFF61716D), height: 1.4),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[i],
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Groq API key ${i + 1}',
                      border: const OutlineInputBorder(),
                      suffixIcon: _controllers.length > 3
                          ? IconButton(
                              tooltip: 'Remove key',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                final controller = _controllers.removeAt(i);
                                controller.dispose();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _controllers.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Add another key'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _teal),
                child: Text(_saving ? 'Saving...' : 'Save keys'),
              ),
            ],
          ),
  );
}
