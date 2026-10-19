// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:milos/main.dart';

void main() {
  testWidgets('shows the empty task list for a new install', (WidgetTester tester) async {
    await tester.pumpWidget(const MilosApp());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Your list is empty.'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });
}
