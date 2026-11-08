import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key, required this.selected, required this.onSelected});
  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(selected == AppLanguage.arabic ? 'الإعدادات' : 'Settings')),
    body: ListView(children: [
      ListTile(
        title: Text(selected == AppLanguage.arabic ? 'اللغة' : 'Language'),
        subtitle: Text(selected == AppLanguage.arabic ? 'العربية' : 'English'),
      ),
      RadioListTile(
        value: AppLanguage.english,
        groupValue: selected,
        title: const Text('English'),
        onChanged: (value) => onSelected(value!),
      ),
      RadioListTile(
        value: AppLanguage.arabic,
        groupValue: selected,
        title: const Text('العربية'),
        onChanged: (value) => onSelected(value!),
      ),
    ]),
  );
}
