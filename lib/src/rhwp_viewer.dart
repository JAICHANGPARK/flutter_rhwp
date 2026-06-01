import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'rhwp_document.dart';

typedef RhwpSvgBuilder = Widget Function(BuildContext context, String svg);

/// Builds an optional overlay for a rendered page.
typedef RhwpPageOverlayBuilder =
    Widget? Function(BuildContext context, int page, String svg);

/// Called after a page render future completes and paints.
typedef RhwpPageRenderedCallback = void Function(int page, int renderRevision);

typedef _RhwpPageScroller = Future<void> Function(int page);

Widget _defaultRhwpSvgBuilder(BuildContext context, String svg) {
  return SvgPicture.string(
    svg,
    fit: BoxFit.contain,
    clipBehavior: Clip.antiAlias,
  );
}

class RhwpViewerController extends ChangeNotifier {
  RhwpViewerController({double zoom = 1.0})
    : _zoom = zoom.clamp(minZoom, maxZoom).toDouble();

  static const zoomSteps = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
  static const minZoom = 0.25;
  static const maxZoom = 3.0;
  static const _zoomEpsilon = 0.0001;

  double _zoom;
  int _currentPage = 0;
  int? _pageCount;
  _RhwpPageScroller? _pageScroller;

  double get zoom => _zoom;

  set zoom(double value) {
    final next = value.clamp(minZoom, maxZoom).toDouble();
    if (next == _zoom) {
      return;
    }
    _zoom = next;
    notifyListeners();
  }

  void zoomIn() => zoom = _nextZoomStep();

  void zoomOut() => zoom = _previousZoomStep();

  void resetZoom() => zoom = 1.0;

  /// Fits the page width to the current viewport.
  ///
  /// `RhwpViewer` treats 100% as page-width fit because the base layout is
  /// constrained to the available viewport width.
  void fitWidth() => zoom = 1.0;

  double _nextZoomStep() {
    for (final step in zoomSteps) {
      if (step > _zoom + _zoomEpsilon) {
        return step;
      }
    }
    return maxZoom;
  }

  double _previousZoomStep() {
    for (final step in zoomSteps.reversed) {
      if (step < _zoom - _zoomEpsilon) {
        return step;
      }
    }
    return minZoom;
  }

  /// The page index most recently requested through this controller.
  int get currentPage => _currentPage;

  /// Scrolls the attached viewer to [page] when a viewer is mounted.
  Future<void> goToPage(int page) async {
    final next = _clampPage(page);
    _setCurrentPage(next);
    await _pageScroller?.call(next);
  }

  /// Scrolls to the previous page when possible.
  Future<void> previousPage() => goToPage(_currentPage - 1);

  /// Scrolls to the next page when possible.
  Future<void> nextPage() => goToPage(_currentPage + 1);

  int _clampPage(int page) {
    final pageCount = _pageCount;
    if (pageCount == null || pageCount <= 0) {
      return page.clamp(0, 1 << 30).toInt();
    }
    return page.clamp(0, pageCount - 1).toInt();
  }

  void _attachPageScroller({
    required int pageCount,
    required _RhwpPageScroller pageScroller,
  }) {
    _pageCount = pageCount;
    _pageScroller = pageScroller;
    if (pageCount > 0 && _currentPage >= pageCount) {
      _currentPage = pageCount - 1;
    }
  }

  void _detachPageScroller() {
    _pageScroller = null;
    _pageCount = null;
  }

  void _setCurrentPageFromViewer(int page) {
    _setCurrentPage(_clampPage(page));
  }

  void _setCurrentPage(int page) {
    if (page == _currentPage) {
      return;
    }
    _currentPage = page;
    notifyListeners();
  }
}

class RhwpViewer extends StatefulWidget {
  const RhwpViewer({
    super.key,
    required this.document,
    this.controller,
    this.padding = const EdgeInsets.all(24),
    this.pageGap = 16,
    this.backgroundColor = const Color(0xfff2f4f7),
    this.svgBuilder = _defaultRhwpSvgBuilder,
    this.pageOverlayBuilder,
    this.ignorePageOverlayPointer = true,
    this.renderRevision = 0,
    this.onPageRendered,
  });

  final RhwpDocument document;
  final RhwpViewerController? controller;
  final EdgeInsets padding;
  final double pageGap;
  final Color backgroundColor;
  final RhwpSvgBuilder svgBuilder;
  final RhwpPageOverlayBuilder? pageOverlayBuilder;
  final int renderRevision;
  final RhwpPageRenderedCallback? onPageRendered;

