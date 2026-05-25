import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
import 'package:flutter_rhwp/src/rust/frb_generated.dart';
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

  test('split paragraph command serializes to the Rust command envelope', () {
    final command = RhwpCommand.splitParagraph(
      section: 0,
      paragraph: 1,
      offset: 2,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'splitParagraph',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });
  });

  test('delete range command serializes to the Rust command envelope', () {
    final command = RhwpCommand.deleteRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
    });
  });

  test('apply char format command serializes to the Rust command envelope', () {
    final command = RhwpCommand.applyCharFormat(
      section: 0,
      paragraph: 1,
      startOffset: 2,
      endOffset: 4,
      bold: true,
      italic: true,
      underline: true,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'applyCharFormat',
      'section': 0,
      'paragraph': 1,
      'startOffset': 2,
      'endOffset': 4,
      'properties': {'bold': true, 'italic': true, 'underline': true},
    });
  });

  test(
    'apply char format range command serializes to the Rust command envelope',
    () {
      final command = RhwpCommand.applyCharFormatRange(
        section: 0,
        startParagraph: 1,
        startOffset: 2,
        endParagraph: 3,
        endOffset: 4,
        bold: true,
      );

      expect(jsonDecode(jsonEncode(command.toJson())), {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 1,
        'startOffset': 2,
        'endParagraph': 3,
        'endOffset': 4,
        'properties': {'bold': true},
      });
    },
  );

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
    expect(
      controller.exportDocument(RhwpExportFormat.hwp),
      throwsA(isA<RhwpUnsupportedPlatformException>()),
    );
  });

  test('generated FRB bridge can call a mock Rust API', () async {
    final api = _FakeRustLibApi();
    RustLib.initMock(api: api);
    addTearDown(RustLib.dispose);

    expect(await rust.rhwpVersion(), 'mock-rhwp');
    expect(api.versionCalls, 1);
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

    await document.deleteRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
    });

    await document.applyCharFormat(
      section: 0,
      paragraph: 1,
      startOffset: 2,
      endOffset: 4,
      bold: true,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyCharFormat',
      'section': 0,
      'paragraph': 1,
      'startOffset': 2,
      'endOffset': 4,
      'properties': {'bold': true},
    });

    await document.applyCharFormatRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
      italic: true,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
      'properties': {'italic': true},
    });

    await document.splitParagraph(section: 0, paragraph: 1, offset: 2);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'splitParagraph',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
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

  test('export formats expose save metadata', () {
    expect(RhwpExportFormat.hwp.fileExtension, 'hwp');
    expect(RhwpExportFormat.hwpx.mimeType, 'application/vnd.hancom.hwpx');
    expect(RhwpExportFormat.pdf.mimeType, 'application/pdf');
    expect(
      RhwpExportFormat.docx.mimeType,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(RhwpExportFormat.text.fileExtension, 'txt');
    expect(RhwpExportFormat.markdown.fileExtension, 'md');
    expect(RhwpExportFormat.svg.mimeType, 'image/svg+xml');
  });

  test('document exportDocument returns bytes with save metadata', () async {
    final session = _FakeRhwpSession();
    session.fileName = '/tmp/source/sample.hwp';
    final document = RhwpDocument.fromSession(session);

    final pdf = await document.exportDocument(RhwpExportFormat.pdf);

    expect(pdf.format, RhwpExportFormat.pdf);
    expect(pdf.bytes, [0x50, 0x44, 0x46]);
    expect(pdf.fileName, 'sample.pdf');
    expect(pdf.mimeType, 'application/pdf');

    final svg = await document.exportDocument(
      RhwpExportFormat.svg,
      sourceFileName: 'picked.hwpx',
      page: 2,
    );

    expect(utf8.decode(svg.bytes), '<svg data-page="2"/>');
    expect(svg.fileName, 'picked-page-3.svg');
    expect(svg.mimeType, 'image/svg+xml');
    expect(session.renderedSvgPages, [2]);
  });

  test('exported document default file names are robust', () {
    expect(
      RhwpExportedDocument.defaultFileName(
        format: RhwpExportFormat.markdown,
        sourceFileName: r'C:\docs\report.hwp',
      ),
      'report.md',
    );
    expect(
      RhwpExportedDocument.defaultFileName(format: RhwpExportFormat.text),
      'document.txt',
    );
    expect(
      RhwpExportedDocument.defaultFileName(
        format: RhwpExportFormat.svg,
        sourceFileName: '.hwp',
        page: 0,
      ),
      'document-page-1.svg',
    );
  });

  test('page layer tree model flattens tolerant layer JSON', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode({
        'type': 'page',
        'children': [
          {
            'kind': 'paragraph',
            'runs': [
              {
                'type': 'span',
                'text': 'Hello',
                'bounds': {'x': 12, 'y': 34, 'width': 56, 'height': 78},
              },
            ],
          },
          {
            'type': 'shape',
            'rect': {'left': 1, 'top': 2, 'right': 11, 'bottom': 22},
          },
        ],
      }),
    );

    expect(tree.page, 0);
    expect(tree.root.type, 'page');
    expect(tree.nodes.map((node) => node.type), [
      'page',
      'paragraph',
      'span',
      'shape',
    ]);
    expect(tree.textNodes.single.text, 'Hello');
    expect(tree.textNodes.single.bounds, const Rect.fromLTWH(12, 34, 56, 78));
    expect(
      tree.findByType('shape').single.bounds,
      const Rect.fromLTRB(1, 2, 11, 22),
    );
    expect(tree.boundedNodes.length, 2);
  });

  test('document page layer tree helper decodes session JSON', () async {
    final session = _FakeRhwpSession();
    session.pageLayerTreeJson = jsonEncode({
      'type': 'page',
      'nodes': [
        {
          'type': 'text',
          'content': 'from session',
          'bbox': [1, 2, 3, 4],
        },
      ],
    });
    final document = RhwpDocument.fromSession(session);

    final tree = await document.pageLayerTreeModel(5);

    expect(session.pageLayerTreePages, [5]);
    expect(tree.textNodes.single.text, 'from session');
    expect(tree.textNodes.single.bounds, const Rect.fromLTWH(1, 2, 3, 4));
  });

  test('page layer tree model maps text run source offsets to page rects', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_textRunLayerTreeJson(charStart: 3)),
    );

    final run = tree.textRuns.single;
    expect(tree.pageSize, const Size(240, 180));
    expect(run.section, 0);
    expect(run.paragraph, 0);
    expect(run.charStart, 3);
    expect(run.charEnd, 7);
    expect(run.bounds, const Rect.fromLTWH(20, 30, 60, 12));

    final caret = tree.caretRectFor(section: 0, paragraph: 0, offset: 5);
    expect(caret!.left, closeTo(40, 0.001));
    expect(caret.top, 30);

    final selection = tree.selectionRectsFor(
      section: 0,
      paragraph: 0,
      startOffset: 4,
      endOffset: 7,
    );
    expect(selection.single, const Rect.fromLTRB(30, 30, 60, 42));

    final hit = tree.textPositionForPoint(const Offset(52, 36));
    expect(hit, isNotNull);
    expect(hit!.section, 0);
    expect(hit.paragraph, 0);
    expect(hit.offset, 6);
    expect(
      tree.textPositionForPoint(const Offset(52, 80), verticalTolerance: 2),
      isNull,
    );
  });

  test('page layer tree model maps multi-paragraph selection ranges', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_multiParagraphLayerTreeJson()),
    );

    final selection = tree.selectionRectsForRange(
      startSection: 0,
      startParagraph: 0,
      startOffset: 2,
      endSection: 0,
      endParagraph: 1,
      endOffset: 2,
    );

    expect(selection, [
      const Rect.fromLTRB(40, 30, 60, 42),
      const Rect.fromLTRB(20, 60, 40, 72),
    ]);

    final text = tree.textForRange(
      startSection: 0,
      startParagraph: 0,
      startOffset: 2,
      endSection: 0,
      endParagraph: 1,
      endOffset: 2,
    );
    expect(text, 'cd\nab');
  });
}

