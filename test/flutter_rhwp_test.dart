import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

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
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
