import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/main.dart';

void main() {
  testWidgets('app starts and shows the title', (tester) async {
    await tester.pumpWidget(const MidnightManorApp());
    expect(find.text('Midnight Manor'), findsOneWidget);
  });
}