Map<String, Object?> _textRunLayerTreeJson({required int charStart}) {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        {
          'kind': 'leaf',
          'bounds': {'x': 20, 'y': 30, 'width': 60, 'height': 12},
          'ops': [
            {
              'type': 'textRun',
              'bbox': {'x': 20, 'y': 30, 'width': 60, 'height': 12},
              'text': 'abcd',
              'source': {
                'id': 0,
                'utf16Range': {'start': 0, 'end': 4},
                'stableSourceKey': 'section:0/para:0/char:$charStart',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 20, 'f': 40},
                'baselineY': 0,
              },
              'clusters': [
                _textCluster(0, 1, 0),
                _textCluster(1, 2, 10),
                _textCluster(2, 3, 20),
                _textCluster(3, 4, 30),
              ],
            },
          ],
        },
      ],
    },
    'textSources': [
      {
        'id': 0,
        'text': 'abcd',
        'utf16Range': {'start': 0, 'end': 4},
        'stableSourceKey': 'section:0/para:0/char:$charStart',
        'annotations': [],
      },
    ],
  };
}

Map<String, Object?> _multiParagraphLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _textRunLayerNode(paragraph: 0, y: 30),
        _textRunLayerNode(paragraph: 1, y: 60),
      ],
    },
  };
}

