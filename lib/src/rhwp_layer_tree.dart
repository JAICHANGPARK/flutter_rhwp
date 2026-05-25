import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Parsed page layer tree returned by the rhwp core.
///
/// The upstream JSON shape can evolve, so this model keeps the original [raw]
/// map and exposes tolerant convenience accessors for common node fields.
class RhwpLayerTree {
  /// Creates a parsed page layer tree.
  RhwpLayerTree({
    required this.page,
    required Map<String, Object?> raw,
    required this.root,
    this.pageWidth,
    this.pageHeight,
  }) : raw = Map.unmodifiable(raw);

  /// Decodes a rhwp page layer tree JSON string.
  factory RhwpLayerTree.fromJsonString(int page, String source) {
    final decoded = jsonDecode(source);
    final raw = _asStringMap(decoded);
    if (raw == null) {
      throw FormatException('Expected page layer tree JSON object.', source);
    }

    return RhwpLayerTree(
      page: page,
      raw: raw,
      root: RhwpLayerNode.fromJson(raw),
      pageWidth: _number(raw['pageWidth']),
      pageHeight: _number(raw['pageHeight']),
    );
  }

  /// The zero-based page index this tree belongs to.
  final int page;

  /// The original decoded JSON object.
  final Map<String, Object?> raw;

  /// The root node of the decoded layer tree.
  final RhwpLayerNode root;

  /// The declared page width in rhwp page coordinates when provided.
  final double? pageWidth;

  /// The declared page height in rhwp page coordinates when provided.
  final double? pageHeight;

