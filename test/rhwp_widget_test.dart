import 'dart:async';
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

const _textInputActionIgnoreTestWindow = Duration(milliseconds: 850);

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

  testWidgets(
    'RhwpViewer ignores editor cursor notifications for page rebuilds',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var overlayBuildCount = 0;

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
              pageOverlayBuilder: (context, page, svg) {
                overlayBuildCount += 1;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      expect(overlayBuildCount, 1);
      expect(session.renderedPages, [0]);

      controller.cursor = const RhwpCursorPosition(offset: 1);
      await tester.pump();

      expect(overlayBuildCount, 1);
      expect(session.renderedPages, [0]);

      controller.zoomIn();
      await tester.pump();

      expect(overlayBuildCount, 2);
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

  testWidgets('RhwpViewer controller scrolls to requested page', (
    tester,
  ) async {
    final controller = RhwpViewerController();
    final session = _FakeRhwpSession(pageCountValue: 8);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 420,
          height: 320,
          child: RhwpViewer(
            document: document,
            controller: controller,
            padding: const EdgeInsets.all(8),
            pageGap: 8,
            svgBuilder: _tallSvgBuilder,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    final scroll = controller.goToPage(5);
    await tester.pumpAndSettle();
    await scroll;

    expect(controller.currentPage, 5);
    expect(session.renderedPages, contains(5));
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

  testWidgets('RhwpViewer keeps SVG widget cached during overlay updates', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var overlayTick = 0;
    var svgBuildCount = 0;
    StateSetter? updateHarness;

    Widget svgBuilder(BuildContext context, String svg) {
      svgBuildCount += 1;
      return Text(
        key: const ValueKey('rhwp-cached-svg-page'),
        svg.contains('#dc2626') ? 'page' : 'other',
      );
    }

    await tester.pumpWidget(
      _WidgetHarness(
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHarness = setState;
            return SizedBox(
              width: 360,
              height: 320,
              child: RhwpViewer(
                document: document,
                padding: const EdgeInsets.all(12),
                pageGap: 0,
                svgBuilder: svgBuilder,
                pageOverlayBuilder: (context, page, svg) {
                  return Text(
                    'overlay $overlayTick',
                    key: const ValueKey('rhwp-page-overlay-tick'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(svgBuildCount, 1);
    expect(session.renderedPages, [0]);
    expect(find.text('overlay 0'), findsOneWidget);

    updateHarness!(() {
      overlayTick += 1;
    });
    await tester.pump();

    expect(svgBuildCount, 1);
    expect(session.renderedPages, [0]);
    expect(find.text('overlay 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('rhwp-cached-svg-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-rendered-svg-repaint-boundary')),
      findsOneWidget,
    );
  });

  testWidgets(
    'RhwpViewer keeps previous SVG while refreshed render is pending',
    (tester) async {
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var renderRevision = 0;

      Widget buildViewer() {
        return _WidgetHarness(
          child: SizedBox(
            width: 360,
            height: 320,
            child: RhwpViewer(
              document: document,
              renderRevision: renderRevision,
              padding: const EdgeInsets.all(12),
              pageGap: 0,
              svgBuilder: (context, svg) {
                return Text(
                  key: const ValueKey('rhwp-test-rendered-svg-state'),
                  svg.contains('#16a34a') ? 'new' : 'old',
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildViewer());
      await _pumpDocumentFrame(tester);
      expect(find.text('old'), findsOneWidget);

      final pendingSvg = Completer<String>();
      session.pendingRenderedSvgs.add(pendingSvg);
      renderRevision += 1;
      await tester.pumpWidget(buildViewer());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('old'), findsOneWidget);

      pendingSvg.complete(_pageSvg.replaceAll('#dc2626', '#16a34a'));
      await _pumpDocumentFrame(tester);

      expect(find.text('new'), findsOneWidget);
    },
  );

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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-footnote')));
    await _pumpDocumentFrame(tester);

    expect(controller.cursor.offset, 3);
    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertFootnote',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-equation')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-equation-script-field')),
      'sqrt x',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-equation-font-size-field')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-equation-color-#2563eb')));
    await tester.tap(find.byKey(const ValueKey('rhwp-equation-apply')));
    await _pumpDocumentFrame(tester);

    expect(controller.cursor.offset, 4);
    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertEquation',
      'section': 0,
      'paragraph': 0,
      'offset': 3,
      'script': 'sqrt x',
      'fontSize': 1200,
      'color': 0x2563eb,
    });
  });

  testWidgets('RhwpNativeEditor inserts page and column breaks', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
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

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-page-break')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
    expect(jsonDecode(session.commands.last), {
      'type': 'insertPageBreak',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-column-break')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 2));
    expect(jsonDecode(session.commands.last), {
      'type': 'insertColumnBreak',
      'section': 0,
      'paragraph': 1,
      'offset': 0,
    });

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(paragraph: 2, offset: 3);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertPageBreak',
      'section': 0,
      'paragraph': 2,
      'offset': 3,
    });

    controller.cursor = const RhwpCursorPosition(paragraph: 3, offset: 4);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertColumnBreak',
      'section': 0,
      'paragraph': 3,
      'offset': 4,
    });
  });

  testWidgets('RhwpNativeEditor insert ribbon inserts a picture', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onImageRequested: () => RhwpEditorImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              extension: '.PNG',
              width: 750,
              height: 1500,
              naturalWidthPx: 10,
              naturalHeightPx: 20,
              description: 'sample.png',
            ),
            onChanged: (_) => changedCalls += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 2);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-insert-picture')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-picture')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 2));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertPicture',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'imageData': [1, 2, 3],
      'width': 750,
      'height': 1500,
      'naturalWidthPx': 10,
      'naturalHeightPx': 20,
      'extension': 'png',
      'description': 'sample.png',
    });
  });

  testWidgets('RhwpNativeEditor insert ribbon inserts shape presets', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
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

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 2);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-insert-shape')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-shape-rectangle')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 10));
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'width': 9000,
      'height': 6750,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'rectangle',
      'treatAsChar': false,
      'textWrap': 'InFrontOfText',
      'lineFlipX': false,
      'lineFlipY': false,
    });

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 10);
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-shape-ellipse')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 0,
      'offset': 10,
      'width': 9000,
      'height': 6750,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'ellipse',
      'treatAsChar': false,
      'textWrap': 'InFrontOfText',
      'lineFlipX': false,
      'lineFlipY': false,
    });

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 18);
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-shape-line')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 0,
      'offset': 18,
      'width': 9000,
      'height': 3000,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'line',
      'treatAsChar': false,
      'textWrap': 'InFrontOfText',
      'lineFlipX': false,
      'lineFlipY': false,
    });

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 26);
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-shape-textbox')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 0,
      'offset': 26,
      'width': 12000,
      'height': 6000,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'textbox',
      'treatAsChar': true,
      'textWrap': 'Square',
      'lineFlipX': false,
      'lineFlipY': false,
    });
  });

  testWidgets('RhwpNativeEditor preserves viewport while editing', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 8);
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

    final scroll = controller.goToPage(5);
    await tester.pumpAndSettle();
    await scroll;
    final offsetBefore = _viewerListOffset(tester);
    expect(offsetBefore, greaterThan(0));

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-text-field')),
      'x',
    );
    await tester.tap(find.byTooltip('Insert'));
    await _pumpDocumentFrame(tester);

    expect(_viewerListOffset(tester), greaterThan(offsetBefore - 100));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 0,
      'text': 'x',
    });
  });

  testWidgets('RhwpNativeEditor edit ribbon restores undo and redo snapshots', (
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

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-text-field')),
      'abc',
    );
    await tester.tap(find.byTooltip('Insert'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 0,
      'text': 'abc',
    });

    await tester.tap(find.text('편집'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-undo')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
      'saveSnapshot',
      'restoreSnapshot',
      'discardSnapshot',
    ]);
    expect(jsonDecode(session.historyCommands[2]), {
      'type': 'restoreSnapshot',
      'snapshotId': 1,
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-redo')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
      'saveSnapshot',
      'restoreSnapshot',
      'discardSnapshot',
      'saveSnapshot',
      'restoreSnapshot',
      'discardSnapshot',
    ]);
    expect(jsonDecode(session.historyCommands[5]), {
      'type': 'restoreSnapshot',
      'snapshotId': 2,
    });
    expect(session.commands, hasLength(1));
  });

  testWidgets('RhwpNativeEditor file ribbon exports save artifacts', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    final exported = <RhwpExportedDocument>[];

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onExported: (document) => exported.add(document),
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('파일'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-save-hwp')));
    await _pumpDocumentFrame(tester);

    expect(exported.single.fileName, 'sample.hwp');
    expect(exported.single.bytes, [0x48, 0x57, 0x50]);
    expect(session.exportHwpCalls, 1);
    expect(session.commands, isEmpty);

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-save-hwpx')));
    await _pumpDocumentFrame(tester);

    expect(exported.last.fileName, 'sample.hwpx');
    expect(exported.last.bytes, [0x48, 0x57, 0x50, 0x58]);
    expect(session.exportHwpxCalls, 1);

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-export-pdf')));
    await _pumpDocumentFrame(tester);

    expect(exported.last.fileName, 'sample.pdf');
    expect(exported.last.bytes, [0x50, 0x44, 0x46]);
    expect(session.exportPdfCalls, 1);
  });

  testWidgets('RhwpNativeEditor file ribbon requests app file open', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var openRequests = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 420,
          child: RhwpNativeEditor(
            document: document,
            controller: controller,
            onOpenRequested: () => openRequests += 1,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('파일'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-open')));
    await _pumpDocumentFrame(tester);

    expect(openRequests, 1);
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor file ribbon shows document info', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
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

    await tester.tap(find.text('파일'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-document-info')));
    await _pumpDocumentFrame(tester);

    expect(find.text('Document info'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('rhwp-document-info-file-name')),
          )
          .data,
      'sample.hwp',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('rhwp-document-info-format')),
          )
          .data,
      'HWP',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('rhwp-document-info-page-count')),
          )
          .data,
      '3',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('rhwp-document-info-raw-json')),
          )
          .data,
      contains('"pageCount":3'),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor view controls synchronize zoom state', (
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

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '100%',
    );

    await tester.tap(find.text('보기'));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toolbar-zoom-in')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom-in')));
    await tester.pump();

    expect(controller.zoom, 1.25);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom')))
          .data,
      '125%',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '125%',
    );

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-status-zoom-out')));
    await tester.pump();

    expect(controller.zoom, 1.0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '100%',
    );

    controller.zoom = 1.5;
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-reset-zoom')));
    await tester.pump();

    expect(controller.zoom, 1.0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom')))
          .data,
      '100%',
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.zoom, 1.25);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '125%',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.zoom, 1.0);

    controller.zoom = 1.5;
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.zoom, 1.0);
    expect(session.commands, isEmpty);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(RhwpViewer)),
        scrollDelta: const Offset(0, -40),
      ),
    );
    await tester.pump();

    expect(controller.zoom, 1.0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(RhwpViewer)),
        scrollDelta: const Offset(0, -40),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.zoom, 1.25);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '125%',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(RhwpViewer)),
        scrollDelta: const Offset(0, 40),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.zoom, 1.0);
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor view ribbon toggles paragraph marks', (
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

    expect(
      find.byKey(const ValueKey('rhwp-editor-paragraph-mark')),
      findsNothing,
    );

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toggle-paragraph-marks')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-toggle-paragraph-marks')),
    );
    await _pumpDocumentFrame(tester);

    expect(
      find.byKey(const ValueKey('rhwp-editor-paragraph-mark')),
      findsOneWidget,
    );
    expect(find.text('¶'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-toggle-paragraph-marks')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('rhwp-editor-paragraph-mark')),
      findsNothing,
    );
  });

  testWidgets(
    'RhwpNativeEditor view ribbon toggles transparent table borders',
    (tester) async {
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

      expect(
        find.byKey(const ValueKey('rhwp-editor-transparent-table-border')),
        findsNothing,
      );

      await tester.tap(find.text('보기'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(
          const ValueKey('rhwp-editor-toggle-transparent-table-borders'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('rhwp-editor-toggle-transparent-table-borders'),
        ),
      );
      await _pumpDocumentFrame(tester);

      expect(
        find.byKey(const ValueKey('rhwp-editor-transparent-table-border')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-transparent-table-border-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('rhwp-editor-toggle-transparent-table-borders'),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('rhwp-editor-transparent-table-border')),
        findsNothing,
      );
    },
  );

  testWidgets('RhwpNativeEditor page ribbon creates header and footer', (
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

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-create-header')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'createHeaderFooter',
      'section': 0,
      'isHeader': true,
      'applyTo': 0,
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-create-footer')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'createHeaderFooter',
      'section': 0,
      'isHeader': false,
      'applyTo': 0,
    });
  });

  testWidgets('RhwpNativeEditor page ribbon inserts header text', (
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

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-header-text')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-header-footer-text-field')),
      'Header from Flutter',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-header-footer-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getHeaderFooter', 'section': 0, 'isHeader': true, 'applyTo': 0},
      {'type': 'getHeaderFooter', 'section': 0, 'isHeader': true, 'applyTo': 0},
      {
        'type': 'createHeaderFooter',
        'section': 0,
        'isHeader': true,
        'applyTo': 0,
      },
      {
        'type': 'insertTextInHeaderFooter',
        'section': 0,
        'isHeader': true,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'text': 'Header from Flutter',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor page ribbon replaces header text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..headerFooterExists = true
      ..headerFooterText = 'Old Header';
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

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-header-text')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-header-footer-text-field')),
          )
          .controller
          ?.text,
      'Old Header',
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-header-footer-text-field')),
      'New Header',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-header-footer-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.headerFooterText, 'New Header');
    expect(session.commands.map(jsonDecode), [
      {'type': 'getHeaderFooter', 'section': 0, 'isHeader': true, 'applyTo': 0},
      {'type': 'getHeaderFooter', 'section': 0, 'isHeader': true, 'applyTo': 0},
      {
        'type': 'deleteTextInHeaderFooter',
        'section': 0,
        'isHeader': true,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'count': 10,
      },
      {
        'type': 'insertTextInHeaderFooter',
        'section': 0,
        'isHeader': true,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'text': 'New Header',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor page ribbon inserts new page number', (
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

    controller.cursor = const RhwpCursorPosition(paragraph: 2, offset: 3);
    await tester.pump();

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-new-number')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-new-number-start-field')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-new-number-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 2, offset: 11),
    );
    expect(jsonDecode(session.commands.single), {
      'type': 'insertNewNumber',
      'section': 0,
      'paragraph': 2,
      'offset': 3,
      'startNumber': 7,
    });
  });

  testWidgets('RhwpNativeEditor page ribbon applies page setup', (
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

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-page-setup')));
    await tester.pumpAndSettle();

    expect(jsonDecode(session.commands.single), {
      'type': 'getPageSetup',
      'section': 0,
    });

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-page-setup-width-field')),
      '200',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-page-setup-height-field')),
      '300',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-page-setup-landscape')));
    await tester.tap(find.byKey(const ValueKey('rhwp-page-setup-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.last), {
      'type': 'setPageSetup',
      'section': 0,
      'properties': {
        'width': 56693,
        'height': 85039,
        'marginLeft': 8504,
        'marginRight': 8504,
        'marginTop': 5669,
        'marginBottom': 4252,
        'marginHeader': 4252,
        'marginFooter': 4252,
        'marginGutter': 0,
        'landscape': true,
        'binding': 0,
      },
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
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-editor-status-position')),
          )
          .data,
      'Cells R2C4:R3C4',
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

  testWidgets(
    'RhwpNativeEditor extends selected table cells with shift click',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
      final document = RhwpDocument.fromSession(session);

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 720,
            child: RhwpNativeEditor(document: document, controller: controller),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
      );
      await tester.pump();
      final firstCellFinder = find.byKey(
        const ValueKey('rhwp-editor-table-cell-selection'),
      );
      final firstCellTopLeft = tester.getTopLeft(firstCellFinder);
      final firstCellSize = tester.getSize(firstCellFinder);
      final secondCellPoint =
          firstCellTopLeft +
          Offset(firstCellSize.width * 1.75, firstCellSize.height * 1.5);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final shiftClick = await tester.startGesture(secondCellPoint);
      await tester.pump();
      await shiftClick.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
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
      expect(session.commands, isEmpty);
    },
  );

  testWidgets('RhwpNativeEditor moves selected table cells with keyboard', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDocumentFrame(tester);

    expect(
      controller.tableCellSelection,
      const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 2,
        startColumn: 4,
        endRow: 2,
        endColumn: 4,
        activeCellIndex: 8,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

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

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _pumpDocumentFrame(tester);

    expect(
      controller.tableCellSelection,
      const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 2,
        startColumn: 4,
        endRow: 2,
        endColumn: 4,
        activeCellIndex: 8,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

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
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor clears transient editor state with escape', (
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'ㅎ', composing: TextRange(start: 0, end: 1)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('rhwp-editor-composing-preview')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(tester.testTextInput.editingState?['text'], '');
    expect(
      find.byKey(const ValueKey('rhwp-editor-composing-preview')),
      findsNothing,
    );

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180),
    );
    await tester.pump();

    expect(controller.tableCellSelection, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.tableCellSelection, isNull);
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-cell-selection')),
      findsNothing,
    );

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
      controller.selection,
      RhwpSelectionRange.collapsed(const RhwpCursorPosition(offset: 3)),
    );

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'bc',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsNothing,
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor enters selected table cell with enter', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 0);
    expect(session.commands, isEmpty);
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
        isTextEditing: true,
      ),
    );

    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Z'));
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 0,
      'text': 'Z',
    });

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
  });

  testWidgets('RhwpNativeEditor exits and re-enters table cell edit mode', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.isTextEditing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
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
    expect(session.commands, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.isTextEditing, isTrue);
    expect(session.commands, isEmpty);
  });

  testWidgets(
    'RhwpNativeEditor keeps committed table cell text visible until refresh completes',
    (tester) async {
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
            Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
      );
      await tester.pump();

      final pendingSvg = Completer<String>();
      session.pendingRenderedSvgs.add(pendingSvg);
      session.renderedPages.clear();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Z',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(jsonDecode(session.commands.single), {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 2,
        'text': 'Z',
      });
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text('Z'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      pendingSvg.complete(_pageSvg);
      await _pumpDocumentFrame(tester);

      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsNothing,
      );
    },
  );

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

  testWidgets('RhwpNativeEditor overwrites text inside selected table cell', (
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
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
    );
    await tester.pump();

    expect(controller.tableCellSelection?.activeOffset, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Z',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);
    expect(controller.tableCellSelection?.activeOffset, 3);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 2,
        'count': 1,
      },
      {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 2,
        'text': 'Z',
      },
    ]);
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
      findsOneWidget,
    );

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.renderedPages, [0]);
  });

  testWidgets('RhwpNativeEditor clears selected table cell text with delete', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 0,
      'count': 4,
    });
  });

  testWidgets(
    'RhwpNativeEditor copies cuts and pastes selected table cell text',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
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

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      await tester.tapAt(
        pageTopLeft +
            Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      var clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'cell');
      expect(session.commands, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'cell');
      expect(changedCalls, 1);
      expect(jsonDecode(session.commands.single), {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 0,
        'count': 4,
      });

      await Clipboard.setData(const ClipboardData(text: 'ZZ'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 2);
      expect(jsonDecode(session.commands.last), {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 0,
        'text': 'ZZ',
      });
    },
  );

  testWidgets('RhwpNativeEditor pastes clipboard table text across cells', (
    tester,
  ) async {
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_tableClipboardLayerTreeJson());
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 100 / 240, pageSize.height * 60 / 180),
    );
    await tester.pump();
    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 1,
      endColumn: 3,
      activeCellIndex: 7,
    );
    await tester.pump();

    await Clipboard.setData(const ClipboardData(text: 'A\tB\nC\tD'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 0,
        'count': 3,
      },
      for (final entry in const [
        (cellIndex: 7, text: 'A'),
        (cellIndex: 8, text: 'B'),
        (cellIndex: 9, text: 'C'),
        (cellIndex: 10, text: 'D'),
      ])
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': entry.cellIndex,
          'cellParagraph': 0,
          'offset': 0,
          'text': entry.text,
        },
    ]);
    expect(controller.tableCellSelection?.activeCellIndex, 10);
    expect(controller.tableCellSelection?.activeOffset, 1);
    expect(controller.tableCellSelection?.isTextEditing, isTrue);
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
        isTextEditing: true,
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-editor-status-position')),
          )
          .data,
      'Cell R2C4 / Para 0 / Offset 2',
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

    await tester.tapAt(
      pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(jsonDecode(session.commands.last), {
      'type': 'deleteTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 2,
      'count': 1,
    });
  });

  testWidgets('RhwpNativeEditor selects objects from page layer tree', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
          Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
    );
    await tester.pump();

    expect(
      controller.objectSelection,
      const RhwpObjectSelection(
        page: 0,
        bounds: Rect.fromLTRB(120, 60, 180, 110),
        type: 'shape',
        section: 0,
        paragraph: 2,
        controlIndex: 1,
        objectIndex: 9,
      ),
    );
    expect(controller.tableCellSelection, isNull);
    expect(
      find.byKey(const ValueKey('rhwp-editor-object-selection')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-editor-status-position')),
          )
          .data,
      'Object shape #9 / Page 1 / Control 1',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.objectSelection, isNull);
    expect(
      find.byKey(const ValueKey('rhwp-editor-object-selection')),
      findsNothing,
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor deletes selected object controls', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
          Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
    );
    await tester.pump();
    expect(controller.objectSelection, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNull);
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteObjectControl',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
    });
    expect(
      find.byKey(const ValueKey('rhwp-editor-object-selection')),
      findsNothing,
    );
  });

  testWidgets('RhwpNativeEditor context menu deletes selected objects', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
    final objectPoint =
        pageTopLeft +
        Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180);

    await tester.tapAt(objectPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(controller.objectSelection, isNotNull);
    expect(find.text('개체 삭제'), findsOneWidget);

    await tester.tap(find.text('개체 삭제'));
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNull);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteObjectControl',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
    });
  });

  testWidgets('RhwpNativeEditor copies and pastes selected object controls', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
          Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
    );
    await tester.pump();
    expect(controller.objectSelection, isNotNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'copyObjectControl',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
      },
    ]);
    expect(session.historyCommands, isEmpty);

    session.commands.clear();
    controller.clearObjectSelection();
    controller.cursor = const RhwpCursorPosition(paragraph: 3, offset: 2);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.objectSelection, isNull);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 4, offset: 0),
    );
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'clipboardHasObjectControl'},
      {'type': 'pasteObjectControl', 'section': 0, 'paragraph': 3, 'offset': 2},
    ]);
  });

  testWidgets('RhwpNativeEditor cuts selected object controls', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
          Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
    );
    await tester.pump();
    expect(controller.objectSelection, isNotNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.objectSelection, isNull);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'copyObjectControl',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
      },
      {
        'type': 'deleteObjectControl',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor edit ribbon changes selected object z order', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
          Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
    );
    await tester.pump();

    final frontButton = find.byKey(const ValueKey('rhwp-editor-object-front'));
    await tester.ensureVisible(frontButton);
    await tester.tap(frontButton);
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNotNull);
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'changeObjectZOrder',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
      'operation': 'front',
    });
  });

  testWidgets(
    'RhwpNativeEditor edit ribbon applies selected object properties',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
            Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180),
      );
      await tester.pump();

      final propertiesButton = find.byKey(
        const ValueKey('rhwp-editor-object-properties'),
      );
      await tester.ensureVisible(propertiesButton);
      await tester.tap(propertiesButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-object-width-field')),
        '1200',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-object-height-field')),
        '2400',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-object-horz-offset-field')),
        '80',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-object-vert-offset-field')),
        '90',
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-object-properties-apply')),
      );
      await _pumpDocumentFrame(tester);

      expect(controller.objectSelection, isNotNull);
      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'getObjectProperties',
          'section': 0,
          'paragraph': 2,
          'controlIndex': 1,
          'objectType': 'shape',
        },
        {
          'type': 'setObjectProperties',
          'section': 0,
          'paragraph': 2,
          'controlIndex': 1,
          'objectType': 'shape',
          'properties': {
            'width': 1200,
            'height': 2400,
            'horzOffset': 80,
            'vertOffset': 90,
          },
        },
      ]);
    },
  );

  testWidgets('RhwpNativeEditor drags selected objects to update position', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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

    await tester.tapAt(pagePoint(150, 85));
    await tester.pump();

    final drag = await tester.startGesture(pagePoint(150, 85));
    await drag.moveTo(pagePoint(162, 93));
    await drag.up();
    await _pumpDocumentFrame(tester);

    _expectRectClose(
      controller.objectSelection!.bounds,
      const Rect.fromLTRB(132, 68, 192, 118),
    );
    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
      },
      {
        'type': 'setObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
        'properties': {
          'width': 60,
          'height': 50,
          'horzOffset': 132,
          'vertOffset': 68,
        },
      },
    ]);
  });

  testWidgets('RhwpNativeEditor drags selected line endpoints', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_lineObjectEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 720,
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

    await tester.tapAt(pagePoint(150, 85));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('rhwp-editor-object-line-start')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-object-line-end')),
      findsOneWidget,
    );

    final selectedPageTopLeft = tester.getTopLeft(pageFinder);
    final selectedPageSize = tester.getSize(pageFinder);
    Offset selectedPagePoint(double x, double y) {
      return selectedPageTopLeft +
          Offset(
            selectedPageSize.width * x / 240,
            selectedPageSize.height * y / 180,
          );
    }

    final drag = await tester.startGesture(selectedPagePoint(180, 110));
    await drag.moveTo(selectedPagePoint(192, 116));
    await drag.up();
    await _pumpDocumentFrame(tester);

    _expectRectClose(
      controller.objectSelection!.bounds,
      const Rect.fromLTRB(120, 60, 192, 116),
    );
    expect(controller.objectSelection!.lineStart!.dx, closeTo(120, 0.01));
    expect(controller.objectSelection!.lineStart!.dy, closeTo(60, 0.01));
    expect(controller.objectSelection!.lineEnd!.dx, closeTo(192, 0.01));
    expect(controller.objectSelection!.lineEnd!.dy, closeTo(116, 0.01));
    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'line',
      },
      {
        'type': 'moveLineEndpoint',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'startX': 120,
        'startY': 60,
        'endX': 192,
        'endY': 116,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor nudges selected objects with keyboard', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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

    await tester.tapAt(pagePoint(150, 85));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    _expectRectClose(
      controller.objectSelection!.bounds,
      const Rect.fromLTRB(130, 60, 190, 110),
    );
    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
      },
      {
        'type': 'setObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
        'properties': {
          'width': 60,
          'height': 50,
          'horzOffset': 130,
          'vertOffset': 60,
        },
      },
    ]);
  });

  testWidgets(
    'RhwpNativeEditor resizes selected objects from overlay handles',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 720,
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

      await tester.tapAt(pagePoint(150, 85));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('rhwp-editor-object-resize-southEast')),
        findsOneWidget,
      );

      final selectedPageTopLeft = tester.getTopLeft(pageFinder);
      final selectedPageSize = tester.getSize(pageFinder);
      Offset selectedPagePoint(double x, double y) {
        return selectedPageTopLeft +
            Offset(
              selectedPageSize.width * x / 240,
              selectedPageSize.height * y / 180,
            );
      }

      final drag = await tester.startGesture(selectedPagePoint(179, 109));
      await drag.moveTo(selectedPagePoint(191, 119));
      await drag.up();
      await _pumpDocumentFrame(tester);

      _expectRectClose(
        controller.objectSelection!.bounds,
        const Rect.fromLTRB(120, 60, 192, 120),
      );
      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'getObjectProperties',
          'section': 0,
          'paragraph': 2,
          'controlIndex': 1,
          'objectType': 'shape',
        },
        {
          'type': 'setObjectProperties',
          'section': 0,
          'paragraph': 2,
          'controlIndex': 1,
          'objectType': 'shape',
          'properties': {
            'width': 72,
            'height': 60,
            'horzOffset': 120,
            'vertOffset': 60,
          },
        },
      ]);
    },
  );

  testWidgets('RhwpNativeEditor preserves object ratio with shift resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 720,
          height: 720,
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

    await tester.tapAt(pagePoint(150, 85));
    await tester.pumpAndSettle();

    final selectedPageTopLeft = tester.getTopLeft(pageFinder);
    final selectedPageSize = tester.getSize(pageFinder);
    Offset selectedPagePoint(double x, double y) {
      return selectedPageTopLeft +
          Offset(
            selectedPageSize.width * x / 240,
            selectedPageSize.height * y / 180,
          );
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final drag = await tester.startGesture(selectedPagePoint(179, 109));
    await drag.moveTo(selectedPagePoint(191, 109));
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    _expectRectClose(
      controller.objectSelection!.bounds,
      const Rect.fromLTRB(120, 60, 192, 120),
    );
    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
      },
      {
        'type': 'setObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
        'objectType': 'shape',
        'properties': {
          'width': 72,
          'height': 60,
          'horzOffset': 120,
          'vertOffset': 60,
        },
      },
    ]);
  });

  testWidgets('RhwpNativeEditor context menu changes selected object z order', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
    final objectPoint =
        pageTopLeft +
        Offset(pageSize.width * 150 / 240, pageSize.height * 85 / 180);

    await tester.tapAt(objectPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(controller.objectSelection, isNotNull);
    expect(find.text('앞으로'), findsOneWidget);

    await tester.tap(find.text('앞으로'));
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNotNull);
    expect(jsonDecode(session.commands.single), {
      'type': 'changeObjectZOrder',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
      'operation': 'forward',
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

  testWidgets('RhwpNativeEditor edit ribbon selects all body text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstText: 'abcd', secondText: 'efgh'),
    );
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

    await tester.tap(find.text('편집'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-select-all')));
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0),
        end: RhwpCursorPosition(paragraph: 1, offset: 4),
      ),
    );
    expect(controller.currentPage, 0);
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
    expect(
      find.byKey(const ValueKey('rhwp-editor-selection')),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('RhwpNativeEditor handles select all shortcut', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstText: 'abcd', secondText: 'efgh'),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0),
        end: RhwpCursorPosition(paragraph: 1, offset: 4),
      ),
    );
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
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

  testWidgets('RhwpNativeEditor blinks caret without removing hit target', (
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

    final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret'));
    final opacityFinder = find.byKey(
      const ValueKey('rhwp-editor-caret-opacity'),
    );
    expect(caretFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1);

    await tester.pump(const Duration(milliseconds: 150));

    expect(caretFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    expect(caretFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
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

  testWidgets('RhwpNativeEditor selects a word on double click', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..pageLayerTreeJson = jsonEncode(
        _editorLayerTreeJson(firstText: 'hello world'),
      );
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

    controller.cursor = const RhwpCursorPosition(offset: 7);
    await tester.pump();
    final wordPoint =
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
        const Offset(1, 6);

    await tester.tapAt(wordPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(wordPoint);
    await tester.pump();

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 6),
        end: RhwpCursorPosition(offset: 11),
      ),
    );
  });

  testWidgets('RhwpNativeEditor selects a paragraph on triple click', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..pageLayerTreeJson = jsonEncode(
        _editorLayerTreeJson(firstText: 'hello world'),
      );
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

    controller.cursor = const RhwpCursorPosition(offset: 7);
    await tester.pump();
    final paragraphPoint =
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
        const Offset(1, 6);

    await tester.tapAt(paragraphPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(paragraphPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(paragraphPoint);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 0),
        end: RhwpCursorPosition(offset: 11),
      ),
    );
  });

  testWidgets('RhwpNativeEditor extends selection with shift click', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..pageLayerTreeJson = jsonEncode(
        _editorLayerTreeJson(firstText: 'hello world'),
      );
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

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    final firstCaretTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('rhwp-editor-caret')),
    );
    controller.cursor = const RhwpCursorPosition(offset: 6);
    await tester.pump();
    final targetPoint =
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
        const Offset(1, 6);
    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(targetPoint);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 1),
        end: RhwpCursorPosition(offset: 6),
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))).dx,
      greaterThan(firstCaretTopLeft.dx),
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

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _pumpDocumentFrame(tester);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 1, offset: 2),
    );

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 3);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1, offset: 3),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(offset: 4));

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 1),
        end: RhwpCursorPosition(offset: 4),
      ),
    );
    expect(session.commands, isEmpty);

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 3),
      end: RhwpCursorPosition(offset: 2),
    );
    await tester.pump();
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

  testWidgets('RhwpNativeEditor moves by word with keyboard modifiers', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstText: 'hello world', secondText: 'tail'),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(offset: 5));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(offset: 6));

    controller.cursor = const RhwpCursorPosition(offset: 8);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 8),
        end: RhwpCursorPosition(offset: 6),
      ),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor deletes by word with keyboard modifiers', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstText: 'hello world', secondText: 'tail'),
    );
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

    controller.cursor = const RhwpCursorPosition(offset: 8);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 6));
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 6,
      'count': 2,
    });

    controller.cursor = const RhwpCursorPosition();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition());
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 0,
      'count': 5,
    });

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 4),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(controller.cursor, const RhwpCursorPosition(offset: 1));
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 3,
    });
  });

  testWidgets('RhwpNativeEditor moves vertically by page geometry', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 4, secondParagraph: 1),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(paragraph: 4, offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 1, offset: 2),
    );

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 3);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1, offset: 3),
        end: RhwpCursorPosition(paragraph: 4, offset: 3),
      ),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor moves vertically across page geometry', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 2);
    session.pageLayerTreeJsonByPage[0] = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 0, secondParagraph: 1),
    );
    session.pageLayerTreeJsonByPage[1] = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 2, secondParagraph: 3),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 2, offset: 2),
    );
    expect(controller.currentPage, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    expect(controller.currentPage, 0);
  });

  testWidgets('RhwpNativeEditor handles page up and page down keys', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[0] = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 0, secondParagraph: 1),
    );
    session.pageLayerTreeJsonByPage[1] = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 2, secondParagraph: 3),
    );
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstParagraph: 4, secondParagraph: 5),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 2, offset: 2),
    );
    expect(controller.currentPage, 1);

    controller.cursor = const RhwpCursorPosition(paragraph: 2, offset: 3);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 2, offset: 3),
        end: RhwpCursorPosition(paragraph: 4, offset: 3),
      ),
    );
    expect(controller.currentPage, 2);

    controller.cursor = const RhwpCursorPosition(paragraph: 4, offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 3, offset: 2),
    );
    expect(controller.currentPage, 1);
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor uses page geometry for home and end', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(
        firstText: 'abcd',
        secondText: 'efgh',
        firstParagraph: 0,
        secondParagraph: 0,
        firstCharStart: 0,
        secondCharStart: 4,
      ),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(offset: 6);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(offset: 4));

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(offset: 8));

    controller.cursor = const RhwpCursorPosition(offset: 7);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(offset: 7),
        end: RhwpCursorPosition(offset: 4),
      ),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor handles document boundary shortcuts', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[0] = jsonEncode(
      _editorLayerTreeJson(
        firstText: 'abcd',
        secondText: 'efgh',
        firstParagraph: 0,
        secondParagraph: 1,
      ),
    );
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(
        firstText: 'ijkl',
        secondText: 'mnop',
        firstParagraph: 4,
        secondParagraph: 5,
      ),
    );
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(paragraph: 3, offset: 2);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 0));
    expect(controller.currentPage, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 5, offset: 4),
    );
    expect(controller.currentPage, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 5, offset: 4),
        end: RhwpCursorPosition(paragraph: 0),
      ),
    );
    expect(controller.currentPage, 0);
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
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

  testWidgets('RhwpNativeEditor inserts tab from keyboard', (tester) async {
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
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'text': '\t',
    });

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition(offset: 2));
    expect(jsonDecode(session.commands[1]), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 2,
    });
    expect(jsonDecode(session.commands[2]), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'text': '\t',
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

  testWidgets('RhwpNativeEditor applies inline character toolbar values', (
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-font-family-field')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-font-family-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('맑은 고딕').last);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontFamily': '맑은 고딕'},
    });

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-font-size-field')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-font-size-field')),
      '14.5',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-apply-font-size')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontSize': 1450},
    });

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-text-color-#2563eb')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'textColor': '#2563eb'},
    });

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-shade-color-#fef08a')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'shadeColor': '#fef08a'},
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-superscript')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 5);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'superscript': true, 'subscript': false},
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-subscript')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 6);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'superscript': false, 'subscript': true},
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-emboss')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 7);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'emboss': true, 'engrave': false},
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-engrave')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 8);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'emboss': false, 'engrave': true},
    });
  });

  testWidgets(
    'RhwpNativeEditor applies character format to selected table cells',
    (tester) async {
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

      await tester.tap(find.text('서식'));
      await tester.pump();
      await tester.tap(find.byTooltip('Bold'));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(jsonDecode(session.commands.single), {
        'type': 'applyCharFormatInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'startOffset': 0,
        'endOffset': 4,
        'properties': {'bold': true},
      });
      expect(controller.tableCellSelection?.activeCellIndex, 7);
    },
  );

  testWidgets(
    'RhwpNativeEditor applies pending character format to table input',
    (tester) async {
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
            Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
      );
      await tester.pump();

      await tester.tap(find.text('서식'));
      await tester.pump();
      await tester.tap(find.byTooltip('Bold'));
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-editor-font-size-field')),
        '14.5',
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-apply-font-size')),
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-text-color-#2563eb')),
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-shade-color-#fef08a')),
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-superscript')));
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-emboss')));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.commands, isEmpty);

      await tester.tapAt(
        pageTopLeft +
            Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Z',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'text': 'Z',
        },
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'startOffset': 2,
          'endOffset': 3,
          'properties': {
            'bold': true,
            'fontSize': 1450,
            'textColor': '#2563eb',
            'shadeColor': '#fef08a',
            'superscript': true,
            'subscript': false,
            'emboss': true,
            'engrave': false,
          },
        },
      ]);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
    },
  );

  testWidgets('RhwpNativeEditor applies pending character format to input', (
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

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Bold'));
    await tester.pump();
    await tester.tap(find.byTooltip('Bold'));
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-font-size-field')),
      '14.5',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-apply-font-size')));
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-text-color-#2563eb')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-shade-color-#fef08a')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-superscript')));
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-emboss')));
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.commands, isEmpty);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Z',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'text': 'Z',
      },
      {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 2,
        'endParagraph': 0,
        'endOffset': 3,
        'properties': {
          'bold': true,
          'fontSize': 1450,
          'textColor': '#2563eb',
          'shadeColor': '#fef08a',
          'superscript': true,
          'subscript': false,
          'emboss': true,
          'engrave': false,
        },
      },
    ]);

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
  });

  testWidgets('RhwpNativeEditor reflects caret character properties in ribbon', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..charPropertiesJson =
          '{"fontFamily":"맑은 고딕","fontSize":1400,"bold":true,"italic":false,"underline":true,"strikethrough":false,"superscript":false,"subscript":false,"emboss":false,"engrave":false,"textColor":"#dc2626","shadeColor":"#dbeafe"}';
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
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();

    expect(session.commands, isEmpty);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.format_bold),
          )
          .isSelected,
      isTrue,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.format_underlined),
          )
          .isSelected,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-editor-font-size-field')),
          )
          .controller
          ?.text,
      '14.0',
    );
  });

  testWidgets('RhwpNativeEditor reflects caret paragraph properties in ribbon', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..paraPropertiesJson =
          '{"alignment":"center","lineSpacing":180.0,"lineSpacingType":"Percent","marginLeft":0.0,"marginRight":0.0,"indent":0.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":1}';
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
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();

    expect(session.commands, isEmpty);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.format_align_center),
          )
          .isSelected,
      isTrue,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey('rhwp-editor-line-spacing-field')),
          )
          .initialValue,
      180,
    );
  });

  testWidgets('RhwpNativeEditor preloads paragraph shape dialog from caret', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..paraPropertiesJson =
          '{"alignment":"center","lineSpacing":180.0,"lineSpacingType":"Fixed","marginLeft":300.0,"marginRight":400.0,"indent":120.0,"spacingBefore":50.0,"spacingAfter":60.0,"paraShapeId":2}';
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
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-paragraph-shape')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-paragraph-shape')));
    await tester.pumpAndSettle();

    expect(session.commands, isEmpty);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('rhwp-para-shape-alignment-field')),
          )
          .initialValue,
      'center',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(
              const ValueKey('rhwp-para-shape-line-spacing-type-field'),
            ),
          )
          .initialValue,
      'Fixed',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-line-spacing-field')),
          )
          .controller
          ?.text,
      '180',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-indent-field')),
          )
          .controller
          ?.text,
      '120',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-margin-left-field')),
          )
          .controller
          ?.text,
      '300',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-margin-right-field')),
          )
          .controller
          ?.text,
      '400',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-spacing-before-field')),
          )
          .controller
          ?.text,
      '50',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-para-shape-spacing-after-field')),
          )
          .controller
          ?.text,
      '60',
    );
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
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-font-family-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('맑은 고딕').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
      '12.5',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-bold')));
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-strikethrough')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-superscript')));
    await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-emboss')));
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-color-#dc2626')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-char-shape-shade-#dbeafe')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-shape-shade-#dbeafe')),
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
        'superscript': true,
        'subscript': false,
        'emboss': true,
        'engrave': false,
        'fontFamily': '맑은 고딕',
        'fontSize': 1250,
        'textColor': '#dc2626',
        'shadeColor': '#dbeafe',
      },
    });
  });

  testWidgets('RhwpNativeEditor preloads character shape dialog from caret', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..charPropertiesJson =
          '{"fontFamily":"맑은 고딕","fontSize":1400,"bold":true,"italic":true,"underline":true,"strikethrough":true,"superscript":true,"subscript":false,"emboss":true,"engrave":false,"textColor":"#dc2626","shadeColor":"#dbeafe"}';
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

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-character-shape')));
    await tester.pumpAndSettle();

    expect(session.commands, isEmpty);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('rhwp-char-shape-font-family-field')),
          )
          .initialValue,
      '맑은 고딕',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
          )
          .controller
          ?.text,
      '14.0',
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-bold')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-italic')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-underline')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-strikethrough')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-superscript')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-subscript')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-emboss')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('rhwp-char-shape-engrave')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('RhwpNativeEditor opens character shape dialog with Alt+L', (
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
      findsOneWidget,
    );
    expect(session.commands, isEmpty);
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

  testWidgets('RhwpNativeEditor applies line spacing preset from ribbon', (
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
      find.byKey(const ValueKey('rhwp-editor-line-spacing-field')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-line-spacing-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('180').last);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 0,
      'endParagraph': 1,
      'properties': {'lineSpacing': 180, 'lineSpacingType': 'Percent'},
    });
  });

  testWidgets('RhwpNativeEditor applies document styles to paragraphs', (
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
      find.byKey(const ValueKey('rhwp-editor-style-picker')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-style-picker')));
    await tester.pumpAndSettle();

    expect(find.text('제목 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rhwp-style-3')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getStyleList'},
      {'type': 'applyStyle', 'section': 0, 'paragraph': 0, 'styleId': 3},
      {'type': 'applyStyle', 'section': 0, 'paragraph': 1, 'styleId': 3},
    ]);
  });

  testWidgets('RhwpNativeEditor applies document styles to table cells', (
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

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 1,
      endColumn: 3,
      activeCellIndex: 7,
      activeCellParagraph: 0,
      activeOffset: 2,
      isTextEditing: true,
    );
    await tester.pump();

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-style-picker')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-style-picker')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rhwp-style-3')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getStyleList'},
      {
        'type': 'applyCellStyle',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'styleId': 3,
      },
    ]);
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

  testWidgets('RhwpNativeEditor applies paragraph alignment to table cells', (
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

    await tester.tap(find.text('서식'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Align center'));
    await tester.pump();
    await tester.tap(find.byTooltip('Align center'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'properties': {'alignment': 'center'},
    });
  });

  testWidgets('RhwpNativeEditor applies table cell fill and border', (
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

    await tester.tap(find.text('표'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-cell-fill-#fef08a')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-cell-fill-#fef08a')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyTableCellStyle',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'properties': {'fillType': 'solid', 'fillColor': '#fef08a'},
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-cell-border')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyTableCellStyle',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'properties': {
        'borderLeft': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderRight': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderTop': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderBottom': {'type': 1, 'width': 1, 'color': '#475569'},
      },
    });

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-cell-align-bottom')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyTableCellStyle',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'properties': {'verticalAlign': 2},
    });
  });

  testWidgets('RhwpNativeEditor applies paragraph alignment shortcuts', (
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

    controller.selection = const RhwpSelectionRange(
      start: RhwpCursorPosition(paragraph: 0, offset: 2),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    for (final shortcut in const [
      (key: LogicalKeyboardKey.keyL, alignment: 'left'),
      (key: LogicalKeyboardKey.keyE, alignment: 'center'),
      (key: LogicalKeyboardKey.keyR, alignment: 'right'),
      (key: LogicalKeyboardKey.keyJ, alignment: 'justify'),
    ]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(shortcut.key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);
    }

    expect(changedCalls, 4);
    expect(session.commands.map(jsonDecode), [
      for (final alignment in const ['left', 'center', 'right', 'justify'])
        {
          'type': 'applyParaFormatRange',
          'section': 0,
          'startParagraph': 0,
          'endParagraph': 1,
          'properties': {'alignment': alignment},
        },
    ]);
  });

  testWidgets('RhwpNativeEditor focuses search with find shortcut', (
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

    expect(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      findsNothing,
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
    );
    expect(searchField.focusNode?.hasFocus, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'needle',
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();

    final focusedSearchField = tester.widget<TextField>(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
    );
    expect(focusedSearchField.focusNode?.hasFocus, isTrue);
    expect(
      focusedSearchField.controller?.selection,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
  });

  testWidgets('RhwpNativeEditor finds and highlights text from layer tree', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyz', secondText: 'mnop'),
    );
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
      'xy',
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
    expect(controller.currentPage, 2);
    expect(session.renderedPages, contains(2));

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-search-clear')));
    await tester.pump();

    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsNothing,
    );
  });

  testWidgets('RhwpNativeEditor debounces live search field input', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyz', secondText: 'mnop'),
    );
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'xy',
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('0 / 0'), findsOneWidget);
    expect(controller.selection.isCollapsed, isTrue);

    await tester.pump(const Duration(milliseconds: 80));
    await _pumpDocumentFrame(tester);

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
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
  });

  testWidgets('RhwpNativeEditor finds text inside table cells', (tester) async {
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'ell',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsOneWidget,
    );
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
        activeCellParagraph: 0,
        activeOffset: 1,
        isTextEditing: true,
      ),
    );
    expect(controller.selection.isCollapsed, isTrue);
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
  });

  testWidgets('RhwpNativeEditor cycles search matches with F3 shortcuts', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyz', secondText: 'xyqr'),
    );
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'xy',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await _pumpDocumentFrame(tester);

    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1),
        end: RhwpCursorPosition(paragraph: 1, offset: 2),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
  });

  testWidgets('RhwpNativeEditor cycles search matches from search field keys', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyz', secondText: 'xyqr'),
    );
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    final searchField = find.byKey(const ValueKey('rhwp-editor-search-field'));
    await tester.enterText(searchField, 'xy');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );

    await tester.tap(searchField);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpDocumentFrame(tester);

    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1),
        end: RhwpCursorPosition(paragraph: 1, offset: 2),
      ),
    );

    await tester.tap(searchField);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );

    await tester.tap(searchField);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-editor-search-active')),
      findsNothing,
    );
    expect(session.commands, isEmpty);
    expect(session.historyCommands, isEmpty);
  });

  testWidgets('RhwpNativeEditor replaces the active search match', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyz', secondText: 'mnop'),
    );
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
      'xy',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
      'AB',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-replace')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map((json) => jsonDecode(json)['type']), [
      'deleteText',
      'insertText',
    ]);
    expect(jsonDecode(session.commands[0]), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 2,
    });
    expect(jsonDecode(session.commands[1]), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'text': 'AB',
    });
    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 3),
      ),
    );
  });

  testWidgets('RhwpNativeEditor replaces the active table cell search match', (
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-search-field')),
      'ell',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
      'XX',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-replace')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 1,
        'count': 3,
      },
      {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 1,
        'text': 'XX',
      },
    ]);
    expect(find.text('0 / 0'), findsOneWidget);
    expect(controller.tableCellSelection?.activeCellIndex, 7);
    expect(controller.tableCellSelection?.activeOffset, 3);
    expect(controller.tableCellSelection?.isTextEditing, isTrue);
  });

  testWidgets(
    'RhwpNativeEditor shifts remaining search matches after replace',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 3);
      session.pageLayerTreeJsonByPage[2] = jsonEncode(
        _editorLayerTreeJson(firstText: 'wxyzxy', secondText: 'mnop'),
      );
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

      await tester.tap(find.text('도구'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-editor-search-field')),
        'xy',
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
      await _pumpDocumentFrame(tester);

      await tester.enterText(
        find.byKey(const ValueKey('rhwp-editor-replace-field')),
        'ABCD',
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-replace')));
      await _pumpDocumentFrame(tester);

      expect(find.text('1 / 1'), findsOneWidget);
      expect(
        controller.selection,
        const RhwpSelectionRange(
          start: RhwpCursorPosition(paragraph: 0, offset: 6),
          end: RhwpCursorPosition(paragraph: 0, offset: 8),
        ),
      );
    },
  );

  testWidgets('RhwpNativeEditor replaces all search matches', (tester) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _editorLayerTreeJson(firstText: 'wxyzxy', secondText: 'xyqr'),
    );
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
      'xy',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-find')));
    await _pumpDocumentFrame(tester);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
      'ABCD',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-replace-all')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-replace-all')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map((json) => jsonDecode(json)['type']), [
      'deleteText',
      'insertText',
      'deleteText',
      'insertText',
      'deleteText',
      'insertText',
    ]);
    expect(jsonDecode(session.commands[0]), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 1,
      'offset': 0,
      'count': 2,
    });
    expect(jsonDecode(session.commands[2]), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 4,
      'count': 2,
    });
    expect(jsonDecode(session.commands[4]), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 0,
      'offset': 1,
      'count': 2,
    });
    for (final index in [1, 3, 5]) {
      expect(jsonDecode(session.commands[index])['text'], 'ABCD');
    }
    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 0, offset: 5),
      ),
    );
  });

  testWidgets('RhwpNativeEditor tools ribbon compares extracted text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.extractedText = 'alpha\nbeta\ngamma';
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

    await tester.tap(find.text('도구'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-compare')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-compare')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-compare-target-field')),
      'alpha\nBETTA\ngamma\ndelta',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-compare-run')));
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-compare-same-count')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-compare-changed-count')),
          )
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-compare-added-count')))
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-compare-removed-count')),
          )
          .data,
      '0',
    );
    expect(find.text('beta  ->  BETTA'), findsOneWidget);
    expect(session.commands, isEmpty);
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
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
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

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
  });

  testWidgets('RhwpNativeEditor toggles overwrite mode with insert key', (
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    final inputMode = find.byKey(
      const ValueKey('rhwp-editor-status-input-mode'),
    );
    expect(tester.widget<Text>(inputMode).data, 'Insert');

    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pump();

    expect(tester.widget<Text>(inputMode).data, 'Overwrite');

    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pump();

    expect(tester.widget<Text>(inputMode).data, 'Insert');
  });

  testWidgets('RhwpNativeEditor overwrites body text while mode is enabled', (
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

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Z',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);
    expect(controller.cursor, const RhwpCursorPosition(offset: 2));
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'deleteText',
        'section': 0,
        'paragraph': 0,
        'offset': 1,
        'count': 1,
      },
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 1,
        'text': 'Z',
      },
    ]);
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
      findsOneWidget,
    );

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.renderedPages, [0]);
  });

  testWidgets('RhwpNativeEditor waits for text input action before refresh', (
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
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(jsonDecode(session.commands.single), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'text': ' ',
    });
    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.renderedPages, [0]);
  });

  testWidgets(
    'RhwpNativeEditor keeps focused text refresh held after input action',
    (tester) async {
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
              editRefreshDelay: const Duration(milliseconds: 120),
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
      session.renderedPages.clear();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.pump(_textInputActionIgnoreTestWindow);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets(
    'RhwpNativeEditor ignores immediate text input action after commit',
    (tester) async {
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
              editRefreshDelay: const Duration(milliseconds: 120),
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
      session.renderedPages.clear();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await _releaseTextInputAction(tester);
      await tester.pump(const Duration(milliseconds: 120));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets(
    'RhwpNativeEditor holds text refresh across desktop input connection churn',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(milliseconds: 120),
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        tester.testTextInput.closeConnection();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.pump(_textInputActionIgnoreTestWindow);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor ignores delayed desktop text input action while focused',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(milliseconds: 120),
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.pump(_textInputActionIgnoreTestWindow);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor absorbs external focus churn during desktop text commit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final externalFocusNode = FocusNode();
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 720,
                    height: 420,
                    child: RhwpNativeEditor(
                      document: document,
                      controller: controller,
                      editRefreshDelay: const Duration(milliseconds: 120),
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(
                      key: ValueKey('external-focus-target'),
                      width: 10,
                      height: 10,
                    ),
                  ),
                ],
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        externalFocusNode.requestFocus();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        externalFocusNode.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor treats ancestor focus action as desktop input churn',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final ancestorFocusNode = FocusNode();
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Focus(
                focusNode: ancestorFocusNode,
                child: SizedBox(
                  width: 720,
                  height: 420,
                  child: RhwpNativeEditor(
                    document: document,
                    controller: controller,
                    editRefreshDelay: const Duration(milliseconds: 120),
                    onChanged: (_) => changedCalls += 1,
                  ),
                ),
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        ancestorFocusNode.requestFocus();
        await tester.pump(_textInputActionIgnoreTestWindow);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        ancestorFocusNode.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor restores desktop text input after delayed churn action',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 720,
                    height: 420,
                    child: RhwpNativeEditor(
                      document: document,
                      controller: controller,
                      editRefreshDelay: const Duration(milliseconds: 120),
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  const TextField(key: ValueKey('external-focus-field')),
                ],
              ),
            ),
          ),
        );
        await _pumpDocumentFrame(tester);

        final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret'));
        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump();

        controller.cursor = const RhwpCursorPosition(offset: 2);
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(_textInputActionIgnoreTestWindow);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump(const Duration(milliseconds: 240));

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('external-focus-field')));
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor cancels scheduled refresh on late desktop input action',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 720,
                    height: 420,
                    child: RhwpNativeEditor(
                      document: document,
                      controller: controller,
                      editRefreshDelay: const Duration(milliseconds: 500),
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  const TextField(key: ValueKey('external-focus-field')),
                ],
              ),
            ),
          ),
        );
        await _pumpDocumentFrame(tester);

        final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret'));
        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump();

        controller.cursor = const RhwpCursorPosition(offset: 2);
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('external-focus-field')));
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor holds text refresh across transient desktop focus loss',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(milliseconds: 120),
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        await tester.tapAt(
          tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
              const Offset(1, 6),
        );
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor debounces desktop focus churn with edit refresh delay',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(seconds: 2),
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
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.closeConnection();
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        await tester.pump(const Duration(milliseconds: 2100));
        await _pumpDocumentFrame(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor cancels transient desktop focus release when focus returns',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(milliseconds: 120),
                onChanged: (_) => changedCalls += 1,
              ),
            ),
          ),
        );
        await _pumpDocumentFrame(tester);

        final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret'));
        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump();

        controller.cursor = const RhwpCursorPosition(offset: 2);
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor reholds text refresh when focus returns after slow commit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final saveSnapshotGate = Completer<void>();
      session.commandGates['saveSnapshot'] = saveSnapshotGate;
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      try {
        await tester.pumpWidget(
          _WidgetHarness(
            child: SizedBox(
              width: 720,
              height: 420,
              child: RhwpNativeEditor(
                document: document,
                controller: controller,
                editRefreshDelay: const Duration(milliseconds: 120),
                onChanged: (_) => changedCalls += 1,
              ),
            ),
          ),
        );
        await _pumpDocumentFrame(tester);

        final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret'));
        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump();

        controller.cursor = const RhwpCursorPosition(offset: 2);
        session.renderedPages.clear();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'A',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          session.historyCommands.map((json) => jsonDecode(json)['type']),
          ['saveSnapshot'],
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();

        saveSnapshotGate.complete();
        await tester.pump();
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(session.commands.map(jsonDecode), [
          {
            'type': 'insertText',
            'section': 0,
            'paragraph': 0,
            'offset': 2,
            'text': 'A',
          },
        ]);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('RhwpNativeEditor queues rapid text input commits', (
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
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'A',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'B',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);
    expect(controller.cursor, const RhwpCursorPosition(offset: 4));
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'text': 'A',
      },
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 3,
        'text': 'B',
      },
    ]);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
      findsOneWidget,
    );
    expect(find.text('AB'), findsOneWidget);

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.renderedPages, [0]);
  });

  testWidgets('RhwpNativeEditor honors custom edit refresh delay', (
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
            editRefreshDelay: const Duration(seconds: 1),
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
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'A',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);

    await _releaseTextInputAction(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(changedCalls, 0);
    expect(session.renderedPages, isEmpty);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(changedCalls, 1);
    expect(session.renderedPages, [0]);
  });

  testWidgets(
    'RhwpNativeEditor keeps committed text visible until refresh completes',
    (tester) async {
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

      controller.cursor = const RhwpCursorPosition(offset: 4);
      await tester.pump();
      final previousCaretLeft = tester
          .getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret')))
          .dx;
      session.renderedPages.clear();
      final pendingSvg = Completer<String>();
      session.pendingRenderedSvgs.add(pendingSvg);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Z',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))).dx,
        greaterThan(previousCaretLeft),
      );
      expect(find.text('Z'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      pendingSvg.complete(_pageSvg);
      await _pumpDocumentFrame(tester);

      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'RhwpNativeEditor masks deleted body text until refresh completes',
    (tester) async {
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

      controller.cursor = const RhwpCursorPosition(offset: 3);
      await tester.pump();
      session.renderedPages.clear();
      final pendingSvg = Completer<String>();
      session.pendingRenderedSvgs.add(pendingSvg);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.pump();

      expect(jsonDecode(session.commands.single), {
        'type': 'deleteText',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'count': 1,
      });
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      pendingSvg.complete(_pageSvg);
      await _pumpDocumentFrame(tester);

      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsNothing,
      );
    },
  );

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

  testWidgets('RhwpNativeEditor pastes multiline body text as paragraphs', (
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

    controller.cursor = const RhwpCursorPosition(offset: 1);
    await Clipboard.setData(const ClipboardData(text: 'AA\nBB\nCC'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 2, offset: 2),
    );
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 0,
        'offset': 1,
        'text': 'AA',
      },
      {'type': 'splitParagraph', 'section': 0, 'paragraph': 0, 'offset': 3},
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 1,
        'offset': 0,
        'text': 'BB',
      },
      {'type': 'splitParagraph', 'section': 0, 'paragraph': 1, 'offset': 2},
      {
        'type': 'insertText',
        'section': 0,
        'paragraph': 2,
        'offset': 0,
        'text': 'CC',
      },
    ]);
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
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
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

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
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
  final historyCommands = <String>[];
  final renderedPages = <int>[];
  final pendingRenderedSvgs = <Completer<String>>[];
  final commandGates = <String, Completer<void>>{};
  final layerTreePages = <int>[];
  int exportHwpCalls = 0;
  int exportHwpxCalls = 0;
  int exportPdfCalls = 0;
  int nextSnapshotId = 1;
  bool hasObjectControlClipboard = false;
  bool headerFooterExists = false;
  String headerFooterText = '';
  String extractedText = 'alpha\nbeta';
  String charPropertiesJson =
      '{"fontFamily":"함초롬바탕","fontSize":1000,"bold":false,"italic":false,"underline":false,"strikethrough":false,"superscript":false,"subscript":false,"emboss":false,"engrave":false,"textColor":"#000000","shadeColor":"#ffffff"}';
  String paraPropertiesJson =
      '{"alignment":"justify","lineSpacing":160.0,"lineSpacingType":"Percent","marginLeft":0.0,"marginRight":0.0,"indent":0.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":0}';
  String pageLayerTreeJson = jsonEncode(_editorLayerTreeJson());
  final pageLayerTreeJsonByPage = <int, String>{};
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    final command = jsonDecode(commandJson);
    final commandType = command is Map ? command['type'] : null;
    if (command is Map &&
        const {
          'saveSnapshot',
          'restoreSnapshot',
          'discardSnapshot',
        }.contains(command['type'])) {
      historyCommands.add(commandJson);
      await _waitForCommandGate(commandType);
      if (command['type'] == 'saveSnapshot') {
        final snapshotId = nextSnapshotId;
        nextSnapshotId += 1;
        return '{"ok":true,"snapshotId":$snapshotId}';
      }
      return '{"ok":true}';
    }

    if (command is Map &&
        (command['type'] == 'getCharPropertiesAt' ||
            command['type'] == 'getCellCharPropertiesAt')) {
      return charPropertiesJson;
    }
    if (command is Map &&
        (command['type'] == 'getParaPropertiesAt' ||
            command['type'] == 'getCellParaPropertiesAt')) {
      return paraPropertiesJson;
    }

    commands.add(commandJson);
    await _waitForCommandGate(commandType);
    if (command is Map && command['type'] == 'getStyleList') {
      return '[{"id":0,"name":"본문","englishName":"Body","type":0,"nextStyleId":0,"paraShapeId":0,"charShapeId":0},{"id":3,"name":"제목 1","englishName":"Heading 1","type":0,"nextStyleId":0,"paraShapeId":1,"charShapeId":1}]';
    }
    if (command is Map && command['type'] == 'insertTable') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        final tableParagraph = offset > 0 ? paragraph + 1 : paragraph;
        return '{"ok":true,"paraIdx":$tableParagraph,"controlIdx":0}';
      }
    }
    if (command is Map && command['type'] == 'insertPicture') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        final pictureParagraph = offset > 0 ? paragraph + 1 : paragraph;
        return '{"ok":true,"paraIdx":$pictureParagraph,"controlIdx":0}';
      }
    }
    if (command is Map && command['type'] == 'copyObjectControl') {
      hasObjectControlClipboard = true;
      return '{"ok":true}';
    }
    if (command is Map && command['type'] == 'clipboardHasObjectControl') {
      return '{"ok":true,"hasControl":$hasObjectControlClipboard}';
    }
    if (command is Map && command['type'] == 'pasteObjectControl') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        final pastedParagraph = offset > 0 ? paragraph + 1 : paragraph;
        return '{"ok":true,"paraIdx":$pastedParagraph,"controlIdx":0}';
      }
    }
    if (command is Map && command['type'] == 'getObjectProperties') {
      return '{"width":60,"height":50,"horzOffset":120,"vertOffset":60}';
    }
    if (command is Map && command['type'] == 'getPageSetup') {
      return '{"width":59528,"height":84189,"marginLeft":8504,"marginRight":8504,"marginTop":5669,"marginBottom":4252,"marginHeader":4252,"marginFooter":4252,"marginGutter":0,"landscape":false,"binding":0}';
    }
    if (command is Map && command['type'] == 'getHeaderFooter') {
      if (!headerFooterExists) {
        return '{"ok":true,"exists":false}';
      }
      return jsonEncode({
        'ok': true,
        'exists': true,
        'kind': command['isHeader'] == true ? 'header' : 'footer',
        'applyTo': command['applyTo'] ?? 0,
        'label': '양 쪽',
        'paraIndex': 0,
        'controlIndex': 1,
        'paraCount': 1,
        'text': headerFooterText,
      });
    }
    if (command is Map && command['type'] == 'createHeaderFooter') {
      headerFooterExists = true;
      return '{"ok":true,"kind":"header","applyTo":0,"label":"양 쪽","paraIndex":0,"controlIndex":1}';
    }
    if (command is Map && command['type'] == 'deleteTextInHeaderFooter') {
      headerFooterText = '';
      return '{"ok":true,"charOffset":0}';
    }
    if (command is Map && command['type'] == 'insertTextInHeaderFooter') {
      headerFooterExists = true;
      headerFooterText = command['text']?.toString() ?? '';
      return '{"ok":true,"charOffset":0}';
    }
    return '{"ok":true}';
  }

  Future<void> _waitForCommandGate(Object? commandType) async {
    if (commandType is! String) {
      return;
    }

    final gate = commandGates[commandType];
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
  }

  @override
  Future<int> pageCount() async => pageCountValue;

  @override
  Future<rust.RhwpDocumentInfo> documentInfo() async {
    return rust.RhwpDocumentInfo(
      pageCount: pageCountValue,
      sourceFormat: 'hwp',
      fileName: 'sample.hwp',
      rawJson: '{"pageCount":$pageCountValue}',
    );
  }

  @override
  Future<String> extractText({int? page}) async => extractedText;

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
  Future<String> renderPageSvg({required int page}) async {
    renderedPages.add(page);
    if (pendingRenderedSvgs.isNotEmpty) {
      return pendingRenderedSvgs.removeAt(0).future;
    }
    return _pageSvg;
  }

  @override
  Future<String> pageLayerTree({required int page}) async {
    layerTreePages.add(page);
    return pageLayerTreeJsonByPage[page] ?? pageLayerTreeJson;
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

Map<String, Object?> _editorLayerTreeJson({
  String firstText = 'abcd',
  String secondText = 'efgh',
  int firstParagraph = 0,
  int secondParagraph = 1,
  int firstCharStart = 0,
  int secondCharStart = 0,
}) {
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
              'text': firstText,
              'source': {
                'id': 0,
                'utf16Range': {'start': 0, 'end': firstText.length},
                'stableSourceKey':
                    'section:0/para:$firstParagraph/char:$firstCharStart',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 80, 'f': 52},
                'baselineY': 0,
              },
              'clusters': _editorTextClusters(firstText.length),
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
              'text': secondText,
              'source': {
                'id': 1,
                'utf16Range': {'start': 0, 'end': secondText.length},
                'stableSourceKey':
                    'section:0/para:$secondParagraph/char:$secondCharStart',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 80, 'f': 92},
                'baselineY': 0,
              },
              'clusters': _editorTextClusters(secondText.length),
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

