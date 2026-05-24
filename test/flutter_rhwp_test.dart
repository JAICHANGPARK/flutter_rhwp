import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insert text command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertText(
      section: 0,
      paragraph: 1,
      offset: 2,
      text: 'hello',
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'text': 'hello',
    });
  });

  test('closed exception has a stable message', () {
    expect(
      const RhwpClosedException().toString(),
      'RhwpException: The rhwp document is already closed.',
    );
  });

  test('Web editor controller reports unsupported off Web', () {
    final controller = RhwpWebEditorController();
    addTearDown(controller.dispose);

    expect(controller.isAttached, isFalse);
    expect(
      controller.exportHwp(),
      throwsA(isA<RhwpUnsupportedPlatformException>()),
    );
  });

  test('document convenience edit methods use command envelopes', () async {
    final session = _FakeRhwpSession();
    final document = RhwpDocument.fromSession(session);

    await document.insertText(
      section: 0,
      paragraph: 1,
      offset: 2,
      text: 'hello',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'text': 'hello',
    });

    await document.deleteText(section: 0, paragraph: 1, offset: 2, count: 3);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'count': 3,
    });
  });

  test('document export helpers forward supported formats', () async {
    final session = _FakeRhwpSession();
    final document = RhwpDocument.fromSession(session);

    expect(await document.exportHwp(), [0x48, 0x57, 0x50]);
    expect(await document.exportHwpx(), [0x48, 0x57, 0x50, 0x58]);
    expect(await document.exportPdf(), [0x50, 0x44, 0x46]);
    expect(await document.exportDocx(), [0x44, 0x4f, 0x43, 0x58]);
    expect(utf8.decode(await document.exportText(page: 2)), 'text page 2');
    expect(utf8.decode(await document.exportMarkdown(page: 3)), '# page 3');
    expect(
      utf8.decode(await document.exportPageSvg(page: 4)),
      '<svg data-page="4"/>',
    );

    expect(session.exportHwpCalls, 1);
    expect(session.exportHwpxCalls, 1);
    expect(session.exportPdfCalls, 1);
    expect(session.exportDocxCalls, 1);
    expect(session.extractedTextPages, [2]);
    expect(session.extractedMarkdownPages, [3]);
    expect(session.renderedSvgPages, [4]);
  });
}

class _FakeRhwpSession implements rust.RhwpSession {
  String? lastCommandJson;
  int exportHwpCalls = 0;
  int exportHwpxCalls = 0;
  int exportPdfCalls = 0;
  int exportDocxCalls = 0;
  final extractedTextPages = <int?>[];
  final extractedMarkdownPages = <int?>[];
  final renderedSvgPages = <int>[];
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    lastCommandJson = commandJson;
    return '{"ok":true}';
  }

  @override
  Future<Uint8List> exportDocx() async {
    exportDocxCalls += 1;
    return Uint8List.fromList([0x44, 0x4f, 0x43, 0x58]);
  }

  @override
  Future<Uint8List> exportHwp() async {
    exportHwpCalls += 1;
    return Uint8List.fromList([0x48, 0x57, 0x50]);
  }

  @override
  Future<Uint8List> exportHwpx() async {
    exportHwpxCalls += 1;
    return Uint8List.fromList([0x48, 0x57, 0x50, 0x58]);
  }

  @override
  Future<Uint8List> exportPdf() async {
    exportPdfCalls += 1;
    return Uint8List.fromList([0x50, 0x44, 0x46]);
  }

  @override
  Future<String> extractText({int? page}) async {
    extractedTextPages.add(page);
    return 'text page ${page ?? 'all'}';
  }

  @override
  Future<String> extractMarkdown({int? page}) async {
    extractedMarkdownPages.add(page);
    return '# page ${page ?? 'all'}';
  }

  @override
  Future<String> renderPageSvg({required int page}) async {
    renderedSvgPages.add(page);
    return '<svg data-page="$page"/>';
  }

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