  /// The page size in rhwp page coordinates when it can be inferred.
  Size? get pageSize {
    final width = pageWidth ?? root.bounds?.width;
    final height = pageHeight ?? root.bounds?.height;
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  /// The root node and all descendant nodes in depth-first order.
  Iterable<RhwpLayerNode> get nodes => root.walk();

  /// Nodes with non-empty text content.
  Iterable<RhwpLayerNode> get textNodes {
    return nodes.where((node) => node.hasText);
  }

  /// Nodes with decoded bounds.
  Iterable<RhwpLayerNode> get boundedNodes {
    return nodes.where((node) => node.bounds != null);
  }

  /// Finds nodes whose [RhwpLayerNode.type] matches [type].
  Iterable<RhwpLayerNode> findByType(String type) {
    return nodes.where((node) => node.type == type);
  }

  /// Text run layouts decoded from `root.*.ops[type=textRun]`.
  late final List<RhwpTextRunLayout> textRuns = List.unmodifiable(
    _parseTextRuns(raw),
  );

  /// Table cell layouts decoded from table/tableCell layer groups.
  late final List<RhwpTableCellLayout> tableCells = List.unmodifiable(
    _parseTableCells(raw),
  );

  /// Maps a page-coordinate point to the smallest table cell containing it.
  RhwpTableCellLayout? tableCellForPoint(Offset point) {
    RhwpTableCellLayout? bestHit;
    var bestArea = double.infinity;

    for (final cell in tableCells) {
      if (!cell.bounds.contains(point)) {
        continue;
      }

      final area = cell.bounds.width * cell.bounds.height;
      if (area < bestArea) {
        bestArea = area;
        bestHit = cell;
      }
    }

    return bestHit;
  }

  /// Returns a caret rectangle in page coordinates for a paragraph offset.
  Rect? caretRectFor({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    for (final run in textRuns) {
      if (run.containsPosition(
        section: section,
        paragraph: paragraph,
        offset: offset,
      )) {
        return run.caretRectForOffset(offset);
      }
    }
    return null;
  }

  /// Returns selection rectangles in page coordinates for a single paragraph.
  List<Rect> selectionRectsFor({
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
  }) {
    final start = math.min(startOffset, endOffset);
    final end = math.max(startOffset, endOffset);
    if (start == end) {
      return const [];
    }

    final rects = <Rect>[];
    for (final run in textRuns) {
      if (run.section != section || run.paragraph != paragraph) {
        continue;
      }
      final rect = run.selectionRectForOffsets(start, end);
      if (rect != null) {
        rects.add(rect);
      }
    }
    return rects;
  }

  /// Returns selection rectangles in page coordinates for a document range.
  ///
  /// The returned rectangles are page-local. If the selection spans multiple
  /// pages, call this on each page layer tree and paint the non-empty result
  /// for that page.
  List<Rect> selectionRectsForRange({
    required int startSection,
    required int startParagraph,
    required int startOffset,
    required int endSection,
    required int endParagraph,
    required int endOffset,
  }) {
    final start = _TextPosition(
      section: startSection,
      paragraph: startParagraph,
      offset: startOffset,
    );
    final end = _TextPosition(
      section: endSection,
      paragraph: endParagraph,
      offset: endOffset,
    );
    if (start == end) {
      return const [];
    }

    final rangeStart = start.compareTo(end) <= 0 ? start : end;
    final rangeEnd = start.compareTo(end) <= 0 ? end : start;
    final rects = <Rect>[];

    for (final run in textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null) {
        continue;
      }

      final runStart = _TextPosition(
        section: section,
        paragraph: paragraph,
        offset: run.charStart,
      );
      final runEnd = _TextPosition(
        section: section,
        paragraph: paragraph,
        offset: run.charEnd,
      );
      if (runEnd.compareTo(rangeStart) <= 0 ||
          runStart.compareTo(rangeEnd) >= 0) {
        continue;
      }

      final rect = run.selectionRectForOffsets(
        _selectionStartForRun(run, rangeStart),
        _selectionEndForRun(run, rangeEnd),
      );
      if (rect != null) {
        rects.add(rect);
      }
    }

    return rects;
  }

  /// Returns text covered by a document range on this page.
  ///
  /// The result is page-local and inserts `\n` when text spans paragraphs.
  String textForRange({
    required int startSection,
    required int startParagraph,
    required int startOffset,
    required int endSection,
    required int endParagraph,
    required int endOffset,
  }) {
    final start = _TextPosition(
      section: startSection,
      paragraph: startParagraph,
      offset: startOffset,
    );
    final end = _TextPosition(
      section: endSection,
      paragraph: endParagraph,
      offset: endOffset,
    );
    if (start == end) {
      return '';
    }

    final rangeStart = start.compareTo(end) <= 0 ? start : end;
    final rangeEnd = start.compareTo(end) <= 0 ? end : start;
    final runs = <RhwpTextRunLayout>[];

    for (final run in textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null) {
        continue;
      }

      final runStart = _TextPosition(
        section: section,
        paragraph: paragraph,
        offset: run.charStart,
      );
      final runEnd = _TextPosition(
        section: section,
        paragraph: paragraph,
        offset: run.charEnd,
      );
      if (runEnd.compareTo(rangeStart) <= 0 ||
          runStart.compareTo(rangeEnd) >= 0) {
        continue;
      }
      runs.add(run);
    }

    runs.sort((a, b) {
      final sectionCompare = (a.section ?? 0).compareTo(b.section ?? 0);
      if (sectionCompare != 0) {
        return sectionCompare;
      }
      final paragraphCompare = (a.paragraph ?? 0).compareTo(b.paragraph ?? 0);
      if (paragraphCompare != 0) {
        return paragraphCompare;
      }
      return a.charStart.compareTo(b.charStart);
    });

    final buffer = StringBuffer();
    int? previousSection;
    int? previousParagraph;

    for (final run in runs) {
      final text = run.textForOffsets(
        _selectionStartForRun(run, rangeStart),
        _selectionEndForRun(run, rangeEnd),
      );
      if (text.isEmpty) {
        continue;
      }

      if (previousSection != null &&
          (run.section != previousSection ||
              run.paragraph != previousParagraph)) {
        buffer.write('\n');
      }
      buffer.write(text);
      previousSection = run.section;
      previousParagraph = run.paragraph;
    }

    return buffer.toString();
  }