Map<String, Object?> _tableClipboardLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
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
            _editorTableCellLayerNode(
              row: 1,
              column: 3,
              modelCellIndex: 7,
              x: 90,
              y: 50,
              text: 'old',
            ),
            _editorTableCellLayerNode(
              row: 1,
              column: 4,
              modelCellIndex: 8,
              x: 140,
              y: 50,
            ),
            _editorTableCellLayerNode(
              row: 2,
              column: 3,
              modelCellIndex: 9,
              x: 90,
              y: 80,
            ),
            _editorTableCellLayerNode(
              row: 2,
              column: 4,
              modelCellIndex: 10,
              x: 140,
              y: 80,
            ),
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _objectEditorLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _editorTextRunLayerNode(paragraph: 0, y: 40),
        {
          'type': 'shape',
          'rect': {'left': 120, 'top': 60, 'right': 180, 'bottom': 110},
          'sectionIndex': 0,
          'paraIndex': 2,
          'controlIndex': 1,
          'objectIndex': 9,
        },
      ],
    },
  };
}

Map<String, Object?> _lineObjectEditorLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _editorTextRunLayerNode(paragraph: 0, y: 40),
        {
          'type': 'line',
          'rect': {'left': 120, 'top': 60, 'right': 180, 'bottom': 110},
          'sectionIndex': 0,
          'paraIndex': 2,
          'controlIndex': 1,
          'objectIndex': 9,
          'children': [
            {
              'kind': 'leaf',
              'bounds': {'x': 120, 'y': 60, 'width': 60, 'height': 50},
              'ops': [
                {
                  'type': 'line',
                  'bbox': {'x': 120, 'y': 60, 'width': 60, 'height': 50},
                  'x1': 120,
                  'y1': 60,
                  'x2': 180,
                  'y2': 110,
                },
              ],
            },
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _editorTableCellLayerNode({
  required int row,
  required int column,
  required int modelCellIndex,
  required double x,
  required double y,
  String? text,
}) {
  return {
    'kind': 'group',
    'bounds': {'x': x, 'y': y, 'width': 40, 'height': 30},
    'groupKind': {
      'kind': 'tableCell',
      'row': row,
      'col': column,
      'rowSpan': 1,
      'colSpan': 1,
      'modelCellIndex': modelCellIndex,
    },
    'children': [
      if (text != null)
        _editorCellTextRunLayerNode(
          cellIndex: modelCellIndex,
          text: text,
          x: x + 6,
          y: y + 10,
        ),
    ],
  };
}

Map<String, Object?> _editorCellTextRunLayerNode({
  int cellIndex = 7,
  String text = 'cell',
  double x = 96,
  double y = 73,
}) {
  return {
    'kind': 'leaf',
    'bounds': {'x': x, 'y': y, 'width': 60, 'height': 12},
    'ops': [
      {
        'type': 'textRun',
        'bbox': {'x': x, 'y': y, 'width': 60, 'height': 12},
        'text': text,
        'source': {
          'id': cellIndex,
          'utf16Range': {'start': 0, 'end': text.length},
          'stableSourceKey': 'section:0/para:5/char:0/cell:5:2:$cellIndex:0:0',
        },
        'placement': {
          'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': x, 'f': y + 10},
          'baselineY': 0,
        },
        'clusters': _editorTextClusters(text.length),
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

List<Map<String, Object?>> _editorTextClusters(int length) {
  return [
    for (var index = 0; index < length; index += 1)
      _editorTextCluster(index, index + 1, index * 10),
  ];
}

void _expectRectClose(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.01));
  expect(actual.top, closeTo(expected.top, 0.01));
  expect(actual.right, closeTo(expected.right, 0.01));
  expect(actual.bottom, closeTo(expected.bottom, 0.01));
}

double _viewerListOffset(WidgetTester tester) {
  final list = tester.widget<ListView>(find.byType(ListView).last);
  return list.controller!.offset;
}

Future<void> _pumpDocumentFrame(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpDesktopTextInputRelease(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pump(const Duration(milliseconds: 150));
  await _pumpDocumentFrame(tester);
}

Future<void> _releaseTextInputAction(WidgetTester tester) async {
  await tester.pump(_textInputActionIgnoreTestWindow);
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  } finally {
    debugDefaultTargetPlatformOverride = previousPlatform;
  }
}