Map<String, Object?> _textRunLayerNode({
  required int paragraph,
  required double y,
}) {
  return {
    'kind': 'leaf',
    'bounds': {'x': 20, 'y': y, 'width': 60, 'height': 12},
    'ops': [
      {
        'type': 'textRun',
        'bbox': {'x': 20, 'y': y, 'width': 60, 'height': 12},
        'text': 'abcd',
        'source': {
          'id': paragraph,
          'utf16Range': {'start': 0, 'end': 4},
          'stableSourceKey': 'section:0/para:$paragraph/char:0',
        },
        'placement': {
          'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 20, 'f': y + 10},
          'baselineY': 0,
        },
        'clusters': [
          _textCluster(0, 1, 0),
          _textCluster(1, 2, 10),
          _textCluster(2, 3, 20),
          _textCluster(3, 4, 30),
        ],
      },
    ],
  };
}

Map<String, Object?> _textCluster(int start, int end, double x) {
  return {
    'textRangeUtf16': {'start': start, 'end': end},
    'origin': {'x': x, 'y': 0},
    'advance': {'dx': 10, 'dy': 0},
  };
}

class _FakeRustLibApi implements RustLibApi {
  int versionCalls = 0;

  @override
  Future<void> crateApiRhwpInitApp() async {}

  @override
  Future<String> crateApiRhwpRhwpVersion() async {
    versionCalls += 1;
    return 'mock-rhwp';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRhwpSession implements rust.RhwpSession {
  String? lastCommandJson;
  String? fileName = 'sample.hwp';
  int exportHwpCalls = 0;
  int exportHwpxCalls = 0;
  int exportPdfCalls = 0;
  int exportDocxCalls = 0;
  final extractedTextPages = <int?>[];
  final extractedMarkdownPages = <int?>[];
  final renderedSvgPages = <int>[];
  final pageLayerTreePages = <int>[];
  String pageLayerTreeJson = '{"type":"page"}';
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    lastCommandJson = commandJson;
    return '{"ok":true}';
  }

  @override
  Future<rust.RhwpDocumentInfo> documentInfo() async {
    return rust.RhwpDocumentInfo(
      pageCount: 5,
      sourceFormat: 'hwp',
      fileName: fileName,
      rawJson: '{"pageCount":5}',
    );
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
  Future<String> pageLayerTree({required int page}) async {
    pageLayerTreePages.add(page);
    return pageLayerTreeJson;
  }

  @override
  Future<int> pageCount() async => 5;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