  /// Maps a page-coordinate point to the nearest text source position.
  ///
  /// This is used by Flutter-native editor hit testing. The returned offset is
  /// the closest caret position on a text run whose vertical bounds are within
  /// [verticalTolerance] of [point].
  RhwpTextHitResult? textPositionForPoint(
    Offset point, {
    double verticalTolerance = 8.0,
  }) {
    RhwpTextHitResult? bestHit;
    var bestScore = double.infinity;

    for (final run in textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null) {
        continue;
      }

      final verticalDistance = _distanceToRange(
        point.dy,
        run.bounds.top,
        run.bounds.bottom,
      );
      if (verticalDistance > verticalTolerance) {
        continue;
      }

      final offset = run.closestOffsetForPoint(point);
      final caretPoint = run.pagePointForOffset(offset);
      final horizontalDistance = (caretPoint.dx - point.dx).abs();
      final score = verticalDistance * 10000 + horizontalDistance;
      if (score < bestScore) {
        bestScore = score;
        bestHit = RhwpTextHitResult(
          section: section,
          paragraph: paragraph,
          offset: offset,
          run: run,
          cellContext: run.cellContext,
        );
      }
    }

    return bestHit;
  }
}

/// A document text position returned from page hit testing.
class RhwpTextHitResult {
  /// Creates a text hit result.
  const RhwpTextHitResult({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.run,
    this.cellContext,
  });

  /// The document section index.
  final int section;

  /// The document paragraph index.
  final int paragraph;

  /// The UTF-16 paragraph offset nearest to the hit point.
  final int offset;

  /// The text run that produced the hit.
  final RhwpTextRunLayout run;

  /// Table cell context when the hit belongs to a cell text run.
  final RhwpCellTextContext? cellContext;
}

/// Source context for text rendered inside a table cell.
class RhwpCellTextContext {
  /// Creates a table cell text context.
  const RhwpCellTextContext({
    required this.parentParagraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.textDirection,
  });

  /// The parent paragraph containing the table control.
  final int parentParagraph;

  /// The table control index inside [parentParagraph].
  final int controlIndex;

  /// The table cell model index.
  final int cellIndex;

  /// The paragraph index inside the table cell.
  final int cellParagraph;

  /// The rhwp text direction value for this cell path entry.
  final int textDirection;
}

/// A table cell decoded from a rhwp page layer tree.
class RhwpTableCellLayout {
  /// Creates a decoded table cell layout.
  const RhwpTableCellLayout({
    required this.bounds,
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
    this.modelCellIndex,
  });

  /// The cell bounds in page coordinates.
  final Rect bounds;

  /// The document section index containing the table.
  final int section;

  /// The parent paragraph index containing the table control.
  final int paragraph;

  /// The table control index inside [paragraph].
  final int controlIndex;

  /// The table row coordinate for this cell.
  final int row;

  /// The table column coordinate for this cell.
  final int column;

  /// The number of rows spanned by this cell.
  final int rowSpan;

  /// The number of columns spanned by this cell.
  final int columnSpan;

  /// The optional model cell index in rhwp's table cell array.
  final int? modelCellIndex;

  /// The last row covered by this cell.
  int get endRow => row + _positiveSpan(rowSpan) - 1;

  /// The last column covered by this cell.
  int get endColumn => column + _positiveSpan(columnSpan) - 1;
}

/// A single node in a parsed rhwp page layer tree.
class RhwpLayerNode {
  /// Creates a parsed layer tree node.
  RhwpLayerNode({
    required Map<String, Object?> raw,
    required List<RhwpLayerNode> children,
    this.type,
    this.text,
    this.bounds,
  }) : raw = Map.unmodifiable(raw),
       children = List.unmodifiable(children);

  /// Decodes a node from a JSON object.
  factory RhwpLayerNode.fromJson(Map<String, Object?> json) {
    return RhwpLayerNode(
      raw: json,
      type: _firstString(json, const ['type', 'kind', 'name']),
      text: _firstString(json, const ['text', 'content', 'value']),
      bounds: _parseBounds(json),
      children: _parseChildren(json),
    );
  }

  /// The node type, kind, or name when present.
  final String? type;

  /// Text content carried by this node when present.
  final String? text;

  /// The decoded node bounds when common coordinate fields are present.
  final Rect? bounds;

  /// The original decoded JSON object for this node.
  final Map<String, Object?> raw;

  /// Child nodes decoded from common nested layer arrays.
  final List<RhwpLayerNode> children;

