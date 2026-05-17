import 'package:flutter_test/flutter_test.dart';
import 'package:parkease_manager/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const Go2ParkingApp());
    expect(find.text('Go2-Parking'), findsAny);
  });
}
