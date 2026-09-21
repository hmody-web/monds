import 'package:flutter_test/flutter_test.dart';
import 'package:mundas/main.dart';

void main() {
  testWidgets('Mundas app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MundasApp());
    await tester.pumpAndSettle();

    expect(find.text('مندس'), findsOneWidget);
    expect(find.text('العب على جهاز واحد'), findsOneWidget);
    expect(find.text('العب مع أصدقائك'), findsOneWidget);
  });
}