  /// Whether page overlays should ignore pointer events.
  ///
  /// Viewers usually keep this true so overlays do not block scrolling. Native
  /// editor surfaces set it to false so page overlays can handle hit testing.
  final bool ignorePageOverlayPointer;

  @override
  State<RhwpViewer> createState() => _RhwpViewerState();
}

class _RhwpViewerState extends State<RhwpViewer> {
  late final RhwpViewerController _controller;
  late final bool _ownsController;
  late Future<int> _pageCount;
  late double _lastControllerZoom;
  final _verticalScrollController = ScrollController();
  final _pageKeys = <GlobalKey>[];
  int _resolvedPageCount = 0;
  bool _visiblePageSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpViewerController();
    _lastControllerZoom = _controller.zoom;
    _controller.addListener(_handleControllerChanged);
    _verticalScrollController.addListener(_handleScrollPositionChanged);
    _pageCount = widget.document.pageCount;
  }

  @override
  void didUpdateWidget(covariant RhwpViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _pageCount = widget.document.pageCount;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller._detachPageScroller();
    _verticalScrollController.removeListener(_handleScrollPositionChanged);
    _verticalScrollController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextZoom = _controller.zoom;
    if (nextZoom == _lastControllerZoom) {
      return;
    }
    _lastControllerZoom = nextZoom;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: FutureBuilder<int>(
        future: _pageCount,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final pageCount = snapshot.requireData;
          _syncPageKeys(pageCount);
          _controller._attachPageScroller(
            pageCount: pageCount,
            pageScroller: _scrollToPage,
          );
          _scheduleVisiblePageSync();
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth * _controller.zoom
                  : 800.0 * _controller.zoom;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width.clamp(320.0, double.infinity).toDouble(),
                  child: ListView.separated(
                    controller: _verticalScrollController,
                    padding: widget.padding,
                    itemCount: pageCount,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: widget.pageGap),
                    itemBuilder: (context, index) {
                      return _RhwpSvgPage(
                        key: _pageKeys[index],
                        document: widget.document,
                        page: index,
                        renderRevision: widget.renderRevision,
                        svgBuilder: widget.svgBuilder,
                        pageOverlayBuilder: widget.pageOverlayBuilder,
                        onPageRendered: widget.onPageRendered,
                        ignorePageOverlayPointer:
                            widget.ignorePageOverlayPointer,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _syncPageKeys(int pageCount) {
    _resolvedPageCount = pageCount;
    if (_pageKeys.length == pageCount) {
      return;
    }
    if (_pageKeys.length < pageCount) {
      _pageKeys.addAll(
        List<GlobalKey>.generate(
          pageCount - _pageKeys.length,
          (_) => GlobalKey(),
        ),
      );
      return;
    }
    _pageKeys.removeRange(pageCount, _pageKeys.length);
  }

  void _handleScrollPositionChanged() {
    _scheduleVisiblePageSync();
  }

  void _scheduleVisiblePageSync() {
    if (_visiblePageSyncScheduled) {
      return;
    }
    _visiblePageSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visiblePageSyncScheduled = false;
      if (mounted) {
        _syncVisiblePageToController();
      }
    });
  }

  void _syncVisiblePageToController() {
    if (_resolvedPageCount <= 0 || !_verticalScrollController.hasClients) {
      return;
    }

    final viewportRenderObject = context.findRenderObject();
    if (viewportRenderObject is! RenderBox || !viewportRenderObject.hasSize) {
      return;
    }

    final viewportHeight = viewportRenderObject.size.height;
    final targetY = widget.padding.top.clamp(0.0, viewportHeight).toDouble();
    int? bestPage;
    double? bestDistance;

    for (var page = 0; page < _pageKeys.length; page += 1) {
      final pageContext = _pageKeys[page].currentContext;
      final pageRenderObject = pageContext?.findRenderObject();
      if (pageRenderObject is! RenderBox || !pageRenderObject.hasSize) {
        continue;
      }

      final top = pageRenderObject
          .localToGlobal(Offset.zero, ancestor: viewportRenderObject)
          .dy;
      final bottom = top + pageRenderObject.size.height;
      final visibleTop = math.max(0.0, top);
      final visibleBottom = math.min(viewportHeight, bottom);
      if (visibleBottom <= visibleTop) {
        continue;
      }

      final distance = targetY >= top && targetY <= bottom
          ? 0.0
          : math.min((targetY - top).abs(), (targetY - bottom).abs());
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestPage = page;
      }
    }

    if (bestPage != null) {
      _controller._setCurrentPageFromViewer(bestPage);
    }
  }

  Future<void> _scrollToPage(int page) async {
    if (!mounted || _resolvedPageCount <= 0) {
      return;
    }

    final pageIndex = page.clamp(0, _resolvedPageCount - 1).toInt();
    final context = _pageKeys[pageIndex].currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 220),
      );
      return;
    }

    if (!_verticalScrollController.hasClients) {
      return;
    }

    final position = _verticalScrollController.position;
    final denominator = (_resolvedPageCount - 1).clamp(1, 1 << 30);
    final estimatedOffset = position.maxScrollExtent * pageIndex / denominator;
    await _verticalScrollController.animateTo(
      estimatedOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) {
      return;
    }
    final revealedContext = _pageKeys[pageIndex].currentContext;
    if (revealedContext != null && revealedContext.mounted) {
      await Scrollable.ensureVisible(
        revealedContext,
        alignment: 0.05,
        duration: const Duration(milliseconds: 120),
      );
    }
  }
}

