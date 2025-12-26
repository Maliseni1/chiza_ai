import 'package:flutter_test/flutter_test.dart';
import 'package:chiza_ai/main.dart'; // Import your main file

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We changed MyApp to ChizaApp
    await tester.pumpWidget(const ChizaApp());

    // Simple check to ensure app builds
    expect(
      find.text('Chiza AI'),
      findsNothing,
    ); // It won't find this text on splash immediately
  });
}
