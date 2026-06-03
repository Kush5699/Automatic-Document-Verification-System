import 'package:flutter_test/flutter_test.dart';
import 'package:id_scanner/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const IDScannerApp());
    expect(find.text('ID Scanner'), findsOneWidget);
  });
}
