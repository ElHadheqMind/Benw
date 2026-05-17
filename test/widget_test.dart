import 'package:flutter_test/flutter_test.dart';
import 'package:benw_edu/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const BenwEduApp());
    expect(find.text('Benw'), findsOneWidget);
  });
}
