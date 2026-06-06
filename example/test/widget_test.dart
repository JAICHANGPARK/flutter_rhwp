import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
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

    expect(
      find.textContaining('korea_ai_action_plan_2026_2028.hwp'),
      findsOneWidget,
    );

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

  testWidgets('native Save As syncs saved file name metadata', (tester) async {
    final session = _FakeExampleRhwpSession();
    final document = RhwpDocument.fromSession(session);
    final controller = RhwpExampleAppController();

    final saved = <RhwpExportedDocument>[];

    await tester.pumpWidget(
      RhwpExampleApp(
        controller: controller,
        autoOpenSample: false,
        startInNativeEditor: true,
        initialDocument: document,
        initialFileName: 'korea_ai_action_plan_2026_2028.hwp',
        initialSourceBytes: Uint8List.fromList([1, 2, 3, 4]),
        saveFile:
            ({
              required exported,
              required dialogTitle,
              required allowedExtensions,
            }) async {
              saved.add(exported);
              expect(dialogTitle, 'Save As HWPX');
              expect(allowedExtensions, ['hwpx']);
              return '/tmp/renamed.hwpx';
            },
      ),
    );
    for (var i = 0; i < 8; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.textContaining('korea_ai_action_plan_2026_2028.hwp'),
      findsOneWidget,
    );
    expect(controller.isAttached, isTrue);
    expect(controller.usesFullEditor, isFalse);
    expect(controller.hasDocument, isTrue);

    await controller.saveAsHwpx();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.error, isNull);
    expect(controller.status, 'Saved /tmp/renamed.hwpx');
    expect(session.exportHwpxCalls, 1);
    expect(saved, hasLength(1));
    expect(saved.single.intent, RhwpExportIntent.saveAs);
    expect(saved.single.fileName, 'korea_ai_action_plan_2026_2028.hwpx');
    expect(session.fileName, 'renamed.hwpx');
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      containsAllInOrder(['convertToEditable', 'setFileName']),
    );
    expect(find.textContaining('renamed.hwpx'), findsWidgets);
    expect(find.textContaining('Saved /tmp/renamed.hwpx'), findsWidgets);
  });
}

class _FakeExampleRhwpSession implements rust.RhwpSession {
  String fileName = 'sample.hwp';
  final commands = <String>[];
  var exportHwpxCalls = 0;
  var _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  Future<String> applyCommand({required String commandJson}) async {
    commands.add(commandJson);
    final command = jsonDecode(commandJson);
    if (command is Map<String, Object?> && command['type'] == 'setFileName') {
      fileName = command['name']?.toString() ?? fileName;
    }
    return commandJson;
  }

  @override
  Future<void> close() async {}

  @override
  Future<rust.RhwpDocumentInfo> documentInfo() async {
    return rust.RhwpDocumentInfo(
      pageCount: 1,
      sourceFormat: fileName.toLowerCase().endsWith('.hwpx') ? 'hwpx' : 'hwp',
      fileName: fileName,
      rawJson: '{"pageCount":1}',
    );
  }

  @override
  Future<Uint8List> exportDocx() async {
    return Uint8List.fromList([0x44, 0x4f, 0x43, 0x58]);
  }

  @override
  Future<Uint8List> exportHwp() async {
    return Uint8List.fromList([0x48, 0x57, 0x50]);
  }

  @override
  Future<Uint8List> exportHwpx() async {
    exportHwpxCalls += 1;
    return Uint8List.fromList([0x48, 0x57, 0x50, 0x58]);
  }

  @override
  Future<Uint8List> exportPdf() async {
    return Uint8List.fromList([0x50, 0x44, 0x46]);
  }

  @override
  Future<String> extractMarkdown({int? page}) async => '# sample';

  @override
  Future<String> extractText({int? page}) async => 'sample';

  @override
  Future<int> pageCount() async => 1;

  @override
  Future<String> pageLayerTree({required int page}) async {
    return jsonEncode({
      'pageWidth': 200,
      'pageHeight': 200,
      'root': {
        'kind': 'group',
        'bounds': {'x': 0, 'y': 0, 'width': 200, 'height': 200},
        'children': <Object?>[],
      },
    });
  }

  @override
  Future<String> renderPageSvg({required int page}) async {
    return '<svg width="200" height="200" viewBox="0 0 200 200"></svg>';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
