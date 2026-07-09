import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app builds and displays the main widget
    expect(find.byType(MyApp), findsOneWidget);
  });
}
