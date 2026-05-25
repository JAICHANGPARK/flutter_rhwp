import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'rhwp_document.dart';

typedef RhwpSvgBuilder = Widget Function(BuildContext context, String svg);

/// Builds an optional overlay for a rendered page.
typedef RhwpPageOverlayBuilder =
    Widget? Function(BuildContext context, int page, String svg);

Widget _defaultRhwpSvgBuilder(BuildContext context, String svg) {
  return SvgPicture.string(
    svg,
    fit: BoxFit.contain,
    clipBehavior: Clip.antiAlias,
  );
}

class RhwpViewerController extends ChangeNotifier {
  RhwpViewerController({double zoom = 1.0})
    : _zoom = zoom.clamp(0.25, 6.0).toDouble();

  double _zoom;

  double get zoom => _zoom;

  set zoom(double value) {
    final next = value.clamp(0.25, 6.0).toDouble();
    if (next == _zoom) {
      return;
    }
    _zoom = next;
    notifyListeners();
  }

  void zoomIn() => zoom = _zoom + 0.25;

  void zoomOut() => zoom = _zoom - 0.25;

  void resetZoom() => zoom = 1.0;
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
  });

  final RhwpDocument document;
  final RhwpViewerController? controller;
  final EdgeInsets padding;
  final double pageGap;
  final Color backgroundColor;
  final RhwpSvgBuilder svgBuilder;
  final RhwpPageOverlayBuilder? pageOverlayBuilder;

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

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpViewerController();
    _controller.addListener(_handleZoomChanged);
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
    _controller.removeListener(_handleZoomChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleZoomChanged() {
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
                    padding: widget.padding,
                    itemCount: pageCount,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: widget.pageGap),
                    itemBuilder: (context, index) {
                      return _RhwpSvgPage(
                        document: widget.document,
                        page: index,
                        svgBuilder: widget.svgBuilder,
                        pageOverlayBuilder: widget.pageOverlayBuilder,
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
}

class _RhwpSvgPage extends StatefulWidget {
  const _RhwpSvgPage({
    required this.document,
    required this.page,
    required this.svgBuilder,
    required this.pageOverlayBuilder,
    required this.ignorePageOverlayPointer,
  });

  final RhwpDocument document;
  final int page;
  final RhwpSvgBuilder svgBuilder;
  final RhwpPageOverlayBuilder? pageOverlayBuilder;
  final bool ignorePageOverlayPointer;

  @override
  State<_RhwpSvgPage> createState() => _RhwpSvgPageState();
}

class _RhwpSvgPageState extends State<_RhwpSvgPage>
    with AutomaticKeepAliveClientMixin {
  late Future<String> _svg;

  @override
  void initState() {
    super.initState();
    _svg = widget.document.renderPageSvg(widget.page);
  }

  @override
  void didUpdateWidget(covariant _RhwpSvgPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.page != widget.page) {
      _svg = widget.document.renderPageSvg(widget.page);
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
          final page = widget.svgBuilder(context, svg);
          final overlay = widget.pageOverlayBuilder?.call(
            context,
            widget.page,
            svg,
          );
          final content = overlay == null
              ? page
              : Stack(
                  fit: StackFit.passthrough,
                  children: [
                    page,
                    Positioned.fill(
                      child: widget.ignorePageOverlayPointer
                          ? IgnorePointer(child: overlay)
                          : overlay,
                    ),
                  ],
                );

          return Padding(padding: const EdgeInsets.all(8), child: content);
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
