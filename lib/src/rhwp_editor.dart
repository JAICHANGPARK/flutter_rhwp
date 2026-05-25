import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rhwp_document.dart';
import 'rhwp_layer_tree.dart';
import 'rhwp_viewer.dart';

class RhwpCursorPosition {
  const RhwpCursorPosition({
    this.section = 0,
    this.paragraph = 0,
    this.offset = 0,
  });

  final int section;
  final int paragraph;
  final int offset;

  int compareTo(RhwpCursorPosition other) {
    final sectionCompare = section.compareTo(other.section);
    if (sectionCompare != 0) {
      return sectionCompare;
    }

    final paragraphCompare = paragraph.compareTo(other.paragraph);
    if (paragraphCompare != 0) {
      return paragraphCompare;
    }

    return offset.compareTo(other.offset);
  }

  RhwpCursorPosition copyWith({int? section, int? paragraph, int? offset}) {
    return RhwpCursorPosition(
      section: section ?? this.section,
      paragraph: paragraph ?? this.paragraph,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RhwpCursorPosition &&
        other.section == section &&
        other.paragraph == paragraph &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(section, paragraph, offset);
}

class RhwpSelectionRange {
  const RhwpSelectionRange({required this.start, required this.end});

  factory RhwpSelectionRange.collapsed(RhwpCursorPosition cursor) {
    return RhwpSelectionRange(start: cursor, end: cursor);
  }

  final RhwpCursorPosition start;
  final RhwpCursorPosition end;

  bool get isCollapsed => start == end;

  RhwpCursorPosition get normalizedStart =>
      start.compareTo(end) <= 0 ? start : end;

  RhwpCursorPosition get normalizedEnd =>
      start.compareTo(end) <= 0 ? end : start;

  @override
  bool operator ==(Object other) {
    return other is RhwpSelectionRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class RhwpEditorController extends RhwpViewerController {
  RhwpEditorController({super.zoom})
    : _cursor = const RhwpCursorPosition(),
      _selection = RhwpSelectionRange.collapsed(const RhwpCursorPosition());

  RhwpCursorPosition _cursor;
  RhwpSelectionRange _selection;

  RhwpCursorPosition get cursor => _cursor;

  set cursor(RhwpCursorPosition value) {
    selection = RhwpSelectionRange.collapsed(value);
  }

  RhwpSelectionRange get selection => _selection;

  set selection(RhwpSelectionRange value) {
    if (value == _selection && value.end == _cursor) {
      return;
    }
    _selection = value;
    _cursor = value.end;
    notifyListeners();
  }

  void clearSelection() {
    selection = RhwpSelectionRange.collapsed(_cursor);
  }
}

class RhwpEditor extends StatefulWidget {
  const RhwpEditor({
    super.key,
    required this.document,
    this.controller,
    this.onChanged,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;

  @override
  State<RhwpEditor> createState() => _RhwpEditorState();
}

class _RhwpEditorState extends State<RhwpEditor> {
  late final RhwpEditorController _controller;
  late final bool _ownsController;
  final _textController = TextEditingController();
  final _sectionController = TextEditingController(text: '0');
  final _paragraphController = TextEditingController(text: '0');
  final _offsetController = TextEditingController(text: '0');
  Key _viewerKey = UniqueKey();
  RhwpLayerTree? _pageLayerTree;
  int _layoutGeneration = 0;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpEditorController();
    _controller.addListener(_handleControllerChanged);
    _syncCursorFields();
    _reloadPageLayerTree();
  }

  @override
  void didUpdateWidget(covariant RhwpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _pageLayerTree = null;
      _reloadPageLayerTree();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _textController.dispose();
    _sectionController.dispose();
    _paragraphController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncCursorFields();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncCursorFields() {
    final cursor = _controller.cursor;
    _setTextIfChanged(_sectionController, cursor.section.toString());
    _setTextIfChanged(_paragraphController, cursor.paragraph.toString());
    _setTextIfChanged(_offsetController, cursor.offset.toString());
  }

  void _setTextIfChanged(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _insertText() async {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }

    await _runEdit(() async {
      final cursor = _readCursor();
      await widget.document.insertText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        text: text,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset + text.length);
      _textController.clear();
    });
  }

  Future<void> _deleteBackward() async {
    await _runEdit(() async {
      final cursor = _readCursor();
      if (cursor.offset <= 0) {
        return;
      }
      await widget.document.deleteText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset - 1,
        count: 1,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset - 1);
    });
  }

  Future<void> _runEdit(Future<void> Function() edit) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await edit();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _viewerKey = UniqueKey();
      });
      _reloadPageLayerTree();
      widget.onChanged?.call(widget.document);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  RhwpCursorPosition _readCursor() {
    final cursor = RhwpCursorPosition(
      section: _parseNonNegative(_sectionController.text),
      paragraph: _parseNonNegative(_paragraphController.text),
      offset: _parseNonNegative(_offsetController.text),
    );
    _controller.cursor = cursor;
    return cursor;
  }

  int _parseNonNegative(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  Future<void> _reloadPageLayerTree() async {
    final generation = ++_layoutGeneration;
    try {
      final pageCount = await widget.document.pageCount;
      if (pageCount <= 0) {
        _setPageLayerTree(generation, null);
        return;
      }

      final tree = await widget.document.pageLayerTreeModel(0);
      _setPageLayerTree(generation, tree);
    } catch (_) {
      _setPageLayerTree(generation, null);
    }
  }

  void _setPageLayerTree(int generation, RhwpLayerTree? tree) {
    if (!mounted || generation != _layoutGeneration) {
      return;
    }
    setState(() {
      _pageLayerTree = tree;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RhwpViewer(
          key: _viewerKey,
          document: widget.document,
          controller: _controller,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _EditorSelectionOverlay(
              selection: _controller.selection,
              zoom: _controller.zoom,
              pageLayerTree: _pageLayerTree,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _EditorOverlay(
            busy: _busy,
            error: _error,
            textController: _textController,
            sectionController: _sectionController,
            paragraphController: _paragraphController,
            offsetController: _offsetController,
            onInsert: _insertText,
            onDeleteBackward: _deleteBackward,
          ),
        ),
      ],
    );
  }
}

class _EditorSelectionOverlay extends StatelessWidget {
  const _EditorSelectionOverlay({
    required this.selection,
    required this.zoom,
    required this.pageLayerTree,
  });

  final RhwpSelectionRange selection;
  final double zoom;
  final RhwpLayerTree? pageLayerTree;

  static const _pageInset = 48.0;
  static const _layerPageInset = 32.0;
  static const _lineHeight = 24.0;
  static const _characterWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final effectiveZoom = zoom.clamp(0.25, 6.0).toDouble();
    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    final top = _pageInset + start.paragraph * _lineHeight * effectiveZoom;
    final left = _pageInset + start.offset * _characterWidth * effectiveZoom;
    final caretLeft =
        _pageInset + selection.end.offset * _characterWidth * effectiveZoom;
    final height = math.max(18.0, _lineHeight * effectiveZoom);
    final selectionWidth = _selectionWidth(start, end, effectiveZoom);
    final layerCaretRect = _layerCaretRect(effectiveZoom);
    final layerSelectionRects = _layerSelectionRects(effectiveZoom);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (layerCaretRect != null) {
          return Stack(
            children: [
              if (!selection.isCollapsed)
                for (final (index, rect) in layerSelectionRects.indexed)
                  _positionedRect(
                    key: index == 0
                        ? const ValueKey('rhwp-editor-selection')
                        : ValueKey('rhwp-editor-selection-$index'),
                    rect: rect,
                    constraints: constraints,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              _positionedRect(
                key: const ValueKey('rhwp-editor-caret'),
                rect: layerCaretRect,
                constraints: constraints,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          );
        }

        final boundedTop = _bound(top, constraints.maxHeight, height);
        final children = <Widget>[
          if (!selection.isCollapsed)
            Positioned(
              key: const ValueKey('rhwp-editor-selection'),
              left: _bound(left, constraints.maxWidth, selectionWidth),
              top: boundedTop,
              width: selectionWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          Positioned(
            key: const ValueKey('rhwp-editor-caret'),
            left: _bound(caretLeft, constraints.maxWidth, 2),
            top: boundedTop,
            width: 2,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ];

        return Stack(children: children);
      },
    );
  }

  double _selectionWidth(
    RhwpCursorPosition start,
    RhwpCursorPosition end,
    double effectiveZoom,
  ) {
    if (start.section != end.section || start.paragraph != end.paragraph) {
      return 160 * effectiveZoom;
    }

    final selectedCharacters = math.max(1, end.offset - start.offset);
    return math.max(8.0, selectedCharacters * _characterWidth * effectiveZoom);
  }

  Rect? _layerCaretRect(double effectiveZoom) {
    final rect = pageLayerTree?.caretRectFor(
      section: selection.end.section,
      paragraph: selection.end.paragraph,
      offset: selection.end.offset,
    );
    return rect == null ? null : _pageRectToOverlay(rect, effectiveZoom, true);
  }

  List<Rect> _layerSelectionRects(double effectiveZoom) {
    if (selection.isCollapsed) {
      return const [];
    }

    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section || start.paragraph != end.paragraph) {
      return const [];
    }

    final rects = pageLayerTree?.selectionRectsFor(
      section: start.section,
      paragraph: start.paragraph,
      startOffset: start.offset,
      endOffset: end.offset,
    );
    if (rects == null) {
      return const [];
    }

    return [
      for (final rect in rects) _pageRectToOverlay(rect, effectiveZoom, false),
    ];
  }

  Rect _pageRectToOverlay(Rect rect, double effectiveZoom, bool caret) {
    return Rect.fromLTWH(
      _layerPageInset + rect.left * effectiveZoom,
      _layerPageInset + rect.top * effectiveZoom,
      math.max(caret ? 2.0 : 4.0, rect.width * effectiveZoom),
      math.max(12.0, rect.height * effectiveZoom),
    );
  }

  Positioned _positionedRect({
    required Key key,
    required Rect rect,
    required BoxConstraints constraints,
    required Widget child,
  }) {
    final left = _bound(rect.left, constraints.maxWidth, rect.width);
    final top = _bound(rect.top, constraints.maxHeight, rect.height);
    return Positioned(
      key: key,
      left: left,
      top: top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  double _bound(double value, double viewport, double extent) {
    if (!viewport.isFinite) {
      return math.max(0, value);
    }
    final maxValue = math.max(0, viewport - extent);
    return value.clamp(0.0, maxValue).toDouble();
  }
}

class _EditorOverlay extends StatelessWidget {
  const _EditorOverlay({
    required this.busy,
    required this.error,
    required this.textController,
    required this.sectionController,
    required this.paragraphController,
    required this.offsetController,
    required this.onInsert,
    required this.onDeleteBackward,
  });

  final bool busy;
  final Object? error;
  final TextEditingController textController;
  final TextEditingController sectionController;
  final TextEditingController paragraphController;
  final TextEditingController offsetController;
  final VoidCallback onInsert;
  final VoidCallback onDeleteBackward;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _NumberField(label: 'Sec', controller: sectionController),
            _NumberField(label: 'Para', controller: paragraphController),
            _NumberField(label: 'Offset', controller: offsetController),
            SizedBox(
              width: 240,
              child: TextField(
                controller: textController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Text',
                ),
                onSubmitted: (_) {
                  if (!busy) {
                    onInsert();
                  }
                },
              ),
            ),
            IconButton.filled(
              tooltip: 'Insert',
              onPressed: busy ? null : onInsert,
              icon: const Icon(Icons.keyboard_return),
            ),
            IconButton(
              tooltip: 'Delete backward',
              onPressed: busy ? null : onDeleteBackward,
              icon: const Icon(Icons.backspace_outlined),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  error.toString(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}
