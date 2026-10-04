import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/main.dart';
import 'package:thrower_app/ui/debug_target_screen.dart';

void main() {
  testWidgets('home screen opens the scoring test target', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThrowerApp()));
    expect(find.text('Thrower App'), findsOneWidget);

    await tester.tap(find.text('Scoring test target'));
    await tester.pumpAndSettle();
    expect(find.byType(DebugTargetScreen), findsOneWidget);
  });
}