  /// Whether this node contains non-empty text.
  bool get hasText => text != null && text!.isNotEmpty;

  /// This node and all descendants in depth-first order.
  Iterable<RhwpLayerNode> walk() sync* {
    yield this;
    for (final child in children) {
      yield* child.walk();
    }
  }
}

/// A text run decoded from a rhwp page layer tree paint operation.
class RhwpTextRunLayout {
  /// Creates a decoded text run layout.
  RhwpTextRunLayout({
    required this.text,
    required this.bounds,
    required this.charStart,
    required this.charEnd,
    required List<RhwpTextClusterLayout> clusters,
    this.sourceId,
    this.stableSourceKey,
    this.section,
    this.paragraph,
    this.cellContext,
    this.transform,
  }) : clusters = List.unmodifiable(clusters);

  /// The text run content.
  final String text;

  /// The text run bounds in page coordinates.
  final Rect bounds;

  /// The optional source table id.
  final int? sourceId;

  /// The stable source key emitted by rhwp, for example
  /// `section:0/para:3/char:12`.
  final String? stableSourceKey;

  /// The document section index when [stableSourceKey] carries one.
  final int? section;

  /// The document paragraph index when [stableSourceKey] carries one.
  final int? paragraph;

  /// The paragraph UTF-16 offset where this run starts.
  final int charStart;

  /// The paragraph UTF-16 offset where this run ends.
  final int charEnd;

  /// Table cell source context when this run belongs to a cell.
  final RhwpCellTextContext? cellContext;

  /// Character cluster geometry in run-local coordinates.
  final List<RhwpTextClusterLayout> clusters;

  /// The affine transform from run-local coordinates to page coordinates.
  final RhwpAffineTransform? transform;

  /// Whether [offset] is covered by this run.
  bool containsPosition({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return this.section == section &&
        this.paragraph == paragraph &&
        offset >= charStart &&
        offset <= charEnd;
  }

  /// Returns a caret rectangle in page coordinates for [offset].
  Rect caretRectForOffset(int offset) {
    final point = pagePointForOffset(offset);
    final height = math.max(12.0, bounds.height);
    return Rect.fromLTWH(point.dx, bounds.top, 2, height);
  }

  /// Returns the page coordinate for [offset] on this run baseline.
  Offset pagePointForOffset(int offset) {
    final localX = _localXForOffset(offset);
    final point = Offset(localX, 0);
    return transform?.transform(point) ??
        Offset(bounds.left + localX, bounds.top);
  }

  /// Returns the closest paragraph offset to [point] in page coordinates.
  int closestOffsetForPoint(Offset point) {
    var bestOffset = charStart;
    var bestDistance = double.infinity;
    for (var offset = charStart; offset <= charEnd; offset += 1) {
      final caretPoint = pagePointForOffset(offset);
      final distance = (caretPoint.dx - point.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestOffset = offset;
      }
    }
    return bestOffset;
  }

  /// Returns the selected area for the overlap of [startOffset] and [endOffset].
  Rect? selectionRectForOffsets(int startOffset, int endOffset) {
    final start = math.max(math.min(startOffset, endOffset), charStart);
    final end = math.min(math.max(startOffset, endOffset), charEnd);
    if (start >= end) {
      return null;
    }

    final startPoint = pagePointForOffset(start);
    final endPoint = pagePointForOffset(end);
    final left = math.min(startPoint.dx, endPoint.dx);
    final right = math.max(startPoint.dx, endPoint.dx);
    return Rect.fromLTRB(
      left,
      bounds.top,
      math.max(left + 2, right),
      bounds.bottom,
    );
  }

  /// Returns the text covered by [startOffset] and [endOffset].
  String textForOffsets(int startOffset, int endOffset) {
    final start = math.max(math.min(startOffset, endOffset), charStart);
    final end = math.min(math.max(startOffset, endOffset), charEnd);
    if (start >= end) {
      return '';
    }

    final localStart = (start - charStart).clamp(0, text.length).toInt();
    final localEnd = (end - charStart).clamp(0, text.length).toInt();
    if (localStart >= localEnd) {
      return '';
    }
    return text.substring(localStart, localEnd);
  }

  double _localXForOffset(int offset) {
    final localOffset = (offset - charStart).clamp(0, charEnd - charStart);
    if (clusters.isEmpty) {
      final length = math.max(1, charEnd - charStart);
      return bounds.width * localOffset / length;
    }

    for (final cluster in clusters) {
      if (localOffset < cluster.startUtf16) {
        return cluster.origin.dx;
      }
      if (localOffset <= cluster.endUtf16) {
        final advance = cluster.advance?.dx ?? 0;
        final width = advance == 0 ? bounds.width / clusters.length : advance;
        final clusterLength = math.max(
          1,
          cluster.endUtf16 - cluster.startUtf16,
        );
        final progress = (localOffset - cluster.startUtf16) / clusterLength;
        return cluster.origin.dx + width * progress.clamp(0.0, 1.0);
      }
    }

    final last = clusters.last;
    return last.origin.dx + (last.advance?.dx ?? 0);
  }
}

/// A text cluster decoded from a rhwp text run.
class RhwpTextClusterLayout {
  /// Creates a decoded text cluster layout.
  const RhwpTextClusterLayout({
    required this.startUtf16,
    required this.endUtf16,
    required this.origin,
    this.advance,
  });

