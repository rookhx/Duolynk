import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/app.dart';

void main() {
  testWidgets('Duolynk app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DuolynkApp()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(DuolynkApp), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
