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

  testWidgets('RhwpNativeEditor converts documents to editable on load', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 640,
          height: 520,
          child: RhwpNativeEditor(document: document),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(session.convertToEditableCalls, 1);
    expect(session.commands, isNot(contains('{"type":"convertToEditable"}')));
  });

  testWidgets('RhwpNativeEditor can keep distribution state on load', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 640,
          height: 520,
          child: RhwpNativeEditor(
            document: document,
            convertToEditableOnLoad: false,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(session.convertToEditableCalls, 0);
  });

  testWidgets('RhwpViewer uses upstream-style zoom presets', (tester) async {
    final controller = RhwpViewerController(zoom: 1.1);

    expect(controller.zoom, 1.1);

    controller.zoomIn();
    expect(controller.zoom, 1.25);

    controller.zoom = 1.5;
    controller.zoomIn();
    expect(controller.zoom, 2.0);

    controller.zoomIn();
    expect(controller.zoom, 3.0);

    controller.zoomIn();
    expect(controller.zoom, 3.0);

    controller.zoomOut();
    expect(controller.zoom, 2.0);

    controller.zoom = 0.4;
    controller.zoomOut();
    expect(controller.zoom, 0.25);

    controller.zoom = 9.0;
    expect(controller.zoom, 3.0);

    controller.fitWidth();
    expect(controller.zoom, 1.0);

    controller.fitPage();
    expect(controller.zoom, 0.75);
  });

  testWidgets('RhwpViewer fit page uses the current viewport height', (
    tester,
  ) async {
    final controller = RhwpViewerController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 400,
          height: 420,
          child: RhwpViewer(
            document: document,
            controller: controller,
            padding: const EdgeInsets.all(8),
            pageGap: 0,
            svgBuilder: _tallSvgBuilder,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    controller.fitPage();
    await tester.pump();

    expect(controller.zoom, closeTo(404 / 816, 0.01));
    expect(session.renderedPages, [0]);
  });

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

  testWidgets('RhwpViewer updates current page from visible scroll position', (
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

    expect(controller.currentPage, 0);

    final verticalScrollable = find.byType(Scrollable).last;
    await tester.drag(verticalScrollable, const Offset(0, -900));
    await _pumpDocumentFrame(tester);

    expect(controller.currentPage, greaterThan(0));
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

  testWidgets('RhwpViewer can refresh only selected pages', (tester) async {
    final session = _FakeRhwpSession(pageCountValue: 8);
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

    session.renderedPages.clear();
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
            renderRevision: 1,
            renderPages: const {1},
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);
    expect(session.renderedPages, [1]);

    session.renderedPages.clear();
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
            renderRevision: 2,
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);
    expect(session.renderedPages, [0, 1]);
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
    expect(
      find.byKey(const ValueKey('rhwp-page-overlay-repaint-boundary')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('rhwp-page-overlay-repaint-boundary')),
      findsOneWidget,
    );
  });

  testWidgets('RhwpViewer keeps SVG widget cached across dependency churn', (
    tester,
  ) async {
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var viewInsetBottom = 0.0;
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
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: viewInsetBottom)),
              child: SizedBox(
                width: 360,
                height: 320,
                child: RhwpViewer(
                  document: document,
                  padding: const EdgeInsets.all(12),
                  pageGap: 0,
                  svgBuilder: svgBuilder,
                ),
              ),
            );
          },
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    expect(svgBuildCount, 1);
    expect(session.renderedPages, [0]);

    updateHarness!(() {
      viewInsetBottom = 24.0;
    });
    await tester.pump();

    expect(svgBuildCount, 1);
    expect(session.renderedPages, [0]);
    expect(find.byKey(const ValueKey('rhwp-cached-svg-page')), findsOneWidget);
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

  testWidgets('RhwpNativeEditor insert ribbon edits footnote text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..footnoteExists = true
      ..footnoteText = 'Old footnote';
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

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 3);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-edit-footnote-text')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-edit-footnote-text')),
    );
    await tester.pumpAndSettle();

    expect(find.text('각주 1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-footnote-text-field')),
          )
          .controller
          ?.text,
      'Old footnote',
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-footnote-text-field')),
      'New footnote',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-footnote-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.footnoteText, 'New footnote');
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getFootnoteAtCursor',
        'section': 0,
        'paragraph': 0,
        'offset': 3,
        'direction': 'backward',
      },
      {
        'type': 'getFootnoteInfo',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 1,
      },
      {
        'type': 'deleteTextInFootnote',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 1,
        'footnoteParagraph': 0,
        'offset': 0,
        'count': 12,
      },
      {
        'type': 'insertTextInFootnote',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 1,
        'footnoteParagraph': 0,
        'offset': 0,
        'text': 'New footnote',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor insert ribbon deletes footnotes', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..footnoteExists = true
      ..footnoteText = 'Old footnote';
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

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 3);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-delete-footnote')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-delete-footnote')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.footnoteExists, isFalse);
    expect(session.footnoteText, isEmpty);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 0, offset: 2),
    );
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'getFootnoteAtCursor',
        'section': 0,
        'paragraph': 0,
        'offset': 3,
        'direction': 'backward',
      },
      {
        'type': 'deleteFootnote',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 1,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor insert ribbon adds a blank paragraph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 1000,
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
      find.byKey(const ValueKey('rhwp-editor-insert-paragraph')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-paragraph')),
    );
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'insertParagraph',
      'section': 0,
      'paragraph': 1,
    });
  });

  testWidgets('RhwpNativeEditor edit ribbon deletes the current paragraph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 1000,
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

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 3);
    await tester.pump();

    await tester.tap(find.text('편집'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-delete-paragraph')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-delete-paragraph')),
    );
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteParagraph',
      'section': 0,
      'paragraph': 1,
    });
  });

  testWidgets('RhwpNativeEditor insert ribbon adds a bookmark', (tester) async {
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
      find.byKey(const ValueKey('rhwp-editor-bookmark')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-bookmark')));
    await tester.pumpAndSettle();

    expect(find.text('intro'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-bookmark-name-field')),
      'chapter-start',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-add')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getBookmarks'},
      {
        'type': 'addBookmark',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'name': 'chapter-start',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor insert ribbon renames a bookmark', (
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-bookmark')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-bookmark')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-intro')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-bookmark-name-field')),
          )
          .controller
          ?.text,
      'intro',
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-bookmark-name-field')),
      'intro-renamed',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-rename')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getBookmarks'},
      {
        'type': 'renameBookmark',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 2,
        'name': 'intro-renamed',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor insert ribbon deletes a bookmark', (
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-bookmark')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-bookmark')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-intro')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-delete')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getBookmarks'},
      {
        'type': 'deleteBookmark',
        'section': 0,
        'paragraph': 0,
        'controlIndex': 2,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor insert ribbon jumps to a bookmark', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 8)
      ..bookmarksJson =
          '[{"name":"chapter","sec":0,"para":5,"ctrlIdx":2,"charPos":3}]';
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-bookmark')),
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-bookmark')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-chapter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-go-to')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 0);
    expect(session.historyCommands, isEmpty);
    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 5, offset: 3),
    );
    expect(controller.currentPage, 5);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getBookmarks'},
      {'type': 'getPageOfPosition', 'section': 0, 'paragraph': 5},
    ]);
  });

  testWidgets('RhwpNativeEditor tools ribbon edits field values', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 1100,
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-fields')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-fields')));
    await tester.pumpAndSettle();

    expect(find.text('customer'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-value-field')),
      'New value',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-field-update')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getFieldList'},
      {'type': 'setFieldValue', 'fieldId': 7, 'value': 'New value'},
    ]);
  });

  testWidgets('RhwpNativeEditor tools ribbon edits field properties', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 1100,
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

    await tester.tap(find.text('도구'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-field-properties')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-field-properties')),
    );
    await tester.pumpAndSettle();

    expect(find.text('누름틀 속성'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-guide-field')),
      '새 안내문',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-memo-field')),
      '새 메모',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-name-field')),
      'customer2',
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-field-props-editable-field')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-field-props-update')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getFieldInfoAt', 'section': 0, 'paragraph': 0, 'offset': 2},
      {'type': 'getClickHereProperties', 'fieldId': 7},
      {
        'type': 'updateClickHereProperties',
        'fieldId': 7,
        'guide': '새 안내문',
        'memo': '새 메모',
        'name': 'customer2',
        'editable': false,
      },
    ]);
  });

  testWidgets(
    'RhwpNativeEditor tools ribbon activates and clears field state',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final document = RhwpDocument.fromSession(session);
      var changedCalls = 0;

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 1100,
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

      await tester.tap(find.text('도구'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('rhwp-editor-activate-field')),
      );
      await tester.pump();

      session.renderedPages.clear();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-activate-field')),
      );
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 0);
      expect(session.historyCommands, isEmpty);
      expect(session.renderedPages, [0]);
      expect(session.commands.map(jsonDecode).toList(), [
        {'type': 'setActiveField', 'section': 0, 'paragraph': 0, 'offset': 2},
      ]);

      session.renderedPages.clear();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-clear-active-field')),
      );
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 0);
      expect(session.historyCommands, isEmpty);
      expect(session.renderedPages, [0]);
      expect(session.commands.map(jsonDecode).toList(), [
        {'type': 'setActiveField', 'section': 0, 'paragraph': 0, 'offset': 2},
        {'type': 'clearActiveField'},
      ]);
    },
  );

  testWidgets('RhwpNativeEditor tools ribbon removes field at cursor', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 1100,
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

    await tester.tap(find.text('도구'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-remove-field')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-remove-field')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'removeFieldAt', 'section': 0, 'paragraph': 0, 'offset': 2},
    ]);
  });

  testWidgets('RhwpNativeEditor inserts page and column breaks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-insert-column-break')),
    );
    await tester.pump();
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

  testWidgets('RhwpNativeEditor inserts a picture with shortcut', (
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
              bytes: Uint8List.fromList([4, 5, 6]),
              extension: 'jpg',
              width: 1200,
              height: 800,
              naturalWidthPx: 120,
              naturalHeightPx: 80,
              description: 'shortcut.jpg',
            ),
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

    controller.cursor = const RhwpCursorPosition(paragraph: 0, offset: 2);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 2));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertPicture',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'imageData': [4, 5, 6],
      'width': 1200,
      'height': 800,
      'naturalWidthPx': 120,
      'naturalHeightPx': 80,
      'extension': 'jpg',
      'description': 'shortcut.jpg',
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

  testWidgets('RhwpNativeEditor inserts shape presets with shortcuts', (
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    Future<void> sendShapeShortcut(LogicalKeyboardKey key, int offset) async {
      controller.cursor = RhwpCursorPosition(paragraph: 0, offset: offset);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);
    }

    await sendShapeShortcut(LogicalKeyboardKey.keyR, 2);
    await sendShapeShortcut(LogicalKeyboardKey.keyO, 10);
    await sendShapeShortcut(LogicalKeyboardKey.keyL, 18);
    await sendShapeShortcut(LogicalKeyboardKey.keyX, 26);

    expect(changedCalls, 4);
    expect(controller.cursor, const RhwpCursorPosition(offset: 34));
    expect(session.commands.map(jsonDecode).toList(), [
      {
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
      },
      {
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
      },
      {
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
      },
      {
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
      },
    ]);
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

  testWidgets('RhwpNativeEditor status bar tracks current page', (
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

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 1 / 8',
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('rhwp-editor-status-previous-page')),
          )
          .onPressed,
      isNull,
    );

    final scroll = controller.goToPage(5);
    await tester.pumpAndSettle();
    await scroll;
    await _pumpDocumentFrame(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 6 / 8',
    );

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-status-previous-page')),
    );
    await tester.pumpAndSettle();
    await _pumpDocumentFrame(tester);

    expect(controller.currentPage, 4);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 5 / 8',
    );

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-status-next-page')),
    );
    await tester.pumpAndSettle();
    await _pumpDocumentFrame(tester);

    expect(controller.currentPage, 5);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 6 / 8',
    );

    final lastPageScroll = controller.goToPage(7);
    await tester.pumpAndSettle();
    await lastPageScroll;
    await _pumpDocumentFrame(tester);

    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('rhwp-editor-status-next-page')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('RhwpNativeEditor status position restores editor focus', (
    tester,
  ) async {
    final externalFocusNode = FocusNode();
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);

    try {
      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 480,
            child: Column(
              children: [
                SizedBox(
                  width: 720,
                  height: 420,
                  child: RhwpNativeEditor(
                    document: document,
                    controller: controller,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const ValueKey('external-focus-field'),
                    focusNode: externalFocusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await _pumpDocumentFrame(tester);

      await tester.tap(find.byKey(const ValueKey('external-focus-field')));
      await tester.pump();

      expect(externalFocusNode.hasFocus, isTrue);

      controller.cursor = const RhwpCursorPosition(offset: 2);
      session.commands.clear();

      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-status-position')),
      );
      await tester.pump();

      expect(externalFocusNode.hasFocus, isFalse);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Q',
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
        'text': 'Q',
      });
    } finally {
      externalFocusNode.dispose();
    }
  });

  testWidgets('RhwpNativeEditor jumps to cursor from position fields', (
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

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-section-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-paragraph-field')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-offset-field')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-go-to-position')));
    await tester.pumpAndSettle();
    await _pumpDocumentFrame(tester);

    expect(
      controller.cursor,
      const RhwpCursorPosition(paragraph: 4, offset: 9),
    );
    expect(controller.currentPage, 4);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 5 / 8',
    );
    expect(jsonDecode(session.commands.single), {
      'type': 'getPageOfPosition',
      'section': 0,
      'paragraph': 4,
    });
  });

  testWidgets('RhwpNativeEditor jumps to page from view ribbon and shortcut', (
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

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-go-to-page')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-go-to-page')));
    await tester.pump();

    expect(find.text('Go to page'), findsOneWidget);
    expect(find.text('Page 1 - 8'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-go-to-page-field')),
      '6',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-go-to-page-apply')));
    await tester.pumpAndSettle();

    expect(controller.currentPage, 5);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 6 / 8',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-go-to-page-field')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-go-to-page-apply')));
    await tester.pumpAndSettle();

    expect(controller.currentPage, 1);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 2 / 8',
    );

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-status-page')));
    await tester.pump();

    expect(find.text('Go to page'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-go-to-page-field')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-go-to-page-apply')));
    await tester.pumpAndSettle();

    expect(controller.currentPage, 6);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-page')))
          .data,
      'Page 7 / 8',
    );
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(exported.last.fileName, 'sample.hwp');
    expect(session.exportHwpCalls, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(exported.last.fileName, 'sample.hwpx');
    expect(session.exportHwpxCalls, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(exported.last.fileName, 'sample.pdf');
    expect(session.exportPdfCalls, 2);
  });

  testWidgets('RhwpNativeEditor file ribbon renames document file', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    final exported = <RhwpExportedDocument>[];
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
            onExported: (document) => exported.add(document),
          ),
        ),
      ),
    );
    await _pumpDocumentFrame(tester);

    await tester.tap(find.text('파일'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-rename-file')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('rhwp-file-name-field')))
          .controller
          ?.text,
      'sample.hwp',
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-file-name-field')),
      'renamed-document.hwp',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-file-name-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.fileName, 'renamed-document.hwp');
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {'type': 'setFileName', 'name': 'renamed-document.hwp'},
    ]);

    session.commands.clear();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-save-hwp')));
    await _pumpDocumentFrame(tester);

    expect(exported.single.fileName, 'renamed-document.hwp');
    expect(session.exportHwpCalls, 1);
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(openRequests, 2);
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

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-toolbar-zoom-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-zoom-preset-150')));
    await tester.pumpAndSettle();

    expect(controller.zoom, 1.5);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom')))
          .data,
      '150%',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-fit-width')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-fit-width')));
    await tester.pump();

    expect(controller.zoom, 1.0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom')))
          .data,
      '100%',
    );

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-status-zoom-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-zoom-preset-75')));
    await tester.pumpAndSettle();

    expect(controller.zoom, 0.75);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '75%',
    );

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-status-zoom-out')));
    await tester.pump();

    expect(controller.zoom, 0.5);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      '50%',
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

    controller.zoom = 1.5;
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-status-fit-width')),
    );
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
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-fit-page')));
    await tester.pump();

    expect(controller.zoom, lessThan(1.5));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-status-zoom')))
          .data,
      isNot('150%'),
    );

    controller.zoom = 1.0;
    await tester.pump();

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
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom-in')));
    await tester.pump();

    expect(controller.zoom, 2.0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rhwp-editor-toolbar-zoom')))
          .data,
      '200%',
    );

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

  testWidgets('RhwpNativeEditor view ribbon toggles the native ruler', (
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

    expect(find.byKey(const ValueKey('rhwp-editor-ruler')), findsNothing);

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toggle-ruler')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toggle-ruler')));
    await tester.pump();

    expect(find.byKey(const ValueKey('rhwp-editor-ruler')), findsOneWidget);
    expect(changedCalls, 0);
    expect(session.commands, isEmpty);

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toggle-ruler')));
    await tester.pump();

    expect(find.byKey(const ValueKey('rhwp-editor-ruler')), findsNothing);
    expect(changedCalls, 0);
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor ruler reflects current paragraph metrics', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..paraPropertiesJson =
          '{"alignment":"justify","lineSpacing":160.0,"lineSpacingType":"Percent","marginLeft":2000.0,"marginRight":1500.0,"indent":1000.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":0}';
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

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toggle-ruler')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toggle-ruler')));
    await tester.pump();

    final leftMarginFinder = find.byKey(
      const ValueKey('rhwp-editor-ruler-left-margin'),
    );
    final firstLineFinder = find.byKey(
      const ValueKey('rhwp-editor-ruler-first-line-indent'),
    );
    final rightMarginFinder = find.byKey(
      const ValueKey('rhwp-editor-ruler-right-margin'),
    );

    expect(leftMarginFinder, findsOneWidget);
    expect(firstLineFinder, findsOneWidget);
    expect(rightMarginFinder, findsOneWidget);

    final leftMarginX = tester.getCenter(leftMarginFinder).dx;
    final firstLineX = tester.getCenter(firstLineFinder).dx;
    final rightMarginX = tester.getCenter(rightMarginFinder).dx;

    expect(leftMarginX, greaterThan(36));
    expect(firstLineX, greaterThan(leftMarginX));
    expect(rightMarginX, greaterThan(firstLineX));

    controller.zoomIn();
    await tester.pump();

    expect(tester.getCenter(leftMarginFinder).dx, greaterThan(leftMarginX));
    expect(tester.getCenter(firstLineFinder).dx, greaterThan(firstLineX));
    expect(tester.getCenter(rightMarginFinder).dx, lessThan(rightMarginX));
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor ruler drags paragraph markers', (tester) async {
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

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toggle-ruler')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toggle-ruler')));
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('rhwp-editor-ruler-left-margin')),
      const Offset(56, 0),
    );
    await _pumpDocumentFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('rhwp-editor-ruler-first-line-indent')),
      const Offset(38, 0),
    );
    await _pumpDocumentFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('rhwp-editor-ruler-right-margin')),
      const Offset(-38, 0),
    );
    await _pumpDocumentFrame(tester);

    expect(session.commands.map(jsonDecode), [
      {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 0,
        'endParagraph': 0,
        'properties': {'marginLeft': 2000},
      },
      {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 0,
        'endParagraph': 0,
        'properties': {'indent': 1000},
      },
      {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 0,
        'endParagraph': 0,
        'properties': {'marginRight': 1000},
      },
    ]);
    expect(changedCalls, 3);
  });

  testWidgets('RhwpNativeEditor ruler opens paragraph shape dialog', (
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

    await tester.tap(find.text('보기'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-toggle-ruler')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-toggle-ruler')));
    await tester.pump();

    final rulerFinder = find.byKey(const ValueKey('rhwp-editor-ruler'));
    final rulerTopLeft = tester.getTopLeft(rulerFinder);
    await tester.tapAt(rulerTopLeft + const Offset(260, 14));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(rulerTopLeft + const Offset(260, 14));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
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

  testWidgets('RhwpNativeEditor page ribbon clears header and footer text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..headerFooterExists = true
      ..footerExists = true
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
      find.byKey(const ValueKey('rhwp-editor-clear-header-text')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.headerFooterText, isEmpty);
    expect(session.commands.map(jsonDecode), [
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
    ]);

    session.commands.clear();
    session.headerFooterText = 'Old Footer';

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-clear-footer-text')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(session.headerFooterText, isEmpty);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'getHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
      },
      {
        'type': 'deleteTextInHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'count': 10,
      },
    ]);
  });

  testWidgets('RhwpNativeEditor page ribbon deletes header footer controls', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..headerFooterExists = true
      ..footerExists = true;
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
      find.byKey(const ValueKey('rhwp-editor-header-footer-list')),
    );
    await tester.pumpAndSettle();

    expect(jsonDecode(session.commands.single), {
      'type': 'getHeaderFooterList',
      'section': 0,
      'isHeader': true,
      'applyTo': 0,
    });

    await tester.tap(
      find.byKey(const ValueKey('rhwp-header-footer-item-0-false-0')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-header-footer-delete')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.footerExists, isFalse);
    expect(jsonDecode(session.commands.last), {
      'type': 'deleteHeaderFooter',
      'section': 0,
      'isHeader': false,
      'applyTo': 0,
    });
  });

  testWidgets('RhwpNativeEditor manager edits selected header footer text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..headerFooterExists = true
      ..footerExists = true
      ..headerFooterText = 'Old Footer';
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
      find.byKey(const ValueKey('rhwp-editor-header-footer-list')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('rhwp-header-footer-item-0-false-0')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-header-footer-edit-text')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-header-footer-text-field')),
          )
          .controller
          ?.text,
      'Old Footer',
    );

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-header-footer-text-field')),
      'Footer From Manager',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-header-footer-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.headerFooterText, 'Footer From Manager');
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'getHeaderFooterList',
        'section': 0,
        'isHeader': true,
        'applyTo': 0,
      },
      {
        'type': 'getHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
      },
      {
        'type': 'getHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
      },
      {
        'type': 'deleteTextInHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'count': 10,
      },
      {
        'type': 'insertTextInHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
        'paragraph': 0,
        'offset': 0,
        'text': 'Footer From Manager',
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

  testWidgets('RhwpNativeEditor page ribbon applies page hide options', (
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

    controller.cursor = const RhwpCursorPosition(paragraph: 2);
    await tester.pump();

    await tester.tap(find.text('쪽'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-page-hide')));
    await tester.pumpAndSettle();

    expect(jsonDecode(session.commands.single), {
      'type': 'getPageHide',
      'section': 0,
      'paragraph': 2,
    });

    await tester.tap(find.byKey(const ValueKey('rhwp-page-hide-header')));
    await tester.tap(find.byKey(const ValueKey('rhwp-page-hide-border')));
    await tester.tap(find.byKey(const ValueKey('rhwp-page-hide-page-number')));
    await tester.tap(find.byKey(const ValueKey('rhwp-page-hide-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.last), {
      'type': 'setPageHide',
      'section': 0,
      'paragraph': 2,
      'hideHeader': true,
      'hideFooter': false,
      'hideMasterPage': false,
      'hideBorder': true,
      'hideFill': false,
      'hidePageNum': true,
    });
  });

  testWidgets('RhwpNativeEditor opens page setup with F7 shortcut', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await tester.pumpAndSettle();

    expect(find.text('쪽 설정'), findsOneWidget);
    expect(jsonDecode(session.commands.single), {
      'type': 'getPageSetup',
      'section': 0,
    });
    expect(changedCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(changedCalls, 0);
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

  testWidgets('RhwpNativeEditor inserts a table with shortcut', (tester) async {
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
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

  testWidgets('RhwpNativeEditor toolbar inserts an inline table', (
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
      find.byKey(const ValueKey('rhwp-editor-insert-table-inline')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-insert-table-inline')),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-table-column-widths')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-table-column-widths')),
      '2000, 2100',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-insert-table')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 10));
    expect(jsonDecode(session.commands.single), {
      'type': 'createTableEx',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'rows': 2,
      'columns': 2,
      'treatAsChar': true,
      'columnWidths': [2000, 2100],
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
      'rhwp-editor-insert-row-above',
      'rhwp-editor-insert-row-below',
      'rhwp-editor-insert-column-left',
      'rhwp-editor-insert-column-right',
      'rhwp-editor-delete-table-row',
      'rhwp-editor-delete-table-column',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(key)));
      await _pumpDocumentFrame(tester);
    }

    expect(changedCalls, 7);
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
        'below': false,
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
        'right': false,
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

  testWidgets('RhwpNativeEditor splits a selected table cell into a grid', (
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
      find.byKey(const ValueKey('rhwp-editor-split-cell-into')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-split-cell-into')));
    await tester.pumpAndSettle();

    expect(find.text('셀 나누기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-split-cell-rows-field')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-split-cell-columns-field')),
      '2',
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-split-cell-equal-height')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-split-cell-merge-first')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-split-cell-confirm')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'splitTableCellInto',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'row': 1,
      'column': 3,
      'rows': 3,
      'columns': 2,
      'equalRowHeight': false,
      'mergeFirst': true,
    });
  });

  testWidgets('RhwpNativeEditor splits selected table cell range into a grid', (
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

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 4,
      activeCellIndex: 7,
    );
    await tester.pump();

    await tester.tap(find.text('표'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-split-cell-into')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-split-cell-into')));
    await tester.pumpAndSettle();

    expect(find.text('셀 나누기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-split-cell-rows-field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-split-cell-columns-field')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-split-cell-confirm')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'splitTableCellsInRange',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'startRow': 1,
      'startColumn': 3,
      'endRow': 2,
      'endColumn': 4,
      'rows': 2,
      'columns': 3,
      'equalRowHeight': true,
    });
  });

  testWidgets('RhwpNativeEditor edits table properties from table ribbon', (
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
      find.byKey(const ValueKey('rhwp-editor-table-properties')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-table-properties')),
    );
    await tester.pumpAndSettle();

    expect(find.text('표 속성'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-table-cell-spacing-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-table-padding-left-field')),
      '210',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-table-padding-right-field')),
      '220',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-table-padding-top-field')),
      '230',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-table-padding-bottom-field')),
      '240',
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-table-repeat-header-field')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-table-properties-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'getTableProperties',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
      },
      {
        'type': 'setTableProperties',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'properties': {
          'cellSpacing': 20,
          'paddingLeft': 210,
          'paddingRight': 220,
          'paddingTop': 230,
          'paddingBottom': 240,
          'pageBreak': 1,
          'repeatHeader': true,
        },
      },
    ]);
  });

  testWidgets(
    'RhwpNativeEditor edits selected cell properties from table ribbon',
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

      await tester.tap(find.text('표'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('rhwp-editor-cell-properties')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-cell-properties')),
      );
      await tester.pumpAndSettle();

      expect(find.text('셀 속성'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-width-field')),
        '6000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-height-field')),
        '3200',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-padding-left-field')),
        '210',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-padding-right-field')),
        '220',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-padding-top-field')),
        '230',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-padding-bottom-field')),
        '240',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-text-direction-field')),
        '1',
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-cell-is-header-field')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rhwp-cell-protect-field')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-cell-properties-apply')),
      );
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'getCellProperties',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
        },
        {
          'type': 'setCellProperties',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'properties': {
            'width': 6000,
            'height': 3200,
            'paddingLeft': 210,
            'paddingRight': 220,
            'paddingTop': 230,
            'paddingBottom': 240,
            'verticalAlign': 1,
            'textDirection': 1,
            'isHeader': true,
            'cellProtect': true,
          },
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor resizes selected table cells from cell properties',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 4,
        activeCellIndex: 7,
      );
      await tester.pump();

      await tester.tap(find.text('표'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('rhwp-editor-cell-properties')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-cell-properties')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-width-field')),
        '5300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-cell-height-field')),
        '2800',
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-cell-properties-apply')),
      );
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'getCellProperties',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
        },
        {
          'type': 'resizeTableCells',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'updates': [
            {'cellIdx': 7, 'widthDelta': 300, 'heightDelta': -200},
            {'cellIdx': 8, 'widthDelta': 300, 'heightDelta': -200},
          ],
        },
        {
          'type': 'setCellProperties',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'properties': {
            'paddingLeft': 100,
            'paddingRight': 110,
            'paddingTop': 120,
            'paddingBottom': 130,
            'verticalAlign': 1,
            'textDirection': 0,
            'isHeader': false,
            'cellProtect': false,
          },
        },
      ]);
    },
  );

  testWidgets('RhwpNativeEditor evaluates table formulas from table ribbon', (
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

    await tester.tap(find.text('표'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-table-formula-field')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-table-formula-field')),
      '=SUM(A1:B1)',
    );
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-evaluate-table-formula')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'evaluateTableFormula',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'row': 1,
        'column': 3,
        'formula': '=SUM(A1:B1)',
        'writeResult': true,
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

  testWidgets('RhwpNativeEditor drags table cell text to select a range', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'cell'),
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    Offset pagePoint(double x, double y) {
      return pageTopLeft +
          Offset(pageSize.width * x / 240, pageSize.height * y / 180);
    }

    final drag = await tester.startGesture(pagePoint(106, 73));
    await tester.pump();
    await drag.moveTo(pagePoint(126, 73));
    await tester.pump();
    await drag.up();
    await tester.pump();

    final selection = controller.tableCellSelection;
    expect(selection?.activeCellIndex, 7);
    expect(selection?.activeCellParagraph, 0);
    expect(selection?.activeOffset, 3);
    expect(selection?.selectionBaseCellParagraph, 0);
    expect(selection?.selectionBaseOffset, 1);
    expect(selection?.hasTextSelection, isTrue);
    expect(controller.selection.isCollapsed, isTrue);
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
      findsOneWidget,
    );
  });

  testWidgets('RhwpNativeEditor shift-clicks table cell text to extend range', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'cell'),
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

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 3,
      activeCellIndex: 7,
      activeOffset: 1,
      isTextEditing: true,
    );
    await tester.pump();

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final targetPoint =
        pageTopLeft +
        Offset(pageSize.width * 126 / 240, pageSize.height * 73 / 180);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(targetPoint);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final selection = controller.tableCellSelection;
    expect(selection?.activeCellIndex, 7);
    expect(selection?.activeCellParagraph, 0);
    expect(selection?.activeOffset, 3);
    expect(selection?.selectionBaseCellParagraph, 0);
    expect(selection?.selectionBaseOffset, 1);
    expect(selection?.hasTextSelection, isTrue);
    expect(controller.selection.isCollapsed, isTrue);
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
      findsOneWidget,
    );
    expect(session.commands, isEmpty);
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

  testWidgets('RhwpNativeEditor tabs between table cells while editing text', (
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
    Offset pagePoint(double x, double y) {
      return pageTopLeft +
          Offset(pageSize.width * x / 240, pageSize.height * y / 180);
    }

    await tester.tapAt(pagePoint(100, 60));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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
        isTextEditing: true,
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
        isTextEditing: true,
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
        isTextEditing: true,
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

  testWidgets(
    'RhwpNativeEditor splits and merges table cell paragraphs with keys',
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

      expect(controller.tableCellSelection?.activeOffset, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
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
          activeCellParagraph: 1,
          activeOffset: 0,
          isTextEditing: true,
        ),
      );
      expect(jsonDecode(session.commands.single), {
        'type': 'splitParagraphInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 2,
      });

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 2);
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
          activeOffset: 2,
          isTextEditing: true,
        ),
      );
      expect(jsonDecode(session.commands.last), {
        'type': 'mergeParagraphInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 1,
      });

      session.commands.clear();
      session.historyCommands.clear();
      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 4,
        isTextEditing: true,
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 3);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
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
          activeOffset: 2,
          isTextEditing: true,
        ),
      );
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'getCellParagraphCount',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
        },
        {
          'type': 'mergeParagraphInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor moves table cell cursor by word with keyboard modifiers',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello world',
          secondCellParagraphText: 'tail',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
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
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 5);
      expect(session.commands, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 6);
      expect(session.commands, isEmpty);

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeOffset: 11,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 0);
      expect(session.commands.map((json) => jsonDecode(json)['type']), [
        'getCellParagraphCount',
      ]);

      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 6);
      expect(session.commands, isEmpty);
    },
  );

  testWidgets('RhwpNativeEditor moves table cell cursor with arrow keys', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(
        cellText: 'cell',
        secondCellParagraphText: 'tail',
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

    controller.tableCellSelection = const RhwpTableCellSelection(
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
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 1);
    expect(session.commands, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 2);
    expect(session.commands, isEmpty);

    controller.tableCellSelection = controller.tableCellSelection?.copyWith(
      activeOffset: 4,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 1);
    expect(controller.tableCellSelection?.activeOffset, 0);
    expect(session.commands.map((json) => jsonDecode(json)['type']), [
      'getCellParagraphCount',
    ]);

    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 4);
    expect(session.commands, isEmpty);
  });

  testWidgets(
    'RhwpNativeEditor extends table cell text selection with shift arrows',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'cell'),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
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
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _pumpDocumentFrame(tester);

      final extendedSelection = controller.tableCellSelection;
      expect(extendedSelection?.activeCellParagraph, 0);
      expect(extendedSelection?.activeOffset, 1);
      expect(extendedSelection?.selectionBaseCellParagraph, 0);
      expect(extendedSelection?.selectionBaseOffset, 2);
      expect(extendedSelection?.hasTextSelection, isTrue);
      expect(session.commands, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _pumpDocumentFrame(tester);

      final collapsedSelection = controller.tableCellSelection;
      expect(collapsedSelection?.activeCellParagraph, 0);
      expect(collapsedSelection?.activeOffset, 0);
      expect(collapsedSelection?.selectionBaseCellParagraph, isNull);
      expect(collapsedSelection?.selectionBaseOffset, isNull);
      expect(collapsedSelection?.hasTextSelection, isFalse);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsNothing,
      );
    },
  );

  testWidgets('RhwpNativeEditor deletes selected table cell text', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(
        cellText: 'cell',
        secondCellParagraphText: 'tail',
      ),
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

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 3,
      activeCellIndex: 7,
      activeOffset: 1,
      isTextEditing: true,
      selectionBaseCellParagraph: 0,
      selectionBaseOffset: 3,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 1);
    expect(controller.tableCellSelection?.hasTextSelection, isFalse);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteTextInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'cellParagraph': 0,
      'offset': 1,
      'count': 2,
    });

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 3,
      activeCellIndex: 7,
      activeCellParagraph: 1,
      activeOffset: 2,
      isTextEditing: true,
      selectionBaseCellParagraph: 0,
      selectionBaseOffset: 4,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 4);
    expect(controller.tableCellSelection?.hasTextSelection, isFalse);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteRangeInTableCell',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
      'cellIndex': 7,
      'startCellParagraph': 0,
      'startOffset': 4,
      'endCellParagraph': 1,
      'endOffset': 2,
    });
  });

  testWidgets(
    'RhwpNativeEditor previews multi paragraph table cell delete while deleteRange is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
      );
      final deleteRangeGate = Completer<void>();
      session.commandGates['deleteRangeInTableCell'] = deleteRangeGate;
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 4,
      );
      await tester.pump();
      session.renderedPages.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 4);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'deleteRangeInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 4,
          'endCellParagraph': 1,
          'endOffset': 2,
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask-1')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask-1')),
        findsOneWidget,
      );

      deleteRangeGate.complete();
      await tester.pump();
      await tester.pump();
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets(
    'RhwpNativeEditor copies and cuts selected table cell text range',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      var clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'ell');
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 1,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
      ]);

      session.commands.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'ell');
      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 1,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
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
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor previews table cell text cut while delete is pending',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
      final deleteGate = Completer<void>();
      session.commandGates['deleteTextInTableCell'] = deleteGate;
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();
      session.commands.clear();
      session.renderedPages.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'ell');
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 1,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
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
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      deleteGate.complete();
      await tester.pump();
      await tester.pump();
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets(
    'RhwpNativeEditor copies multi paragraph selected table cell text range',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
      );
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

      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
            const Offset(1, 6),
      );
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 4,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'o\nta');
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 4,
          'endCellParagraph': 1,
          'endOffset': 2,
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor previews multi paragraph table cell cut while deleteRange is pending',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
      );
      final deleteRangeGate = Completer<void>();
      session.commandGates['deleteRangeInTableCell'] = deleteRangeGate;
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 4,
      );
      await tester.pump();
      session.commands.clear();
      session.renderedPages.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'o\nta');
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 4);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 4,
          'endCellParagraph': 1,
          'endOffset': 2,
        },
        {
          'type': 'deleteRangeInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 4,
          'endCellParagraph': 1,
          'endOffset': 2,
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask-1')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask-1')),
        findsOneWidget,
      );

      deleteRangeGate.complete();
      await tester.pump();
      await tester.pump();
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets('RhwpNativeEditor replaces selected table cell text input', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(includeBodyParagraphFive: true),
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 3,
      activeCellIndex: 7,
      activeOffset: 1,
      isTextEditing: true,
      selectionBaseCellParagraph: 0,
      selectionBaseOffset: 3,
    );
    await tester.pump();
    session.commands.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Z',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(changedCalls, 0);
    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 2);
    expect(controller.tableCellSelection?.hasTextSelection, isFalse);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 1,
        'count': 2,
      },
      {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 1,
        'text': 'Z',
      },
    ]);
    expect(
      find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
          )
          .dy,
      greaterThan(pageTopLeft.dy + pageSize.height * 0.3),
    );

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
  });

  testWidgets(
    'RhwpNativeEditor previews selected table cell text replacement while delete is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(includeBodyParagraphFive: true),
      );
      final deleteGate = Completer<void>();
      session.commandGates['deleteTextInTableCell'] = deleteGate;
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
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
            const Offset(1, 6),
      );
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 1,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 3,
      );
      await tester.pump();
      session.commands.clear();
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
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 2);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'deleteTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 1,
          'count': 2,
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
            )
            .dy,
        greaterThan(pageTopLeft.dy + pageSize.height * 0.3),
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text('Z'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      deleteGate.complete();
      await tester.pump();
      await tester.pump();

      expect(session.commands.map(jsonDecode), [
        {
          'type': 'deleteTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 1,
          'count': 2,
        },
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 1,
          'text': 'Z',
        },
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
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
    },
  );

  testWidgets(
    'RhwpNativeEditor moves table cell cursor vertically with arrow keys',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'cell',
          secondCellParagraphText: 'tail',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
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
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 2);
      expect(session.commands, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 2);
      expect(session.commands, isEmpty);

      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'cell'),
      );
      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 3,
        isTextEditing: true,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 3);
      expect(session.commands.map((json) => jsonDecode(json)['type']), [
        'getCellParagraphCount',
        'getCellParagraphLength',
      ]);
    },
  );

  testWidgets('RhwpNativeEditor moves table cell text cursor with page keys', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 3);
    session.pageLayerTreeJsonByPage[0] = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'cell'),
    );
    session.pageLayerTreeJsonByPage[1] = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'cell'),
    );
    session.pageLayerTreeJsonByPage[2] = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'hi'),
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

    controller.tableCellSelection = const RhwpTableCellSelection(
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
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await _pumpDocumentFrame(tester);

    expect(controller.currentPage, 1);
    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 2);
    expect(controller.tableCellSelection?.hasTextSelection, isFalse);
    expect(session.commands, isEmpty);

    controller.tableCellSelection = controller.tableCellSelection?.copyWith(
      activeOffset: 4,
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    final selection = controller.tableCellSelection;
    expect(controller.currentPage, 2);
    expect(selection?.activeCellParagraph, 0);
    expect(selection?.activeOffset, 2);
    expect(selection?.selectionBaseCellParagraph, 0);
    expect(selection?.selectionBaseOffset, 4);
    expect(selection?.hasTextSelection, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await _pumpDocumentFrame(tester);

    expect(controller.currentPage, 1);
    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 2);
    expect(controller.tableCellSelection?.hasTextSelection, isFalse);
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor moves table cell cursor with home and end', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(cellText: 'hello world'),
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

    controller.tableCellSelection = const RhwpTableCellSelection(
      section: 0,
      paragraph: 5,
      controlIndex: 2,
      startRow: 1,
      startColumn: 3,
      endRow: 2,
      endColumn: 3,
      activeCellIndex: 7,
      activeOffset: 5,
      isTextEditing: true,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 0);
    expect(session.commands, isEmpty);

    controller.tableCellSelection = controller.tableCellSelection?.copyWith(
      activeOffset: 3,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 0);
    expect(controller.tableCellSelection?.activeOffset, 11);
    expect(session.commands, isEmpty);

    controller.tableCellSelection = controller.tableCellSelection?.copyWith(
      activeCellParagraph: 1,
      activeOffset: 1,
    );
    await tester.pump();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 1);
    expect(controller.tableCellSelection?.activeOffset, 4);
    expect(session.commands.map((json) => jsonDecode(json)['type']), [
      'getCellParagraphLength',
    ]);

    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection?.activeCellParagraph, 1);
    expect(controller.tableCellSelection?.activeOffset, 0);
    expect(session.commands, isEmpty);
  });

  testWidgets(
    'RhwpNativeEditor moves table cell cursor to cell boundaries with shortcuts',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 3,
        isTextEditing: true,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 4);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map((json) => jsonDecode(json)['type']), [
        'getCellParagraphCount',
      ]);

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeCellParagraph: 1,
        activeOffset: 2,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 0);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands, isEmpty);

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeOffset: 1,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      final selection = controller.tableCellSelection;
      expect(selection?.activeCellParagraph, 1);
      expect(selection?.activeOffset, 4);
      expect(selection?.selectionBaseCellParagraph, 0);
      expect(selection?.selectionBaseOffset, 1);
      expect(selection?.hasTextSelection, isTrue);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );
      expect(session.commands.map((json) => jsonDecode(json)['type']), [
        'getCellParagraphCount',
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor deletes table cell words with keyboard modifiers',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello world',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 8,
        isTextEditing: true,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.activeOffset, 6);
      expect(jsonDecode(session.commands.single), {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 6,
        'count': 2,
      });

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeOffset: 0,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 2);
      expect(controller.tableCellSelection?.activeOffset, 0);
      expect(jsonDecode(session.commands.single), {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'offset': 0,
        'count': 5,
      });

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeCellParagraph: 1,
        activeOffset: 0,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 3);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 6);
      expect(jsonDecode(session.commands.single), {
        'type': 'deleteRangeInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'startCellParagraph': 0,
        'startOffset': 6,
        'endCellParagraph': 1,
        'endOffset': 0,
      });

      controller.tableCellSelection = controller.tableCellSelection?.copyWith(
        activeCellParagraph: 0,
        activeOffset: 11,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 4);
      expect(controller.tableCellSelection?.activeCellParagraph, 0);
      expect(controller.tableCellSelection?.activeOffset, 11);
      expect(session.commands.map((json) => jsonDecode(json)['type']), [
        'getCellParagraphCount',
        'deleteRangeInTableCell',
      ]);
      expect(jsonDecode(session.commands.last), {
        'type': 'deleteRangeInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'startCellParagraph': 0,
        'startOffset': 11,
        'endCellParagraph': 1,
        'endOffset': 0,
      });
    },
  );

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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpDocumentFrame(tester);

    expect(controller.tableCellSelection, isNull);
    expect(
      controller.objectSelection,
      const RhwpObjectSelection(
        page: 0,
        bounds: Rect.fromLTRB(80, 40, 180, 120),
        type: 'table',
        section: 0,
        paragraph: 5,
        controlIndex: 2,
      ),
    );
    expect(session.commands, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNull);
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

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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

  testWidgets(
    'RhwpNativeEditor previews rapid table cell text while insert is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(_tableCellEditorLayerTreeJson());
      final insertGate = Completer<void>();
      session.commandGates['insertTextInTableCell'] = insertGate;
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
      session.renderedPages.clear();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeOffset, 3);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'text': ' ',
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Positioned>(
              find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
            )
            .child,
        isA<RepaintBoundary>(),
      );
      expect(
        tester
            .widget<Positioned>(find.byKey(const ValueKey('rhwp-editor-caret')))
            .child,
        isA<RepaintBoundary>(),
      );
      expect(find.text(' '), findsOneWidget);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeOffset, 4);
      expect(session.commands.length, 1);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text(' A'), findsOneWidget);

      insertGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(session.commands.map(jsonDecode), [
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'text': ' ',
        },
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 3,
          'text': 'A',
        },
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(find.text(' A'), findsOneWidget);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets(
    'RhwpNativeEditor anchors pending table cell text to the cell run',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(includeBodyParagraphFive: true),
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

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      await tester.tapAt(
        pageTopLeft +
            Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180),
      );
      await tester.pump();

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
      expect(session.renderedPages, isEmpty);

      final previewTop = tester
          .getTopLeft(
            find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          )
          .dy;
      expect(previewTop, greaterThan(pageTopLeft.dy + pageSize.height * 0.3));
    },
  );

  testWidgets(
    'RhwpNativeEditor anchors table cell caret and composing preview to the cell run',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(includeBodyParagraphFive: true),
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

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
            const Offset(1, 6),
      );
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final caretTop = tester
          .getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret')))
          .dy;
      expect(caretTop, greaterThan(pageTopLeft.dy + pageSize.height * 0.3));

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ㅎ',
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();

      final composingTop = tester
          .getTopLeft(
            find.byKey(const ValueKey('rhwp-editor-composing-preview')),
          )
          .dy;
      expect(composingTop, greaterThan(pageTopLeft.dy + pageSize.height * 0.3));
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
    session.pageLayerTreeJson = jsonEncode(
      _tableCellEditorLayerTreeJson(includeBodyParagraphFive: true),
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
      tester
          .getTopLeft(
            find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
          )
          .dy,
      greaterThan(pageTopLeft.dy + pageSize.height * 0.3),
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
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 0,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
      ]);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'cell');
      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).skip(1), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 0,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
        {
          'type': 'deleteTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 0,
          'count': 4,
        },
      ]);

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

  testWidgets(
    'RhwpNativeEditor pastes copied table cell text through HTML import',
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

      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
            const Offset(1, 6),
      );
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 0,
        isTextEditing: true,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.activeOffset, 6);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 0,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
        {
          'type': 'pasteHtmlInCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'html':
              '<html><body><!--StartFragment--><p><span>bc</span></p><!--EndFragment--></body></html>',
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor replaces selected table cell text with HTML paste',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 5,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.activeOffset, 5);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionInCellHtml',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'startCellParagraph': 0,
          'startOffset': 1,
          'endCellParagraph': 0,
          'endOffset': 4,
        },
        {
          'type': 'deleteTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 1,
          'count': 4,
        },
        {
          'type': 'pasteHtmlInCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 1,
          'html':
              '<html><body><!--StartFragment--><p><span>bc</span></p><!--EndFragment--></body></html>',
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor pastes multiline text into selected table cell text',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();
      session.commands.clear();

      await Clipboard.setData(const ClipboardData(text: 'A\nB'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(session.commands.map(jsonDecode), [
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
          'text': 'A',
        },
        {
          'type': 'splitParagraphInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
        },
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'offset': 0,
          'text': 'B',
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor previews multiline table cell paste while insert is pending',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
      final insertGate = Completer<void>();
      session.commandGates['insertTextInTableCell'] = insertGate;
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();
      session.commands.clear();
      session.renderedPages.clear();

      await Clipboard.setData(const ClipboardData(text: 'A\nB'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.tableCellSelection?.activeCellParagraph, 1);
      expect(controller.tableCellSelection?.activeOffset, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
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
          'text': 'A',
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
      expect(find.text('A'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      insertGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(session.commands.map(jsonDecode), [
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
          'text': 'A',
        },
        {
          'type': 'splitParagraphInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
        },
        {
          'type': 'insertTextInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'offset': 0,
          'text': 'B',
        },
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
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

  testWidgets('RhwpNativeEditor deletes selected table controls', (
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

    await tester.tapAt(pagePoint(85, 45));
    await tester.pump();

    expect(
      controller.objectSelection,
      const RhwpObjectSelection(
        page: 0,
        bounds: Rect.fromLTRB(80, 40, 180, 120),
        type: 'table',
        section: 0,
        paragraph: 5,
        controlIndex: 2,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(controller.objectSelection, isNull);
    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteTableControl',
      'section': 0,
      'paragraph': 5,
      'controlIndex': 2,
    });
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
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
      {
        'type': 'exportControlHtml',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
      },
    ]);
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');
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

  testWidgets('RhwpNativeEditor falls back to object HTML clipboard paste', (
    tester,
  ) async {
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
      {
        'type': 'exportControlHtml',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 1,
      },
    ]);
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');

    session.commands.clear();
    session.hasObjectControlClipboard = false;
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
      const RhwpCursorPosition(paragraph: 3, offset: 4),
    );
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'clipboardHasObjectControl'},
      {
        'type': 'pasteHtml',
        'section': 0,
        'paragraph': 3,
        'offset': 2,
        'html':
            '<html><body><!--StartFragment--><p><span>bc</span></p><!--EndFragment--></body></html>',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor cuts selected object controls', (tester) async {
    final clipboard = _MockClipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handleMethodCall,
    );
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(_objectEditorLayerTreeJson());
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
        'type': 'exportControlHtml',
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

  testWidgets('RhwpNativeEditor moves selected table objects by offset', (
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

    await tester.tapAt(pagePoint(85, 45));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('rhwp-editor-object-resize-southEast')),
      findsNothing,
    );

    final drag = await tester.startGesture(pagePoint(100, 45));
    await drag.moveTo(pagePoint(112, 53));
    await drag.up();
    await _pumpDocumentFrame(tester);

    expect(
      controller.objectSelection,
      const RhwpObjectSelection(
        page: 0,
        bounds: Rect.fromLTRB(92, 48, 192, 128),
        type: 'table',
        section: 0,
        paragraph: 5,
        controlIndex: 2,
      ),
    );
    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {
        'type': 'moveTableOffset',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'deltaH': 12,
        'deltaV': 8,
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
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'exportSelectionHtml',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
      },
    ]);
  });

  testWidgets(
    'RhwpNativeEditor context menu applies pending character format to input',
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

      controller.cursor = const RhwpCursorPosition(offset: 2);
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final menuPoint =
          pageTopLeft +
          Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

      await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('굵게'), findsOneWidget);
      await tester.tap(find.text('굵게'));
      await tester.pumpAndSettle();

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
          'properties': {'bold': true},
        },
      ]);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
    },
  );

  testWidgets('RhwpNativeEditor context menu applies character effects', (
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('글자 효과'), findsOneWidget);
    await tester.tap(find.text('글자 효과'));
    await tester.pumpAndSettle();

    expect(find.text('위첨자'), findsOneWidget);
    expect(find.text('아래첨자'), findsOneWidget);
    expect(find.text('양각'), findsOneWidget);
    expect(find.text('음각'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-effect-superscript')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'superscript': true, 'subscript': false},
    });
  });

  testWidgets('RhwpNativeEditor context menu applies font family', (
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('글꼴/크기'), findsOneWidget);
    await tester.tap(find.text('글꼴/크기'));
    await tester.pumpAndSettle();

    expect(find.text('글꼴'), findsOneWidget);
    expect(find.text('크기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rhwp-char-font-family-맑은 고딕')));
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
  });

  testWidgets('RhwpNativeEditor context menu applies character colors', (
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('글자 색상'), findsOneWidget);
    await tester.tap(find.text('글자 색상'));
    await tester.pumpAndSettle();

    expect(find.text('글자 색'), findsOneWidget);
    expect(find.text('배경 색'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('rhwp-char-color-text-#2563eb')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'textColor': '#2563eb'},
    });
  });

  testWidgets(
    'RhwpNativeEditor context menu character shape sets pending format at caret',
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

      controller.cursor = const RhwpCursorPosition(offset: 2);
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final menuPoint =
          pageTopLeft +
          Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

      await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('글자 모양'));
      await tester.pump();
      await tester.tap(find.text('글자 모양'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(session.commands, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
        '12.5',
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-bold')));
      await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-apply')));
      await tester.pumpAndSettle();

      expect(changedCalls, 0);
      expect(session.commands, isEmpty);

      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
            const Offset(1, 6),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Q',
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
          'text': 'Q',
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
            'italic': false,
            'underline': false,
            'strikethrough': false,
            'superscript': false,
            'subscript': false,
            'emboss': false,
            'engrave': false,
            'fontFamily': '함초롬바탕',
            'fontSize': 1250,
            'textColor': '#000000',
            'shadeColor': '#ffffff',
          },
        },
      ]);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
    },
  );

  testWidgets('RhwpNativeEditor context menu inserts body objects and breaks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('그림 넣기'), findsOneWidget);
    expect(find.text('각주 넣기'), findsOneWidget);
    expect(find.text('수식 넣기'), findsOneWidget);
    expect(find.text('책갈피'), findsOneWidget);
    expect(find.text('사각형'), findsOneWidget);
    expect(find.text('타원'), findsOneWidget);
    expect(find.text('선'), findsOneWidget);
    expect(find.text('글상자'), findsOneWidget);
    expect(find.text('쪽 나누기'), findsOneWidget);
    expect(find.text('단 나누기'), findsOneWidget);
    expect(find.text('새 번호로 시작'), findsOneWidget);

    await tester.tap(find.text('그림 넣기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.last), {
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

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('사각형'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
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

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('쪽 나누기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertPageBreak',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 번호로 시작'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-new-number-start-field')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-new-number-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertNewNumber',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'startNumber': 9,
    });
  });

  testWidgets('RhwpNativeEditor context menu inserts references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('각주 넣기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertFootnote',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수식 넣기'));
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

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'insertEquation',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'script': 'sqrt x',
      'fontSize': 1200,
      'color': 0x2563eb,
    });

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('책갈피'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-bookmark-name-field')),
      'context-mark',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-add')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(session.commands.map(jsonDecode).toList().sublist(2), [
      {'type': 'getBookmarks'},
      {
        'type': 'addBookmark',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'name': 'context-mark',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor context menu edits body field controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    controller.cursor = const RhwpCursorPosition(offset: 2);
    await tester.pump();

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('필드 목록'), findsOneWidget);
    expect(find.text('누름틀 속성'), findsOneWidget);
    expect(find.text('필드 삭제'), findsOneWidget);

    await tester.tap(find.text('누름틀 속성'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-guide-field')),
      '본문 안내',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-memo-field')),
      '본문 메모',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-field-props-name-field')),
      'body_field',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-field-props-update')));
    await _pumpDocumentFrame(tester);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('필드 삭제'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
      'saveSnapshot',
    ]);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getFieldInfoAt', 'section': 0, 'paragraph': 0, 'offset': 2},
      {'type': 'getClickHereProperties', 'fieldId': 7},
      {
        'type': 'updateClickHereProperties',
        'fieldId': 7,
        'guide': '본문 안내',
        'memo': '본문 메모',
        'name': 'body_field',
        'editable': true,
      },
      {'type': 'removeFieldAt', 'section': 0, 'paragraph': 0, 'offset': 2},
    ]);
  });

  testWidgets('RhwpNativeEditor inserts footnote with shortcut', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertFootnote',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
    });
  });

  testWidgets('RhwpNativeEditor opens equation dialog with shortcut', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-equation-script-field')),
      'sum x',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rhwp-equation-font-size-field')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-equation-color-#2563eb')));
    await tester.tap(find.byKey(const ValueKey('rhwp-equation-apply')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 3));
    expect(jsonDecode(session.commands.single), {
      'type': 'insertEquation',
      'section': 0,
      'paragraph': 0,
      'offset': 2,
      'script': 'sum x',
      'fontSize': 1200,
      'color': 0x2563eb,
    });
  });

  testWidgets('RhwpNativeEditor opens bookmark dialog with shortcut', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-bookmark-name-field')),
      'shortcut-mark',
    );
    await tester.tap(find.byKey(const ValueKey('rhwp-bookmark-add')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode).toList(), [
      {'type': 'getBookmarks'},
      {
        'type': 'addBookmark',
        'section': 0,
        'paragraph': 0,
        'offset': 2,
        'name': 'shortcut-mark',
      },
    ]);
  });

  testWidgets('RhwpNativeEditor context menu applies document styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('스타일'), findsOneWidget);
    await tester.tap(find.text('스타일'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rhwp-style-3')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rhwp-style-3')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getStyleList'},
      {'type': 'applyStyle', 'section': 0, 'paragraph': 0, 'styleId': 3},
      {'type': 'applyStyle', 'section': 0, 'paragraph': 1, 'styleId': 3},
    ]);
  });

  testWidgets('RhwpNativeEditor context menu applies line spacing preset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('줄 간격'), findsOneWidget);
    await tester.tap(find.text('줄 간격'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rhwp-line-spacing-180')));
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

  testWidgets('RhwpNativeEditor context menu decreases paragraph indent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..paraPropertiesJson =
          '{"alignment":"justify","lineSpacing":160.0,"lineSpacingType":"Percent","marginLeft":2000.0,"marginRight":0.0,"indent":0.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":0}';
    final document = RhwpDocument.fromSession(session);
    var changedCalls = 0;

    await tester.pumpWidget(
      _WidgetHarness(
        child: SizedBox(
          width: 900,
          height: 520,
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final menuPoint =
        pageTopLeft +
        Offset(pageSize.width * 105 / 240, pageSize.height * 48 / 180);

    await tester.tapAt(menuPoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('들여쓰기 줄이기'), findsOneWidget);
    expect(find.text('들여쓰기 늘리기'), findsOneWidget);
    await tester.tap(find.text('들여쓰기 줄이기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 0,
      'endParagraph': 1,
      'properties': {'marginLeft': 1000},
    });
  });

  testWidgets('RhwpNativeEditor context menu runs table cell actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('위에 줄 삽입'), findsOneWidget);
    expect(find.text('아래에 줄 삽입'), findsOneWidget);
    expect(find.text('왼쪽에 칸 삽입'), findsOneWidget);
    expect(find.text('오른쪽에 칸 삽입'), findsOneWidget);
    expect(find.text('줄 삭제'), findsOneWidget);
    expect(find.text('칸 삭제'), findsOneWidget);
    expect(find.text('셀 위쪽 정렬'), findsOneWidget);
    expect(find.text('셀 가운데 정렬'), findsOneWidget);
    expect(find.text('셀 아래쪽 정렬'), findsOneWidget);
    expect(find.text('셀 노랑 채우기'), findsOneWidget);
    expect(find.text('셀 채우기 제거'), findsOneWidget);
    expect(find.text('셀 테두리'), findsOneWidget);
    await tester.tap(find.text('셀 노랑 채우기'));
    await _pumpDocumentFrame(tester);

    await tester.tapAt(tablePoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('셀 아래쪽 정렬'));
    await _pumpDocumentFrame(tester);

    await tester.tapAt(tablePoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('줄 삭제'));
    await _pumpDocumentFrame(tester);

    await tester.tapAt(tablePoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('셀 나누기'), findsOneWidget);
    await tester.tap(find.text('셀 나누기'));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 4);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'applyTableCellStyle',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'properties': {'fillType': 'solid', 'fillColor': '#fef08a'},
      },
      {
        'type': 'applyTableCellStyle',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'properties': {'verticalAlign': 2},
      },
      {
        'type': 'deleteTableRow',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'row': 1,
      },
      {
        'type': 'splitTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'row': 1,
        'column': 3,
      },
    ]);
  });

  testWidgets(
    'RhwpNativeEditor keeps table cell text selection on secondary click',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
      );
      final document = RhwpDocument.fromSession(session);
      const selectedCellText = RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );

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

      controller.tableCellSelection = selectedCellText;
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final selectedTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(selectedTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(controller.tableCellSelection, selectedCellText);
      expect(controller.selection.isCollapsed, isTrue);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );
      expect(find.text('복사'), findsOneWidget);
      expect(session.commands, isEmpty);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu formats selected table cell text',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final selectedTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(selectedTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('굵게'), findsOneWidget);
      await tester.tap(find.text('굵게'));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'startOffset': 1,
          'endOffset': 5,
          'properties': {'bold': true},
        },
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'startOffset': 0,
          'endOffset': 2,
          'properties': {'bold': true},
        },
      ]);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies effects to table cell text',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final selectedTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(selectedTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('글자 효과'), findsOneWidget);
      await tester.tap(find.text('글자 효과'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rhwp-char-effect-engrave')));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'startOffset': 1,
          'endOffset': 5,
          'properties': {'emboss': false, 'engrave': true},
        },
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'startOffset': 0,
          'endOffset': 2,
          'properties': {'emboss': false, 'engrave': true},
        },
      ]);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies font size to table cell text',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final selectedTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(selectedTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('글꼴/크기'), findsOneWidget);
      await tester.tap(find.text('글꼴/크기'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('rhwp-char-font-size-1400')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rhwp-char-font-size-1400')));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'startOffset': 1,
          'endOffset': 5,
          'properties': {'fontSize': 1400},
        },
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'startOffset': 0,
          'endOffset': 2,
          'properties': {'fontSize': 1400},
        },
      ]);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies colors to table cell text',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final selectedTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(selectedTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('글자 색상'), findsOneWidget);
      await tester.tap(find.text('글자 색상'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('rhwp-char-color-shade-#fef08a')),
      );
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'startOffset': 1,
          'endOffset': 5,
          'properties': {'shadeColor': '#fef08a'},
        },
        {
          'type': 'applyCharFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'startOffset': 0,
          'endOffset': 2,
          'properties': {'shadeColor': '#fef08a'},
        },
      ]);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies pending format to table input',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('굵게'), findsOneWidget);
      expect(find.text('글자 모양'), findsOneWidget);
      await tester.tap(find.text('굵게'));
      await tester.pumpAndSettle();

      expect(changedCalls, 0);
      expect(session.commands, isEmpty);

      await tester.tapAt(cellTextPoint);
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
          'properties': {'bold': true},
        },
      ]);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(controller.tableCellSelection?.activeOffset, 3);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu removes table cell field controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('필드 목록'), findsOneWidget);
      expect(find.text('누름틀 속성'), findsOneWidget);
      expect(find.text('필드 삭제'), findsOneWidget);

      await tester.tap(find.text('필드 삭제'));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'removeFieldAtInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'isTextBox': false,
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu edits table cell field properties',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('누름틀 속성'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('rhwp-field-props-guide-field')),
        '셀 안내',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-field-props-memo-field')),
        '셀 메모',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rhwp-field-props-name-field')),
        'cell_field',
      );
      await tester.tap(
        find.byKey(const ValueKey('rhwp-field-props-editable-field')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rhwp-field-props-update')));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'getFieldInfoAtInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'offset': 2,
          'isTextBox': false,
        },
        {'type': 'getClickHereProperties', 'fieldId': 7},
        {
          'type': 'updateClickHereProperties',
          'fieldId': 7,
          'guide': '셀 안내',
          'memo': '셀 메모',
          'name': 'cell_field',
          'editable': false,
        },
      ]);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu character shape sets pending table format',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('글자 모양'));
      await tester.pump();
      await tester.tap(find.text('글자 모양'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(session.commands, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('rhwp-char-shape-font-size-field')),
        '12.5',
      );
      await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-bold')));
      await tester.tap(find.byKey(const ValueKey('rhwp-char-shape-apply')));
      await tester.pumpAndSettle();

      expect(changedCalls, 0);
      expect(session.commands, isEmpty);

      await tester.tapAt(cellTextPoint);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Q',
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
          'text': 'Q',
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
            'italic': false,
            'underline': false,
            'strikethrough': false,
            'superscript': false,
            'subscript': false,
            'emboss': false,
            'engrave': false,
            'fontFamily': '함초롬바탕',
            'fontSize': 1250,
            'textColor': '#000000',
            'shadeColor': '#ffffff',
          },
        },
      ]);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(controller.tableCellSelection?.activeOffset, 3);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies paragraph alignment to table text',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('문단 모양'), findsOneWidget);
      expect(find.text('가운데 정렬'), findsOneWidget);
      await tester.tap(find.text('가운데 정렬'));
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
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(controller.tableCellSelection?.activeOffset, 2);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies paragraph shape to table text',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('문단 모양'));
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
        'type': 'applyParaFormatInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
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
      expect(controller.tableCellSelection?.hasTextSelection, isFalse);
      expect(controller.tableCellSelection?.activeOffset, 2);
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies document style to table text',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('스타일'), findsOneWidget);
      await tester.tap(find.text('스타일'));
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
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu applies line spacing to table text',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('줄 간격'), findsOneWidget);
      await tester.tap(find.text('줄 간격'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rhwp-line-spacing-180')));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(jsonDecode(session.commands.single), {
        'type': 'applyParaFormatInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'properties': {'lineSpacing': 180, 'lineSpacingType': 'Percent'},
      });
    },
  );

  testWidgets(
    'RhwpNativeEditor context menu increases table text paragraph indent',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 0,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final cellTextPoint =
          pageTopLeft +
          Offset(pageSize.width * 118 / 240, pageSize.height * 76 / 180);

      await tester.tapAt(cellTextPoint, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('들여쓰기 늘리기'), findsOneWidget);
      await tester.tap(find.text('들여쓰기 늘리기'));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(jsonDecode(session.commands.single), {
        'type': 'applyParaFormatInTableCell',
        'section': 0,
        'paragraph': 5,
        'controlIndex': 2,
        'cellIndex': 7,
        'cellParagraph': 0,
        'properties': {'marginLeft': 1000},
      });
    },
  );

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

  testWidgets(
    'RhwpNativeEditor selects all active table cell text with shortcut',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
      );
      await tester.pump();
      session.commands.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      final selection = controller.tableCellSelection;
      expect(selection?.activeCellParagraph, 1);
      expect(selection?.activeOffset, 4);
      expect(selection?.selectionBaseCellParagraph, 0);
      expect(selection?.selectionBaseOffset, 0);
      expect(selection?.hasTextSelection, isTrue);
      expect(controller.selection.isCollapsed, isTrue);
      expect(session.commands, isEmpty);
      expect(session.historyCommands, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );
    },
  );

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

    await tester.pump(const Duration(milliseconds: 550));

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

  testWidgets('RhwpNativeEditor selects a table cell word on double click', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(cellText: 'hello'),
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

    final pageFinder = find.byType(SvgPicture);
    final pageTopLeft = tester.getTopLeft(pageFinder);
    final pageSize = tester.getSize(pageFinder);
    final wordPoint =
        pageTopLeft +
        Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

    await tester.tapAt(wordPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(wordPoint);
    await tester.pump();

    final selection = controller.tableCellSelection;
    expect(selection?.activeCellIndex, 7);
    expect(selection?.activeCellParagraph, 0);
    expect(selection?.activeOffset, 5);
    expect(selection?.selectionBaseCellParagraph, 0);
    expect(selection?.selectionBaseOffset, 0);
    expect(selection?.hasTextSelection, isTrue);
    expect(controller.selection.isCollapsed, isTrue);
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
      findsOneWidget,
    );
  });

  testWidgets(
    'RhwpNativeEditor selects a table cell paragraph on triple click',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1)
        ..pageLayerTreeJson = jsonEncode(
          _tableCellEditorLayerTreeJson(
            cellText: 'hello world',
            secondCellParagraphText: 'tail',
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

      final pageFinder = find.byType(SvgPicture);
      final pageTopLeft = tester.getTopLeft(pageFinder);
      final pageSize = tester.getSize(pageFinder);
      final paragraphPoint =
          pageTopLeft +
          Offset(pageSize.width * 116 / 240, pageSize.height * 73 / 180);

      await tester.tapAt(paragraphPoint);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(paragraphPoint);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(paragraphPoint);
      await tester.pump();

      final selection = controller.tableCellSelection;
      expect(selection?.activeCellIndex, 7);
      expect(selection?.activeCellParagraph, 0);
      expect(selection?.activeOffset, 11);
      expect(selection?.selectionBaseCellParagraph, 0);
      expect(selection?.selectionBaseOffset, 0);
      expect(selection?.hasTextSelection, isTrue);
      expect(controller.selection.isCollapsed, isTrue);
      expect(
        find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
        findsOneWidget,
      );
    },
  );

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

  testWidgets('RhwpNativeEditor moves horizontally across paragraphs', (
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    controller.cursor = const RhwpCursorPosition(offset: 4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _pumpDocumentFrame(tester);

    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1),
        end: RhwpCursorPosition(offset: 4),
      ),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor moves horizontally across empty paragraphs', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.bodyParagraphLengths[0] = 0;
    final layerTree = _editorLayerTreeJson(
      firstText: 'abcd',
      secondText: 'efgh',
    );
    final root = layerTree['root']! as Map<String, Object?>;
    final children = root['children']! as List<Object?>;
    children.removeAt(0);
    session.pageLayerTreeJson = jsonEncode(layerTree);
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

    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition());
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      containsAll(['getParagraphCount', 'getParagraphLength']),
    );

    controller.cursor = const RhwpCursorPosition();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      contains('getParagraphLength'),
    );
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

    controller.cursor = const RhwpCursorPosition(offset: 11);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);
    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);
    expect(
      controller.selection,
      const RhwpSelectionRange(
        start: RhwpCursorPosition(paragraph: 1),
        end: RhwpCursorPosition(offset: 6),
      ),
    );
    expect(session.commands, isEmpty);
  });

  testWidgets('RhwpNativeEditor moves by word across empty paragraphs', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.bodyParagraphLengths[0] = 0;
    final layerTree = _editorLayerTreeJson(
      firstText: 'abcd',
      secondText: 'tail',
    );
    final root = layerTree['root']! as Map<String, Object?>;
    final children = root['children']! as List<Object?>;
    children.removeAt(0);
    session.pageLayerTreeJson = jsonEncode(layerTree);
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

    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    session.commands.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition());
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      containsAll(['getParagraphCount', 'getParagraphLength']),
    );

    controller.cursor = const RhwpCursorPosition();
    session.commands.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(controller.cursor, const RhwpCursorPosition(paragraph: 1));
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

  testWidgets('RhwpNativeEditor deletes by word across paragraph boundaries', (
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

    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    session.commands.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 6));
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 6,
      'endParagraph': 1,
      'endOffset': 0,
    });

    controller.cursor = const RhwpCursorPosition(offset: 11);
    session.commands.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition(offset: 11));
    expect(jsonDecode(session.commands.single), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 11,
      'endParagraph': 1,
      'endOffset': 0,
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

  testWidgets('RhwpNativeEditor merges paragraphs at keyboard boundaries', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.pageLayerTreeJson = jsonEncode(
      _editorLayerTreeJson(firstText: 'abcd', secondText: 'efgh'),
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

    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 4));
    expect(jsonDecode(session.commands.single), {
      'type': 'mergeParagraph',
      'section': 0,
      'paragraph': 1,
    });

    session.commands.clear();
    controller.cursor = const RhwpCursorPosition(offset: 4);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition(offset: 4));
    expect(jsonDecode(session.commands.single), {
      'type': 'mergeParagraph',
      'section': 0,
      'paragraph': 1,
    });

    session.commands.clear();
    controller.cursor = const RhwpCursorPosition();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(session.commands, isEmpty);

    controller.cursor = const RhwpCursorPosition(paragraph: 1, offset: 4);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getParagraphCount', 'section': 0},
    ]);
  });

  testWidgets('RhwpNativeEditor merges empty paragraphs using core metrics', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    final session = _FakeRhwpSession(pageCountValue: 1);
    session.bodyParagraphLengths[0] = 0;
    final layerTree = _editorLayerTreeJson(
      firstText: 'abcd',
      secondText: 'efgh',
    );
    final root = layerTree['root']! as Map<String, Object?>;
    final children = root['children']! as List<Object?>;
    children.removeAt(0);
    session.pageLayerTreeJson = jsonEncode(layerTree);
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

    controller.cursor = const RhwpCursorPosition();
    session.commands.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition());
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      containsAll([
        'getParagraphLength',
        'getParagraphCount',
        'mergeParagraph',
      ]),
    );
    expect(jsonDecode(session.commands.last), {
      'type': 'mergeParagraph',
      'section': 0,
      'paragraph': 1,
    });

    session.commands.clear();
    controller.cursor = const RhwpCursorPosition(paragraph: 1);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(controller.cursor, const RhwpCursorPosition());
    expect(
      session.commands.map((json) => jsonDecode(json)['type']),
      containsAll([
        'getParagraphCount',
        'getParagraphLength',
        'mergeParagraph',
      ]),
    );
    expect(jsonDecode(session.commands.last), {
      'type': 'mergeParagraph',
      'section': 0,
      'paragraph': 1,
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

  testWidgets('RhwpNativeEditor toggles active character formatting off', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 1)
      ..charPropertiesJson =
          '{"fontFamily":"함초롬바탕","fontSize":1000,"bold":true,"italic":true,"underline":true,"strikethrough":false,"superscript":false,"subscript":false,"emboss":false,"engrave":false,"textColor":"#000000","shadeColor":"#ffffff"}';
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

    await tester.tap(find.byTooltip('Bold'));
    await _pumpDocumentFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
        'properties': {'bold': false},
      },
      {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
        'properties': {'italic': false},
      },
      {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
        'properties': {'underline': false},
      },
    ]);
  });

  testWidgets('RhwpNativeEditor applies character effect shortcuts', (
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
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 3);
    expect(jsonDecode(session.commands[0]), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'strikethrough': true},
    });
    expect(jsonDecode(session.commands[1]), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'superscript': true, 'subscript': false},
    });
    expect(jsonDecode(session.commands[2]), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'superscript': false, 'subscript': true},
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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-text-color-menu')));
    await tester.pumpAndSettle();
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
      find.byKey(const ValueKey('rhwp-editor-shade-color-menu')),
    );
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
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

  testWidgets('RhwpNativeEditor steps inline font size from toolbar buttons', (
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
      find.byKey(const ValueKey('rhwp-editor-font-size-increase')),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-font-size-increase')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-editor-font-size-field')),
          )
          .controller
          ?.text,
      '11.0',
    );
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontSize': 1100},
    });

    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-font-size-decrease')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-font-size-decrease')),
    );
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rhwp-editor-font-size-field')),
          )
          .controller
          ?.text,
      '10.0',
    );
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontSize': 1000},
    });
  });

  testWidgets('RhwpNativeEditor steps font size from keyboard shortcuts', (
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
      start: RhwpCursorPosition(offset: 1),
      end: RhwpCursorPosition(offset: 3),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontSize': 1100},
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 2);
    expect(jsonDecode(session.commands.last), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 0,
      'startOffset': 1,
      'endParagraph': 0,
      'endOffset': 3,
      'properties': {'fontSize': 1000},
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
        find.byKey(const ValueKey('rhwp-editor-text-color-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-text-color-#2563eb')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-shade-color-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rhwp-editor-shade-color-#fef08a')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-superscript')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
      await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-text-color-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-text-color-#2563eb')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-shade-color-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rhwp-editor-shade-color-#fef08a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-superscript')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-effects-menu')));
    await tester.pumpAndSettle();
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
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      find.byKey(const ValueKey('rhwp-editor-character-shape')),
    );
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('rhwp-editor-character-shape')),
    );
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

  testWidgets('RhwpNativeEditor opens paragraph shape dialog with Alt+T', (
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
      start: RhwpCursorPosition(paragraph: 0, offset: 1),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhwp-para-shape-line-spacing-field')),
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

  testWidgets('RhwpNativeEditor applies line spacing shortcuts', (
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
      start: RhwpCursorPosition(paragraph: 0, offset: 1),
      end: RhwpCursorPosition(paragraph: 1, offset: 2),
    );
    await tester.pump();

    for (final shortcut in const [
      (key: LogicalKeyboardKey.digit1, lineSpacing: 100),
      (key: LogicalKeyboardKey.digit2, lineSpacing: 200),
      (key: LogicalKeyboardKey.digit5, lineSpacing: 150),
    ]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(shortcut.key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);
    }

    expect(changedCalls, 3);
    expect(session.commands.map(jsonDecode), [
      for (final lineSpacing in const [100, 200, 150])
        {
          'type': 'applyParaFormatRange',
          'section': 0,
          'startParagraph': 0,
          'endParagraph': 1,
          'properties': {
            'lineSpacing': lineSpacing,
            'lineSpacingType': 'Percent',
          },
        },
    ]);
  });

  testWidgets('RhwpNativeEditor increases paragraph indent from ribbon', (
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
      find.byKey(const ValueKey('rhwp-editor-increase-indent')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rhwp-editor-increase-indent')));
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(jsonDecode(session.commands.single), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 0,
      'endParagraph': 1,
      'properties': {'marginLeft': 1000},
    });
  });

  testWidgets('RhwpNativeEditor applies paragraph indent shortcuts', (
    tester,
  ) async {
    Future<List<Object?>> runShortcut({
      required LogicalKeyboardKey key,
      String? paraPropertiesJson,
    }) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      if (paraPropertiesJson != null) {
        session.paraPropertiesJson = paraPropertiesJson;
      }
      final document = RhwpDocument.fromSession(session);

      await tester.pumpWidget(
        _WidgetHarness(
          child: SizedBox(
            width: 720,
            height: 420,
            child: RhwpNativeEditor(
              key: ValueKey('rhwp-indent-shortcut-${key.keyId}'),
              document: document,
              controller: controller,
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
        start: RhwpCursorPosition(paragraph: 0, offset: 1),
        end: RhwpCursorPosition(paragraph: 1, offset: 2),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpDocumentFrame(tester);

      return session.commands.map(jsonDecode).toList();
    }

    final increaseCommands = await runShortcut(
      key: LogicalKeyboardKey.bracketRight,
    );
    expect(increaseCommands, [
      {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 0,
        'endParagraph': 1,
        'properties': {'marginLeft': 1000},
      },
    ]);

    final decreaseCommands = await runShortcut(
      key: LogicalKeyboardKey.bracketLeft,
      paraPropertiesJson:
          '{"alignment":"justify","lineSpacing":160.0,"lineSpacingType":"Percent","marginLeft":2000.0,"marginRight":0.0,"indent":0.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":0}',
    );
    expect(decreaseCommands, [
      {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 0,
        'endParagraph': 1,
        'properties': {'marginLeft': 1000},
      },
    ]);
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

  testWidgets('RhwpNativeEditor opens style picker with F6 shortcut', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('rhwp-style-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhwp-style-3')), findsOneWidget);
    expect(changedCalls, 0);
    expect(session.commands.map(jsonDecode), [
      {'type': 'getStyleList'},
    ]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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

  testWidgets(
    'RhwpNativeEditor applies document styles to selected table cell text paragraphs',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
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
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode).toList(), [
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
        {
          'type': 'applyCellStyle',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'styleId': 3,
        },
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    },
  );

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

  testWidgets(
    'RhwpNativeEditor applies paragraph alignment to selected table cell text paragraphs',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      session.pageLayerTreeJson = jsonEncode(
        _tableCellEditorLayerTreeJson(
          cellText: 'hello',
          secondCellParagraphText: 'tail',
        ),
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

      controller.tableCellSelection = const RhwpTableCellSelection(
        section: 0,
        paragraph: 5,
        controlIndex: 2,
        startRow: 1,
        startColumn: 3,
        endRow: 2,
        endColumn: 3,
        activeCellIndex: 7,
        activeCellParagraph: 1,
        activeOffset: 2,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
      );
      await tester.pump();

      await tester.tap(find.text('서식'));
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('Align center'));
      await tester.pump();
      await tester.tap(find.byTooltip('Align center'));
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.commands.map(jsonDecode).toList(), [
        {
          'type': 'applyParaFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 0,
          'properties': {'alignment': 'center'},
        },
        {
          'type': 'applyParaFormatInTableCell',
          'section': 0,
          'paragraph': 5,
          'controlIndex': 2,
          'cellIndex': 7,
          'cellParagraph': 1,
          'properties': {'alignment': 'center'},
        },
      ]);
      expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    },
  );

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

  testWidgets('RhwpNativeEditor focuses replace with replace shortcut', (
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
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
      findsNothing,
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();

    final replaceField = tester.widget<TextField>(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
    );
    expect(replaceField.focusNode?.hasFocus, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
      'replacement',
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('rhwp-editor-caret'))) +
          const Offset(1, 6),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();

    final focusedReplaceField = tester.widget<TextField>(
      find.byKey(const ValueKey('rhwp-editor-replace-field')),
    );
    expect(focusedReplaceField.focusNode?.hasFocus, isTrue);
    expect(
      focusedReplaceField.controller?.selection,
      const TextSelection(baseOffset: 0, extentOffset: 11),
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('Go to page'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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
        activeOffset: 4,
        isTextEditing: true,
        selectionBaseCellParagraph: 0,
        selectionBaseOffset: 1,
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

  testWidgets('RhwpNativeEditor handles replace field enter and escape keys', (
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

    final replaceField = find.byKey(
      const ValueKey('rhwp-editor-replace-field'),
    );
    await tester.enterText(replaceField, 'AB');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
      'saveSnapshot',
    ]);
    expect(session.commands.map((json) => jsonDecode(json)['type']), [
      'deleteText',
      'insertText',
    ]);

    await tester.enterText(replaceField, 'CD');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(tester.widget<TextField>(replaceField).controller?.text, isEmpty);
    expect(tester.widget<TextField>(replaceField).focusNode?.hasFocus, isFalse);
    expect(changedCalls, 1);
    expect(session.commands, hasLength(2));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('Go to page'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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

    expect(controller.tableCellSelection?.activeCellIndex, 7);
    expect(controller.tableCellSelection?.activeOffset, 4);
    expect(controller.tableCellSelection?.selectionBaseCellParagraph, 0);
    expect(controller.tableCellSelection?.selectionBaseOffset, 1);
    expect(controller.tableCellSelection?.hasTextSelection, isTrue);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('rhwp-editor-status-input-mode')),
          )
          .data,
      'Selection',
    );
    expect(
      find.byKey(const ValueKey('rhwp-editor-table-text-selection')),
      findsOneWidget,
    );

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
    expect(controller.tableCellSelection?.selectionBaseCellParagraph, 0);
    expect(controller.tableCellSelection?.selectionBaseOffset, 1);
    expect(controller.tableCellSelection?.hasTextSelection, isTrue);
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
    session.renderedPages.clear();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();

    expect(session.commands, isEmpty);
    expect(session.renderedPages, isEmpty);
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
    expect(session.renderedPages, isEmpty);
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

  testWidgets(
    'RhwpNativeEditor toggles overwrite mode with insert key and status bar',
    (tester) async {
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

      await tester.tap(inputMode);
      await tester.pump();

      expect(tester.widget<Text>(inputMode).data, 'Overwrite');

      await tester.tap(inputMode);
      await tester.pump();

      expect(tester.widget<Text>(inputMode).data, 'Insert');
      expect(session.commands, isEmpty);
    },
  );

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

  testWidgets(
    'RhwpNativeEditor previews selected body text replacement while delete is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final deleteGate = Completer<void>();
      session.commandGates['deleteText'] = deleteGate;
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
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'deleteText',
          'section': 0,
          'paragraph': 0,
          'offset': 1,
          'count': 2,
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
      expect(find.text('Z'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      deleteGate.complete();
      await tester.pump();
      await tester.pump();

      expect(session.commands.map(jsonDecode), [
        {
          'type': 'deleteText',
          'section': 0,
          'paragraph': 0,
          'offset': 1,
          'count': 2,
        },
        {
          'type': 'insertText',
          'section': 0,
          'paragraph': 0,
          'offset': 1,
          'text': 'Z',
        },
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
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
    },
  );

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

  testWidgets('RhwpNativeEditor refreshes only edited page after text input', (
    tester,
  ) async {
    final controller = RhwpEditorController();
    final session = _FakeRhwpSession(pageCountValue: 8);
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

    final scroll = controller.goToPage(2);
    await tester.pumpAndSettle();
    await scroll;
    expect(controller.currentPage, 2);
    expect(session.renderedPages, contains(2));

    final caretFinder = find.byKey(const ValueKey('rhwp-editor-caret')).last;
    await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
    await tester.pump();

    final focusedScroll = controller.goToPage(2);
    await tester.pumpAndSettle();
    await focusedScroll;
    expect(controller.currentPage, 2);

    controller.cursor = const RhwpCursorPosition(offset: 2);
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

    await _releaseTextInputAction(tester);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(session.renderedPages, [2]);
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
                      key: ValueKey('connection-churn-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
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
    'RhwpNativeEditor ignores delayed desktop text input action until external focus',
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
                      key: ValueKey('delayed-action-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
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
                  Focus(
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
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(
                      key: ValueKey('ancestor-focus-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        ancestorFocusNode.dispose();
        externalFocusNode.dispose();
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
                      key: ValueKey('transient-focus-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
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
                holdTextRefreshWhileFocused: false,
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
    'RhwpNativeEditor can hold desktop text refresh until external focus',
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
                      holdTextRefreshWhileFocused: true,
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
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.closeConnection();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('external-focus-field')));
        await _pumpDocumentFrame(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor ignores transient external focus while holding text refresh',
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
                      holdTextRefreshWhileFocused: true,
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(
                      key: ValueKey('transient-external-focus-target'),
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

        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
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
    'RhwpNativeEditor delays external focus refresh during desktop input churn',
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
                      holdTextRefreshWhileFocused: true,
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(
                      key: ValueKey('external-churn-target'),
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

        externalFocusNode.requestFocus();
        tester.testTextInput.closeConnection();
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.tapAt(tester.getTopLeft(caretFinder) + const Offset(1, 6));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
        await tester.pump(const Duration(milliseconds: 1800));
        await _pumpDocumentFrame(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        externalFocusNode.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor keeps refresh held while desktop text connection is active',
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
                      editRefreshDelay: const Duration(seconds: 3),
                      holdTextRefreshWhileFocused: true,
                      onChanged: (_) => changedCalls += 1,
                    ),
                  ),
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(
                      key: ValueKey('active-connection-release-target'),
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

        externalFocusNode.requestFocus();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);
        expect(
          find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 2));
        await _pumpDocumentFrame(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        externalFocusNode.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'RhwpNativeEditor cancels transient desktop focus release when focus returns',
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
                      key: ValueKey('cancel-focus-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
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
    'RhwpNativeEditor reholds text refresh when focus returns after slow commit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final externalFocusNode = FocusNode();
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final saveSnapshotGate = Completer<void>();
      session.commandGates['saveSnapshot'] = saveSnapshotGate;
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
                      key: ValueKey('slow-commit-release-target'),
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

        expect(changedCalls, 0);
        expect(session.renderedPages, isEmpty);

        externalFocusNode.requestFocus();
        await _pumpDesktopTextInputRelease(tester);

        expect(changedCalls, 1);
        expect(session.renderedPages, [0]);
      } finally {
        externalFocusNode.dispose();
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

  testWidgets(
    'RhwpNativeEditor previews rapid text while an insert command is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final insertGate = Completer<void>();
      session.commandGates['insertText'] = insertGate;
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

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.cursor, const RhwpCursorPosition(offset: 3));
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'insertText',
          'section': 0,
          'paragraph': 0,
          'offset': 2,
          'text': ' ',
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text(' '), findsOneWidget);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.cursor, const RhwpCursorPosition(offset: 4));
      expect(session.commands.length, 1);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text(' A'), findsOneWidget);

      insertGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(session.commands.map(jsonDecode), [
        {
          'type': 'insertText',
          'section': 0,
          'paragraph': 0,
          'offset': 2,
          'text': ' ',
        },
        {
          'type': 'insertText',
          'section': 0,
          'paragraph': 0,
          'offset': 3,
          'text': 'A',
        },
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(find.text(' A'), findsOneWidget);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

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
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'exportSelectionHtml',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
      },
    ]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'bc');
    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 1));
    expect(session.commands.map(jsonDecode).skip(1), [
      {
        'type': 'exportSelectionHtml',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
      },
      {
        'type': 'deleteText',
        'section': 0,
        'paragraph': 0,
        'offset': 1,
        'count': 2,
      },
    ]);

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

  testWidgets(
    'RhwpNativeEditor previews body text cut while delete is pending',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final deleteGate = Completer<void>();
      session.commandGates['deleteText'] = deleteGate;
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
      session.renderedPages.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, 'bc');
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(controller.cursor, const RhwpCursorPosition(offset: 1));
      expect(session.historyCommands.map((json) => jsonDecode(json)['type']), [
        'saveSnapshot',
      ]);
      expect(session.commands.map(jsonDecode), [
        {
          'type': 'exportSelectionHtml',
          'section': 0,
          'startParagraph': 0,
          'startOffset': 1,
          'endParagraph': 0,
          'endOffset': 3,
        },
        {
          'type': 'deleteText',
          'section': 0,
          'paragraph': 0,
          'offset': 1,
          'count': 2,
        },
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );

      deleteGate.complete();
      await tester.pump();
      await tester.pump();
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

  testWidgets('RhwpNativeEditor pastes copied body text through HTML import', (
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

    controller.cursor = const RhwpCursorPosition(offset: 4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpDocumentFrame(tester);

    expect(changedCalls, 1);
    expect(controller.cursor, const RhwpCursorPosition(offset: 6));
    expect(session.commands.map(jsonDecode), [
      {
        'type': 'exportSelectionHtml',
        'section': 0,
        'startParagraph': 0,
        'startOffset': 1,
        'endParagraph': 0,
        'endOffset': 3,
      },
      {
        'type': 'pasteHtml',
        'section': 0,
        'paragraph': 0,
        'offset': 4,
        'html':
            '<html><body><!--StartFragment--><p><span>bc</span></p><!--EndFragment--></body></html>',
      },
    ]);
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

  testWidgets(
    'RhwpNativeEditor previews multiline body paste while insert is pending',
    (tester) async {
      final clipboard = _MockClipboard();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        clipboard.handleMethodCall,
      );
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final insertGate = Completer<void>();
      session.commandGates['insertText'] = insertGate;
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
      session.renderedPages.clear();
      await Clipboard.setData(const ClipboardData(text: 'AA\nBB'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        controller.cursor,
        const RhwpCursorPosition(paragraph: 1, offset: 2),
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
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text('AA'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );

      insertGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

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
      ]);
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

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
    'RhwpNativeEditor previews multi-paragraph body replacement while deleteRange is pending',
    (tester) async {
      final controller = RhwpEditorController();
      final session = _FakeRhwpSession(pageCountValue: 1);
      final deleteRangeGate = Completer<void>();
      session.commandGates['deleteRange'] = deleteRangeGate;
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
      ]);
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-delete-mask-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rhwp-editor-pending-text-preview')),
        findsOneWidget,
      );
      expect(find.text('Z'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      deleteRangeGate.complete();
      await tester.pump();
      await tester.pump();

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
      expect(changedCalls, 0);
      expect(session.renderedPages, isEmpty);

      await _releaseTextInputAction(tester);
      await _pumpDocumentFrame(tester);

      expect(changedCalls, 1);
      expect(session.renderedPages, [0]);
    },
  );

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
  int sectionCountValue = 1;
  int bodyParagraphCount = 2;
  int convertToEditableCalls = 0;
  bool convertToEditableConverted = false;
  bool hasObjectControlClipboard = false;
  bool headerFooterExists = false;
  bool footerExists = false;
  String headerFooterText = '';
  bool footnoteExists = false;
  String footnoteText = '';
  String fileName = 'sample.hwp';
  String extractedText = 'alpha\nbeta';
  String charPropertiesJson =
      '{"fontFamily":"함초롬바탕","fontSize":1000,"bold":false,"italic":false,"underline":false,"strikethrough":false,"superscript":false,"subscript":false,"emboss":false,"engrave":false,"textColor":"#000000","shadeColor":"#ffffff"}';
  String paraPropertiesJson =
      '{"alignment":"justify","lineSpacing":160.0,"lineSpacingType":"Percent","marginLeft":0.0,"marginRight":0.0,"indent":0.0,"spacingBefore":0.0,"spacingAfter":0.0,"paraShapeId":0}';
  String bookmarksJson =
      '[{"name":"intro","sec":0,"para":0,"ctrlIdx":2,"charPos":1}]';
  String pageLayerTreeJson = jsonEncode(_editorLayerTreeJson());
  final pageLayerTreeJsonByPage = <int, String>{};
  final bodyParagraphLengths = <int, int>{0: 4, 1: 4};
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
    if (command is Map && command['type'] == 'convertToEditable') {
      convertToEditableCalls += 1;
      return '{"ok":true,"converted":$convertToEditableConverted}';
    }

    commands.add(commandJson);
    await _waitForCommandGate(commandType);
    if (command is Map && command['type'] == 'getStyleList') {
      return '[{"id":0,"name":"본문","englishName":"Body","type":0,"nextStyleId":0,"paraShapeId":0,"charShapeId":0},{"id":3,"name":"제목 1","englishName":"Heading 1","type":0,"nextStyleId":0,"paraShapeId":1,"charShapeId":1}]';
    }
    if (command is Map && command['type'] == 'getBookmarks') {
      return bookmarksJson;
    }
    if (command is Map && command['type'] == 'getPageOfPosition') {
      final paragraph = command['paragraph'];
      final page = paragraph is int
          ? paragraph.clamp(0, pageCountValue - 1).toInt()
          : 0;
      return '{"ok":true,"page":$page}';
    }
    if (command is Map && command['type'] == 'getFieldList') {
      return '[{"fieldId":7,"fieldType":"ClickHere","name":"customer","guide":"고객명","command":"ClickHere customer","value":"Old","location":{"section":0,"paragraph":0}}]';
    }
    if (command is Map &&
        (command['type'] == 'getFieldInfoAt' ||
            command['type'] == 'getFieldInfoAtInTableCell')) {
      return '{"inField":true,"fieldId":7,"fieldType":"ClickHere","startCharIdx":1,"endCharIdx":4,"isGuide":false,"guideName":"고객명"}';
    }
    if (command is Map && command['type'] == 'getClickHereProperties') {
      return '{"ok":true,"guide":"고객명","memo":"기존 메모","name":"customer","editable":true}';
    }
    if (command is Map &&
        (command['type'] == 'setActiveField' ||
            command['type'] == 'setActiveFieldInTableCell')) {
      return '{"ok":true,"changed":true}';
    }
    if (command is Map && command['type'] == 'clearActiveField') {
      return '{"ok":true}';
    }
    if (command is Map && command['type'] == 'insertFootnote') {
      footnoteExists = true;
      footnoteText = '';
      return '{"ok":true,"paraIdx":0,"controlIdx":1,"footnoteNumber":1}';
    }
    if (command is Map && command['type'] == 'getFootnoteAtCursor') {
      if (footnoteExists && command['direction'] == 'backward') {
        return '{"hit":true,"sectionIndex":0,"paragraphIndex":0,"controlIndex":1,"charOffset":2,"footnoteNumber":1}';
      }
      return '{"hit":false}';
    }
    if (command is Map && command['type'] == 'getFootnoteInfo') {
      return jsonEncode({
        'ok': true,
        'paraCount': 1,
        'totalTextLen': footnoteText.runes.length,
        'number': 1,
        'texts': [footnoteText],
      });
    }
    if (command is Map && command['type'] == 'deleteFootnote') {
      footnoteExists = false;
      footnoteText = '';
      return '{"ok":true,"sectionIndex":0,"paragraphIndex":0,"controlIndex":1,"charOffset":2,"deletedNumber":1}';
    }
    if (command is Map && command['type'] == 'deleteTextInFootnote') {
      footnoteText = '';
      return '{"ok":true,"charOffset":0}';
    }
    if (command is Map && command['type'] == 'insertTextInFootnote') {
      footnoteText = command['text']?.toString() ?? '';
      return '{"ok":true,"charOffset":0}';
    }
    if (command is Map && command['type'] == 'setFileName') {
      fileName = command['name']?.toString() ?? fileName;
      return '{"ok":true}';
    }
    if (command is Map && command['type'] == 'insertTable') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        final tableParagraph = offset > 0 ? paragraph + 1 : paragraph;
        return '{"ok":true,"paraIdx":$tableParagraph,"controlIdx":0}';
      }
    }
    if (command is Map && command['type'] == 'createTableEx') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        return '{"ok":true,"paraIdx":$paragraph,"controlIdx":0,"logicalOffset":${offset + 8}}';
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
    if (command is Map &&
        const {
          'exportSelectionHtml',
          'exportSelectionInCellHtml',
          'exportControlHtml',
        }.contains(command['type'])) {
      return '<html><body><!--StartFragment--><p><span>bc</span></p><!--EndFragment--></body></html>';
    }
    if (command is Map && command['type'] == 'pasteHtml') {
      final paragraph = command['paragraph'];
      final offset = command['offset'];
      if (paragraph is int && offset is int) {
        return '{"ok":true,"paraIdx":$paragraph,"charOffset":${offset + 2}}';
      }
    }
    if (command is Map && command['type'] == 'pasteHtmlInCell') {
      final cellParagraph = command['cellParagraph'];
      final offset = command['offset'];
      if (cellParagraph is int && offset is int) {
        return '{"ok":true,"cellParaIdx":$cellParagraph,"charOffset":${offset + 4}}';
      }
    }
    if (command is Map && command['type'] == 'getObjectProperties') {
      return '{"width":60,"height":50,"horzOffset":120,"vertOffset":60}';
    }
    if (command is Map && command['type'] == 'getTableProperties') {
      return '{"cellSpacing":10,"paddingLeft":100,"paddingRight":110,"paddingTop":120,"paddingBottom":130,"pageBreak":1,"repeatHeader":false}';
    }
    if (command is Map && command['type'] == 'getCellProperties') {
      return '{"width":5000,"height":3000,"paddingLeft":100,"paddingRight":110,"paddingTop":120,"paddingBottom":130,"verticalAlign":1,"textDirection":0,"isHeader":false,"cellProtect":false}';
    }
    if (command is Map && command['type'] == 'splitParagraphInTableCell') {
      return '{"ok":true,"cellParaIndex":1,"charOffset":0}';
    }
    if (command is Map && command['type'] == 'mergeParagraphInTableCell') {
      return '{"ok":true,"cellParaIndex":0,"charOffset":2}';
    }
    if (command is Map && command['type'] == 'mergeParagraph') {
      final paragraph = command['paragraph'];
      if (paragraph is int && paragraph > 0) {
        final charOffset = bodyParagraphLengths[paragraph - 1] ?? 4;
        return '{"ok":true,"paraIdx":${paragraph - 1},"charOffset":$charOffset}';
      }
      return '{"ok":false,"error":"cannot merge first paragraph"}';
    }
    if (command is Map && command['type'] == 'deleteParagraph') {
      return '{"ok":true,"removedCharCount":4,"newParagraphCount":2}';
    }
    if (command is Map && command['type'] == 'getSectionCount') {
      return '{"count":$sectionCountValue}';
    }
    if (command is Map && command['type'] == 'getParagraphCount') {
      return '{"count":$bodyParagraphCount}';
    }
    if (command is Map && command['type'] == 'getParagraphLength') {
      final paragraph = command['paragraph'];
      final length = paragraph is int
          ? (bodyParagraphLengths[paragraph] ?? 4)
          : 4;
      return '{"length":$length}';
    }
    if (command is Map && command['type'] == 'getCellParagraphCount') {
      return '{"count":2}';
    }
    if (command is Map && command['type'] == 'getCellParagraphLength') {
      return '{"length":4}';
    }
    if (command is Map && command['type'] == 'evaluateTableFormula') {
      return '{"ok":true,"result":3,"formula":"=SUM(A1:B1)"}';
    }
    if (command is Map && command['type'] == 'getPageSetup') {
      return '{"width":59528,"height":84189,"marginLeft":8504,"marginRight":8504,"marginTop":5669,"marginBottom":4252,"marginHeader":4252,"marginFooter":4252,"marginGutter":0,"landscape":false,"binding":0}';
    }
    if (command is Map && command['type'] == 'getPageHide') {
      return '{"ok":true,"exists":false}';
    }
    if (command is Map && command['type'] == 'getHeaderFooter') {
      final isHeader = command['isHeader'] == true;
      if (isHeader ? !headerFooterExists : !footerExists) {
        return '{"ok":true,"exists":false}';
      }
      return jsonEncode({
        'ok': true,
        'exists': true,
        'kind': isHeader ? 'header' : 'footer',
        'applyTo': command['applyTo'] ?? 0,
        'label': '양 쪽',
        'paraIndex': 0,
        'controlIndex': 1,
        'paraCount': 1,
        'text': headerFooterText,
      });
    }
    if (command is Map && command['type'] == 'getHeaderFooterList') {
      return jsonEncode({
        'ok': true,
        'items': [
          if (headerFooterExists)
            {
              'sectionIdx': 0,
              'isHeader': true,
              'applyTo': 0,
              'label': '머리말(양 쪽)',
            },
          if (footerExists)
            {
              'sectionIdx': 0,
              'isHeader': false,
              'applyTo': 0,
              'label': '꼬리말(양 쪽)',
            },
        ],
        'currentIndex': 0,
      });
    }
    if (command is Map && command['type'] == 'createHeaderFooter') {
      if (command['isHeader'] == true) {
        headerFooterExists = true;
      } else {
        footerExists = true;
      }
      return '{"ok":true,"kind":"header","applyTo":0,"label":"양 쪽","paraIndex":0,"controlIndex":1}';
    }
    if (command is Map && command['type'] == 'deleteHeaderFooter') {
      if (command['isHeader'] == true) {
        headerFooterExists = false;
      } else {
        footerExists = false;
      }
      return '{"ok":true}';
    }
    if (command is Map && command['type'] == 'deleteTextInHeaderFooter') {
      headerFooterText = '';
      return '{"ok":true,"charOffset":0}';
    }
    if (command is Map && command['type'] == 'insertTextInHeaderFooter') {
      if (command['isHeader'] == true) {
        headerFooterExists = true;
      } else {
        footerExists = true;
      }
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
      fileName: fileName,
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

Map<String, Object?> _tableCellEditorLayerTreeJson({
  String cellText = 'cell',
  String? secondCellParagraphText,
  bool includeBodyParagraphFive = false,
}) {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _editorTextRunLayerNode(paragraph: 0, y: 40),
        if (includeBodyParagraphFive)
          _editorTextRunLayerNode(paragraph: 5, y: 16),
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
              'children': [
                _editorCellTextRunLayerNode(text: cellText),
                if (secondCellParagraphText != null)
                  _editorCellTextRunLayerNode(
                    text: secondCellParagraphText,
                    cellParagraph: 1,
                    y: 91,
                  ),
              ],
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
  int cellParagraph = 0,
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
          'stableSourceKey':
              'section:0/para:5/char:0/cell:5:2:$cellIndex:$cellParagraph:0',
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
