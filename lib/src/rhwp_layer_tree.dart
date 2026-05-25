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

List<RhwpTextRunLayout> _parseTextRuns(Map<String, Object?> raw) {
  final root = _asStringMap(raw['root']) ?? raw;
  final textSources = _parseTextSourceLookup(raw['textSources']);
  final runs = <RhwpTextRunLayout>[];
  _collectTextRuns(root, textSources, runs);
  return runs;
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
    transform: _parsePlacementTransform(op),
    clusters: _parseTextClusters(op['clusters']),
  );
}

_StableSourcePosition? _parseStableSourceKey(String? value) {
  if (value == null) {
    return null;
  }

  final match = RegExp(
    r'^section:(\d+)/para:(\d+)/char:(\d+)',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  return _StableSourcePosition(
    section: int.parse(match.group(1)!),
    paragraph: int.parse(match.group(2)!),
    charStart: int.parse(match.group(3)!),
  );
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
  });

  final int section;
  final int paragraph;
  final int charStart;
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
