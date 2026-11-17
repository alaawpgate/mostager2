import 'package:flutter_test/flutter_test.dart';
import 'package:mostager_app/main.dart';

void main() {
  testWidgets('Mostager App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MostagerApp());
    expect(find.text('مُستأجِر'), findsOneWidget);
  });
}
