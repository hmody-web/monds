import 'package:flutter_test/flutter_test.dart';
import 'package:sooky/main.dart';

void main() {
  testWidgets('Sooky app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MundasApp());
    await tester.pumpAndSettle();

    expect(find.text('سوكي'), findsWidgets);
  });
}
