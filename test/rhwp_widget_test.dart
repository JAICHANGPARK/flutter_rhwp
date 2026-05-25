import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
import 'package:flutter_svg/flutter_svg.dart';
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

  testWidgets('RhwpViewer composes page overlay over rendered SVG', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    final overlayPages = <int>[];
    final overlaySvgs = <String>[];

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 360,
          height: 320,
          child: RhwpViewer(
            document: document,
            padding: const EdgeInsets.all(12),
            pageGap: 0,
            svgBuilder: _testSvgBuilder,
            pageOverlayBuilder: (context, page, svg) {
              overlayPages.add(page);
              overlaySvgs.add(svg);
              return const ColoredBox(
                key: ValueKey('rhwp-page-overlay'),
                color: Colors.transparent,
              );
            },
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(find.byKey(const ValueKey('rhwp-page-overlay')), findsOneWidget);
    expect(overlayPages, [0]);
    expect(overlaySvgs.single, contains('#dc2626'));
  });

  testWidgets('RhwpNativeEditor toolbar applies insert and delete commands', (
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
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-text-field')),
      'abc',
    );
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

  testWidgets('RhwpNativeEditor toolbar inserts a table', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 0);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    final insertTableButton = find.widgetWithIcon(
      IconButton,
      Icons.table_chart_outlined,
    );
    await tester.ensureVisible(insertTableButton);
    await tester.pump();
    await tester.tap(insertTableButton);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 2));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertTable',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'rows': 2,
      'columns': 2,
    });
  });

  testWidgets('RhwpNativeEditor toolbar edits table rows and columns', (
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
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-insert-table')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-table')));
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('표'));
    await tester.pump();

    for (final key in [
      'rhwp-editor-insert-row-below',
      'rhwp-editor-insert-column-right',
      'rhwp-editor-delete-table-row',
      'rhwp-editor-delete-table-column',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(key)));
      await _pumpDocumentFrame(tester);
    }

    expect(changedCalls, 5);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'insertTable',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'rows': 2,
        'columns': 2,
      },
      {
        'type': 'insertTableRow',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'row': 0,
        'below': true,
      },
      {
        'type': 'insertTableColumn',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'column': 0,
        'right': true,
      },
      {
        'type': 'deleteTableRow',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'row': 0,
      },
      {
        'type': 'deleteTableColumn',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'column': 0,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor toolbar merges and splits table cells', (
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
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-insert-table')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-table')));
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('표'));
    await tester.pump();

    for (final key in ['rhwp-editor-merge-cells', 'rhwp-editor-split-cell']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(key)));
      await _pumpDocumentFrame(tester);
    }

    expect(changedCalls, 3);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'insertTable',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'rows': 2,
        'columns': 2,
      },
      {
        'type': 'mergeTableCells',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'startRow': 0,
        'startColumn': 0,
        'endRow': 1,
        'endColumn': 1,
      },
      {
        'type': 'splitTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 0,
        'row': 0,
        'column': 0,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor taps table cell to set table edit context', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180),
    );
    await tester.pump();

    expect(
      controller.tableCellSelection,
      const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
      ),
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-cell-selection')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-split-cell')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-split-cell')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'splitTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'row': 1,
      'column': 3,
    });
  });

  testWidgets('RhwpNativeEditor drags table cells to extend table edit range', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    Offset pagePoint(double x, double y) {
      return pageTopLeft +
          Offset(pageSize.width * x / 240, pageSize.height * y / 180);
    }

    final drag = await tester.startGesture(pagePoint(100, 60));
    await tester.pump();
    await drag.moveTo(pagePoint(150, 95));
    await tester.pump();
    await drag.up();
    await tester.pump();

    expect(
      controller.tableCellSelection,
      const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 4,
        activeCellIndex: 7,
      ),
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-cell-selection')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-cell-selection-1')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-merge-cells')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-merge-cells')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'mergeTableCells',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'startRow': 1,
      'startColumn': 3,
      'endRow': 2,
      'endColumn': 4,
    });
  });

  testWidgets('RhwpNativeEditor inserts text into selected table cell', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-text-field')),
      'cell',
    );
    await tester.tap(find.byTooltip('Insert'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 0,
      'text': 'cell',
    });

    await tester.tap(find.byTooltip('Delete backward'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 3,
      'count': 1,
    });
  });

  testWidgets('RhwpNativeEditor taps table cell text to set cell edit offset', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(document: document, controller: controller),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
    );
    await tester.pump();

    expect(
      controller.tableCellSelection,
      const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 2,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-text-field')),
      'X',
    );
    await tester.tap(find.byTooltip('Insert'));
    await _pumpDocumentFrame(tester);

    expect(jsonDecode(session.commands.single), {
      'type': 'insertTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 2,
      'text': 'X',
    });
  });

  testWidgets('RhwpNativeEditor context menu copies selected text', (
    tester,
  ) async {
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(document: document, controller: controller),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('복사'), findsOneWidget);
    await tester.tap(find.text('복사'));
    await tester.pumpAndSettle();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor context menu runs table cell actions', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final tablePoint =
        pageTopLeft +
        Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180);

    await tester.tapAt(tablePoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('셀 나누기'), findsOneWidget);
    await tester.tap(find.text('셀 나누기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'splitTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'row': 1,
      'column': 3,
    });
  });

  testWidgets('RhwpCommandEditor paints caret and selection target overlay', (
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
          child: RhwpCommandEditor(document: document, controller: controller),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(find.text('파일'), findsOneWidget);
    expect(find.text('입력'), findsOneWidget);
    expect(find.text('서식'), findsOneWidget);
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

  testWidgets(
    'RhwpCommandEditor positions caret from page layer tree text runs',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 420,
            child: RhwpCommandEditor(
              document: document,
              controller: controller,
            ),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      controller.cursor = const RhwpCursorPosition(offset: 1);
      await tester.pump();

      final firstCaretTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('rhwp-editor-caret')),
      );

      controller.cursor = const RhwpCursorPosition(offset: 2);
      await tester.pump();

      final secondCaretTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('rhwp-editor-caret')),
      );
      final caretAdvance = secondCaretTopLeft.dx - firstCaretTopLeft.dx;

      expect(session.layerTreePages, [0]);
      expect(caretAdvance, greaterThan(20));
      expect(caretAdvance, lessThan(40));
      expect(secondCaretTopLeft.dy, firstCaretTopLeft.dy);
    },
  );

  testWidgets('RhwpNativeEditor moves caret from page tap hit testing', (
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
          child: RhwpNativeEditor(document: document, controller: controller),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final firstCaretTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('rhwp-editor-caret')),
    );

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    final secondCaretTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('rhwp-editor-caret')),
    );
    final caretAdvance = secondCaretTopLeft.dx - firstCaretTopLeft.dx;

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    await tester.tapAt(firstCaretTopLeft + Offset(caretAdvance * 2.1, 6));
    await tester.pump();

    expect(controller.cursor, const RhwpCursorPosition(offset: 2));

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    final dragStart = tester.getTopLeft(
      find.byKey(const ValueKey('rhwp-editor-caret')),
    );
    controller.cursor = const RhwpCursorPosition(offset: 3);
    await tester.pump();
    final dragEnd = tester.getTopLeft(
      find.byKey(const ValueKey('rhwp-editor-caret')),
    );
    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();

    final drag = await tester.startGesture(dragStart + const Offset(1, 6));
    await tester.pump();
    await drag.moveTo(dragEnd + const Offset(1, 6));
    await tester.pump(const Duration(milliseconds: 16));
    await drag.up();
    await tester.pump();

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 1),
        end: RhwpCursorPosition(offset: 3),
      ),
    );
  });

  testWidgets('RhwpNativeEditor handles keyboard navigation and delete', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 3),
        end: RhwpCursorPosition(offset: 2),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(offset: 2));
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'count': 1,
    });

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.cursor, const RhwpCursorPosition(offset: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(offset: 1));
    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 1,
    });
  });

  testWidgets('RhwpNativeEditor handles enter and soft line break', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
    expect(jsonDecode(session.commands.single), {
      'type': 'splitParagraph',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 1, offset: 1),
    );
    expect(jsonDecode(session.commands.last), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 1,
      'offset': 0,
      'text': '\n',
    });
  });

  testWidgets('RhwpNativeEditor applies character formatting', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Bold'));
    await tester.pump();
    await tester.tap(find.byTooltip('Bold'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'bold': true},
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands[1]), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'italic': true},
    });
    expect(jsonDecode(session.commands[2]), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'underline': true},
    });

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(paragraph: 0, offset: 2),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 2,
      'endParagraph': 1,
      'endOffset': 2,
      'properties': {'bold': true},
    });
  });

  testWidgets('RhwpNativeEditor applies character shape dialog values', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-character-shape')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
      '12.5',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-bold')));
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-strikethrough')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-color-#dc2626')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {
        'bold': true,
        'italic': false,
        'underline': false,
        'strikethrough': true,
        'fontSize': 1250,
        'textColor': '#dc2626',
      },
    });
  });

  testWidgets('RhwpNativeEditor applies paragraph shape dialog values', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(paragraph: 0, offset: 1),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-paragraph-shape')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-paragraph-shape')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-line-spacing-field')),
      '180',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-indent-field')),
      '120',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-margin-left-field')),
      '300',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-margin-right-field')),
      '400',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-spacing-before-field')),
      '50',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-para-shape-spacing-after-field')),
      '60',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-para-shape-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 0,
      'endParagraph': 1,
      'properties': {
        'alignment': 'justify',
        'lineSpacing': 180,
        'lineSpacingType': 'Percent',
        'indent': 120,
        'marginLeft': 300,
        'marginRight': 400,
        'spacingBefore': 50,
        'spacingAfter': 60,
      },
    });
  });

  testWidgets('RhwpNativeEditor applies paragraph alignment', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(paragraph: 0, offset: 2),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Align center'));
    await tester.pump();
    await tester.tap(find.byTooltip('Align center'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 0,
      'endParagraph': 1,
      'properties': {'alignment': 'center'},
    });

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 2);
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Align right'));
    await tester.pump();
    await tester.tap(find.byTooltip('Align right'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 1,
      'endParagraph': 1,
      'properties': {'alignment': 'right'},
    });
  });

  testWidgets('RhwpNativeEditor finds and highlights text from layer tree', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'bc',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 0);
    expect(session.commands, isEmpty);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsOneWidget,
    );
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-search-clear')));
    await tester.pump();

    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsNothing,
    );
  });

  testWidgets('RhwpNativeEditor commits text input after IME composition', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();

    expect(session.commands, isEmpty);
    expect(controller.cursor, const RhwpCursorPosition(offset: 2));
    expect(
      find.byKey(const ValueKey('rhwp-editor-composing-preview')),
      findsOneWidget,
    );
    expect(find.text('ㅎ'), findsOneWidget);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'text': '한',
    });
    expect(tester.testTextInput.editingState?['text'], '');
    expect(
      find.byKey(const ValueKey('rhwp-editor-composing-preview')),
      findsNothing,
    );
  });

  testWidgets('RhwpNativeEditor copies cuts and pastes selected text', (
    tester,
  ) async {
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    var clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');
    expect(session.commands, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');
    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 1));
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 2,
    });

    await Clipboard.setData(const ClipboardData(text: 'ZZ'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(jsonDecode(session.commands.last), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'text': 'ZZ',
    });
  });

  testWidgets('RhwpNativeEditor replaces multi-paragraph selection', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isTrue);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(paragraph: 0, offset: 2),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Z',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'deleteRange',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 2,
        'endParagraph': 1,
        'endOffset': 2,
      },
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'text': 'Z',
      },
    ]);
  });

  testWidgets(
    'RhwpCommandEditor paints page-local selection across paragraphs',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 420,
            child: RhwpCommandEditor(
              document: document,
              controller: controller,
            ),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      controller.selection = const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 2),
        end: RhwpCursorPosition(paragraph: 1, offset: 2),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('rhwp-editor-selection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-selection-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('RhwpFullEditor reports unsupported host platforms', (
    tester,
  ) async {
    if (kIsWeb) {
      return;
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

    try {
      await tester.pumpWidget(
        const _WidgetHarness(
          child: SizedBox(width: 360, height: 240, child: RhwpFullEditor()),
        ),
      );

      expect(
        find.text(
          'The rhwp full editor requires Android, iOS, macOS, Windows, Linux, or Web.',
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
  final layerTreePages = <int>[];
  String pageLayerTreeJson = jsonEncode(_editorLayerTreeJson());
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    commands.add(commandJson);
    final command = jsonDecode(commandJson);
    if (command is Map && command['type'] == 'insertTable') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        final tableParagraph = offset > 0 ? paragraph + 1 : paragraph;
        return '{"ok":true,"paraIdx":$tableParagraph,"controlIdx":0}';
      }
    }
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
  Future<String> pageLayerTree({required int page}) async {
    layerTreePages.add(page);
    return pageLayerTreeJson;
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

class _MockClipboard {
  Map<String, dynamic>? _data = <String, dynamic>{'text': null};

  Future<Object?> handleMethodCall(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Clipboard.getData':
        return _data;
      case 'Clipboard.setData':
        _data = Map<String, dynamic>.from(methodCall.arguments as Map);
        return null;
      case 'Clipboard.hasStrings':
        final text = _data?['text'] as String?;
        return <String, bool>{'value': text != null && text.isNotEmpty};
    }
    return null;
  }
}

Map<String, Object?> _editorLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        {
          'kind': 'leaf',
          'bounds': {'x': 80, 'y': 40, 'width': 80, 'height': 16},
          'ops': [
            {
              'type': 'textRun',
              'bbox': {'x': 80, 'y': 40, 'width': 80, 'height': 16},
              'text': 'abcd',
              'source': {
                'id': 0,
                'utf16Range': {'start': 0, 'end': 4},
                'stableSourceKey': 'section:0/para:0/char:0',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 80, 'f': 52},
                'baselineY': 0,
              },
              'clusters': [
                _editorTextCluster(0, 1, 0),
                _editorTextCluster(1, 2, 10),
                _editorTextCluster(2, 3, 20),
                _editorTextCluster(3, 4, 30),
              ],
            },
          ],
        },
        {
          'kind': 'leaf',
          'bounds': {'x': 80, 'y': 80, 'width': 80, 'height': 16},
          'ops': [
            {
              'type': 'textRun',
              'bbox': {'x': 80, 'y': 80, 'width': 80, 'height': 16},
              'text': 'efgh',
              'source': {
                'id': 1,
                'utf16Range': {'start': 0, 'end': 4},
                'stableSourceKey': 'section:0/para:1/char:0',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 80, 'f': 92},
                'baselineY': 0,
              },
              'clusters': [
                _editorTextCluster(0, 1, 0),
                _editorTextCluster(1, 2, 10),
                _editorTextCluster(2, 3, 20),
                _editorTextCluster(3, 4, 30),
              ],
            },
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _tableCellEditorLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _editorTextRunLayerNode(paragraph: 0, y: 40),
        {
          'kind': 'group',
          'bounds': {'x': 80, 'y': 40, 'width': 100, 'height': 80},
          'groupKind': {
            'kind': 'table',
            'sectionIndex': 0,
            'paraIndex': 5,
            'controlIndex': 2,
            'rowCount': 4,
            'colCount': 5,
          },
          'children': [
            {
              'kind': 'group',
              'bounds': {'x': 90, 'y': 50, 'width': 40, 'height': 30},
              'groupKind': {
                'kind': 'tableCell',
                'row': 1,
                'col': 3,
                'rowSpan': 2,
                'colSpan': 1,
                'modelCellIndex': 7,
              },
              'children': [_editorCellTextRunLayerNode()],
            },
            {
              'kind': 'group',
              'bounds': {'x': 140, 'y': 80, 'width': 40, 'height': 30},
              'groupKind': {
                'kind': 'tableCell',
                'row': 2,
                'col': 4,
                'rowSpan': 1,
                'colSpan': 1,
                'modelCellIndex': 8,
              },
            },
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _editorCellTextRunLayerNode() {
  return {
    'kind': 'leaf',
    'bounds': {'x': 96, 'y': 73, 'width': 60, 'height': 12},
    'ops': [
      {
        'type': 'textRun',
        'bbox': {'x': 96, 'y': 73, 'width': 60, 'height': 12},
        'text': 'cell',
        'source': {
          'id': 7,
          'utf16Range': {'start': 0, 'end': 4},
          'stableSourceKey': 'section:0/para:5/char:0/cell:5:2:7:0:0',
        },
        'placement': {
          'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 96, 'f': 83},
          'baselineY': 0,
        },
        'clusters': [
          _editorTextCluster(0, 1, 0),
          _editorTextCluster(1, 2, 10),
          _editorTextCluster(2, 3, 20),
          _editorTextCluster(3, 4, 30),
        ],
      },
    ],
  };
}

Map<String, Object?> _editorTextRunLayerNode({
  required int paragraph,
  required double y,
}) {
  return {
    'kind': 'leaf',
    'bounds': {'x': 80, 'y': y, 'width': 80, 'height': 16},
    'ops': [
      {
        'type': 'textRun',
        'bbox': {'x': 80, 'y': y, 'width': 80, 'height': 16},
        'text': 'abcd',
        'source': {
          'id': paragraph,
          'utf16Range': {'start': 0, 'end': 4},
          'stableSourceKey': 'section:0/para:$paragraph/char:0',
        },
        'placement': {
          'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 80, 'f': y + 12},
          'baselineY': 0,
        },
        'clusters': [
          _editorTextCluster(0, 1, 0),
          _editorTextCluster(1, 2, 10),
          _editorTextCluster(2, 3, 20),
          _editorTextCluster(3, 4, 30),
        ],
      },
    ],
  };
}

Map<String, Object?> _editorTextCluster(int start, int end, double x) {
  return {
    'textRangeUtf16': {'start': start, 'end': end},
    'origin': {'x': x, 'y': 0},
    'advance': {'dx': 10, 'dy': 0},
  };
}

Future<void> _pumpDocumentFrame(WidgetTester tester) async {
  for (var i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
