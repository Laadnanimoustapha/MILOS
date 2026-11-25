// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:milos/habit_store.dart';
import 'package:milos/main.dart';
import 'package:milos/task.dart';
import 'package:milos/task_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('selects Arabic on first launch and can change it in settings', (WidgetTester tester) async {
    await tester.pumpWidget(const MilosApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('قائمتك فارغة.'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('اليوم'))),
      TextDirection.rtl,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  test('Task failed state round-trips and resets on recurrence', () {
    final now = DateTime(2026, 11, 25, 10, 0);
    final task = Task(
      id: 1,
      title: 'Read 10 pages',
      remindAt: now,
      remindUntil: now.add(const Duration(hours: 1)),
      failed: true,
      repeat: TaskRepeat.daily,
    );
    final restored = Task.fromJson(task.toJson());
    expect(restored.failed, isTrue);
    expect(restored.done, isFalse);
    expect(TaskStore.countFailed([restored]), 1);
    expect(restored.nextRecurrence(2).failed, isFalse);

    // Legacy JSON without 'failed' defaults to false
    final legacy = Task.fromJson({
      'id': 3,
      'title': 'Legacy',
      'remindAt': now.toIso8601String(),
      'remindUntil': now.toIso8601String(),
    });
    expect(legacy.failed, isFalse);
  });

  test('HabitStore prayer counts increment, decrement, sum totals, and migrate legacy bools', () async {
    SharedPreferences.setMockInitialValues({
      'milos.habits.prayers.2026-11-24': '{"Fajr":true,"Dhuhr":false}',
    });
    final yesterday = await HabitStore.loadPrayerCounts('2026-11-24');
    expect(yesterday['Fajr'], 1);
    expect(yesterday['Dhuhr'], 0);

    await HabitStore.incrementPrayer('Fajr', '2026-11-25');
    await HabitStore.incrementPrayer('Fajr', '2026-11-25');
    await HabitStore.incrementPrayer('Asr', '2026-11-25');
    await HabitStore.decrementPrayer('Asr', '2026-11-25');
    await HabitStore.decrementPrayer('Asr', '2026-11-25'); // floors at 0

    final today = await HabitStore.loadPrayerCounts('2026-11-25');
    expect(today['Fajr'], 2);
    expect(today['Asr'], 0);

    final totals = await HabitStore.loadPrayerTotals();
    expect(totals['Fajr'], 3);
    expect(totals['Asr'], 0);
  });
}
