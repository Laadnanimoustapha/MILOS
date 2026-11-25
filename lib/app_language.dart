import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_page.dart';
import 'update_service.dart';

enum AppLanguage { english, arabic }

class AppLanguageStore {
  static const _key = 'milos.language.v1';

  static Future<AppLanguage?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == 'ar' ? AppLanguage.arabic : value == 'en' ? AppLanguage.english : null;
  }

  static Future<void> save(AppLanguage language) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      language == AppLanguage.arabic ? 'ar' : 'en',
    );
  }
}

class LanguageChoicePage extends StatelessWidget {
  const LanguageChoicePage({super.key, required this.onSelected});
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.translate_rounded, size: 56, color: Color(0xFF4CAF9E)),
          const SizedBox(height: 20),
          const Text('Choose your language', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('اختر لغتك', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => onSelected(AppLanguage.english), child: const Text('English')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => onSelected(AppLanguage.arabic), child: const Text('العربية')),
        ]),
      ),
    ),
  );
}

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key, required this.selected, required this.onSelected});
  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  bool _ar(String ar, String en) => widget.selected == AppLanguage.arabic;
  String _t(String en, String ar) => widget.selected == AppLanguage.arabic ? ar : en;

  UpdateInfo? _updateInfo;
  bool _checking = false;
  bool _checkedOnce = false;

  Future<void> _checkUpdate() async {
    setState(() { _checking = true; _checkedOnce = true; });
    final info = await UpdateService.checkNow();
    if (mounted) setState(() { _updateInfo = info; _checking = false; });
  }

  void _openUrl(String url) {
    // Open URL using platform intent (Android only via am start)
    // On other platforms show a selectable text dialog
    if (Platform.isAndroid) {
      try {
        Process.run('am', ['start', '--user', '0', '-a', 'android.intent.action.VIEW', '-d', url]);
        return;
      } catch (_) {}
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Download link', 'رابط التنزيل')),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF4CAF9E);
    const ink = Color(0xFF253533);
    const muted = Color(0xFF82908D);

    return Scaffold(
      appBar: AppBar(title: Text(_t('Settings', 'الإعدادات'))),
      body: RadioGroup<AppLanguage>(
        groupValue: widget.selected,
        onChanged: (value) {
          if (value != null) widget.onSelected(value);
        },
        child: ListView(children: [
          ListTile(
            title: Text(_t('Language', 'اللغة')),
            subtitle: Text(_t('English', 'العربية')),
          ),
          const RadioListTile(value: AppLanguage.english, title: Text('English')),
          const RadioListTile(value: AppLanguage.arabic, title: Text('العربية')),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.psychology_outlined, color: teal),
            title: Text(
              _t("Milos's Memory", 'ذاكرة ميلوس'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _t(
                'View and manage what Milos remembers about you',
                'عرض وتعديل ما يتذكره المساعد الذكي عنك',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MemoryPage(arabic: widget.selected == AppLanguage.arabic),
                ),
              );
            },
          ),
          const Divider(height: 32),
          // ─── App Update Section ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('App Update', 'تحديث التطبيق'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      '${_t("Current version", "الإصدار الحالي")}: v${UpdateService.currentVersion}',
                      style: const TextStyle(fontSize: 13, color: ink),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _checkUpdate,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.system_update_rounded, size: 18),
                    label: Text(_t('Check for Updates', 'البحث عن تحديث')),
                    style: FilledButton.styleFrom(
                      backgroundColor: teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_checkedOnce && !_checking) ...[
                  const SizedBox(height: 10),
                  if (_updateInfo == null)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: teal),
                        const SizedBox(width: 6),
                        Text(
                          _t('You\'re up to date ✓', 'أنت على أحدث إصدار ✓'),
                          style: const TextStyle(fontSize: 13, color: teal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE07A30).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_t("New version available", "إصدار جديد متاح")}: v${_updateInfo!.version}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC36E36),
                            ),
                          ),
                          if (_updateInfo!.releaseNotes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _updateInfo!.releaseNotes.length > 200
                                  ? '${_updateInfo!.releaseNotes.substring(0, 200)}…'
                                  : _updateInfo!.releaseNotes,
                              style: const TextStyle(fontSize: 12, color: ink),
                            ),
                          ],
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _openUrl(_updateInfo!.downloadUrl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE07A30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _t('Download APK', 'تنزيل APK'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