  /// The local UTF-16 start offset inside the run.
  final int startUtf16;

  /// The local UTF-16 end offset inside the run.
  final int endUtf16;

  /// The run-local baseline origin for this cluster.
  final Offset origin;

  /// The run-local advance for this cluster when provided.
  final Offset? advance;
}

/// A two-dimensional affine transform.
class RhwpAffineTransform {
  /// Creates an affine transform using Canvas-style `a,b,c,d,e,f` values.
  const RhwpAffineTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
  });

  /// Horizontal scale/skew component.
  final double a;

  /// Vertical skew component.
  final double b;

  /// Horizontal skew component.
  final double c;

  /// Vertical scale/skew component.
  final double d;

  /// Horizontal translation.
  final double e;

  /// Vertical translation.
  final double f;

  /// Applies this transform to [point].
  Offset transform(Offset point) {
    return Offset(
      a * point.dx + c * point.dy + e,
      b * point.dx + d * point.dy + f,
    );
  }
}

const _childKeys = [
  'children',
  'items',
  'nodes',
  'layers',
  'objects',
  'paragraphs',
  'lines',
  'runs',
  'spans',
  'elements',
];

const _boundsKeys = ['bounds', 'bbox', 'rect', 'frame'];

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? _firstString(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) {
      return value;
    }
  }
  return null;
}

List<RhwpLayerNode> _parseChildren(Map<String, Object?> json) {
  final children = <RhwpLayerNode>[];
  for (final key in _childKeys) {
    final value = json[key];
    if (value is List) {
      for (final item in value) {
        final child = _asStringMap(item);
        if (child != null) {
          children.add(RhwpLayerNode.fromJson(child));
        }
      }
    } else {
      final child = _asStringMap(value);
      if (child != null) {
        children.add(RhwpLayerNode.fromJson(child));
      }
    }
  }
  return children;
}

Rect? _parseBounds(Map<String, Object?> json) {
  for (final key in _boundsKeys) {
    final bounds = _parseBoundsObject(json[key]);
    if (bounds != null) {
      return bounds;
    }
  }

  return _parseBoundsMap(json, includeNested: false);
}

Rect? _parseBoundsObject(Object? value) {
  final map = _asStringMap(value);
  if (map != null) {
    return _parseBoundsMap(map);
  }

  if (value is List && value.length >= 4) {
    final x = _number(value[0]);
    final y = _number(value[1]);
    final width = _number(value[2]);
    final height = _number(value[3]);
    if (x != null && y != null && width != null && height != null) {
      return Rect.fromLTWH(x, y, width, height);
    }
  }

  return null;
}