class _RhwpSvgPage extends StatefulWidget {
  const _RhwpSvgPage({
    super.key,
    required this.document,
    required this.page,
    required this.renderRevision,
    required this.svgBuilder,
    required this.pageOverlayBuilder,
    required this.onPageRendered,
    required this.ignorePageOverlayPointer,
  });

  final RhwpDocument document;
  final int page;
  final int renderRevision;
  final RhwpSvgBuilder svgBuilder;
  final RhwpPageOverlayBuilder? pageOverlayBuilder;
  final RhwpPageRenderedCallback? onPageRendered;
  final bool ignorePageOverlayPointer;

  @override
  State<_RhwpSvgPage> createState() => _RhwpSvgPageState();
}

class _RhwpSvgPageState extends State<_RhwpSvgPage>
    with AutomaticKeepAliveClientMixin {
  late Future<String> _svg;
  String? _lastSvg;
  String? _cachedSvg;
  RhwpSvgBuilder? _cachedSvgBuilder;
  Widget? _cachedSvgPage;
  int? _reportedRenderRevision;

  @override
  void initState() {
    super.initState();
    _svg = widget.document.renderPageSvg(widget.page);
  }

  @override
  void didUpdateWidget(covariant _RhwpSvgPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.page != widget.page ||
        oldWidget.renderRevision != widget.renderRevision) {
      _svg = widget.document.renderPageSvg(widget.page);
      _reportedRenderRevision = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffd0d5dd)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FutureBuilder<String>(
        future: _svg,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            final lastSvg = _lastSvg;
            if (lastSvg != null) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: _buildPageContent(context, lastSvg),
              );
            }
            return const SizedBox(
              height: 480,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 240,
              child: Center(child: Text(snapshot.error.toString())),
            );
          }

          final svg = snapshot.requireData;
          _lastSvg = svg;
          _reportRendered();
          return Padding(
            padding: const EdgeInsets.all(8),
            child: _buildPageContent(context, svg),
          );
        },
      ),
    );
  }

  Widget _buildPageContent(BuildContext context, String svg) {
    final page = _pageWidgetForSvg(context, svg);
    final overlay = widget.pageOverlayBuilder?.call(context, widget.page, svg);
    if (overlay == null) {
      return page;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        page,
        Positioned.fill(
          child: widget.ignorePageOverlayPointer
              ? IgnorePointer(child: _pageOverlayBoundary(overlay))
              : _pageOverlayBoundary(overlay),
        ),
      ],
    );
  }

  Widget _pageOverlayBoundary(Widget overlay) {
    return RepaintBoundary(
      key: const ValueKey('rhwp-page-overlay-repaint-boundary'),
      child: overlay,
    );
  }

  Widget _pageWidgetForSvg(BuildContext context, String svg) {
    final cachedPage = _cachedSvgPage;
    if (cachedPage != null &&
        _cachedSvg == svg &&
        _cachedSvgBuilder == widget.svgBuilder) {
      return cachedPage;
    }

    final page = RepaintBoundary(
      key: const ValueKey('rhwp-rendered-svg-repaint-boundary'),
      child: widget.svgBuilder(context, svg),
    );
    _cachedSvg = svg;
    _cachedSvgBuilder = widget.svgBuilder;
    _cachedSvgPage = page;
    return page;
  }

  void _reportRendered() {
    final callback = widget.onPageRendered;
    final renderRevision = widget.renderRevision;
    if (callback == null || _reportedRenderRevision == renderRevision) {
      return;
    }

    _reportedRenderRevision = renderRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback(widget.page, renderRevision);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;
}
