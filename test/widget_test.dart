import 'package:flutter_test/flutter_test.dart';

import 'package:leave_it_here/main.dart';

void main() {
  testWidgets('App renders journal flow sections', (WidgetTester tester) async {
    await tester.pumpWidget(const LeaveItHereApp());
    await tester.pumpAndSettle();

    expect(find.text('Leave It Here · Journal'), findsOneWidget);
    expect(find.text('Today\'s journal'), findsOneWidget);
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
  });
}
