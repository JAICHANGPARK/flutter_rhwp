import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

const _pageSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180" viewBox="0 0 240 180">
  <rect width="240" height="180" fill="#ffffff"/>
  <rect x="24" y="24" width="192" height="132" fill="#dc2626"/>
  <circle cx="120" cy="90" r="36" fill="#2563eb"/>
</svg>
''';

void main() {
  testWidgets('RhwpViewer paints SVG content through its builder', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    final renderedSvg = <String>[];

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 360,
          height: 320,
          child: RhwpViewer(
            document: document,
            padding: const EdgeInsets.all(12),
            pageGap: 0,
            svgBuilder: (context, svg) {
              renderedSvg.add(svg);
              return _TestSvgCanvas(svg: svg);
            },
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(session.renderedPages, [0]);
    expect(renderedSvg.single, contains('#dc2626'));
    expect(
      find.byKey(const ValueKey('test-svg-canvas')),
      paints
        ..rect(color: Colors.white)
        ..rect(color: const Color(0xffdc2626))
        ..circle(color: const Color(0xff2563eb)),
    );
  });

  testWidgets(
    'RhwpViewer zoom updates layout without rerendering cached page',
    (tester) async {
      final controller = RhwpViewerController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 400,
            height: 280,
            child: RhwpViewer(
              document: document,
              controller: controller,
              padding: const EdgeInsets.all(8),
              svgBuilder: _testSvgBuilder,
            ),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      final initialWidth = tester.getSize(find.byType(ListView)).width;

      controller.zoomIn();
      await _pumpDocumentFrame(tester);

      final zoomedWidth = tester.getSize(find.byType(ListView)).width;
      expect(zoomedWidth, greaterThan(initialWidth));
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets('RhwpViewer lazily renders pages as they enter the viewport', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 25);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 420,
          height: 320,
          child: RhwpViewer(
            document: document,
            padding: const EdgeInsets.all(8),
            pageGap: 8,
            svgBuilder: _tallSvgBuilder,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(session.renderedPages, [0, 1]);

    final verticalScrollable = find.byType(Scrollable).last;
    for (var i = 0; i < 3; i += 1) {
      await tester.drag(verticalScrollable, const Offset(0, -900));
      await _pumpDocumentFrame(tester);
    }

    expect(session.renderedPages.any((page) => page > 1), isTrue);
    expect(session.renderedPages.length, lessThan(session.pageCountValue));
    expect(
      session.renderedPages.toSet(),
      hasLength(session.renderedPages.length),
    );
  });

  testWidgets('RhwpEditor overlay applies insert and delete commands', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 0);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.enterText(find.byType(TextField).at(3), 'abc');
    await tester.tap(find.byTooltip('Insert'));
    await _pumpDocumentFrame(tester);

    expect(controller.cursor.offset, 3);
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 0,
      'text': 'abc',
    });

    await tester.tap(find.byTooltip('Delete backward'));
    await _pumpDocumentFrame(tester);

    expect(controller.cursor.offset, 2);
    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'count': 1,
    });
  });

  testWidgets('RhwpEditor paints caret and selection target overlay', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpEditor(document: document, controller: controller),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(find.byKey(const ValueKey('rhwp-editor-caret')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhwp-editor-selection')), findsNothing);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 5),
    );
    await tester.pump();

    expect(controller.cursor.offset, 5);
    expect(find.byKey(const ValueKey('rhwp-editor-caret')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhwp-editor-selection')), findsOneWidget);
  });
}

class _WidgetHarness extends StatelessWidget {
  const _WidgetHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }
}

Widget _testSvgBuilder(BuildContext context, String svg) {
  return _TestSvgCanvas(svg: svg);
}

Widget _tallSvgBuilder(BuildContext context, String svg) {
  return SizedBox(width: 240, height: 800, child: _TestSvgCanvas(svg: svg));
}

class _TestSvgCanvas extends StatelessWidget {
  const _TestSvgCanvas({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 180,
      child: CustomPaint(
        key: const ValueKey('test-svg-canvas'),
        painter: _TestSvgPainter(svg),
      ),
    );
  }
}

class _TestSvgPainter extends CustomPainter {
  const _TestSvgPainter(this.svg);

  final String svg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (svg.contains('#dc2626')) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * 0.1,
          size.height * 0.1,
          size.width * 0.8,
          size.height * 0.73,
        ),
        Paint()..color = const Color(0xffdc2626),
      );
    }
    if (svg.contains('#2563eb')) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.shortestSide * 0.2,
        Paint()..color = const Color(0xff2563eb),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TestSvgPainter oldDelegate) {
    return oldDelegate.svg != svg;
  }
}

class _FakeRhwpSession implements rust.RhwpSession {
  _FakeRhwpSession({required this.pageCountValue});

  final int pageCountValue;
  final commands = <String>[];
  final renderedPages = <int>[];
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    commands.add(commandJson);
    return '{"ok":true}';
  }

  @override
  Future<int> pageCount() async => pageCountValue;

  @override
  Future<String> renderPageSvg({required int page}) async {
    renderedPages.add(page);
    return _pageSvg;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpDocumentFrame(WidgetTester tester) async {
  for (var i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
