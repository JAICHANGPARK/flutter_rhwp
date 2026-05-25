import 'dart:convert';
import 'dart:ui' show Rect;

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
    );
  }

  /// The zero-based page index this tree belongs to.
  final int page;

  /// The original decoded JSON object.
  final Map<String, Object?> raw;

  /// The root node of the decoded layer tree.
  final RhwpLayerNode root;

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