Rect? _parseBoundsMap(Map<String, Object?> json, {bool includeNested = true}) {
  if (includeNested) {
    for (final key in _boundsKeys) {
      final bounds = _parseBoundsObject(json[key]);
      if (bounds != null) {
        return bounds;
      }
    }
  }

  final x = _number(json['x']);
  final y = _number(json['y']);
  final width = _number(json['width'] ?? json['w']);
  final height = _number(json['height'] ?? json['h']);
  if (x != null && y != null && width != null && height != null) {
    return Rect.fromLTWH(x, y, width, height);
  }

  final left = _number(json['left']);
  final top = _number(json['top']);
  final right = _number(json['right']);
  final bottom = _number(json['bottom']);
  if (left != null && top != null && right != null && bottom != null) {
    return Rect.fromLTRB(left, top, right, bottom);
  }

  return null;
}

double? _number(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _integer(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

int? _firstInteger(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = _integer(json[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int _positiveSpan(int value) {
  return value < 1 ? 1 : value;
}

List<RhwpTextRunLayout> _parseTextRuns(Map<String, Object?> raw) {
  final root = _asStringMap(raw['root']) ?? raw;
  final textSources = _parseTextSourceLookup(raw['textSources']);
  final runs = <RhwpTextRunLayout>[];
  _collectTextRuns(root, textSources, runs);
  return runs;
}

List<RhwpTableCellLayout> _parseTableCells(Map<String, Object?> raw) {
  final root = _asStringMap(raw['root']) ?? raw;
  final cells = <RhwpTableCellLayout>[];
  _collectTableCells(root, null, cells);
  return cells;
}

void _collectTableCells(
  Map<String, Object?> node,
  _TableLayerContext? context,
  List<RhwpTableCellLayout> cells,
) {
  final groupKind = _asStringMap(node['groupKind']);
  final kind = _firstString(groupKind ?? const {}, const ['kind']);
  var nextContext = context;

  if (groupKind != null && kind == 'table') {
    nextContext = _TableLayerContext.fromJson(groupKind) ?? context;
  } else if (groupKind != null && kind == 'tableCell' && context != null) {
    final cell = _parseTableCell(node, groupKind, context);
    if (cell != null) {
      cells.add(cell);
    }
  }

  for (final child in _childMaps(node)) {
    _collectTableCells(child, nextContext, cells);
  }
}

RhwpTableCellLayout? _parseTableCell(
  Map<String, Object?> node,
  Map<String, Object?> groupKind,
  _TableLayerContext context,
) {
  final bounds = _parseBounds(node);
  final row = _integer(groupKind['row']);
  final column = _integer(groupKind['col'] ?? groupKind['column']);
  if (bounds == null || row == null || column == null) {
    return null;
  }

  return RhwpTableCellLayout(
    bounds: bounds,
    section: context.section,
    paragraph: context.paragraph,
    controlIndex: context.controlIndex,
    row: row,
    column: column,
    rowSpan: _integer(groupKind['rowSpan']) ?? 1,
    columnSpan: _integer(groupKind['colSpan'] ?? groupKind['columnSpan']) ?? 1,
    modelCellIndex: _integer(groupKind['modelCellIndex']),
  );
}

Iterable<Map<String, Object?>> _childMaps(Map<String, Object?> json) sync* {
  for (final key in _childKeys) {
    final value = json[key];
    if (value is List) {
      for (final item in value) {
        final child = _asStringMap(item);
        if (child != null) {
          yield child;
        }
      }
    } else {
      final child = _asStringMap(value);
      if (child != null) {
        yield child;
      }
    }
  }
}

Map<int, Map<String, Object?>> _parseTextSourceLookup(Object? value) {
  final lookup = <int, Map<String, Object?>>{};
  if (value is! List) {
    return lookup;
  }

  for (final item in value) {
    final source = _asStringMap(item);
    final id = _integer(source?['id']);
    if (source != null && id != null) {
      lookup[id] = source;
    }
  }
  return lookup;
}

class _TableLayerContext {
  const _TableLayerContext({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  static _TableLayerContext? fromJson(Map<String, Object?> json) {
    final section = _firstInteger(json, const [
      'sectionIndex',
      'sectionIdx',
      'section',
      'secIdx',
      'sec',
    ]);
    final paragraph = _firstInteger(json, const [
      'paraIndex',
      'paragraph',
      'parentParaIdx',
      'parentPara',
      'para',
    ]);
    final controlIndex = _firstInteger(json, const [
      'controlIndex',
      'controlIdx',
      'ctrl',
    ]);

    if (section == null || paragraph == null || controlIndex == null) {
      return null;
    }

    return _TableLayerContext(
      section: section,
      paragraph: paragraph,
      controlIndex: controlIndex,
    );
  }

  final int section;
  final int paragraph;
  final int controlIndex;
}

void _collectTextRuns(
  Map<String, Object?> node,
  Map<int, Map<String, Object?>> textSources,
  List<RhwpTextRunLayout> runs,
) {
  final ops = node['ops'];
  if (ops is List) {
    for (final opValue in ops) {
      final op = _asStringMap(opValue);
      if (op == null) {
        continue;
      }
      if (op['type'] == 'textRun') {
        final run = _parseTextRun(op, textSources);
        if (run != null) {
          runs.add(run);
        }
      }
    }
  }

  final children = node['children'];
  if (children is List) {
    for (final childValue in children) {
      final child = _asStringMap(childValue);
      if (child != null) {
        _collectTextRuns(child, textSources, runs);
      }
    }
  }

  final child = _asStringMap(node['child']);
  if (child != null) {
    _collectTextRuns(child, textSources, runs);
  }
}

RhwpTextRunLayout? _parseTextRun(
  Map<String, Object?> op,
  Map<int, Map<String, Object?>> textSources,
) {
  final bounds = _parseBounds(op);
  if (bounds == null) {
    return null;
  }

  final source = _asStringMap(op['source']);
  final sourceId = _integer(source?['id']);
  final sourceEntry = sourceId == null ? null : textSources[sourceId];
  final stableSourceKey =
      _firstString(source ?? const {}, const ['stableSourceKey']) ??
      _firstString(sourceEntry ?? const {}, const ['stableSourceKey']);
  final sourceRange =
      _parseTextRange(_asStringMap(source?['utf16Range'])) ??
      _parseTextRange(_asStringMap(sourceEntry?['utf16Range']));
  final text = _firstString(op, const ['text']) ?? '';
  final sourcePosition = _parseStableSourceKey(stableSourceKey);
  final charStart = sourcePosition?.charStart ?? 0;
  final charLength = sourceRange == null
      ? text.length
      : math.max(0, sourceRange.end - sourceRange.start);

  return RhwpTextRunLayout(
    text: text,
    bounds: bounds,
    sourceId: sourceId,
    stableSourceKey: stableSourceKey,
    section: sourcePosition?.section,
    paragraph: sourcePosition?.paragraph,
    charStart: charStart,
    charEnd: charStart + charLength,
    cellContext: sourcePosition?.cellContext,
    transform: _parsePlacementTransform(op),
    clusters: _parseTextClusters(op['clusters']),
  );
}

_StableSourcePosition? _parseStableSourceKey(String? value) {
  if (value == null) {
    return null;
  }

  final match = RegExp(
    r'^section:(\d+)/para:(\d+)/char:(\d+)(?:/cell:(\d+):(.+))?',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  return _StableSourcePosition(
    section: int.parse(match.group(1)!),
    paragraph: int.parse(match.group(2)!),
    charStart: int.parse(match.group(3)!),
    cellContext: _parseCellTextContext(
      parentParagraph: _parseIntGroup(match, 4),
      path: match.group(5),
    ),
  );
}

RhwpCellTextContext? _parseCellTextContext({
  required int? parentParagraph,
  required String? path,
}) {
  if (parentParagraph == null || path == null || path.isEmpty) {
    return null;
  }

  final firstEntry = path.split('.').first;
  final parts = firstEntry.split(':');
  if (parts.length < 4) {
    return null;
  }

  final controlIndex = int.tryParse(parts[0]);
  final cellIndex = int.tryParse(parts[1]);
  final cellParagraph = int.tryParse(parts[2]);
  final textDirection = int.tryParse(parts[3]);
  if (controlIndex == null ||
      cellIndex == null ||
      cellParagraph == null ||
      textDirection == null) {
    return null;
  }

  return RhwpCellTextContext(
    parentParagraph: parentParagraph,
    controlIndex: controlIndex,
    cellIndex: cellIndex,
    cellParagraph: cellParagraph,
    textDirection: textDirection,
  );
}

int? _parseIntGroup(RegExpMatch match, int group) {
  final value = match.group(group);
  return value == null ? null : int.tryParse(value);
}

_TextRange? _parseTextRange(Map<String, Object?>? json) {
  if (json == null) {
    return null;
  }

  final start = _integer(json['start']);
  final end = _integer(json['end']);
  if (start == null || end == null) {
    return null;
  }
  return _TextRange(start: start, end: end);
}

RhwpAffineTransform? _parsePlacementTransform(Map<String, Object?> op) {
  final placement = _asStringMap(op['placement']);
  final transform = _asStringMap(placement?['runToPage']);
  if (transform == null) {
    return null;
  }

  final a = _number(transform['a']);
  final b = _number(transform['b']);
  final c = _number(transform['c']);
  final d = _number(transform['d']);
  final e = _number(transform['e']);
  final f = _number(transform['f']);
  if (a == null ||
      b == null ||
      c == null ||
      d == null ||
      e == null ||
      f == null) {
    return null;
  }

  return RhwpAffineTransform(a: a, b: b, c: c, d: d, e: e, f: f);
}

List<RhwpTextClusterLayout> _parseTextClusters(Object? value) {
  if (value is! List) {
    return const [];
  }

  final clusters = <RhwpTextClusterLayout>[];
  for (final item in value) {
    final cluster = _parseTextCluster(_asStringMap(item));
    if (cluster != null) {
      clusters.add(cluster);
    }
  }
  return clusters;
}

RhwpTextClusterLayout? _parseTextCluster(Map<String, Object?>? json) {
  if (json == null) {
    return null;
  }

  final range =
      _parseTextRange(_asStringMap(json['textRangeUtf16'])) ??
      _parseTextRange(_asStringMap(json['sourceRangeUtf16']));
  final origin = _parsePoint(json['origin']);
  if (range == null || origin == null) {
    return null;
  }

  return RhwpTextClusterLayout(
    startUtf16: range.start,
    endUtf16: range.end,
    origin: origin,
    advance: _parseVector(json['advance']),
  );
}

Offset? _parsePoint(Object? value) {
  final json = _asStringMap(value);
  if (json == null) {
    return null;
  }

  final x = _number(json['x']);
  final y = _number(json['y']);
  if (x == null || y == null) {
    return null;
  }
  return Offset(x, y);
}

Offset? _parseVector(Object? value) {
  final json = _asStringMap(value);
  if (json == null) {
    return null;
  }

  final dx = _number(json['dx']);
  final dy = _number(json['dy']);
  if (dx == null || dy == null) {
    return null;
  }
  return Offset(dx, dy);
}

class _StableSourcePosition {
  const _StableSourcePosition({
    required this.section,
    required this.paragraph,
    required this.charStart,
    this.cellContext,
  });

  final int section;
  final int paragraph;
  final int charStart;
  final RhwpCellTextContext? cellContext;
}

class _TextRange {
  const _TextRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _TextPosition {
  const _TextPosition({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  int compareTo(_TextPosition other) {
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

  @override
  bool operator ==(Object other) {
    return other is _TextPosition &&
        other.section == section &&
        other.paragraph == paragraph &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(section, paragraph, offset);
}

int _selectionStartForRun(RhwpTextRunLayout run, _TextPosition rangeStart) {
  if (run.section == rangeStart.section &&
      run.paragraph == rangeStart.paragraph) {
    return math.max(run.charStart, rangeStart.offset);
  }
  return run.charStart;
}

int _selectionEndForRun(RhwpTextRunLayout run, _TextPosition rangeEnd) {
  if (run.section == rangeEnd.section && run.paragraph == rangeEnd.paragraph) {
    return math.min(run.charEnd, rangeEnd.offset);
  }
  return run.charEnd;
}

double _distanceToRange(double value, double start, double end) {
  if (value < start) {
    return start - value;
  }
  if (value > end) {
    return value - end;
  }
  return 0;
}
