import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'opens bundled HWP asset and exports supported formats',
    () async {
      final data = await rootBundle.load(
        'assets/korea_ai_action_plan_2026_2028.hwp',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final document = await Rhwp.open(
        bytes,
        fileName: 'korea_ai_action_plan_2026_2028.hwp',
      );
      addTearDown(document.close);

      final metadata = await document.metadata();
      expect(metadata.pageCount, greaterThan(0));
      expect(metadata.fileName, 'korea_ai_action_plan_2026_2028.hwp');

      final firstPageSvg = await document.renderPageSvg(0);
      expect(firstPageSvg, contains('<svg'));

      final text = await document.extractText(page: 0);
      expect(text.trim(), isNotEmpty);

      final markdown = await document.extractMarkdown(page: 0);
      expect(markdown.trim(), isNotEmpty);

      expect(await document.exportHwp(), isNotEmpty);
      expect(await document.exportHwpx(), isNotEmpty);

      if (kIsWeb) {
        expect(
          document.exportPdf(),
          throwsA(isA<RhwpUnsupportedPlatformException>()),
        );
      } else {
        final pdf = await document.exportDocument(
          RhwpExportFormat.pdf,
          sourceFileName: metadata.fileName,
        );
        expect(pdf.fileName, 'korea_ai_action_plan_2026_2028.pdf');
        expect(pdf.mimeType, 'application/pdf');
        expect(pdf.bytes.take(5), orderedEquals(ascii.encode('%PDF-')));
        expect(_containsAscii(pdf.bytes, '%%EOF'), isTrue);
      }

      final docx = await document.exportDocx();
      expect(docx.take(2), orderedEquals([0x50, 0x4b]));

      expect(
        utf8.decode(await document.exportText(page: 0)).trim(),
        isNotEmpty,
      );
      expect(
        utf8.decode(await document.exportMarkdown(page: 0)).trim(),
        isNotEmpty,
      );
      expect(
        utf8.decode(await document.exportPageSvg(page: 0)),
        contains('<svg'),
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

bool _containsAscii(List<int> bytes, String needle) {
  final needleBytes = ascii.encode(needle);
  for (var offset = 0; offset <= bytes.length - needleBytes.length; offset++) {
    var matches = true;
    for (var index = 0; index < needleBytes.length; index++) {
      if (bytes[offset + index] != needleBytes[index]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}
