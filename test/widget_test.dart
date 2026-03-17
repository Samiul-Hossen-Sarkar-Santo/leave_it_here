import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Leave It Here')),
      ),
    );

    expect(find.text('Leave It Here'), findsOneWidget);
  });
}
