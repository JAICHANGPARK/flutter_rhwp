import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rhwp_example/main.dart';

void main() {
  testWidgets('shows example shell', (tester) async {
    await tester.pumpWidget(const RhwpExampleApp(autoOpenSample: false));

    expect(find.text('flutter_rhwp'), findsOneWidget);
    if (kIsWeb) {
      expect(find.text('Web editor'), findsOneWidget);
    }
  });
}
