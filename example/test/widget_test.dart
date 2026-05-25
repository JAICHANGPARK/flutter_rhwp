import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rhwp_example/main.dart';

void main() {
  testWidgets('shows example shell', (tester) async {
    await tester.pumpWidget(const RhwpExampleApp(autoOpenSample: false));

    expect(find.text('flutter_rhwp'), findsOneWidget);
    expect(find.text('Native editor'), findsOneWidget);
    expect(find.text('Full editor'), findsOneWidget);
  });

  testWidgets('opens bundled sample in full editor mode on Web', (
    tester,
  ) async {
    if (!kIsWeb) {
      return;
    }

    await tester.pumpWidget(
      RhwpExampleApp(
        webEditorModuleUrl: '',
        sampleBytesLoader: () async => Uint8List.fromList([1, 2, 3, 4]),
      ),
    );
    for (var i = 0; i < 8; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('flutter_rhwp'), findsOneWidget);
    expect(find.text('Full editor'), findsOneWidget);
    expect(
      find.textContaining('korea_ai_action_plan_2026_2028.hwp'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Opened bundled sample in full editor'),
      findsWidgets,
    );
  });
}
