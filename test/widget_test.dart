import 'package:flutter_test/flutter_test.dart';
import 'package:checkpay/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CheckPayApp());
    expect(find.byType(CheckPayApp), findsOneWidget);
  });
}
