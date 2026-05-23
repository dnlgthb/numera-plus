import 'package:flutter_test/flutter_test.dart';
import 'package:sumo_app/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NumeraApp());
    expect(find.text('Practicar'), findsOneWidget);
  });
}
