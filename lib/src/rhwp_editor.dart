import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        ValueListenable,
        ValueNotifier,
        defaultTargetPlatform,
        kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rhwp_document.dart';
import 'rhwp_layer_tree.dart';
import 'rhwp_viewer.dart';

typedef RhwpEditorImagePicker = FutureOr<RhwpEditorImage?> Function();

class RhwpEditorImage {
  const RhwpEditorImage({
    required this.bytes,
    required this.extension,
    this.width,
    this.height,
    this.naturalWidthPx,
    this.naturalHeightPx,
    this.description = '',
  });

  final Uint8List bytes;
  final String extension;
  final int? width;
  final int? height;
  final int? naturalWidthPx;
  final int? naturalHeightPx;
  final String description;
}

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

  @override
  String toString() {
    return 'RhwpCursorPosition(section: $section, paragraph: $paragraph, offset: $offset)';
  }
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

  @override
  String toString() {
    return 'RhwpSelectionRange(start: $start, end: $end)';
  }
}

/// A selected table cell or rectangular cell range in the native editor.
class RhwpTableCellSelection {
  /// Creates a selected table cell range.
  const RhwpTableCellSelection({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
    this.activeCellIndex,
    this.activeCellParagraph = 0,
    this.activeOffset = 0,
    this.isTextEditing = false,
  });

  /// Creates a selection from a decoded page layer tree cell.
  factory RhwpTableCellSelection.fromCell(RhwpTableCellLayout cell) {
    return RhwpTableCellSelection(
      section: cell.section,
      paragraph: cell.paragraph,
      controlIndex: cell.controlIndex,
      startRow: cell.row,
      startColumn: cell.column,
      endRow: cell.endRow,
      endColumn: cell.endColumn,
      activeCellIndex: cell.modelCellIndex,
    );
  }

  /// Creates a rectangular selection from two decoded page layer tree cells.
  factory RhwpTableCellSelection.fromCells(
    RhwpTableCellLayout anchor,
    RhwpTableCellLayout extent,
  ) {
    if (anchor.section != extent.section ||
        anchor.paragraph != extent.paragraph ||
        anchor.controlIndex != extent.controlIndex) {
      return RhwpTableCellSelection.fromCell(extent);
    }

    return RhwpTableCellSelection(
      section: anchor.section,
      paragraph: anchor.paragraph,
      controlIndex: anchor.controlIndex,
      startRow: math.min(anchor.row, extent.row),
      startColumn: math.min(anchor.column, extent.column),
      endRow: math.max(anchor.endRow, extent.endRow),
      endColumn: math.max(anchor.endColumn, extent.endColumn),
      activeCellIndex: anchor.modelCellIndex,
    );
  }

  /// Extends an existing table selection to include [extent].
  factory RhwpTableCellSelection.fromSelectionAndCell(
    RhwpTableCellSelection selection,
    RhwpTableCellLayout extent,
  ) {
    if (!selection.isSameTableAs(extent)) {
      return RhwpTableCellSelection.fromCell(extent);
    }

    return RhwpTableCellSelection(
      section: selection.section,
      paragraph: selection.paragraph,
      controlIndex: selection.controlIndex,
      startRow: math.min(selection.startRow, extent.row),
      startColumn: math.min(selection.startColumn, extent.column),
      endRow: math.max(selection.endRow, extent.endRow),
      endColumn: math.max(selection.endColumn, extent.endColumn),
      activeCellIndex: selection.activeCellIndex ?? extent.modelCellIndex,
      activeCellParagraph: selection.activeCellParagraph,
      activeOffset: selection.activeOffset,
      isTextEditing: false,
    );
  }

  /// Creates a selection from a table cell and text hit inside that cell.
  factory RhwpTableCellSelection.fromCellTextHit(
    RhwpTableCellLayout cell,
    RhwpTextHitResult hit,
  ) {
    final context = hit.cellContext;
    return RhwpTableCellSelection(
      section: cell.section,
      paragraph: cell.paragraph,
      controlIndex: cell.controlIndex,
      startRow: cell.row,
      startColumn: cell.column,
      endRow: cell.endRow,
      endColumn: cell.endColumn,
      activeCellIndex: context?.cellIndex ?? cell.modelCellIndex,
      activeCellParagraph: context?.cellParagraph ?? 0,
      activeOffset: hit.offset,
      isTextEditing: true,
    );
  }

  /// The document section index containing the table.
  final int section;

  /// The parent paragraph index containing the table control.
  final int paragraph;

  /// The table control index inside [paragraph].
  final int controlIndex;

  /// The first selected row.
  final int startRow;

  /// The first selected column.
  final int startColumn;

  /// The last selected row.
  final int endRow;

  /// The last selected column.
  final int endColumn;

  /// The active table cell model index used for text editing.
  final int? activeCellIndex;

  /// The active paragraph index inside [activeCellIndex].
  final int activeCellParagraph;

  /// The active UTF-16 offset inside [activeCellParagraph].
  final int activeOffset;

  /// Whether keyboard deletion should edit text at [activeOffset].
  final bool isTextEditing;

  /// Whether this selection intersects [cell].
  bool containsCell(RhwpTableCellLayout cell) {
    if (!isSameTableAs(cell)) {
      return false;
    }

    return cell.row <= endRow &&
        cell.endRow >= startRow &&
        cell.column <= endColumn &&
        cell.endColumn >= startColumn;
  }

  /// Creates a copy with selected fields changed.
  RhwpTableCellSelection copyWith({
    int? section,
    int? paragraph,
    int? controlIndex,
    int? startRow,
    int? startColumn,
    int? endRow,
    int? endColumn,
    int? activeCellIndex,
    int? activeCellParagraph,
    int? activeOffset,
    bool? isTextEditing,
  }) {
    return RhwpTableCellSelection(
      section: section ?? this.section,
      paragraph: paragraph ?? this.paragraph,
      controlIndex: controlIndex ?? this.controlIndex,
      startRow: startRow ?? this.startRow,
      startColumn: startColumn ?? this.startColumn,
      endRow: endRow ?? this.endRow,
      endColumn: endColumn ?? this.endColumn,
      activeCellIndex: activeCellIndex ?? this.activeCellIndex,
      activeCellParagraph: activeCellParagraph ?? this.activeCellParagraph,
      activeOffset: activeOffset ?? this.activeOffset,
      isTextEditing: isTextEditing ?? this.isTextEditing,
    );
  }

  /// Whether [cell] belongs to the same table control as this selection.
  bool isSameTableAs(RhwpTableCellLayout cell) {
    return cell.section == section &&
        cell.paragraph == paragraph &&
        cell.controlIndex == controlIndex;
  }

  @override
  bool operator ==(Object other) {
    return other is RhwpTableCellSelection &&
        other.section == section &&
        other.paragraph == paragraph &&
        other.controlIndex == controlIndex &&
        other.startRow == startRow &&
        other.startColumn == startColumn &&
        other.endRow == endRow &&
        other.endColumn == endColumn &&
        other.activeCellIndex == activeCellIndex &&
        other.activeCellParagraph == activeCellParagraph &&
        other.activeOffset == activeOffset &&
        other.isTextEditing == isTextEditing;
  }

  @override
  int get hashCode => Object.hash(
    section,
    paragraph,
    controlIndex,
    startRow,
    startColumn,
    endRow,
    endColumn,
    activeCellIndex,
    activeCellParagraph,
    activeOffset,
    isTextEditing,
  );

  @override
  String toString() {
    return 'RhwpTableCellSelection(section: $section, paragraph: $paragraph, controlIndex: $controlIndex, startRow: $startRow, startColumn: $startColumn, endRow: $endRow, endColumn: $endColumn, activeCellIndex: $activeCellIndex, activeCellParagraph: $activeCellParagraph, activeOffset: $activeOffset, isTextEditing: $isTextEditing)';
  }
}

/// A selected object/control in the native editor.
class RhwpObjectSelection {
  /// Creates a selected object/control range.
  const RhwpObjectSelection({
    required this.page,
    required this.bounds,
    required this.type,
    this.section,
    this.paragraph,
    this.controlIndex,
    this.objectIndex,
    this.lineStart,
    this.lineEnd,
  });

  /// Creates a selection from a decoded page layer tree object/control.
  factory RhwpObjectSelection.fromLayout(int page, RhwpObjectLayout object) {
    return RhwpObjectSelection(
      page: page,
      bounds: object.bounds,
      type: object.type,
      section: object.section,
      paragraph: object.paragraph,
      controlIndex: object.controlIndex,
      objectIndex: object.objectIndex,
      lineStart: object.lineStart,
      lineEnd: object.lineEnd,
    );
  }

  /// The rendered page that contains this object.
  final int page;

  /// The object bounds in page coordinates.
  final Rect bounds;

  /// The object/control type from the page layer tree.
  final String type;

  /// The document section index when available.
  final int? section;

  /// The parent paragraph index when available.
  final int? paragraph;

  /// The paragraph control index when available.
  final int? controlIndex;

  /// The object/model index when available.
  final int? objectIndex;

  /// Rendered start point for line-like objects, in page coordinates.
  final Offset? lineStart;

  /// Rendered end point for line-like objects, in page coordinates.
  final Offset? lineEnd;

  /// Whether this selected object should use line endpoint editing handles.
  bool get isLineObject {
    return (lineStart != null && lineEnd != null) || _isLineObjectType(type);
  }

  /// Creates a copy with selected fields changed.
  RhwpObjectSelection copyWith({
    int? page,
    Rect? bounds,
    String? type,
    int? section,
    int? paragraph,
    int? controlIndex,
    int? objectIndex,
    Offset? lineStart,
    Offset? lineEnd,
  }) {
    return RhwpObjectSelection(
      page: page ?? this.page,
      bounds: bounds ?? this.bounds,
      type: type ?? this.type,
      section: section ?? this.section,
      paragraph: paragraph ?? this.paragraph,
      controlIndex: controlIndex ?? this.controlIndex,
      objectIndex: objectIndex ?? this.objectIndex,
      lineStart: lineStart ?? this.lineStart,
      lineEnd: lineEnd ?? this.lineEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RhwpObjectSelection &&
        other.page == page &&
        other.bounds == bounds &&
        other.type == type &&
        other.section == section &&
        other.paragraph == paragraph &&
        other.controlIndex == controlIndex &&
        other.objectIndex == objectIndex &&
        other.lineStart == lineStart &&
        other.lineEnd == lineEnd;
  }

  @override
  int get hashCode => Object.hash(
    page,
    bounds,
    type,
    section,
    paragraph,
    controlIndex,
    objectIndex,
    lineStart,
    lineEnd,
  );

  @override
  String toString() {
    return 'RhwpObjectSelection(page: $page, bounds: $bounds, type: $type, section: $section, paragraph: $paragraph, controlIndex: $controlIndex, objectIndex: $objectIndex, lineStart: $lineStart, lineEnd: $lineEnd)';
  }
}

bool _isLineObjectType(String type) {
  final normalized = type.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  return normalized == 'line' ||
      normalized == 'connector' ||
      normalized == 'straightline';
}

Offset _lineStartForSelection(RhwpObjectSelection selection) {
  return selection.lineStart ?? selection.bounds.topLeft;
}

Offset _lineEndForSelection(RhwpObjectSelection selection) {
  return selection.lineEnd ?? selection.bounds.bottomRight;
}

Rect _lineBoundsFromEndpoints(Offset start, Offset end) {
  return Rect.fromLTRB(
    math.min(start.dx, end.dx),
    math.min(start.dy, end.dy),
    math.max(start.dx, end.dx),
    math.max(start.dy, end.dy),
  );
}

class _TableReference {
  const _TableReference({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    required this.column,
    required this.endRow,
    required this.endColumn,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;
  final int column;
  final int endRow;
  final int endColumn;
}

enum _EditorContextMenuAction {
  selectAll,
  cut,
  copy,
  paste,
  bold,
  italic,
  underline,
  strikethrough,
  charShape,
  paraShape,
  alignLeft,
  alignCenter,
  alignRight,
  alignJustify,
  insertTable,
  insertTableRow,
  insertTableColumn,
  mergeCells,
  splitCell,
  splitCellInto,
  deleteObject,
  bringObjectToFront,
  sendObjectToBack,
  moveObjectForward,
  moveObjectBackward,
  objectProperties,
}

enum _EditorClipboardDomain { text, objectControl }

enum _TableCellNavigationDirection { left, right, up, down }

class _ObjectPropertiesDialogResult {
  const _ObjectPropertiesDialogResult({
    required this.width,
    required this.height,
    required this.horzOffset,
    required this.vertOffset,
  });

  final int width;
  final int height;
  final int horzOffset;
  final int vertOffset;
}

class _CharShapeDialogResult {
  const _CharShapeDialogResult({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.superscript,
    required this.subscript,
    required this.emboss,
    required this.engrave,
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
    required this.shadeColor,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool superscript;
  final bool subscript;
  final bool emboss;
  final bool engrave;
  final String fontFamily;
  final int fontSize;
  final String textColor;
  final String shadeColor;
}

class _PendingCharFormat {
  const _PendingCharFormat({
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.superscript,
    this.subscript,
    this.emboss,
    this.engrave,
    this.fontFamily,
    this.fontSize,
    this.textColor,
    this.shadeColor,
  });

  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final bool? superscript;
  final bool? subscript;
  final bool? emboss;
  final bool? engrave;
  final String? fontFamily;
  final int? fontSize;
  final String? textColor;
  final String? shadeColor;

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      strikethrough == null &&
      superscript == null &&
      subscript == null &&
      emboss == null &&
      engrave == null &&
      fontFamily == null &&
      fontSize == null &&
      textColor == null &&
      shadeColor == null;

  factory _PendingCharFormat.fromCharProperties(RhwpCharProperties properties) {
    return _PendingCharFormat(
      bold: properties.bold,
      italic: properties.italic,
      underline: properties.underline,
      strikethrough: properties.strikethrough,
      superscript: properties.superscript,
      subscript: properties.subscript,
      emboss: properties.emboss,
      engrave: properties.engrave,
      fontFamily: properties.fontFamily,
      fontSize: properties.fontSize,
      textColor: properties.textColor,
      shadeColor: properties.shadeColor,
    );
  }

  _PendingCharFormat withFallback(_PendingCharFormat fallback) {
    return _PendingCharFormat(
      bold: bold ?? fallback.bold,
      italic: italic ?? fallback.italic,
      underline: underline ?? fallback.underline,
      strikethrough: strikethrough ?? fallback.strikethrough,
      superscript: superscript ?? fallback.superscript,
      subscript: subscript ?? fallback.subscript,
      emboss: emboss ?? fallback.emboss,
      engrave: engrave ?? fallback.engrave,
      fontFamily: fontFamily ?? fallback.fontFamily,
      fontSize: fontSize ?? fallback.fontSize,
      textColor: textColor ?? fallback.textColor,
      shadeColor: shadeColor ?? fallback.shadeColor,
    );
  }

  _PendingCharFormat merge({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) {
    return _PendingCharFormat(
      bold: bold == null ? this.bold : _toggleBool(this.bold, bold),
      italic: italic == null ? this.italic : _toggleBool(this.italic, italic),
      underline: underline == null
          ? this.underline
          : _toggleBool(this.underline, underline),
      strikethrough: strikethrough == null
          ? this.strikethrough
          : _toggleBool(this.strikethrough, strikethrough),
      superscript: superscript == null
          ? (subscript == true ? false : this.superscript)
          : _toggleBool(this.superscript, superscript),
      subscript: subscript == null
          ? (superscript == true ? false : this.subscript)
          : _toggleBool(this.subscript, subscript),
      emboss: emboss == null
          ? (engrave == true ? false : this.emboss)
          : _toggleBool(this.emboss, emboss),
      engrave: engrave == null
          ? (emboss == true ? false : this.engrave)
          : _toggleBool(this.engrave, engrave),
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      shadeColor: shadeColor ?? this.shadeColor,
    );
  }

  _PendingCharFormat mergeWithFallback(
    _PendingCharFormat fallback, {
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) {
    return _PendingCharFormat(
      bold: bold == null
          ? this.bold
          : _toggleBool(this.bold ?? fallback.bold, bold),
      italic: italic == null
          ? this.italic
          : _toggleBool(this.italic ?? fallback.italic, italic),
      underline: underline == null
          ? this.underline
          : _toggleBool(this.underline ?? fallback.underline, underline),
      strikethrough: strikethrough == null
          ? this.strikethrough
          : _toggleBool(
              this.strikethrough ?? fallback.strikethrough,
              strikethrough,
            ),
      superscript: superscript == null
          ? (subscript == true ? false : this.superscript)
          : _toggleBool(this.superscript ?? fallback.superscript, superscript),
      subscript: subscript == null
          ? (superscript == true ? false : this.subscript)
          : _toggleBool(this.subscript ?? fallback.subscript, subscript),
      emboss: emboss == null
          ? (engrave == true ? false : this.emboss)
          : _toggleBool(this.emboss ?? fallback.emboss, emboss),
      engrave: engrave == null
          ? (emboss == true ? false : this.engrave)
          : _toggleBool(this.engrave ?? fallback.engrave, engrave),
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      shadeColor: shadeColor ?? this.shadeColor,
    );
  }

  _PendingCharFormat applyExplicit({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) {
    return _PendingCharFormat(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      superscript: superscript ?? this.superscript,
      subscript: subscript ?? this.subscript,
      emboss: emboss ?? this.emboss,
      engrave: engrave ?? this.engrave,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      shadeColor: shadeColor ?? this.shadeColor,
    );
  }

  static bool _toggleBool(bool? current, bool requested) {
    if (!requested) {
      return false;
    }
    return current == true ? false : true;
  }
}

class _CurrentParaFormat {
  const _CurrentParaFormat({
    this.alignment,
    this.lineSpacing,
    this.lineSpacingType,
    this.indent,
    this.marginLeft,
    this.marginRight,
    this.spacingBefore,
    this.spacingAfter,
  });

  factory _CurrentParaFormat.fromParaProperties(RhwpParaProperties properties) {
    return _CurrentParaFormat(
      alignment: properties.alignment,
      lineSpacing: properties.lineSpacing,
      lineSpacingType: properties.lineSpacingType,
      indent: properties.indent,
      marginLeft: properties.marginLeft,
      marginRight: properties.marginRight,
      spacingBefore: properties.spacingBefore,
      spacingAfter: properties.spacingAfter,
    );
  }

  final String? alignment;
  final int? lineSpacing;
  final String? lineSpacingType;
  final int? indent;
  final int? marginLeft;
  final int? marginRight;
  final int? spacingBefore;
  final int? spacingAfter;

  bool isAlignment(String value) => alignment == value;
}

class _ParaShapeDialogResult {
  const _ParaShapeDialogResult({
    required this.alignment,
    required this.lineSpacing,
    required this.lineSpacingType,
    required this.indent,
    required this.marginLeft,
    required this.marginRight,
    required this.spacingBefore,
    required this.spacingAfter,
  });

  final String alignment;
  final int lineSpacing;
  final String lineSpacingType;
  final int indent;
  final int marginLeft;
  final int marginRight;
  final int spacingBefore;
  final int spacingAfter;
}

class _PageSetupDialogResult {
  const _PageSetupDialogResult({
    required this.width,
    required this.height,
    required this.marginLeft,
    required this.marginRight,
    required this.marginTop,
    required this.marginBottom,
    required this.marginHeader,
    required this.marginFooter,
    required this.marginGutter,
    required this.landscape,
    required this.binding,
  });

  final int width;
  final int height;
  final int marginLeft;
  final int marginRight;
  final int marginTop;
  final int marginBottom;
  final int marginHeader;
  final int marginFooter;
  final int marginGutter;
  final bool landscape;
  final int binding;
}

class _NewNumberDialogResult {
  const _NewNumberDialogResult({required this.startNumber});

  final int startNumber;
}

class _HeaderFooterTextDialogResult {
  const _HeaderFooterTextDialogResult({
    required this.text,
    required this.applyTo,
    required this.paragraph,
    required this.offset,
    required this.replaceExisting,
  });

  final String text;
  final int applyTo;
  final int paragraph;
  final int offset;
  final bool replaceExisting;
}

class _EquationDialogResult {
  const _EquationDialogResult({
    required this.script,
    required this.fontSize,
    required this.color,
  });

  final String script;
  final int fontSize;
  final int color;
}

class _SplitTableCellIntoDialogResult {
  const _SplitTableCellIntoDialogResult({
    required this.rows,
    required this.columns,
    required this.equalRowHeight,
    required this.mergeFirst,
  });

  final int rows;
  final int columns;
  final bool equalRowHeight;
  final bool mergeFirst;
}

class _ResolvedEditorImage {
  const _ResolvedEditorImage({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
    required this.naturalWidthPx,
    required this.naturalHeightPx,
    required this.description,
  });

  final Uint8List bytes;
  final String extension;
  final int width;
  final int height;
  final int naturalWidthPx;
  final int naturalHeightPx;
  final String description;
}

class _EditorSearchMatch {
  const _EditorSearchMatch({
    required this.page,
    required this.section,
    required this.paragraph,
    required this.startOffset,
    required this.endOffset,
    this.tableControlIndex,
    this.cellIndex,
    this.cellParagraph,
    this.cellRow,
    this.cellColumn,
    this.cellEndRow,
    this.cellEndColumn,
  });

  final int page;
  final int section;
  final int paragraph;
  final int startOffset;
  final int endOffset;
  final int? tableControlIndex;
  final int? cellIndex;
  final int? cellParagraph;
  final int? cellRow;
  final int? cellColumn;
  final int? cellEndRow;
  final int? cellEndColumn;

  bool get isTableCell => tableControlIndex != null && cellIndex != null;

  RhwpSelectionRange get selection {
    return RhwpSelectionRange(
      start: RhwpCursorPosition(
        section: section,
        paragraph: paragraph,
        offset: startOffset,
      ),
      end: RhwpCursorPosition(
        section: section,
        paragraph: paragraph,
        offset: endOffset,
      ),
    );
  }

  RhwpTableCellSelection? get tableCellSelection {
    final tableControlIndex = this.tableControlIndex;
    final cellIndex = this.cellIndex;
    final cellParagraph = this.cellParagraph;
    final cellRow = this.cellRow;
    final cellColumn = this.cellColumn;
    final cellEndRow = this.cellEndRow;
    final cellEndColumn = this.cellEndColumn;
    if (tableControlIndex == null ||
        cellIndex == null ||
        cellParagraph == null ||
        cellRow == null ||
        cellColumn == null ||
        cellEndRow == null ||
        cellEndColumn == null) {
      return null;
    }

    return RhwpTableCellSelection(
      section: section,
      paragraph: paragraph,
      controlIndex: tableControlIndex,
      startRow: cellRow,
      startColumn: cellColumn,
      endRow: cellEndRow,
      endColumn: cellEndColumn,
      activeCellIndex: cellIndex,
      activeCellParagraph: cellParagraph,
      activeOffset: startOffset,
      isTextEditing: true,
    );
  }

  bool matchesRun(RhwpTextRunLayout run) {
    if (run.section != section || run.paragraph != paragraph) {
      return false;
    }

    final context = run.cellContext;
    if (!isTableCell) {
      return context == null;
    }

    return context != null &&
        context.controlIndex == tableControlIndex &&
        context.cellIndex == cellIndex &&
        context.cellParagraph == cellParagraph;
  }

  _EditorSearchMatch copyWith({int? startOffset, int? endOffset}) {
    return _EditorSearchMatch(
      page: page,
      section: section,
      paragraph: paragraph,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      tableControlIndex: tableControlIndex,
      cellIndex: cellIndex,
      cellParagraph: cellParagraph,
      cellRow: cellRow,
      cellColumn: cellColumn,
      cellEndRow: cellEndRow,
      cellEndColumn: cellEndColumn,
    );
  }
}

/// Controller for the Flutter-native command editor overlay.
class RhwpEditorController extends RhwpViewerController {
  RhwpEditorController({super.zoom})
    : _cursor = const RhwpCursorPosition(),
      _selection = RhwpSelectionRange.collapsed(const RhwpCursorPosition());

  RhwpCursorPosition _cursor;
  RhwpSelectionRange _selection;
  RhwpTableCellSelection? _tableCellSelection;
  RhwpObjectSelection? _objectSelection;

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
    _objectSelection = null;
    notifyListeners();
  }

  void clearSelection() {
    selection = RhwpSelectionRange.collapsed(_cursor);
  }

  /// The active table cell selection for page overlay and table commands.
  RhwpTableCellSelection? get tableCellSelection => _tableCellSelection;

  set tableCellSelection(RhwpTableCellSelection? value) {
    if (value == _tableCellSelection) {
      return;
    }
    _tableCellSelection = value;
    if (value != null) {
      _objectSelection = null;
    }
    notifyListeners();
  }

  /// Selects the table cell decoded from the page layer tree.
  void selectTableCell(RhwpTableCellLayout cell) {
    tableCellSelection = RhwpTableCellSelection.fromCell(cell);
  }

  /// Selects the rectangular cell range between two page layer tree cells.
  void selectTableCellRange(
    RhwpTableCellLayout anchor,
    RhwpTableCellLayout extent,
  ) {
    tableCellSelection = RhwpTableCellSelection.fromCells(anchor, extent);
  }

  /// Clears the active table cell selection.
  void clearTableCellSelection() {
    tableCellSelection = null;
  }

  /// The active object/control selection for page overlay.
  RhwpObjectSelection? get objectSelection => _objectSelection;

  set objectSelection(RhwpObjectSelection? value) {
    if (value == _objectSelection) {
      return;
    }
    _objectSelection = value;
    if (value != null) {
      _tableCellSelection = null;
    }
    notifyListeners();
  }

  /// Clears the active object/control selection.
  void clearObjectSelection() {
    objectSelection = null;
  }
}

/// Explicit controller name for [RhwpCommandEditor].
typedef RhwpCommandEditorController = RhwpEditorController;

/// Flutter-native HWP editor surface.
///
/// This widget is the Flutter-native editor track. It renders pages through
/// [RhwpViewer], draws caret/selection overlays with Flutter widgets, shows a
/// native toolbar/status bar, and applies explicit edit commands through the
/// Rust bridge. It is intentionally separate from [RhwpFullEditor], which hosts
/// the upstream Web editor.
class RhwpEditor extends StatefulWidget {
  const RhwpEditor({
    super.key,
    required this.document,
    this.controller,
    this.onChanged,
    this.onOpenRequested,
    this.onImageRequested,
    this.onExported,
    this.editRefreshDelay = _defaultEditRefreshDelay,
    this.holdTextRefreshWhileFocused = false,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final RhwpEditorImagePicker? onImageRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;

  /// How long text-like edits wait before refreshing rendered page SVG.
  ///
  /// The document command is applied immediately. This delay only controls the
  /// heavier page render synchronization so typing can stay visually stable.
  final Duration editRefreshDelay;

  /// Keeps text-input page refresh deferred until focus actually leaves the
  /// editor.
  ///
  /// This is useful for large desktop documents where macOS, Windows, or Linux
  /// text-input focus churn can otherwise release the deferred SVG refresh
  /// between Space/text commits.
  final bool holdTextRefreshWhileFocused;

  @override
  State<RhwpEditor> createState() => _RhwpEditorState();
}

/// Public name for the Flutter-native editor track.
class RhwpNativeEditor extends StatelessWidget {
  const RhwpNativeEditor({
    super.key,
    required this.document,
    this.controller,
    this.onChanged,
    this.onOpenRequested,
    this.onImageRequested,
    this.onExported,
    this.editRefreshDelay = _defaultEditRefreshDelay,
    this.holdTextRefreshWhileFocused = false,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final RhwpEditorImagePicker? onImageRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;
  final Duration editRefreshDelay;
  final bool holdTextRefreshWhileFocused;

  @override
  Widget build(BuildContext context) {
    return RhwpEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
      onOpenRequested: onOpenRequested,
      onImageRequested: onImageRequested,
      onExported: onExported,
      editRefreshDelay: editRefreshDelay,
      holdTextRefreshWhileFocused: holdTextRefreshWhileFocused,
    );
  }
}

/// Compatibility name for the Flutter-native command editor surface.
///
/// Prefer [RhwpNativeEditor] for new code. This wrapper remains for apps that
/// adopted the earlier command-editor API name.
class RhwpCommandEditor extends StatelessWidget {
  const RhwpCommandEditor({
    super.key,
    required this.document,
    this.controller,
    this.onChanged,
    this.onOpenRequested,
    this.onImageRequested,
    this.onExported,
    this.editRefreshDelay = _defaultEditRefreshDelay,
    this.holdTextRefreshWhileFocused = false,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final RhwpEditorImagePicker? onImageRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;
  final Duration editRefreshDelay;
  final bool holdTextRefreshWhileFocused;

  @override
  Widget build(BuildContext context) {
    return RhwpNativeEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
      onOpenRequested: onOpenRequested,
      onImageRequested: onImageRequested,
      onExported: onExported,
      editRefreshDelay: editRefreshDelay,
      holdTextRefreshWhileFocused: holdTextRefreshWhileFocused,
    );
  }
}

const _defaultEditRefreshDelay = Duration(milliseconds: 350);

const _charColorSwatches = [
  (label: '검정', color: Color(0xff000000), value: '#000000'),
  (label: '빨강', color: Color(0xffdc2626), value: '#dc2626'),
  (label: '파랑', color: Color(0xff2563eb), value: '#2563eb'),
  (label: '초록', color: Color(0xff16a34a), value: '#16a34a'),
];

const _charShadeSwatches = [
  (label: '없음', color: Color(0xffffffff), value: '#ffffff'),
  (label: '노랑', color: Color(0xfffef08a), value: '#fef08a'),
  (label: '파랑', color: Color(0xffdbeafe), value: '#dbeafe'),
  (label: '초록', color: Color(0xffdcfce7), value: '#dcfce7'),
  (label: '분홍', color: Color(0xffffe4e6), value: '#ffe4e6'),
];

const _fontFamilyOptions = [
  '함초롬바탕',
  '함초롬돋움',
  '맑은 고딕',
  '돋움',
  '굴림',
  '바탕',
  'HY헤드라인M',
  'HY견고딕',
  'HY그래픽',
  'HY견명조',
  'Arial',
  'Times New Roman',
];

const _lineSpacingPresets = [100, 120, 130, 140, 150, 160, 180, 200, 250, 300];

const _cellFillSwatches = [
  (label: '노랑', color: Color(0xfffef08a), value: '#fef08a'),
  (label: '파랑', color: Color(0xffdbeafe), value: '#dbeafe'),
  (label: '초록', color: Color(0xffdcfce7), value: '#dcfce7'),
  (label: '분홍', color: Color(0xffffe4e6), value: '#ffe4e6'),
];

int _hwpFontSizeFromPointText(String text) {
  final points = double.tryParse(text.trim()) ?? 10.0;
  final clampedPoints = points.clamp(1.0, 200.0);
  return (clampedPoints * 100).round();
}

String _hwpFontSizeToPointText(int fontSize) {
  final points = fontSize / 100.0;
  return points.toStringAsFixed(1);
}

class _PendingTextOverlay {
  const _PendingTextOverlay({
    required this.page,
    required this.cursor,
    required this.text,
  });

  final int page;
  final RhwpCursorPosition cursor;
  final String text;

  _PendingTextOverlay copyWith({String? text}) {
    return _PendingTextOverlay(
      page: page,
      cursor: cursor,
      text: text ?? this.text,
    );
  }
}

class _PendingDeletionOverlay {
  const _PendingDeletionOverlay({required this.page, required this.range});

  final int page;
  final RhwpSelectionRange range;
}

class _TableCellTextSegment {
  const _TableCellTextSegment({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.row,
    required this.column,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int row;
  final int column;
  final int startOffset;
  final int endOffset;
  final String text;
}

class _TableCellDeleteRange {
  const _TableCellDeleteRange({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.startOffset,
    required this.endOffset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int startOffset;
  final int endOffset;

  _TableCellDeleteRange expandTo(_TableCellTextSegment segment) {
    return _TableCellDeleteRange(
      section: section,
      paragraph: paragraph,
      controlIndex: controlIndex,
      cellIndex: cellIndex,
      cellParagraph: cellParagraph,
      startOffset: math.min(startOffset, segment.startOffset),
      endOffset: math.max(endOffset, segment.endOffset),
    );
  }
}

class _TableCellParagraphTarget {
  const _TableCellParagraphTarget({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
}

class _RhwpEditorState extends State<RhwpEditor> with TextInputClient {
  late final RhwpEditorController _controller;
  late final bool _ownsController;
  final _toolbarKey = GlobalKey<_EditorToolbarState>();
  final _focusNode = FocusNode(debugLabel: 'RhwpNativeEditor');
  final _searchFocusNode = FocusNode(debugLabel: 'RhwpNativeEditorSearch');
  final _replaceFocusNode = FocusNode(debugLabel: 'RhwpNativeEditorReplace');
  final _textController = TextEditingController();
  final _sectionController = TextEditingController(text: '0');
  final _paragraphController = TextEditingController(text: '0');
  final _offsetController = TextEditingController(text: '0');
  final _tableRowsController = TextEditingController(text: '2');
  final _tableColumnsController = TextEditingController(text: '2');
  final _tableParagraphController = TextEditingController(text: '0');
  final _tableControlController = TextEditingController(text: '0');
  final _tableRowController = TextEditingController(text: '0');
  final _tableColumnController = TextEditingController(text: '0');
  final _tableEndRowController = TextEditingController(text: '1');
  final _tableEndColumnController = TextEditingController(text: '1');
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  TextInputConnection? _textInputConnection;
  Future<void> _textInputEditQueue = Future<void>.value();
  TextEditingValue _inputValue = TextEditingValue.empty;
  Timer? _textInputActionIgnoreTimer;
  Timer? _textInputFocusReleaseTimer;
  Timer? _desktopTextInputCommitHoldTimer;
  Timer? _deferredEditRefreshTimer;
  Timer? _searchInputDebounceTimer;
  int _pendingTextInputCommits = 0;
  List<_PendingTextOverlay> _pendingTextOverlays = const [];
  final _pendingTextOverlaysListenable =
      ValueNotifier<List<_PendingTextOverlay>>(const []);
  int? _pendingTextRefreshRevision;
  List<_PendingDeletionOverlay> _pendingDeletionOverlays = const [];
  int? _pendingDeletionRefreshRevision;
  final _composingTextListenable = ValueNotifier<String?>(null);
  int _renderRevision = 0;
  List<_EditorSearchMatch> _searchMatches = const [];
  int _activeSearchMatch = -1;
  int? _pageCountValue;
  _PendingCharFormat _pendingCharFormat = const _PendingCharFormat();
  _PendingCharFormat _currentCharFormat = const _PendingCharFormat();
  _CurrentParaFormat _currentParaFormat = const _CurrentParaFormat();
  _EditorClipboardDomain? _clipboardDomain;
  final _undoSnapshots = <int>[];
  final _redoSnapshots = <int>[];
  bool _busy = false;
  bool _visibleBusy = false;
  bool _searching = false;
  bool _ignoreTextInputActions = false;
  bool _desktopTextInputCommitHoldActive = false;
  bool _hasDeferredEditRefresh = false;
  bool _deferredEditRefreshAwaitsTextInput = false;
  bool _textRefreshHeldForFocusedInput = false;
  bool _textInputUndoBatchOpen = false;
  bool _suppressControllerChangedSetState = false;
  bool _showParagraphMarks = false;
  bool _showTransparentTableBorders = false;
  bool _overwriteMode = false;
  Object? _error;
  int _charFormatQueryRevision = 0;
  int _paraFormatQueryRevision = 0;

  static const _maxUndoSnapshots = 100;
  static const _textInputActionIgnoreWindow = Duration(milliseconds: 800);
  static const _searchInputDebounceDelay = Duration(milliseconds: 300);
  static const _minimumDesktopTextInputFocusReleaseDelay = Duration(
    milliseconds: 900,
  );
  static const _maximumDesktopTextInputFocusReleaseDelay = Duration(seconds: 5);
  static const _desktopTextInputCommitHoldWindow = Duration(milliseconds: 1400);
  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpEditorController();
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    FocusManager.instance.addListener(_handlePrimaryFocusChanged);
    _syncCursorFields();
    unawaited(_syncCurrentCharFormat());
    unawaited(_syncCurrentParaFormat());
    _loadPageCount();
  }

  @override
  void didUpdateWidget(covariant RhwpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _cancelDeferredEditRefresh();
      _renderRevision += 1;
      _pageCountValue = null;
      _currentCharFormat = const _PendingCharFormat();
      _currentParaFormat = const _CurrentParaFormat();
      _charFormatQueryRevision += 1;
      _paraFormatQueryRevision += 1;
      unawaited(_syncCurrentCharFormat());
      unawaited(_syncCurrentParaFormat());
      _loadPageCount();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    FocusManager.instance.removeListener(_handlePrimaryFocusChanged);
    _textInputActionIgnoreTimer?.cancel();
    _textInputFocusReleaseTimer?.cancel();
    _desktopTextInputCommitHoldTimer?.cancel();
    _searchInputDebounceTimer?.cancel();
    _pendingTextInputCommits = 0;
    _cancelDeferredEditRefresh();
    _closeTextInput();
    _pendingTextOverlaysListenable.dispose();
    _composingTextListenable.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _replaceFocusNode.dispose();
    _textController.dispose();
    _sectionController.dispose();
    _paragraphController.dispose();
    _offsetController.dispose();
    _tableRowsController.dispose();
    _tableColumnsController.dispose();
    _tableParagraphController.dispose();
    _tableControlController.dispose();
    _tableRowController.dispose();
    _tableColumnController.dispose();
    _tableEndRowController.dispose();
    _tableEndColumnController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _inputValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  void _handleControllerChanged() {
    final tableSelection = _controller.tableCellSelection;
    if (tableSelection == null) {
      final objectSelection = _controller.objectSelection;
      if (objectSelection == null) {
        _syncCursorFields();
      } else {
        _syncObjectSelectionFields(objectSelection);
      }
    } else {
      _syncTableSelectionFields(tableSelection);
    }
    if (mounted && !_suppressControllerChangedSetState) {
      setState(() {});
      unawaited(_syncCurrentCharFormat());
      unawaited(_syncCurrentParaFormat());
    }
  }

  Future<void> _syncCurrentCharFormat() async {
    if (_busy ||
        _controller.objectSelection != null ||
        _hasPendingOptimisticTextEdit ||
        _pendingTextInputCommits > 0) {
      return;
    }

    final revision = ++_charFormatQueryRevision;
    try {
      final tableSelection = _controller.tableCellSelection;
      final RhwpCharProperties properties;
      if (tableSelection?.activeCellIndex != null) {
        properties = await widget.document.cellCharPropertiesAt(
          section: tableSelection!.section,
          paragraph: tableSelection.paragraph,
          controlIndex: tableSelection.controlIndex,
          cellIndex: tableSelection.activeCellIndex!,
          cellParagraph: tableSelection.activeCellParagraph,
          offset: tableSelection.activeOffset,
        );
      } else {
        final selection = _controller.selection;
        final cursor = selection.isCollapsed
            ? _controller.cursor
            : selection.normalizedStart;
        properties = await widget.document.charPropertiesAt(
          section: cursor.section,
          paragraph: cursor.paragraph,
          offset: cursor.offset,
        );
      }

      if (!mounted || revision != _charFormatQueryRevision) {
        return;
      }
      setState(() {
        _currentCharFormat = _PendingCharFormat.fromCharProperties(properties);
      });
    } catch (_) {
      // Some documents do not expose style information for every cursor target.
    }
  }

  Future<void> _syncCurrentParaFormat() async {
    if (_busy ||
        _controller.objectSelection != null ||
        _hasPendingOptimisticTextEdit ||
        _pendingTextInputCommits > 0) {
      return;
    }

    final revision = ++_paraFormatQueryRevision;
    try {
      final tableSelection = _controller.tableCellSelection;
      final RhwpParaProperties properties;
      if (tableSelection?.activeCellIndex != null) {
        properties = await widget.document.cellParaPropertiesAt(
          section: tableSelection!.section,
          paragraph: tableSelection.paragraph,
          controlIndex: tableSelection.controlIndex,
          cellIndex: tableSelection.activeCellIndex!,
          cellParagraph: tableSelection.activeCellParagraph,
        );
      } else {
        final selection = _controller.selection;
        final cursor = selection.isCollapsed
            ? _controller.cursor
            : selection.normalizedStart;
        properties = await widget.document.paraPropertiesAt(
          section: cursor.section,
          paragraph: cursor.paragraph,
        );
      }

      if (!mounted || revision != _paraFormatQueryRevision) {
        return;
      }
      setState(() {
        _currentParaFormat = _CurrentParaFormat.fromParaProperties(properties);
      });
    } catch (_) {
      // Some documents do not expose paragraph information for every target.
    }
  }

  void _syncCursorFields() {
    final cursor = _controller.cursor;
    _setTextIfChanged(_sectionController, cursor.section.toString());
    _setTextIfChanged(_paragraphController, cursor.paragraph.toString());
    _setTextIfChanged(_offsetController, cursor.offset.toString());
  }

  void _syncTableSelectionFields(RhwpTableCellSelection selection) {
    _setTextIfChanged(_sectionController, selection.section.toString());
    _setTextIfChanged(
      _tableParagraphController,
      selection.paragraph.toString(),
    );
    _setTextIfChanged(
      _tableControlController,
      selection.controlIndex.toString(),
    );
    _setTextIfChanged(_tableRowController, selection.startRow.toString());
    _setTextIfChanged(_tableColumnController, selection.startColumn.toString());
    _setTextIfChanged(_tableEndRowController, selection.endRow.toString());
    _setTextIfChanged(
      _tableEndColumnController,
      selection.endColumn.toString(),
    );
    _setTextIfChanged(_offsetController, selection.activeOffset.toString());
  }

  void _syncObjectSelectionFields(RhwpObjectSelection selection) {
    final section = selection.section;
    if (section != null) {
      _setTextIfChanged(_sectionController, section.toString());
    }

    final paragraph = selection.paragraph;
    if (paragraph != null) {
      _setTextIfChanged(_paragraphController, paragraph.toString());
      _setTextIfChanged(_tableParagraphController, paragraph.toString());
    }

    final controlIndex = selection.controlIndex;
    if (controlIndex != null) {
      _setTextIfChanged(_tableControlController, controlIndex.toString());
    }
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

  void _toggleParagraphMarks() {
    setState(() {
      _showParagraphMarks = !_showParagraphMarks;
    });
    _focusEditor();
  }

  void _toggleTransparentTableBorders() {
    setState(() {
      _showTransparentTableBorders = !_showTransparentTableBorders;
    });
    _focusEditor();
  }

  void _toggleOverwriteMode() {
    setState(() {
      _overwriteMode = !_overwriteMode;
    });
    _focusEditor();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _textInputFocusReleaseTimer?.cancel();
      _textInputFocusReleaseTimer = null;
      _holdDeferredEditRefreshForTextInput();
      _openTextInput();
    } else {
      if (_shouldDelayDesktopTextInputFocusRelease) {
        _scheduleDesktopTextInputFocusRelease();
      } else {
        _closeTextInput();
      }
    }
  }

  void _handlePrimaryFocusChanged() {
    if (!mounted ||
        !_textRefreshHeldForFocusedInput ||
        !_hasDeferredEditRefresh) {
      return;
    }
    if (!_hasExternalPrimaryFocus) {
      return;
    }

    _textRefreshHeldForFocusedInput = false;
    _releaseDeferredEditRefreshFromTextInput(force: true);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }

    final shortcutPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!shortcutPressed) {
      return;
    }

    if (event.scrollDelta.dy < 0) {
      _controller.zoomIn();
    } else {
      _controller.zoomOut();
    }
    _focusEditor();
  }

  Future<void> _loadPageCount() async {
    try {
      final pageCount = await widget.document.pageCount;
      if (!mounted) {
        return;
      }
      setState(() {
        _pageCountValue = pageCount;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _showGoToPageDialog() async {
    final pageCount = _pageCountValue;
    if (_busy || pageCount == null || pageCount <= 0) {
      return;
    }

    final page = await showDialog<int>(
      context: context,
      builder: (context) => _GoToPageDialog(
        currentPage: _controller.currentPage,
        pageCount: pageCount,
      ),
    );
    if (!mounted) {
      return;
    }
    if (page == null) {
      _focusEditor();
      return;
    }

    await _controller.goToPage(page - 1);
    if (mounted) {
      _focusEditor();
    }
  }

  Future<void> _insertText() async {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }

    if (_editableTableCellSelection != null) {
      await _insertTextInSelectedTableCell(text, clearTextController: true);
      return;
    }

    await _runEdit(() async {
      final selection = _controller.selection;
      final cursor = selection.isCollapsed
          ? _readCursor()
          : selection.normalizedStart;
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      } else {
        await _deleteOverwriteText(cursor, text);
      }
      await widget.document.insertText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        text: text,
      );
      await _applyPendingCharFormatToInsertedText(cursor: cursor, text: text);
      _controller.cursor = cursor.copyWith(offset: cursor.offset + text.length);
      _textController.clear();
    });
  }

  Future<void> _exportFromEditor(RhwpExportFormat format) async {
    final onExported = widget.onExported;
    if (_busy || onExported == null) {
      return;
    }

    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      final exported = await widget.document.exportDocument(format);
      await onExported(exported);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }
  }

  Future<void> _requestOpenFromEditor() async {
    final onOpenRequested = widget.onOpenRequested;
    if (_busy || onOpenRequested == null) {
      return;
    }

    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      await onOpenRequested();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }
  }

  Future<void> _showDocumentInfoDialog() async {
    if (_busy) {
      return;
    }

    RhwpDocumentMetadata? metadata;
    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      metadata = await widget.document.metadata();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }

    if (!mounted || metadata == null) {
      return;
    }
    final dialogMetadata = metadata;

    await showDialog<void>(
      context: context,
      builder: (context) => _DocumentInfoDialog(metadata: dialogMetadata),
    );
    _focusEditor();
  }

  Future<void> _showCompareDialog() async {
    if (_busy) {
      return;
    }

    String? sourceText;
    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      sourceText = await widget.document.extractText();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }

    if (!mounted || sourceText == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _CompareDialog(sourceText: sourceText!),
    );
    _focusEditor();
  }

  Future<void> _insertCommittedText(
    String text, {
    bool awaitTextInputBeforeRefresh = false,
    bool visibleBusy = true,
  }) async {
    if (text.isEmpty || _busy) {
      return;
    }

    if (_editableTableCellSelection != null) {
      await _insertTextInSelectedTableCell(
        text,
        deferRefresh: true,
        awaitTextInputBeforeRefresh: awaitTextInputBeforeRefresh,
        visibleBusy: visibleBusy,
      );
      return;
    }

    late RhwpCursorPosition insertCursor;
    RhwpSelectionRange? deletedRange;
    final edited = await _runEdit(
      () async {
        final selection = _controller.selection;
        final cursor = selection.isCollapsed
            ? _controller.cursor
            : selection.normalizedStart;
        insertCursor = cursor;
        if (!selection.isCollapsed) {
          if (await _deleteSelectedText(selection)) {
            deletedRange = selection;
          }
        } else {
          deletedRange = await _deleteOverwriteText(cursor, text);
        }
        await widget.document.insertText(
          section: cursor.section,
          paragraph: cursor.paragraph,
          offset: cursor.offset,
          text: text,
        );
        await _applyPendingCharFormatToInsertedText(cursor: cursor, text: text);
        final nextCursor = cursor.copyWith(offset: cursor.offset + text.length);
        if (awaitTextInputBeforeRefresh) {
          _setCursorForPendingText(nextCursor);
        } else {
          _controller.cursor = nextCursor;
        }
      },
      deferRefresh: true,
      awaitTextInputBeforeRefresh: awaitTextInputBeforeRefresh,
      visibleBusy: visibleBusy,
      mergeIntoTextInputUndoBatch: awaitTextInputBeforeRefresh,
    );
    if (edited) {
      if (deletedRange != null) {
        _recordPendingDeletionOverlay(deletedRange!);
      }
      _recordPendingTextOverlay(insertCursor, text);
    }
  }

  Future<RhwpSelectionRange?> _deleteOverwriteText(
    RhwpCursorPosition cursor,
    String text,
  ) async {
    if (!_overwriteMode || text.isEmpty || text.contains('\n')) {
      return null;
    }

    final int? endOffset;
    try {
      endOffset = await _paragraphEndOffsetFor(cursor);
    } catch (_) {
      return null;
    }
    if (endOffset == null || cursor.offset >= endOffset) {
      return null;
    }

    final count = math.min(text.length, endOffset - cursor.offset);
    if (count <= 0) {
      return null;
    }

    await widget.document.deleteText(
      section: cursor.section,
      paragraph: cursor.paragraph,
      offset: cursor.offset,
      count: count,
    );
    return RhwpSelectionRange(
      start: cursor,
      end: cursor.copyWith(offset: cursor.offset + count),
    );
  }

  Future<void> _applyPendingCharFormatToInsertedText({
    required RhwpCursorPosition cursor,
    required String text,
  }) async {
    final pending = _pendingCharFormat;
    if (pending.isEmpty || text.isEmpty || text.contains('\n')) {
      return;
    }

    await widget.document.applyCharFormatRange(
      section: cursor.section,
      startParagraph: cursor.paragraph,
      startOffset: cursor.offset,
      endParagraph: cursor.paragraph,
      endOffset: cursor.offset + text.length,
      bold: pending.bold,
      italic: pending.italic,
      underline: pending.underline,
      strikethrough: pending.strikethrough,
      superscript: pending.superscript,
      subscript: pending.subscript,
      emboss: pending.emboss,
      engrave: pending.engrave,
      fontFamily: pending.fontFamily,
      fontSize: pending.fontSize,
      textColor: pending.textColor,
      shadeColor: pending.shadeColor,
    );
  }

  Future<void> _applyPendingCharFormatToInsertedTableCellText({
    required RhwpTableCellSelection tableSelection,
    required int startOffset,
    required int endOffset,
    required String text,
  }) async {
    final pending = _pendingCharFormat;
    final cellIndex = tableSelection.activeCellIndex;
    if (pending.isEmpty ||
        cellIndex == null ||
        text.isEmpty ||
        text.contains('\n') ||
        startOffset >= endOffset) {
      return;
    }

    await widget.document.applyCharFormatInTableCell(
      section: tableSelection.section,
      paragraph: tableSelection.paragraph,
      controlIndex: tableSelection.controlIndex,
      cellIndex: cellIndex,
      cellParagraph: tableSelection.activeCellParagraph,
      startOffset: startOffset,
      endOffset: endOffset,
      bold: pending.bold,
      italic: pending.italic,
      underline: pending.underline,
      strikethrough: pending.strikethrough,
      superscript: pending.superscript,
      subscript: pending.subscript,
      emboss: pending.emboss,
      engrave: pending.engrave,
      fontFamily: pending.fontFamily,
      fontSize: pending.fontSize,
      textColor: pending.textColor,
      shadeColor: pending.shadeColor,
    );
  }

  void _queueCommittedText(String text) {
    if (text.isEmpty) {
      return;
    }

    if (widget.holdTextRefreshWhileFocused && _isDesktopTextInputPlatform) {
      _textRefreshHeldForFocusedInput = true;
    }
    _beginTextInputCommit();
    final previous = _textInputEditQueue;
    _textInputEditQueue = () async {
      try {
        await previous;
      } catch (_) {
        // Keep later input commits moving after an earlier edit error.
      }
      if (!mounted) {
        _endTextInputCommit();
        return;
      }
      try {
        await _insertCommittedText(
          text,
          awaitTextInputBeforeRefresh: true,
          visibleBusy: false,
        );
      } finally {
        _endTextInputCommit();
      }
    }();
    unawaited(_textInputEditQueue);
  }

  Future<void> _insertTextInSelectedTableCell(
    String text, {
    bool clearTextController = false,
    bool deferRefresh = false,
    bool awaitTextInputBeforeRefresh = false,
    bool visibleBusy = true,
  }) async {
    final tableSelection = _editableTableCellSelection;
    if (tableSelection == null || _busy) {
      return;
    }

    final offset = _parseNonNegative(_offsetController.text);
    RhwpSelectionRange? deletedRange;
    final edited = await _runEdit(
      () async {
        deletedRange = await _deleteOverwriteTextInSelectedTableCell(
          tableSelection,
          offset,
          text,
        );
        final result = await widget.document.insertTextInTableCell(
          section: tableSelection.section,
          paragraph: tableSelection.paragraph,
          controlIndex: tableSelection.controlIndex,
          cellIndex: tableSelection.activeCellIndex!,
          cellParagraph: tableSelection.activeCellParagraph,
          offset: offset,
          text: text,
        );
        final nextOffset =
            _readIntResult(result, 'charOffset') ?? offset + text.length;
        await _applyPendingCharFormatToInsertedTableCellText(
          tableSelection: tableSelection,
          startOffset: offset,
          endOffset: nextOffset,
          text: text,
        );
        _setTextIfChanged(_offsetController, nextOffset.toString());
        final nextSelection = RhwpTableCellSelection(
          section: tableSelection.section,
          paragraph: tableSelection.paragraph,
          controlIndex: tableSelection.controlIndex,
          startRow: tableSelection.startRow,
          startColumn: tableSelection.startColumn,
          endRow: tableSelection.endRow,
          endColumn: tableSelection.endColumn,
          activeCellIndex: tableSelection.activeCellIndex,
          activeCellParagraph: tableSelection.activeCellParagraph,
          activeOffset: nextOffset,
          isTextEditing: true,
        );
        if (deferRefresh && awaitTextInputBeforeRefresh) {
          _setTableSelectionForPendingText(nextSelection);
        } else {
          _controller.tableCellSelection = nextSelection;
        }
        if (clearTextController) {
          _textController.clear();
        }
      },
      deferRefresh: deferRefresh,
      awaitTextInputBeforeRefresh: awaitTextInputBeforeRefresh,
      visibleBusy: visibleBusy,
      mergeIntoTextInputUndoBatch: awaitTextInputBeforeRefresh,
    );
    if (edited && deferRefresh) {
      if (deletedRange != null) {
        _recordPendingDeletionOverlay(deletedRange!);
      }
      _recordPendingTextOverlay(
        RhwpCursorPosition(
          section: tableSelection.section,
          paragraph: tableSelection.paragraph,
          offset: offset,
        ),
        text,
      );
    }
  }

  Future<RhwpSelectionRange?> _deleteOverwriteTextInSelectedTableCell(
    RhwpTableCellSelection tableSelection,
    int offset,
    String text,
  ) async {
    final cellIndex = tableSelection.activeCellIndex;
    if (!_overwriteMode ||
        cellIndex == null ||
        text.isEmpty ||
        text.contains('\n')) {
      return null;
    }

    final int? endOffset;
    try {
      endOffset = await _tableCellParagraphEndOffsetFor(tableSelection);
    } catch (_) {
      return null;
    }
    if (endOffset == null || offset >= endOffset) {
      return null;
    }

    final count = math.min(text.length, endOffset - offset);
    if (count <= 0) {
      return null;
    }

    await widget.document.deleteTextInTableCell(
      section: tableSelection.section,
      paragraph: tableSelection.paragraph,
      controlIndex: tableSelection.controlIndex,
      cellIndex: cellIndex,
      cellParagraph: tableSelection.activeCellParagraph,
      offset: offset,
      count: count,
    );

    final cursor = RhwpCursorPosition(
      section: tableSelection.section,
      paragraph: tableSelection.paragraph,
      offset: offset,
    );
    return RhwpSelectionRange(
      start: cursor,
      end: cursor.copyWith(offset: offset + count),
    );
  }

  Future<void> _copySelection() async {
    if (_controller.objectSelection != null) {
      await _copySelectedObject();
      return;
    }

    final tableText = await _selectedTableCellText();
    if (tableText != null && tableText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: tableText));
      _clipboardDomain = _EditorClipboardDomain.text;
      return;
    }

    final text = await _selectedText();
    if (text == null || text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _clipboardDomain = _EditorClipboardDomain.text;
  }

  Future<void> _cutSelection() async {
    if (_controller.objectSelection != null) {
      await _cutSelectedObject();
      return;
    }

    final tableSelection = _controller.tableCellSelection;
    final tableText = await _selectedTableCellText();
    if (tableSelection != null && tableText != null && tableText.isNotEmpty) {
      if (_busy) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: tableText));
      _clipboardDomain = _EditorClipboardDomain.text;
      await _deleteSelectedTableCellText(tableSelection);
      return;
    }

    final text = await _selectedText();
    if (text == null || text.isEmpty || _busy) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    _clipboardDomain = _EditorClipboardDomain.text;
    await _runEdit(() async {
      await _deleteSelectedText(_controller.selection);
    });
  }

  Future<void> _pasteClipboard() async {
    if (_busy) {
      return;
    }
    if (_clipboardDomain == _EditorClipboardDomain.objectControl &&
        await _pasteObjectClipboard()) {
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null &&
        await _pasteTableClipboardText(tableSelection, text)) {
      return;
    }
    if (_isMultiParagraphClipboardText(text)) {
      await _pasteMultiParagraphText(text);
      return;
    }
    _clipboardDomain = _EditorClipboardDomain.text;
    await _insertCommittedText(text);
  }

  bool _isMultiParagraphClipboardText(String text) {
    return text.contains('\n') || text.contains('\r');
  }

  List<String> _parseMultiParagraphClipboardText(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  Future<void> _pasteMultiParagraphText(String text) async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    final lines = _parseMultiParagraphClipboardText(text);
    if (lines.isEmpty) {
      return;
    }

    await _runEdit(() async {
      final selection = _controller.selection;
      var cursor = selection.isCollapsed
          ? _controller.cursor
          : selection.normalizedStart;
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }

      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (line.isNotEmpty) {
          await widget.document.insertText(
            section: cursor.section,
            paragraph: cursor.paragraph,
            offset: cursor.offset,
            text: line,
          );
          await _applyPendingCharFormatToInsertedText(
            cursor: cursor,
            text: line,
          );
          cursor = cursor.copyWith(offset: cursor.offset + line.length);
        }

        if (index < lines.length - 1) {
          await widget.document.splitParagraph(
            section: cursor.section,
            paragraph: cursor.paragraph,
            offset: cursor.offset,
          );
          cursor = cursor.copyWith(paragraph: cursor.paragraph + 1, offset: 0);
        }
      }

      _controller.cursor = cursor;
    });
  }

  Future<void> _selectAllText() async {
    if (_busy || _searching) {
      return;
    }

    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });

    try {
      final pageCount = await widget.document.pageCount;
      RhwpCursorPosition? start;
      RhwpCursorPosition? end;
      var startPage = 0;

      for (var page = 0; page < pageCount; page += 1) {
        final tree = await widget.document.pageLayerTreeModel(page);
        for (final run in tree.textRuns) {
          final section = run.section;
          final paragraph = run.paragraph;
          if (section == null ||
              paragraph == null ||
              run.cellContext != null ||
              run.text.isEmpty) {
            continue;
          }

          final runStart = RhwpCursorPosition(
            section: section,
            paragraph: paragraph,
            offset: run.charStart,
          );
          final runEnd = RhwpCursorPosition(
            section: section,
            paragraph: paragraph,
            offset: run.charEnd,
          );
          if (start == null || runStart.compareTo(start) < 0) {
            start = runStart;
            startPage = page;
          }
          if (end == null || runEnd.compareTo(end) > 0) {
            end = runEnd;
          }
        }
      }

      if (!mounted) {
        return;
      }

      if (start != null && end != null && start != end) {
        _controller.clearTableCellSelection();
        _controller.selection = RhwpSelectionRange(start: start, end: end);
        unawaited(_controller.goToPage(startPage));
        _focusEditor();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }
  }

  Future<void> _insertLineBreak() async {
    await _insertCommittedText('\n');
  }

  Future<void> _copySelectedObject() async {
    if (_busy) {
      return;
    }

    final target = _selectedObjectTarget();
    if (target == null) {
      return;
    }

    try {
      await widget.document.copyObjectControl(
        section: target.section,
        paragraph: target.paragraph,
        controlIndex: target.controlIndex,
      );
      _clipboardDomain = _EditorClipboardDomain.objectControl;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _cutSelectedObject() async {
    if (_busy) {
      return;
    }

    await _copySelectedObject();
    if (_clipboardDomain != _EditorClipboardDomain.objectControl) {
      return;
    }
    await _deleteSelectedObject();
  }

  Future<bool> _pasteObjectClipboard() async {
    if (_busy) {
      return false;
    }

    final bool hasControl;
    try {
      hasControl = await widget.document.clipboardHasObjectControl();
    } catch (_) {
      _clipboardDomain = null;
      return false;
    }
    if (!hasControl) {
      _clipboardDomain = null;
      return false;
    }

    final objectTarget = _selectedObjectTarget(silent: true);
    final cursor = _controller.cursor;
    final section = objectTarget?.section ?? cursor.section;
    final paragraph = objectTarget?.paragraph ?? cursor.paragraph;
    final offset = objectTarget == null ? cursor.offset : 0;
    var pasted = false;

    await _runEdit(() async {
      final result = await widget.document.pasteObjectControl(
        section: section,
        paragraph: paragraph,
        offset: offset,
      );
      final decoded = jsonDecode(result);
      if (decoded is Map<String, Object?> && decoded['ok'] == false) {
        return;
      }
      pasted = true;
      final nextParagraph =
          _readIntResult(result, 'paraIdx') ?? paragraph + (offset > 0 ? 1 : 0);
      _controller.clearObjectSelection();
      _controller.cursor = RhwpCursorPosition(
        section: section,
        paragraph: nextParagraph,
        offset: 0,
      );
    });

    return pasted;
  }

  ({int section, int paragraph, int controlIndex, String objectType})?
  _selectedObjectTarget({bool silent = false}) {
    final selection = _controller.objectSelection;
    if (selection == null) {
      return null;
    }

    final section = selection.section;
    final paragraph = selection.paragraph;
    final controlIndex = selection.controlIndex;
    if (section == null || paragraph == null || controlIndex == null) {
      if (!silent) {
        setState(() {
          _error =
              'Selected object is missing section, paragraph, or control index.';
        });
      }
      return null;
    }

    return (
      section: section,
      paragraph: paragraph,
      controlIndex: controlIndex,
      objectType: selection.type,
    );
  }

  Future<void> _deleteSelectedObject() async {
    if (_busy) {
      return;
    }

    final target = _selectedObjectTarget();
    if (target == null) {
      return;
    }

    await _runEdit(() async {
      await widget.document.deleteObjectControl(
        section: target.section,
        paragraph: target.paragraph,
        controlIndex: target.controlIndex,
        objectType: target.objectType,
      );
      _controller.clearObjectSelection();
      _controller.cursor = RhwpCursorPosition(
        section: target.section,
        paragraph: target.paragraph,
        offset: _controller.cursor.offset,
      );
    });
  }

  Future<void> _changeSelectedObjectZOrder(
    RhwpObjectZOrderOperation operation,
  ) async {
    if (_busy) {
      return;
    }

    final target = _selectedObjectTarget();
    if (target == null) {
      return;
    }

    await _runEdit(() async {
      await widget.document.changeObjectZOrder(
        section: target.section,
        paragraph: target.paragraph,
        controlIndex: target.controlIndex,
        objectType: target.objectType,
        operation: operation,
      );
    });
  }

  Future<void> _showObjectPropertiesDialog() async {
    if (_busy) {
      return;
    }

    final target = _selectedObjectTarget();
    if (target == null) {
      return;
    }

    RhwpObjectProperties properties;
    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      properties = await widget.document.objectProperties(
        section: target.section,
        paragraph: target.paragraph,
        controlIndex: target.controlIndex,
        objectType: target.objectType,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
          _error = error;
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _visibleBusy = false;
    });

    final result = await showDialog<_ObjectPropertiesDialogResult>(
      context: context,
      builder: (_) => _ObjectPropertiesDialog(properties: properties),
    );
    if (!mounted || result == null) {
      return;
    }

    await _runEdit(() async {
      await widget.document.setObjectProperties(
        section: target.section,
        paragraph: target.paragraph,
        controlIndex: target.controlIndex,
        objectType: target.objectType,
        width: result.width,
        height: result.height,
        horzOffset: result.horzOffset,
        vertOffset: result.vertOffset,
      );
    });
  }

  Future<void> _commitObjectBoundsChange(
    RhwpObjectSelection original,
    RhwpObjectSelection updated,
  ) async {
    if (_busy || original == updated) {
      return;
    }

    final section = original.section;
    final paragraph = original.paragraph;
    final controlIndex = original.controlIndex;
    if (section == null || paragraph == null || controlIndex == null) {
      setState(() {
        _error =
            'Selected object is missing section, paragraph, or control index.';
      });
      _controller.objectSelection = original;
      return;
    }

    final committed = await _runEdit(() async {
      final properties = await widget.document.objectProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: original.type,
      );
      if (original.isLineObject) {
        final mapped = _mapLineEndpointsToProperties(
          original: original,
          updated: updated,
          currentProperties: properties,
        );
        await widget.document.moveLineEndpoint(
          section: section,
          paragraph: paragraph,
          controlIndex: controlIndex,
          startX: mapped.startX,
          startY: mapped.startY,
          endX: mapped.endX,
          endY: mapped.endY,
        );
        _controller.objectSelection = updated;
        return;
      }

      if (original.bounds == updated.bounds) {
        _controller.objectSelection = updated;
        return;
      }

      final mapped = _mapObjectBoundsToProperties(
        currentBounds: original.bounds,
        updatedBounds: updated.bounds,
        currentProperties: properties,
      );
      await widget.document.setObjectProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: original.type,
        width: mapped.width,
        height: mapped.height,
        horzOffset: mapped.horzOffset,
        vertOffset: mapped.vertOffset,
      );
      _controller.objectSelection = updated;
    });

    if (!committed) {
      _controller.objectSelection = original;
    }
  }

  bool _nudgeSelectedObject(Offset delta) {
    final selection = _controller.objectSelection;
    if (_busy || selection == null || delta == Offset.zero) {
      return false;
    }

    final left = math.max(0.0, selection.bounds.left + delta.dx);
    final top = math.max(0.0, selection.bounds.top + delta.dy);
    final appliedDelta = Offset(
      left - selection.bounds.left,
      top - selection.bounds.top,
    );
    if (appliedDelta == Offset.zero) {
      return true;
    }

    final updated = selection.isLineObject
        ? selection.copyWith(
            bounds: selection.bounds.shift(appliedDelta),
            lineStart: _lineStartForSelection(selection) + appliedDelta,
            lineEnd: _lineEndForSelection(selection) + appliedDelta,
          )
        : selection.copyWith(bounds: selection.bounds.shift(appliedDelta));
    _controller.objectSelection = updated;
    unawaited(_commitObjectBoundsChange(selection, updated));
    return true;
  }

  ({int startX, int startY, int endX, int endY}) _mapLineEndpointsToProperties({
    required RhwpObjectSelection original,
    required RhwpObjectSelection updated,
    required RhwpObjectProperties currentProperties,
  }) {
    final currentBounds = original.bounds;
    final currentWidth = math.max(1.0, currentBounds.width);
    final currentHeight = math.max(1.0, currentBounds.height);
    final widthBase = currentProperties.width ?? currentBounds.width.round();
    final heightBase = currentProperties.height ?? currentBounds.height.round();
    final horizontalScale = widthBase / currentWidth;
    final verticalScale = heightBase / currentHeight;
    final horzOffsetBase =
        currentProperties.horzOffset ?? currentBounds.left.round();
    final vertOffsetBase =
        currentProperties.vertOffset ?? currentBounds.top.round();

    Offset mapPoint(Offset point) {
      return Offset(
        horzOffsetBase + (point.dx - currentBounds.left) * horizontalScale,
        vertOffsetBase + (point.dy - currentBounds.top) * verticalScale,
      );
    }

    final start = mapPoint(_lineStartForSelection(updated));
    final end = mapPoint(_lineEndForSelection(updated));
    return (
      startX: math.max(0, start.dx.round()),
      startY: math.max(0, start.dy.round()),
      endX: math.max(0, end.dx.round()),
      endY: math.max(0, end.dy.round()),
    );
  }

  ({int width, int height, int horzOffset, int vertOffset})
  _mapObjectBoundsToProperties({
    required Rect currentBounds,
    required Rect updatedBounds,
    required RhwpObjectProperties currentProperties,
  }) {
    final currentWidth = math.max(1.0, currentBounds.width);
    final currentHeight = math.max(1.0, currentBounds.height);
    final widthBase = currentProperties.width ?? currentBounds.width.round();
    final heightBase = currentProperties.height ?? currentBounds.height.round();
    final horizontalScale = widthBase / currentWidth;
    final verticalScale = heightBase / currentHeight;
    final horzOffsetBase =
        currentProperties.horzOffset ?? currentBounds.left.round();
    final vertOffsetBase =
        currentProperties.vertOffset ?? currentBounds.top.round();

    return (
      width: math.max(0, (updatedBounds.width * horizontalScale).round()),
      height: math.max(0, (updatedBounds.height * verticalScale).round()),
      horzOffset: math.max(
        0,
        (horzOffsetBase +
                (updatedBounds.left - currentBounds.left) * horizontalScale)
            .round(),
      ),
      vertOffset: math.max(
        0,
        (vertOffsetBase +
                (updatedBounds.top - currentBounds.top) * verticalScale)
            .round(),
      ),
    );
  }

  Future<void> _splitParagraph() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final selection = _controller.selection;
      final cursor = selection.isCollapsed
          ? _controller.cursor
          : selection.normalizedStart;
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      await widget.document.splitParagraph(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
      );
      _controller.cursor = cursor.copyWith(
        paragraph: cursor.paragraph + 1,
        offset: 0,
      );
    });
  }

  Future<void> _insertPageBreak() async {
    await _insertDocumentBreak(columnBreak: false);
  }

  Future<void> _insertColumnBreak() async {
    await _insertDocumentBreak(columnBreak: true);
  }

  Future<void> _insertDocumentBreak({required bool columnBreak}) async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    await _runEdit(() async {
      final selection = _controller.selection;
      final cursor = selection.isCollapsed
          ? _controller.cursor
          : selection.normalizedStart;
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }

      final result = columnBreak
          ? await widget.document.insertColumnBreak(
              section: cursor.section,
              paragraph: cursor.paragraph,
              offset: cursor.offset,
            )
          : await widget.document.insertPageBreak(
              section: cursor.section,
              paragraph: cursor.paragraph,
              offset: cursor.offset,
            );
      _controller.cursor = RhwpCursorPosition(
        section: cursor.section,
        paragraph: _readIntResult(result, 'paraIdx') ?? cursor.paragraph + 1,
        offset: _readIntResult(result, 'charOffset') ?? 0,
      );
    });
  }

  Future<void> _showInsertNewNumberDialog() async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    final result = await showDialog<_NewNumberDialogResult>(
      context: context,
      builder: (context) => const _NewNumberDialog(),
    );
    if (result == null) {
      return;
    }

    final selection = _controller.selection;
    final cursor = selection.isCollapsed
        ? _controller.cursor
        : selection.normalizedStart;
    await _runEdit(() async {
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      await widget.document.insertNewNumber(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        startNumber: result.startNumber,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset + 8);
    });
  }

  Future<void> _insertTable() async {
    if (_busy) {
      return;
    }

    final rows = _parsePositive(_tableRowsController.text, max: 256);
    final columns = _parsePositive(_tableColumnsController.text, max: 256);
    _setTextIfChanged(_tableRowsController, rows.toString());
    _setTextIfChanged(_tableColumnsController, columns.toString());

    await _runEdit(() async {
      final selection = _controller.selection;
      final cursor = selection.isCollapsed
          ? _readCursor()
          : selection.normalizedStart;
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      final result = await widget.document.insertTable(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        rows: rows,
        columns: columns,
      );
      final tableParagraph =
          _readIntResult(result, 'paraIdx') ?? cursor.paragraph;
      _setTextIfChanged(_tableParagraphController, tableParagraph.toString());
      _setTextIfChanged(_tableControlController, '0');
      _setTextIfChanged(_tableRowController, '0');
      _setTextIfChanged(_tableColumnController, '0');
      _setTextIfChanged(_tableEndRowController, '1');
      _setTextIfChanged(_tableEndColumnController, '1');
      _controller.cursor = RhwpCursorPosition(
        section: cursor.section,
        paragraph: tableParagraph + 1,
      );
    });
  }

  Future<void> _insertFootnote() async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    final selection = _controller.selection;
    final cursor = selection.isCollapsed
        ? _controller.cursor
        : selection.normalizedStart;
    await _runEdit(() async {
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      await widget.document.insertFootnote(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset + 1);
    });
  }

  Future<void> _showInsertEquationDialog() async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    final result = await showDialog<_EquationDialogResult>(
      context: context,
      builder: (context) => const _EquationDialog(),
    );
    if (result == null || result.script.trim().isEmpty) {
      return;
    }

    final selection = _controller.selection;
    final cursor = selection.isCollapsed
        ? _controller.cursor
        : selection.normalizedStart;
    await _runEdit(() async {
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      await widget.document.insertEquation(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        script: result.script.trim(),
        fontSize: result.fontSize,
        color: result.color,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset + 1);
    });
  }

  Future<void> _insertPicture() async {
    final onImageRequested = widget.onImageRequested;
    if (_busy ||
        onImageRequested == null ||
        _controller.tableCellSelection != null) {
      return;
    }

    final RhwpEditorImage? image;
    final _ResolvedEditorImage resolvedImage;
    try {
      image = await onImageRequested();
      if (!mounted || image == null || image.bytes.isEmpty) {
        return;
      }
      resolvedImage = await _resolveEditorImage(image);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
      return;
    }

    final selection = _controller.selection;
    final cursor = selection.isCollapsed
        ? _controller.cursor
        : selection.normalizedStart;
    await _runEdit(() async {
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      final result = await widget.document.insertPicture(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        imageData: resolvedImage.bytes,
        width: resolvedImage.width,
        height: resolvedImage.height,
        naturalWidthPx: resolvedImage.naturalWidthPx,
        naturalHeightPx: resolvedImage.naturalHeightPx,
        extension: resolvedImage.extension,
        description: resolvedImage.description,
      );
      final pictureParagraph =
          _readIntResult(result, 'paraIdx') ?? cursor.paragraph;
      _controller.cursor = RhwpCursorPosition(
        section: cursor.section,
        paragraph: pictureParagraph + 1,
      );
    });
  }

  Future<void> _insertShape(_EditorShapePreset preset) async {
    if (_busy || _controller.tableCellSelection != null) {
      return;
    }

    final selection = _controller.selection;
    final cursor = selection.isCollapsed
        ? _controller.cursor
        : selection.normalizedStart;
    await _runEdit(() async {
      if (!selection.isCollapsed) {
        await _deleteSelectedText(selection);
      }
      final result = await widget.document.insertShape(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        width: preset.width,
        height: preset.height,
        horzOffset: preset.horzOffset,
        vertOffset: preset.vertOffset,
        shapeType: preset.shapeType,
        treatAsChar: preset.treatAsChar,
        textWrap: preset.textWrap,
        lineFlipX: preset.lineFlipX,
        lineFlipY: preset.lineFlipY,
      );
      final shapeParagraph =
          _readIntResult(result, 'paraIdx') ?? cursor.paragraph;
      _controller.cursor = RhwpCursorPosition(
        section: cursor.section,
        paragraph: shapeParagraph,
        offset: cursor.offset + 8,
      );
    });
  }

  Future<void> _insertTableRow() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.insertTableRow(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        row: ref.row,
      );
    });
  }

  Future<void> _insertTableColumn() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.insertTableColumn(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        column: ref.column,
      );
    });
  }

  Future<void> _deleteTableRow() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.deleteTableRow(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        row: ref.row,
      );
    });
  }

  Future<void> _deleteTableColumn() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.deleteTableColumn(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        column: ref.column,
      );
    });
  }

  Future<void> _mergeTableCells() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.mergeTableCells(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        startRow: ref.row,
        startColumn: ref.column,
        endRow: ref.endRow,
        endColumn: ref.endColumn,
      );
    });
  }

  Future<void> _splitTableCell() async {
    if (_busy) {
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.splitTableCell(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        row: ref.row,
        column: ref.column,
      );
    });
  }

  Future<void> _splitTableCellInto() async {
    if (_busy) {
      return;
    }

    final result = await showDialog<_SplitTableCellIntoDialogResult>(
      context: context,
      builder: (context) => const _SplitTableCellIntoDialog(),
    );
    if (result == null) {
      _focusEditor();
      return;
    }

    await _runEdit(() async {
      final ref = _readTableReference();
      await widget.document.splitTableCellInto(
        section: ref.section,
        paragraph: ref.paragraph,
        controlIndex: ref.controlIndex,
        row: ref.row,
        column: ref.column,
        rows: result.rows,
        columns: result.columns,
        equalRowHeight: result.equalRowHeight,
        mergeFirst: result.mergeFirst,
      );
    });
  }

  Future<void> _applyTableCellStyle({
    String? fillColor,
    bool clearFill = false,
    String? borderColor,
    int? borderWidth,
    int? borderType,
    int? verticalAlign,
  }) async {
    if (_busy) {
      return;
    }

    final tableSelection = _controller.tableCellSelection;
    if (tableSelection == null) {
      return;
    }

    final targets = await _tableCellStyleTargets(tableSelection);
    if (!mounted || targets.isEmpty) {
      return;
    }

    await _runEdit(() async {
      for (final target in targets) {
        await widget.document.applyTableCellStyle(
          section: target.cell.section,
          paragraph: target.cell.paragraph,
          controlIndex: target.cell.controlIndex,
          cellIndex: target.cell.modelCellIndex!,
          fillColor: fillColor,
          clearFill: clearFill,
          borderColor: borderColor,
          borderWidth: borderWidth,
          borderType: borderType,
          verticalAlign: verticalAlign,
        );
      }
      _controller.tableCellSelection = tableSelection;
    });
  }

  Future<void> _createHeaderFooter({required bool isHeader}) async {
    if (_busy) {
      return;
    }

    final section = _parseNonNegative(_sectionController.text);
    await _runEdit(() async {
      await widget.document.createHeaderFooter(
        section: section,
        isHeader: isHeader,
      );
      _controller.cursor = _controller.cursor.copyWith(section: section);
    });
  }

  Future<void> _showHeaderFooterTextDialog({required bool isHeader}) async {
    if (_busy) {
      return;
    }

    final section = _parseNonNegative(_sectionController.text);
    RhwpHeaderFooterInfo? initialInfo;
    try {
      initialInfo = await widget.document.headerFooter(
        section: section,
        isHeader: isHeader,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }

    final result = await showDialog<_HeaderFooterTextDialogResult>(
      context: context,
      builder: (context) =>
          _HeaderFooterTextDialog(isHeader: isHeader, initialInfo: initialInfo),
    );
    if (result == null) {
      return;
    }

    await _runEdit(() async {
      final info = await widget.document.headerFooter(
        section: section,
        isHeader: isHeader,
        applyTo: result.applyTo,
      );
      if (!info.exists) {
        await widget.document.createHeaderFooter(
          section: section,
          isHeader: isHeader,
          applyTo: result.applyTo,
        );
      }
      if (result.replaceExisting && info.exists) {
        final count = info.text?.runes.length ?? 0;
        if (count > 0) {
          await widget.document.deleteTextInHeaderFooter(
            section: section,
            isHeader: isHeader,
            applyTo: result.applyTo,
            paragraph: 0,
            offset: 0,
            count: count,
          );
        }
      }
      if (result.text.isNotEmpty) {
        await widget.document.insertTextInHeaderFooter(
          section: section,
          isHeader: isHeader,
          applyTo: result.applyTo,
          paragraph: result.replaceExisting ? 0 : result.paragraph,
          offset: result.replaceExisting ? 0 : result.offset,
          text: result.text,
        );
      }
      _controller.cursor = _controller.cursor.copyWith(section: section);
    });
  }

  Future<void> _showPageSetupDialog() async {
    if (_busy) {
      return;
    }

    final section = _parseNonNegative(_sectionController.text);
    late final RhwpPageSetup current;
    try {
      current = await widget.document.pageSetup(section: section);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final result = await showDialog<_PageSetupDialogResult>(
      context: context,
      builder: (context) => _PageSetupDialog(initial: current),
    );
    if (result == null) {
      return;
    }

    await _runEdit(() async {
      await widget.document.setPageSetup(
        section: section,
        width: result.width,
        height: result.height,
        marginLeft: result.marginLeft,
        marginRight: result.marginRight,
        marginTop: result.marginTop,
        marginBottom: result.marginBottom,
        marginHeader: result.marginHeader,
        marginFooter: result.marginFooter,
        marginGutter: result.marginGutter,
        landscape: result.landscape,
        binding: result.binding,
      );
      _controller.cursor = _controller.cursor.copyWith(section: section);
    });
  }

  Future<void> _applyCharFormat({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) async {
    if (_busy) {
      return;
    }

    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null) {
      if (tableSelection.isTextEditing) {
        _mergePendingCharFormat(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
          superscript: superscript,
          subscript: subscript,
          emboss: emboss,
          engrave: engrave,
          fontFamily: fontFamily,
          fontSize: fontSize,
          textColor: textColor,
          shadeColor: shadeColor,
        );
        return;
      }

      final segments = await _tableCellTextSegments(tableSelection);
      if (!mounted) {
        return;
      }
      final nonEmptySegments = [
        for (final segment in segments)
          if (segment.startOffset < segment.endOffset) segment,
      ];
      if (nonEmptySegments.isEmpty) {
        _mergePendingCharFormat(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
          superscript: superscript,
          subscript: subscript,
          emboss: emboss,
          engrave: engrave,
          fontFamily: fontFamily,
          fontSize: fontSize,
          textColor: textColor,
          shadeColor: shadeColor,
        );
        return;
      }

      final edited = await _runEdit(() async {
        for (final segment in nonEmptySegments) {
          await widget.document.applyCharFormatInTableCell(
            section: segment.section,
            paragraph: segment.paragraph,
            controlIndex: segment.controlIndex,
            cellIndex: segment.cellIndex,
            cellParagraph: segment.cellParagraph,
            startOffset: segment.startOffset,
            endOffset: segment.endOffset,
            bold: bold,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough,
            superscript: superscript,
            subscript: subscript,
            emboss: emboss,
            engrave: engrave,
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: textColor,
            shadeColor: shadeColor,
          );
        }
        _controller.tableCellSelection = tableSelection;
      });
      if (edited) {
        _rememberAppliedCharFormat(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
          superscript: superscript,
          subscript: subscript,
          emboss: emboss,
          engrave: engrave,
          fontFamily: fontFamily,
          fontSize: fontSize,
          textColor: textColor,
          shadeColor: shadeColor,
        );
      }
      return;
    }

    final selection = _controller.selection;
    if (selection.isCollapsed) {
      _mergePendingCharFormat(
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
      );
      return;
    }

    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    final edited = await _runEdit(() async {
      await widget.document.applyCharFormatRange(
        section: start.section,
        startParagraph: start.paragraph,
        startOffset: start.offset,
        endParagraph: end.paragraph,
        endOffset: end.offset,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
      );
      _controller.selection = RhwpSelectionRange(start: start, end: end);
    });
    if (edited) {
      _rememberAppliedCharFormat(
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
      );
    }
  }

  Future<void> _toggleCharFormat({
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    bool superscript = false,
    bool subscript = false,
    bool emboss = false,
    bool engrave = false,
  }) {
    final active = _pendingCharFormat.withFallback(_currentCharFormat);
    final bool? nextSuperscript;
    final bool? nextSubscript;
    if (superscript) {
      nextSuperscript = active.superscript == true ? false : true;
      nextSubscript = false;
    } else if (subscript) {
      nextSuperscript = false;
      nextSubscript = active.subscript == true ? false : true;
    } else {
      nextSuperscript = null;
      nextSubscript = null;
    }

    final bool? nextEmboss;
    final bool? nextEngrave;
    if (emboss) {
      nextEmboss = active.emboss == true ? false : true;
      nextEngrave = false;
    } else if (engrave) {
      nextEmboss = false;
      nextEngrave = active.engrave == true ? false : true;
    } else {
      nextEmboss = null;
      nextEngrave = null;
    }

    return _applyCharFormat(
      bold: bold ? active.bold != true : null,
      italic: italic ? active.italic != true : null,
      underline: underline ? active.underline != true : null,
      strikethrough: strikethrough ? active.strikethrough != true : null,
      superscript: nextSuperscript,
      subscript: nextSubscript,
      emboss: nextEmboss,
      engrave: nextEngrave,
    );
  }

  void _rememberAppliedCharFormat({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentCharFormat = _currentCharFormat.applyExplicit(
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
      );
    });
  }

  void _mergePendingCharFormat({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) {
    setState(() {
      _pendingCharFormat = _pendingCharFormat.mergeWithFallback(
        _currentCharFormat,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
      );
    });
  }

  Future<void> _showCharShapeDialog() async {
    if (_busy ||
        (_controller.selection.isCollapsed &&
            _controller.tableCellSelection == null)) {
      return;
    }

    final result = await showDialog<_CharShapeDialogResult>(
      context: context,
      builder: (context) => _CharShapeDialog(
        initialFormat: _pendingCharFormat.withFallback(_currentCharFormat),
      ),
    );
    if (result == null) {
      return;
    }

    await _applyCharFormat(
      bold: result.bold,
      italic: result.italic,
      underline: result.underline,
      strikethrough: result.strikethrough,
      superscript: result.superscript,
      subscript: result.subscript,
      emboss: result.emboss,
      engrave: result.engrave,
      fontFamily: result.fontFamily,
      fontSize: result.fontSize,
      textColor: result.textColor,
      shadeColor: result.shadeColor,
    );
  }

  Future<void> _applyParagraphAlignment(String alignment) async {
    await _applyParagraphFormat(alignment: alignment);
  }

  Future<void> _showParaShapeDialog() async {
    if (_busy) {
      return;
    }

    final result = await showDialog<_ParaShapeDialogResult>(
      context: context,
      builder: (context) => _ParaShapeDialog(initialFormat: _currentParaFormat),
    );
    if (result == null) {
      return;
    }

    await _applyParagraphFormat(
      alignment: result.alignment,
      lineSpacing: result.lineSpacing,
      lineSpacingType: result.lineSpacingType,
      indent: result.indent,
      marginLeft: result.marginLeft,
      marginRight: result.marginRight,
      spacingBefore: result.spacingBefore,
      spacingAfter: result.spacingAfter,
    );
  }

  Future<void> _showStylePicker() async {
    if (_busy) {
      return;
    }

    List<RhwpStyleInfo> styles = const [];
    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });
    try {
      styles = await widget.document.styleList();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
        });
      }
    }

    if (!mounted) {
      return;
    }
    if (styles.isEmpty) {
      setState(() {
        _error = StateError('No styles are defined in this document.');
      });
      _focusEditor();
      return;
    }

    final styleId = await showDialog<int>(
      context: context,
      builder: (context) => _StylePickerDialog(styles: styles),
    );
    if (styleId != null) {
      await _applyStyle(styleId);
    }
    _focusEditor();
  }

  Future<void> _runSearch() async {
    _searchInputDebounceTimer?.cancel();
    _searchInputDebounceTimer = null;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    if (_searching) {
      _scheduleSearchInputDebounce();
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final pageCount = await widget.document.pageCount;
      final matches = <_EditorSearchMatch>[];
      for (var page = 0; page < pageCount; page += 1) {
        final tree = await widget.document.pageLayerTreeModel(page);
        matches.addAll(_searchTree(tree, query));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _searchMatches = List.unmodifiable(matches);
        _activeSearchMatch = matches.isEmpty ? -1 : 0;
      });
      _selectActiveSearchMatch();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _searchMatches = const [];
        _activeSearchMatch = -1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  void _handleSearchInputChanged(String value) {
    _scheduleSearchInputDebounce();
  }

  void _scheduleSearchInputDebounce() {
    _searchInputDebounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _searchInputDebounceTimer = Timer(_searchInputDebounceDelay, () {
      _searchInputDebounceTimer = null;
      unawaited(_runSearch());
    });
  }

  void _focusSearchField() {
    _toolbarKey.currentState?.activateTab(_EditorTab.tools);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
      _searchFocusNode.requestFocus();
    });
  }

  void _focusReplaceField() {
    _toolbarKey.currentState?.activateTab(_EditorTab.tools);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _replaceController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _replaceController.text.length,
      );
      _replaceFocusNode.requestFocus();
    });
  }

  List<_EditorSearchMatch> _searchTree(RhwpLayerTree tree, String query) {
    final foldedQuery = query.toLowerCase();
    final matches = <_EditorSearchMatch>[];
    for (final run in tree.textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null) {
        continue;
      }

      final foldedText = run.text.toLowerCase();
      var index = foldedText.indexOf(foldedQuery);
      while (index >= 0) {
        final match = _searchMatchForRun(
          tree: tree,
          run: run,
          section: section,
          paragraph: paragraph,
          startOffset: run.charStart + index,
          endOffset: run.charStart + index + query.length,
        );
        if (match != null) {
          matches.add(match);
        }
        index = foldedText.indexOf(foldedQuery, index + foldedQuery.length);
      }
    }
    return matches;
  }

  _EditorSearchMatch? _searchMatchForRun({
    required RhwpLayerTree tree,
    required RhwpTextRunLayout run,
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
  }) {
    final context = run.cellContext;
    if (context == null) {
      return _EditorSearchMatch(
        page: tree.page,
        section: section,
        paragraph: paragraph,
        startOffset: startOffset,
        endOffset: endOffset,
      );
    }

    for (final cell in tree.tableCells) {
      if (cell.section == section &&
          cell.paragraph == paragraph &&
          cell.controlIndex == context.controlIndex &&
          cell.modelCellIndex == context.cellIndex) {
        return _EditorSearchMatch(
          page: tree.page,
          section: section,
          paragraph: paragraph,
          startOffset: startOffset,
          endOffset: endOffset,
          tableControlIndex: context.controlIndex,
          cellIndex: context.cellIndex,
          cellParagraph: context.cellParagraph,
          cellRow: cell.row,
          cellColumn: cell.column,
          cellEndRow: cell.endRow,
          cellEndColumn: cell.endColumn,
        );
      }
    }

    return null;
  }

  void _searchNext() {
    if (_searchMatches.isEmpty) {
      return;
    }
    setState(() {
      _activeSearchMatch = (_activeSearchMatch + 1) % _searchMatches.length;
    });
    _selectActiveSearchMatch();
  }

  void _searchPrevious() {
    if (_searchMatches.isEmpty) {
      return;
    }
    setState(() {
      _activeSearchMatch =
          (_activeSearchMatch - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
    _selectActiveSearchMatch();
  }

  void _clearSearch() {
    _searchInputDebounceTimer?.cancel();
    _searchInputDebounceTimer = null;
    _searchController.clear();
    setState(() {
      _searchMatches = const [];
      _activeSearchMatch = -1;
    });
  }

  void _selectActiveSearchMatch() {
    if (_activeSearchMatch < 0 || _activeSearchMatch >= _searchMatches.length) {
      return;
    }

    final match = _searchMatches[_activeSearchMatch];
    final tableSelection = match.tableCellSelection;
    if (tableSelection == null) {
      _controller.clearTableCellSelection();
      _controller.selection = match.selection;
    } else {
      _controller.clearSelection();
      _syncTableSelectionFields(tableSelection);
      _controller.tableCellSelection = tableSelection;
    }
    unawaited(_controller.goToPage(match.page));
    _focusEditor();
  }

  Future<void> _replaceActiveSearchMatch() async {
    if (_busy ||
        _activeSearchMatch < 0 ||
        _activeSearchMatch >= _searchMatches.length) {
      return;
    }

    final matchIndex = _activeSearchMatch;
    final match = _searchMatches[matchIndex];
    final replacement = _replaceController.text;
    final replaced = await _runEdit(() async {
      await _replaceSearchMatchText(match, replacement);
      _selectSearchReplacementRange(match, replacement.length);
    });
    if (!replaced) {
      return;
    }

    if (!mounted) {
      return;
    }

    final remainingMatches = _searchMatches
        .asMap()
        .entries
        .where((entry) => entry.key != matchIndex)
        .map((entry) => _shiftSearchMatchAfterReplacement(entry.value, match))
        .toList(growable: false);
    setState(() {
      _searchMatches = List.unmodifiable(remainingMatches);
      if (remainingMatches.isEmpty) {
        _activeSearchMatch = -1;
      } else {
        _activeSearchMatch = math.min(matchIndex, remainingMatches.length - 1);
      }
    });
    if (_activeSearchMatch >= 0) {
      _selectActiveSearchMatch();
    } else {
      _focusEditor();
    }
  }

  Future<void> _replaceAllSearchMatches() async {
    if (_busy || _searchMatches.isEmpty) {
      return;
    }

    final replacement = _replaceController.text;
    final matches = List<_EditorSearchMatch>.of(_searchMatches)
      ..sort(_compareSearchMatchesDescending);
    final firstMatch = _searchMatches.first;

    final replaced = await _runEdit(() async {
      for (final match in matches) {
        await _replaceSearchMatchText(match, replacement);
      }
      _selectSearchReplacementRange(firstMatch, replacement.length);
    });
    if (!replaced || !mounted) {
      return;
    }

    setState(() {
      _searchMatches = const [];
      _activeSearchMatch = -1;
    });
    _focusEditor();
  }

  int _compareSearchMatchesDescending(
    _EditorSearchMatch left,
    _EditorSearchMatch right,
  ) {
    final section = right.section.compareTo(left.section);
    if (section != 0) {
      return section;
    }
    final paragraph = right.paragraph.compareTo(left.paragraph);
    if (paragraph != 0) {
      return paragraph;
    }
    final control = (right.tableControlIndex ?? -1).compareTo(
      left.tableControlIndex ?? -1,
    );
    if (control != 0) {
      return control;
    }
    final cell = (right.cellIndex ?? -1).compareTo(left.cellIndex ?? -1);
    if (cell != 0) {
      return cell;
    }
    final cellParagraph = (right.cellParagraph ?? -1).compareTo(
      left.cellParagraph ?? -1,
    );
    if (cellParagraph != 0) {
      return cellParagraph;
    }
    return right.startOffset.compareTo(left.startOffset);
  }

  _EditorSearchMatch _shiftSearchMatchAfterReplacement(
    _EditorSearchMatch candidate,
    _EditorSearchMatch replaced,
  ) {
    if (!_sameSearchTarget(candidate, replaced) ||
        candidate.startOffset < replaced.endOffset) {
      return candidate;
    }

    final delta =
        _replaceController.text.length -
        (replaced.endOffset - replaced.startOffset);
    if (delta == 0) {
      return candidate;
    }

    return candidate.copyWith(
      startOffset: candidate.startOffset + delta,
      endOffset: candidate.endOffset + delta,
    );
  }

  bool _sameSearchTarget(_EditorSearchMatch left, _EditorSearchMatch right) {
    return left.section == right.section &&
        left.paragraph == right.paragraph &&
        left.tableControlIndex == right.tableControlIndex &&
        left.cellIndex == right.cellIndex &&
        left.cellParagraph == right.cellParagraph;
  }

  Future<void> _replaceSearchMatchText(
    _EditorSearchMatch match,
    String replacement,
  ) async {
    final tableControlIndex = match.tableControlIndex;
    final cellIndex = match.cellIndex;
    final cellParagraph = match.cellParagraph;
    if (tableControlIndex != null &&
        cellIndex != null &&
        cellParagraph != null) {
      await widget.document.deleteTextInTableCell(
        section: match.section,
        paragraph: match.paragraph,
        controlIndex: tableControlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: match.startOffset,
        count: match.endOffset - match.startOffset,
      );
      if (replacement.isNotEmpty) {
        await widget.document.insertTextInTableCell(
          section: match.section,
          paragraph: match.paragraph,
          controlIndex: tableControlIndex,
          cellIndex: cellIndex,
          cellParagraph: cellParagraph,
          offset: match.startOffset,
          text: replacement,
        );
      }
      return;
    }

    await widget.document.deleteText(
      section: match.section,
      paragraph: match.paragraph,
      offset: match.startOffset,
      count: match.endOffset - match.startOffset,
    );
    if (replacement.isNotEmpty) {
      await widget.document.insertText(
        section: match.section,
        paragraph: match.paragraph,
        offset: match.startOffset,
        text: replacement,
      );
    }
  }

  void _selectSearchReplacementRange(
    _EditorSearchMatch match,
    int replacementLength,
  ) {
    final replacementStart = RhwpCursorPosition(
      section: match.section,
      paragraph: match.paragraph,
      offset: match.startOffset,
    );
    final replacementEnd = replacementStart.copyWith(
      offset: match.startOffset + replacementLength,
    );
    final tableSelection = match.tableCellSelection;
    if (tableSelection == null) {
      _controller.clearTableCellSelection();
      _controller.selection = RhwpSelectionRange(
        start: replacementStart,
        end: replacementEnd,
      );
      return;
    }

    final replacementSelection = RhwpTableCellSelection(
      section: tableSelection.section,
      paragraph: tableSelection.paragraph,
      controlIndex: tableSelection.controlIndex,
      startRow: tableSelection.startRow,
      startColumn: tableSelection.startColumn,
      endRow: tableSelection.endRow,
      endColumn: tableSelection.endColumn,
      activeCellIndex: tableSelection.activeCellIndex,
      activeCellParagraph: tableSelection.activeCellParagraph,
      activeOffset: replacementEnd.offset,
      isTextEditing: true,
    );
    _controller.clearSelection();
    _syncTableSelectionFields(replacementSelection);
    _controller.tableCellSelection = replacementSelection;
  }

  Future<void> _applyParagraphFormat({
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) async {
    if (_busy) {
      return;
    }

    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null) {
      final targets = await _tableCellParagraphTargets(tableSelection);
      if (!mounted || targets.isEmpty) {
        return;
      }

      final edited = await _runEdit(() async {
        for (final target in targets) {
          await widget.document.applyParaFormatInTableCell(
            section: target.section,
            paragraph: target.paragraph,
            controlIndex: target.controlIndex,
            cellIndex: target.cellIndex,
            cellParagraph: target.cellParagraph,
            alignment: alignment,
            lineSpacing: lineSpacing,
            lineSpacingType: lineSpacingType,
            indent: indent,
            marginLeft: marginLeft,
            marginRight: marginRight,
            spacingBefore: spacingBefore,
            spacingAfter: spacingAfter,
          );
        }
        _controller.tableCellSelection = tableSelection;
      });
      if (edited) {
        unawaited(_syncCurrentParaFormat());
      }
      return;
    }

    final selection = _controller.selection;
    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    final edited = await _runEdit(() async {
      await widget.document.applyParaFormatRange(
        section: start.section,
        startParagraph: start.paragraph,
        endParagraph: end.paragraph,
        alignment: alignment,
        lineSpacing: lineSpacing,
        lineSpacingType: lineSpacingType,
        indent: indent,
        marginLeft: marginLeft,
        marginRight: marginRight,
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
      );
      _controller.selection = selection.isCollapsed
          ? RhwpSelectionRange.collapsed(start)
          : RhwpSelectionRange(start: start, end: end);
    });
    if (edited) {
      unawaited(_syncCurrentParaFormat());
    }
  }

  Future<void> _applyStyle(int styleId) async {
    if (_busy) {
      return;
    }

    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null) {
      final targets = await _tableCellParagraphTargets(tableSelection);
      if (!mounted || targets.isEmpty) {
        return;
      }

      await _runEdit(() async {
        for (final target in targets) {
          await widget.document.applyCellStyle(
            section: target.section,
            paragraph: target.paragraph,
            controlIndex: target.controlIndex,
            cellIndex: target.cellIndex,
            cellParagraph: target.cellParagraph,
            styleId: styleId,
          );
        }
        _controller.tableCellSelection = tableSelection;
      });
      return;
    }

    final selection = _controller.selection;
    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    await _runEdit(() async {
      for (
        var paragraph = start.paragraph;
        paragraph <= end.paragraph;
        paragraph += 1
      ) {
        await widget.document.applyStyle(
          section: start.section,
          paragraph: paragraph,
          styleId: styleId,
        );
      }
      _controller.selection = selection.isCollapsed
          ? RhwpSelectionRange.collapsed(start)
          : RhwpSelectionRange(start: start, end: end);
    });
  }

  Future<List<_TableCellParagraphTarget>> _tableCellParagraphTargets(
    RhwpTableCellSelection selection,
  ) async {
    final activeCellIndex = selection.activeCellIndex;
    if (selection.isTextEditing && activeCellIndex != null) {
      return [
        _TableCellParagraphTarget(
          section: selection.section,
          paragraph: selection.paragraph,
          controlIndex: selection.controlIndex,
          cellIndex: activeCellIndex,
          cellParagraph: selection.activeCellParagraph,
        ),
      ];
    }

    final allCells = await _tableCellsForSelection(selection);
    final cells = [
      for (final entry in allCells)
        if (selection.containsCell(entry.cell)) entry.cell,
    ];
    final segments = await _tableCellTextSegments(selection);
    final targets = <String, _TableCellParagraphTarget>{};

    for (final cell in cells) {
      final cellIndex = cell.modelCellIndex;
      if (cellIndex == null) {
        continue;
      }

      var hasSegment = false;
      for (final segment in segments) {
        if (segment.cellIndex != cellIndex) {
          continue;
        }
        hasSegment = true;
        final key =
            '${segment.section}/${segment.paragraph}/${segment.controlIndex}/${segment.cellIndex}/${segment.cellParagraph}';
        targets[key] = _TableCellParagraphTarget(
          section: segment.section,
          paragraph: segment.paragraph,
          controlIndex: segment.controlIndex,
          cellIndex: segment.cellIndex,
          cellParagraph: segment.cellParagraph,
        );
      }

      if (!hasSegment) {
        final key =
            '${cell.section}/${cell.paragraph}/${cell.controlIndex}/$cellIndex/0';
        targets[key] = _TableCellParagraphTarget(
          section: cell.section,
          paragraph: cell.paragraph,
          controlIndex: cell.controlIndex,
          cellIndex: cellIndex,
          cellParagraph: 0,
        );
      }
    }

    return targets.values.toList(growable: false);
  }

  Future<String?> _selectedText() async {
    final selection = _controller.selection;
    if (selection.isCollapsed) {
      return null;
    }

    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    final pageCount = await widget.document.pageCount;
    final parts = <String>[];
    for (var page = 0; page < pageCount; page += 1) {
      try {
        final tree = await widget.document.pageLayerTreeModel(page);
        final text = tree.textForRange(
          startSection: start.section,
          startParagraph: start.paragraph,
          startOffset: start.offset,
          endSection: end.section,
          endParagraph: end.paragraph,
          endOffset: end.offset,
        );
        if (text.isNotEmpty) {
          parts.add(text);
        }
      } catch (_) {
        // Some rhwp builds may not expose layer-tree text for every page yet.
      }
    }

    if (parts.isEmpty) {
      return null;
    }
    return parts.join('\n');
  }

  Future<String?> _selectedTableCellText() async {
    final selection = _controller.tableCellSelection;
    if (selection == null) {
      return null;
    }

    final allCells = await _tableCellsForSelection(selection);
    final cells = [
      for (final entry in allCells)
        if (selection.containsCell(entry.cell)) entry.cell,
    ];
    if (cells.isEmpty) {
      return null;
    }

    final segments = await _tableCellTextSegments(selection);
    final buffer = StringBuffer();
    int? previousRow;
    var needsCellSeparator = false;

    for (final cell in cells) {
      if (previousRow != null && cell.row != previousRow) {
        buffer.write('\n');
        needsCellSeparator = false;
      }
      if (needsCellSeparator) {
        buffer.write('\t');
      }
      buffer.write(_tableCellTextFromSegments(cell, segments));
      previousRow = cell.row;
      needsCellSeparator = true;
    }

    return buffer.toString();
  }

  Future<List<_TableCellTextSegment>> _tableCellTextSegments(
    RhwpTableCellSelection selection,
  ) async {
    final pageCount = await widget.document.pageCount;
    final segments = <_TableCellTextSegment>[];

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final cell in tree.tableCells) {
        final cellIndex = cell.modelCellIndex;
        if (cellIndex == null || !selection.containsCell(cell)) {
          continue;
        }

        for (final run in tree.textRuns) {
          final context = run.cellContext;
          final section = run.section;
          final paragraph = run.paragraph;
          if (context == null ||
              section == null ||
              paragraph == null ||
              section != cell.section ||
              paragraph != cell.paragraph ||
              context.parentParagraph != cell.paragraph ||
              context.controlIndex != cell.controlIndex ||
              context.cellIndex != cellIndex) {
            continue;
          }

          segments.add(
            _TableCellTextSegment(
              section: section,
              paragraph: paragraph,
              controlIndex: context.controlIndex,
              cellIndex: context.cellIndex,
              cellParagraph: context.cellParagraph,
              row: cell.row,
              column: cell.column,
              startOffset: run.charStart,
              endOffset: run.charEnd,
              text: run.text,
            ),
          );
        }
      }
    }

    segments.sort((left, right) {
      final row = left.row.compareTo(right.row);
      if (row != 0) {
        return row;
      }
      final column = left.column.compareTo(right.column);
      if (column != 0) {
        return column;
      }
      final paragraph = left.cellParagraph.compareTo(right.cellParagraph);
      if (paragraph != 0) {
        return paragraph;
      }
      return left.startOffset.compareTo(right.startOffset);
    });
    return segments;
  }

  Future<int?> _tableCellParagraphEndOffsetFor(
    RhwpTableCellSelection selection,
  ) async {
    final activeCellIndex = selection.activeCellIndex;
    if (activeCellIndex == null) {
      return null;
    }

    int? endOffset;
    final segments = await _tableCellTextSegments(selection);
    for (final segment in segments) {
      if (segment.cellIndex != activeCellIndex ||
          segment.cellParagraph != selection.activeCellParagraph) {
        continue;
      }
      if (endOffset == null || segment.endOffset > endOffset) {
        endOffset = segment.endOffset;
      }
    }
    return endOffset;
  }

  String _tableCellTextFromSegments(
    RhwpTableCellLayout cell,
    List<_TableCellTextSegment> segments,
  ) {
    final cellIndex = cell.modelCellIndex;
    if (cellIndex == null) {
      return '';
    }

    final buffer = StringBuffer();
    int? previousParagraph;
    for (final segment in segments) {
      if (segment.cellIndex != cellIndex) {
        continue;
      }
      if (previousParagraph != null &&
          segment.cellParagraph != previousParagraph) {
        buffer.write('\n');
      }
      buffer.write(segment.text);
      previousParagraph = segment.cellParagraph;
    }
    return buffer.toString();
  }

  bool _isTableClipboardText(String text) {
    return text.contains('\t') || text.contains('\n') || text.contains('\r');
  }

  List<List<String>> _parseTableClipboardText(String text) {
    var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.endsWith('\n')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return [for (final row in normalized.split('\n')) row.split('\t')];
  }

  List<_TableCellDeleteRange> _tableCellDeleteRangesFromSegments(
    Iterable<_TableCellTextSegment> segments,
  ) {
    final ranges = <String, _TableCellDeleteRange>{};
    for (final segment in segments) {
      if (segment.startOffset >= segment.endOffset) {
        continue;
      }
      final key =
          '${segment.section}/${segment.paragraph}/${segment.controlIndex}/${segment.cellIndex}/${segment.cellParagraph}';
      final existing = ranges[key];
      ranges[key] = existing == null
          ? _TableCellDeleteRange(
              section: segment.section,
              paragraph: segment.paragraph,
              controlIndex: segment.controlIndex,
              cellIndex: segment.cellIndex,
              cellParagraph: segment.cellParagraph,
              startOffset: segment.startOffset,
              endOffset: segment.endOffset,
            )
          : existing.expandTo(segment);
    }
    return ranges.values.toList(growable: false);
  }

  Future<bool> _pasteTableClipboardText(
    RhwpTableCellSelection selection,
    String text,
  ) async {
    if (selection.isTextEditing || !_isTableClipboardText(text) || _busy) {
      return false;
    }

    final rows = _parseTableClipboardText(text);
    if (rows.isEmpty) {
      return false;
    }

    final cells = await _tableCellsForSelection(selection);
    if (!mounted || cells.isEmpty) {
      return false;
    }

    final targets = <({RhwpTableCellLayout cell, String text})>[];
    final targetCellIndexes = <int>{};
    var maxColumnCount = 0;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      final columns = rows[rowIndex];
      maxColumnCount = math.max(maxColumnCount, columns.length);
      for (
        var columnIndex = 0;
        columnIndex < columns.length;
        columnIndex += 1
      ) {
        final target = _tableCellAt(
          cells,
          selection.startRow + rowIndex,
          selection.startColumn + columnIndex,
        );
        final cell = target?.cell;
        final cellIndex = cell?.modelCellIndex;
        if (cell == null ||
            cellIndex == null ||
            !targetCellIndexes.add(cellIndex)) {
          continue;
        }
        targets.add((cell: cell, text: columns[columnIndex]));
      }
    }

    if (targets.isEmpty || maxColumnCount <= 0) {
      return false;
    }

    final pasteSelection = RhwpTableCellSelection(
      section: selection.section,
      paragraph: selection.paragraph,
      controlIndex: selection.controlIndex,
      startRow: selection.startRow,
      startColumn: selection.startColumn,
      endRow: selection.startRow + rows.length - 1,
      endColumn: selection.startColumn + maxColumnCount - 1,
    );
    final existingSegments = await _tableCellTextSegments(pasteSelection);
    final deleteRanges = _tableCellDeleteRangesFromSegments(
      existingSegments.where(
        (segment) => targetCellIndexes.contains(segment.cellIndex),
      ),
    );
    final hasInsertedText = targets.any((target) => target.text.isNotEmpty);
    if (deleteRanges.isEmpty && !hasInsertedText) {
      return false;
    }

    final lastTarget = targets.last;
    final edited = await _runEdit(() async {
      for (final range in deleteRanges) {
        await widget.document.deleteTextInTableCell(
          section: range.section,
          paragraph: range.paragraph,
          controlIndex: range.controlIndex,
          cellIndex: range.cellIndex,
          cellParagraph: range.cellParagraph,
          offset: range.startOffset,
          count: range.endOffset - range.startOffset,
        );
      }

      for (final target in targets) {
        if (target.text.isEmpty) {
          continue;
        }
        await widget.document.insertTextInTableCell(
          section: selection.section,
          paragraph: selection.paragraph,
          controlIndex: selection.controlIndex,
          cellIndex: target.cell.modelCellIndex!,
          cellParagraph: 0,
          offset: 0,
          text: target.text,
        );
      }

      final nextSelection = RhwpTableCellSelection(
        section: selection.section,
        paragraph: selection.paragraph,
        controlIndex: selection.controlIndex,
        startRow: lastTarget.cell.row,
        startColumn: lastTarget.cell.column,
        endRow: lastTarget.cell.endRow,
        endColumn: lastTarget.cell.endColumn,
        activeCellIndex: lastTarget.cell.modelCellIndex,
        activeOffset: lastTarget.text.length,
        isTextEditing: true,
      );
      _syncTableSelectionFields(nextSelection);
      _controller.tableCellSelection = nextSelection;
    }, deferRefresh: true);
    return edited;
  }

  Future<void> _deleteSelectedTableCellText(
    RhwpTableCellSelection selection,
  ) async {
    final segments = await _tableCellTextSegments(selection);
    final ranges = _tableCellDeleteRangesFromSegments(segments);
    if (ranges.isEmpty) {
      return;
    }

    await _runEdit(() async {
      for (final range in ranges) {
        await widget.document.deleteTextInTableCell(
          section: range.section,
          paragraph: range.paragraph,
          controlIndex: range.controlIndex,
          cellIndex: range.cellIndex,
          cellParagraph: range.cellParagraph,
          offset: range.startOffset,
          count: range.endOffset - range.startOffset,
        );
      }
      _syncTableSelectionFields(
        RhwpTableCellSelection(
          section: selection.section,
          paragraph: selection.paragraph,
          controlIndex: selection.controlIndex,
          startRow: selection.startRow,
          startColumn: selection.startColumn,
          endRow: selection.endRow,
          endColumn: selection.endColumn,
          activeCellIndex: selection.activeCellIndex,
          activeCellParagraph: selection.activeCellParagraph,
        ),
      );
    });
  }

  Future<void> _deleteBackward() async {
    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null && !tableSelection.isTextEditing) {
      await _deleteSelectedTableCellText(tableSelection);
      return;
    }

    if (_editableTableCellSelection != null) {
      await _deleteTextInSelectedTableCell(backward: true);
      return;
    }

    if (_controller.objectSelection != null) {
      await _deleteSelectedObject();
      return;
    }

    RhwpSelectionRange? deletedRange;
    final edited = await _runEdit(() async {
      final selection = _controller.selection;
      if (await _deleteSelectedText(selection)) {
        deletedRange = selection;
        return;
      }
      final cursor = _readCursor();
      if (cursor.offset <= 0) {
        return;
      }
      deletedRange = RhwpSelectionRange(
        start: cursor.copyWith(offset: cursor.offset - 1),
        end: cursor,
      );
      await widget.document.deleteText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset - 1,
        count: 1,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset - 1);
    }, deferRefresh: true);
    if (edited && deletedRange != null) {
      _recordPendingDeletionOverlay(deletedRange!);
    }
  }

  Future<void> _deleteForward() async {
    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null && !tableSelection.isTextEditing) {
      await _deleteSelectedTableCellText(tableSelection);
      return;
    }

    if (_editableTableCellSelection != null) {
      await _deleteTextInSelectedTableCell(backward: false);
      return;
    }

    if (_controller.objectSelection != null) {
      await _deleteSelectedObject();
      return;
    }

    RhwpSelectionRange? deletedRange;
    final edited = await _runEdit(() async {
      final selection = _controller.selection;
      if (await _deleteSelectedText(selection)) {
        deletedRange = selection;
        return;
      }
      final cursor = _readCursor();
      deletedRange = RhwpSelectionRange(
        start: cursor,
        end: cursor.copyWith(offset: cursor.offset + 1),
      );
      await widget.document.deleteText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        count: 1,
      );
      _controller.cursor = cursor;
    }, deferRefresh: true);
    if (edited && deletedRange != null) {
      _recordPendingDeletionOverlay(deletedRange!);
    }
  }

  Future<void> _deleteWord({required bool backward}) async {
    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null && !tableSelection.isTextEditing) {
      await _deleteSelectedTableCellText(tableSelection);
      return;
    }

    if (_editableTableCellSelection != null) {
      await _deleteTextInSelectedTableCell(backward: backward);
      return;
    }

    if (_controller.objectSelection != null) {
      await _deleteSelectedObject();
      return;
    }

    RhwpSelectionRange? deletedRange;
    final edited = await _runEdit(() async {
      final selection = _controller.selection;
      if (await _deleteSelectedText(selection)) {
        deletedRange = selection;
        return;
      }

      final cursor = _readCursor();
      final paragraphText = await _paragraphTextFor(cursor);
      final targetOffset = paragraphText == null
          ? (backward ? math.max(0, cursor.offset - 1) : cursor.offset + 1)
          : _wordBoundaryOffset(
              paragraphText.text,
              cursor.offset,
              backward ? -1 : 1,
            );
      final deleteOffset = math.min(cursor.offset, targetOffset);
      final count = (cursor.offset - targetOffset).abs();
      if (count == 0) {
        return;
      }

      deletedRange = RhwpSelectionRange(
        start: cursor.copyWith(offset: deleteOffset),
        end: cursor.copyWith(offset: deleteOffset + count),
      );
      await widget.document.deleteText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: deleteOffset,
        count: count,
      );
      _controller.cursor = cursor.copyWith(offset: deleteOffset);
    }, deferRefresh: true);
    if (edited && deletedRange != null) {
      _recordPendingDeletionOverlay(deletedRange!);
    }
  }

  Future<void> _deleteTextInSelectedTableCell({required bool backward}) async {
    final tableSelection = _editableTableCellSelection;
    if (tableSelection == null || _busy) {
      return;
    }

    final currentOffset = _parseNonNegative(_offsetController.text);
    final deleteOffset = backward ? currentOffset - 1 : currentOffset;
    if (deleteOffset < 0) {
      return;
    }

    await _runEdit(() async {
      final result = await widget.document.deleteTextInTableCell(
        section: tableSelection.section,
        paragraph: tableSelection.paragraph,
        controlIndex: tableSelection.controlIndex,
        cellIndex: tableSelection.activeCellIndex!,
        cellParagraph: tableSelection.activeCellParagraph,
        offset: deleteOffset,
        count: 1,
      );
      final nextOffset =
          _readIntResult(result, 'charOffset') ??
          (backward ? deleteOffset : currentOffset);
      _setTextIfChanged(_offsetController, nextOffset.toString());
      _controller.tableCellSelection = RhwpTableCellSelection(
        section: tableSelection.section,
        paragraph: tableSelection.paragraph,
        controlIndex: tableSelection.controlIndex,
        startRow: tableSelection.startRow,
        startColumn: tableSelection.startColumn,
        endRow: tableSelection.endRow,
        endColumn: tableSelection.endColumn,
        activeCellIndex: tableSelection.activeCellIndex,
        activeCellParagraph: tableSelection.activeCellParagraph,
        activeOffset: nextOffset,
        isTextEditing: true,
      );
    }, deferRefresh: true);
  }

  Future<void> _moveTableCellSelection(
    _TableCellNavigationDirection direction, {
    required bool extendSelection,
  }) async {
    final selection = _controller.tableCellSelection;
    if (selection == null || _busy) {
      return;
    }

    try {
      final cells = await _tableCellsForSelection(selection);
      if (!mounted || cells.isEmpty) {
        return;
      }

      final active = _activeTableCellForSelection(selection, cells);
      if (active == null) {
        return;
      }

      final target = _tableCellNeighbor(cells, active.cell, direction);
      if (target == null) {
        return;
      }

      final nextSelection = extendSelection
          ? _tableSelectionFromAnchorAndActive(
              _anchorTableCellForSelection(selection, cells, active.cell) ??
                  active.cell,
              target.cell,
            )
          : RhwpTableCellSelection.fromCell(target.cell);
      _setKeyboardTableCellSelection(nextSelection, page: target.page);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _moveTableCellSelectionByTab({required bool backward}) async {
    final selection = _controller.tableCellSelection;
    if (selection == null || _busy) {
      return;
    }

    try {
      final cells = await _tableCellsForSelection(selection);
      if (!mounted || cells.isEmpty) {
        return;
      }

      final active = _activeTableCellForSelection(selection, cells);
      if (active == null) {
        return;
      }

      final currentIndex = cells.indexWhere((entry) {
        return _sameTableCell(entry.cell, active.cell);
      });
      if (currentIndex < 0) {
        return;
      }

      final targetIndex = backward ? currentIndex - 1 : currentIndex + 1;
      if (targetIndex < 0 || targetIndex >= cells.length) {
        return;
      }

      final target = cells[targetIndex];
      _setKeyboardTableCellSelection(
        RhwpTableCellSelection.fromCell(target.cell),
        page: target.page,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _enterSelectedTableCell() async {
    final selection = _controller.tableCellSelection;
    if (selection == null || _busy) {
      return;
    }

    try {
      final cells = await _tableCellsForSelection(selection);
      if (!mounted || cells.isEmpty) {
        _focusEditor();
        return;
      }

      final active = _activeTableCellForSelection(selection, cells);
      if (active == null) {
        _focusEditor();
        return;
      }

      _setKeyboardTableCellSelection(
        RhwpTableCellSelection(
          section: active.cell.section,
          paragraph: active.cell.paragraph,
          controlIndex: active.cell.controlIndex,
          startRow: active.cell.row,
          startColumn: active.cell.column,
          endRow: active.cell.endRow,
          endColumn: active.cell.endColumn,
          activeCellIndex: active.cell.modelCellIndex,
          isTextEditing: true,
        ),
        page: active.page,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<List<({RhwpTableCellLayout cell, int page})>> _tableCellsForSelection(
    RhwpTableCellSelection selection,
  ) async {
    final pageCount = await widget.document.pageCount;
    final cells = <({RhwpTableCellLayout cell, int page})>[];

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final cell in tree.tableCells) {
        if (selection.isSameTableAs(cell)) {
          cells.add((cell: cell, page: page));
        }
      }
    }

    cells.sort((left, right) {
      final row = left.cell.row.compareTo(right.cell.row);
      if (row != 0) {
        return row;
      }
      final column = left.cell.column.compareTo(right.cell.column);
      if (column != 0) {
        return column;
      }
      return (left.cell.modelCellIndex ?? -1).compareTo(
        right.cell.modelCellIndex ?? -1,
      );
    });
    return cells;
  }

  Future<List<({RhwpTableCellLayout cell, int page})>> _tableCellStyleTargets(
    RhwpTableCellSelection selection,
  ) async {
    final cells = await _tableCellsForSelection(selection);
    if (selection.isTextEditing) {
      final activeCellIndex = selection.activeCellIndex;
      if (activeCellIndex == null) {
        return const [];
      }
      return [
        for (final entry in cells)
          if (entry.cell.modelCellIndex == activeCellIndex) entry,
      ];
    }

    final seen = <int>{};
    return [
      for (final entry in cells)
        if (selection.containsCell(entry.cell) &&
            entry.cell.modelCellIndex != null &&
            seen.add(entry.cell.modelCellIndex!))
          entry,
    ];
  }

  ({RhwpTableCellLayout cell, int page})? _activeTableCellForSelection(
    RhwpTableCellSelection selection,
    List<({RhwpTableCellLayout cell, int page})> cells,
  ) {
    final activeCellIndex = selection.activeCellIndex;
    if (activeCellIndex != null) {
      for (final entry in cells) {
        if (entry.cell.modelCellIndex == activeCellIndex) {
          return entry;
        }
      }
    }

    return _tableCellAt(cells, selection.startRow, selection.startColumn);
  }

  RhwpTableCellLayout? _anchorTableCellForSelection(
    RhwpTableCellSelection selection,
    List<({RhwpTableCellLayout cell, int page})> cells,
    RhwpTableCellLayout active,
  ) {
    final start = _tableCellAt(
      cells,
      selection.startRow,
      selection.startColumn,
    );
    final end = _tableCellAt(cells, selection.endRow, selection.endColumn);
    if (start != null &&
        end != null &&
        !_sameTableCell(start.cell, end.cell) &&
        _sameTableCell(start.cell, active)) {
      return end.cell;
    }
    return start?.cell;
  }

  ({RhwpTableCellLayout cell, int page})? _tableCellAt(
    List<({RhwpTableCellLayout cell, int page})> cells,
    int row,
    int column,
  ) {
    for (final entry in cells) {
      if (entry.cell.row <= row &&
          entry.cell.endRow >= row &&
          entry.cell.column <= column &&
          entry.cell.endColumn >= column) {
        return entry;
      }
    }
    return null;
  }

  ({RhwpTableCellLayout cell, int page})? _tableCellNeighbor(
    List<({RhwpTableCellLayout cell, int page})> cells,
    RhwpTableCellLayout active,
    _TableCellNavigationDirection direction,
  ) {
    final candidates = cells.where((entry) {
      final cell = entry.cell;
      if (_sameTableCell(cell, active)) {
        return false;
      }

      return switch (direction) {
        _TableCellNavigationDirection.left =>
          _rowRangesOverlap(cell, active) && cell.endColumn < active.column,
        _TableCellNavigationDirection.right =>
          _rowRangesOverlap(cell, active) && cell.column > active.endColumn,
        _TableCellNavigationDirection.up =>
          _columnRangesOverlap(cell, active) && cell.endRow < active.row,
        _TableCellNavigationDirection.down =>
          _columnRangesOverlap(cell, active) && cell.row > active.endRow,
      };
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((left, right) {
      return switch (direction) {
        _TableCellNavigationDirection.left => _compareLeftTableCellCandidate(
          active,
          left.cell,
          right.cell,
        ),
        _TableCellNavigationDirection.right => _compareRightTableCellCandidate(
          active,
          left.cell,
          right.cell,
        ),
        _TableCellNavigationDirection.up => _compareUpTableCellCandidate(
          active,
          left.cell,
          right.cell,
        ),
        _TableCellNavigationDirection.down => _compareDownTableCellCandidate(
          active,
          left.cell,
          right.cell,
        ),
      };
    });
    return candidates.first;
  }

  int _compareLeftTableCellCandidate(
    RhwpTableCellLayout active,
    RhwpTableCellLayout left,
    RhwpTableCellLayout right,
  ) {
    final column = right.endColumn.compareTo(left.endColumn);
    if (column != 0) {
      return column;
    }
    return _compareTableCellDistance(active, left, right);
  }

  int _compareRightTableCellCandidate(
    RhwpTableCellLayout active,
    RhwpTableCellLayout left,
    RhwpTableCellLayout right,
  ) {
    final column = left.column.compareTo(right.column);
    if (column != 0) {
      return column;
    }
    return _compareTableCellDistance(active, left, right);
  }

  int _compareUpTableCellCandidate(
    RhwpTableCellLayout active,
    RhwpTableCellLayout left,
    RhwpTableCellLayout right,
  ) {
    final row = right.endRow.compareTo(left.endRow);
    if (row != 0) {
      return row;
    }
    return _compareTableCellDistance(active, left, right);
  }

  int _compareDownTableCellCandidate(
    RhwpTableCellLayout active,
    RhwpTableCellLayout left,
    RhwpTableCellLayout right,
  ) {
    final row = left.row.compareTo(right.row);
    if (row != 0) {
      return row;
    }
    return _compareTableCellDistance(active, left, right);
  }

  int _compareTableCellDistance(
    RhwpTableCellLayout active,
    RhwpTableCellLayout left,
    RhwpTableCellLayout right,
  ) {
    final leftDistance = (left.bounds.center - active.bounds.center).distance;
    final rightDistance = (right.bounds.center - active.bounds.center).distance;
    final distance = leftDistance.compareTo(rightDistance);
    if (distance != 0) {
      return distance;
    }
    final row = left.row.compareTo(right.row);
    if (row != 0) {
      return row;
    }
    return left.column.compareTo(right.column);
  }

  bool _rowRangesOverlap(RhwpTableCellLayout a, RhwpTableCellLayout b) {
    return a.row <= b.endRow && b.row <= a.endRow;
  }

  bool _columnRangesOverlap(RhwpTableCellLayout a, RhwpTableCellLayout b) {
    return a.column <= b.endColumn && b.column <= a.endColumn;
  }

  bool _sameTableCell(RhwpTableCellLayout a, RhwpTableCellLayout b) {
    return a.section == b.section &&
        a.paragraph == b.paragraph &&
        a.controlIndex == b.controlIndex &&
        a.row == b.row &&
        a.column == b.column &&
        a.modelCellIndex == b.modelCellIndex;
  }

  RhwpTableCellSelection _tableSelectionFromAnchorAndActive(
    RhwpTableCellLayout anchor,
    RhwpTableCellLayout active,
  ) {
    return RhwpTableCellSelection(
      section: anchor.section,
      paragraph: anchor.paragraph,
      controlIndex: anchor.controlIndex,
      startRow: math.min(anchor.row, active.row),
      startColumn: math.min(anchor.column, active.column),
      endRow: math.max(anchor.endRow, active.endRow),
      endColumn: math.max(anchor.endColumn, active.endColumn),
      activeCellIndex: active.modelCellIndex,
    );
  }

  void _setKeyboardTableCellSelection(
    RhwpTableCellSelection selection, {
    required int page,
  }) {
    _controller.clearSelection();
    _syncTableSelectionFields(selection);
    _controller.tableCellSelection = selection;
    unawaited(_controller.goToPage(page));
    _focusEditor();
  }

  Future<bool> _deleteSelectedText(RhwpSelectionRange selection) async {
    if (selection.isCollapsed) {
      return false;
    }

    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return false;
    }

    if (start.paragraph == end.paragraph) {
      final count = end.offset - start.offset;
      if (count <= 0) {
        return false;
      }

      await widget.document.deleteText(
        section: start.section,
        paragraph: start.paragraph,
        offset: start.offset,
        count: count,
      );
      _controller.cursor = start;
      return true;
    }

    if (start.paragraph > end.paragraph) {
      return false;
    }

    await widget.document.deleteRange(
      section: start.section,
      startParagraph: start.paragraph,
      startOffset: start.offset,
      endParagraph: end.paragraph,
      endOffset: end.offset,
    );
    _controller.cursor = start;
    return true;
  }

  bool get _hasActiveTextInputConnection {
    final connection = _textInputConnection;
    return connection != null && connection.attached;
  }

  bool get _isDesktopTextInputPlatform {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS => false,
    };
  }

  bool get _hasPendingDesktopTextInputFocusRelease {
    final timer = _textInputFocusReleaseTimer;
    return timer != null && timer.isActive;
  }

  bool get _shouldDelayDesktopTextInputFocusRelease {
    return _isDesktopTextInputPlatform &&
        (_pendingTextInputCommits > 0 ||
            (_hasDeferredEditRefresh && _deferredEditRefreshAwaitsTextInput));
  }

  bool get _hasPendingOptimisticTextEdit {
    return _pendingTextOverlays.isNotEmpty ||
        _pendingDeletionOverlays.isNotEmpty;
  }

  bool get _hasScheduledDeferredEditRefresh {
    final timer = _deferredEditRefreshTimer;
    return timer != null && timer.isActive;
  }

  bool get _hasExternalPrimaryFocus {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null ||
        primaryFocus == _focusNode ||
        primaryFocus == _searchFocusNode ||
        primaryFocus == _replaceFocusNode) {
      return false;
    }

    final focusContext = primaryFocus.context;
    if (focusContext == null) {
      return false;
    }

    return !_isEditorRelatedFocusContext(focusContext);
  }

  bool get _hasExternalPrimaryFocusEndingTextInput {
    if (!_hasExternalPrimaryFocus) {
      return false;
    }
    return !_shouldTreatExternalFocusAsDesktopTextInputChurn;
  }

  bool get _shouldTreatExternalFocusAsDesktopTextInputChurn {
    return _isDesktopTextInputPlatform &&
        (_pendingTextInputCommits > 0 ||
            _hasActiveTextInputConnection ||
            _hasPendingDesktopTextInputFocusRelease ||
            _desktopTextInputCommitHoldActive);
  }

  bool _isEditorRelatedFocusContext(BuildContext focusContext) {
    return identical(focusContext, context) ||
        _hasAncestorContext(focusContext, context) ||
        _hasAncestorContext(context, focusContext);
  }

  bool _hasAncestorContext(BuildContext child, BuildContext ancestor) {
    var found = false;
    child.visitAncestorElements((element) {
      if (identical(element, ancestor)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  bool get _shouldKeepDesktopTextEditRefreshHeld {
    return _isDesktopTextInputPlatform &&
        _hasDeferredEditRefresh &&
        _hasPendingOptimisticTextEdit &&
        !_hasExternalPrimaryFocusEndingTextInput &&
        (_focusNode.hasFocus ||
            _hasActiveTextInputConnection ||
            _hasPendingDesktopTextInputFocusRelease ||
            _desktopTextInputCommitHoldActive);
  }

  bool get _shouldTreatPendingDesktopTextEditAsChurn {
    return _isDesktopTextInputPlatform &&
        _hasDeferredEditRefresh &&
        _hasPendingOptimisticTextEdit &&
        !_hasExternalPrimaryFocusEndingTextInput &&
        (_deferredEditRefreshAwaitsTextInput ||
            _hasScheduledDeferredEditRefresh ||
            _pendingTextInputCommits > 0);
  }

  bool get _shouldHoldFocusedTextInputRefresh {
    return _hasDeferredEditRefresh &&
        _deferredEditRefreshAwaitsTextInput &&
        !_hasExternalPrimaryFocusEndingTextInput &&
        (_focusNode.hasFocus ||
            _hasActiveTextInputConnection ||
            _hasPendingDesktopTextInputFocusRelease ||
            _desktopTextInputCommitHoldActive);
  }

  bool get _shouldHoldFocusedDesktopTextRefresh {
    return widget.holdTextRefreshWhileFocused &&
        _isDesktopTextInputPlatform &&
        _textRefreshHeldForFocusedInput &&
        _hasDeferredEditRefresh &&
        _hasPendingOptimisticTextEdit &&
        !_hasExternalPrimaryFocus;
  }

  bool get _shouldHoldDeferredRefreshForTextInput {
    return _pendingTextInputCommits > 0 ||
        _focusNode.hasFocus ||
        _hasActiveTextInputConnection ||
        _hasPendingDesktopTextInputFocusRelease ||
        _desktopTextInputCommitHoldActive ||
        _shouldHoldFocusedDesktopTextRefresh ||
        _shouldKeepDesktopTextEditRefreshHeld;
  }

  Duration get _desktopTextInputFocusReleaseDelay {
    final editDelay = widget.editRefreshDelay;
    if (editDelay <= _minimumDesktopTextInputFocusReleaseDelay) {
      return _minimumDesktopTextInputFocusReleaseDelay;
    }
    if (editDelay >= _maximumDesktopTextInputFocusReleaseDelay) {
      return _maximumDesktopTextInputFocusReleaseDelay;
    }
    return editDelay;
  }

  bool get _shouldIgnoreTextInputActionAfterCommit {
    return _ignoreTextInputActions;
  }

  void _startTextInputActionIgnoreWindow() {
    _textInputActionIgnoreTimer?.cancel();
    _ignoreTextInputActions = true;
    _textInputActionIgnoreTimer = Timer(_textInputActionIgnoreWindow, () {
      _ignoreTextInputActions = false;
      _textInputActionIgnoreTimer = null;
    });
  }

  void _startDesktopTextInputCommitHoldWindow() {
    if (!_isDesktopTextInputPlatform) {
      return;
    }

    _desktopTextInputCommitHoldTimer?.cancel();
    _desktopTextInputCommitHoldActive = true;
    _desktopTextInputCommitHoldTimer = Timer(
      _desktopTextInputCommitHoldWindow,
      () {
        _desktopTextInputCommitHoldTimer = null;
        _desktopTextInputCommitHoldActive = false;
        if (_shouldKeepDesktopTextEditRefreshHeld &&
            !_hasExternalPrimaryFocus) {
          _restoreDesktopTextInputAfterChurn();
          return;
        }
        if (!_shouldHoldDeferredRefreshForTextInput) {
          _releaseDeferredEditRefreshFromTextInput();
        }
      },
    );
  }

  void _restoreDesktopTextInputAfterChurn() {
    if (!_isDesktopTextInputPlatform || !mounted) {
      return;
    }

    scheduleMicrotask(() {
      if (!mounted) {
        return;
      }

      if (_searchFocusNode.hasFocus) {
        return;
      }
      if (_hasExternalPrimaryFocus) {
        return;
      }

      _textInputFocusReleaseTimer?.cancel();
      _textInputFocusReleaseTimer = null;
      _holdDeferredEditRefreshForTextInput();
      _focusNode.requestFocus();
      _openTextInput();
    });
  }

  void _clearDesktopTextInputCommitHoldWindow() {
    _desktopTextInputCommitHoldTimer?.cancel();
    _desktopTextInputCommitHoldTimer = null;
    _desktopTextInputCommitHoldActive = false;
  }

  void _scheduleDesktopTextInputFocusRelease() {
    _textInputFocusReleaseTimer?.cancel();
    _textInputFocusReleaseTimer = Timer(_desktopTextInputFocusReleaseDelay, () {
      _textInputFocusReleaseTimer = null;
      if (!mounted) {
        return;
      }
      if (_focusNode.hasFocus) {
        _openTextInput();
        return;
      }
      _closeTextInput();
    });
  }

  bool get _shouldTreatConnectionClosedAsDesktopInputChurn {
    if (!_isDesktopTextInputPlatform) {
      return false;
    }

    if (_shouldTreatPendingDesktopTextEditAsChurn) {
      return true;
    }

    if (_hasExternalPrimaryFocusEndingTextInput) {
      return false;
    }

    if (_pendingTextInputCommits <= 0 &&
        (!_hasDeferredEditRefresh || !_deferredEditRefreshAwaitsTextInput)) {
      return false;
    }

    return _pendingTextInputCommits > 0 ||
        _focusNode.hasFocus ||
        _hasPendingDesktopTextInputFocusRelease ||
        _desktopTextInputCommitHoldActive;
  }

  bool get _shouldTreatTextInputActionAsDesktopInputChurn {
    if (!_isDesktopTextInputPlatform) {
      return false;
    }

    if (_shouldTreatPendingDesktopTextEditAsChurn) {
      return true;
    }

    if (_hasExternalPrimaryFocusEndingTextInput) {
      return false;
    }

    if (_pendingTextInputCommits <= 0 &&
        (!_hasDeferredEditRefresh || !_deferredEditRefreshAwaitsTextInput)) {
      return false;
    }

    return _pendingTextInputCommits > 0 ||
        _focusNode.hasFocus ||
        _hasPendingDesktopTextInputFocusRelease ||
        _hasActiveTextInputConnection ||
        _desktopTextInputCommitHoldActive;
  }

  void _scheduleDeferredEditRefresh({
    bool awaitTextInputBeforeRefresh = false,
  }) {
    _hasDeferredEditRefresh = true;
    _deferredEditRefreshTimer?.cancel();
    _deferredEditRefreshAwaitsTextInput =
        _deferredEditRefreshAwaitsTextInput ||
        (awaitTextInputBeforeRefresh && _shouldHoldDeferredRefreshForTextInput);
    if (_deferredEditRefreshAwaitsTextInput) {
      return;
    }

    final delay = widget.editRefreshDelay;
    if (delay <= Duration.zero) {
      scheduleMicrotask(_flushDeferredEditRefresh);
      return;
    }
    _deferredEditRefreshTimer = Timer(delay, _flushDeferredEditRefresh);
  }

  void _cancelDeferredEditRefresh() {
    _deferredEditRefreshTimer?.cancel();
    _deferredEditRefreshTimer = null;
    _hasDeferredEditRefresh = false;
    _deferredEditRefreshAwaitsTextInput = false;
    _textRefreshHeldForFocusedInput = false;
    _textInputUndoBatchOpen = false;
    _clearDesktopTextInputCommitHoldWindow();
    _setPendingTextOverlays(const []);
    _pendingTextRefreshRevision = null;
    _pendingDeletionOverlays = const [];
    _pendingDeletionRefreshRevision = null;
  }

  void _releaseDeferredEditRefreshFromTextInput({bool force = false}) {
    if (!_hasDeferredEditRefresh || !_deferredEditRefreshAwaitsTextInput) {
      return;
    }
    if (!force &&
        (_shouldHoldFocusedTextInputRefresh ||
            (_isDesktopTextInputPlatform &&
                _shouldHoldDeferredRefreshForTextInput))) {
      return;
    }

    _textRefreshHeldForFocusedInput = false;
    _deferredEditRefreshAwaitsTextInput = false;
    _scheduleDeferredEditRefresh();
  }

  void _beginTextInputCommit() {
    _pendingTextInputCommits += 1;
  }

  void _endTextInputCommit() {
    if (_pendingTextInputCommits <= 0) {
      _pendingTextInputCommits = 0;
      return;
    }

    _pendingTextInputCommits -= 1;
    if (!_shouldHoldDeferredRefreshForTextInput) {
      _releaseDeferredEditRefreshFromTextInput();
    }
  }

  void _holdDeferredEditRefreshForTextInput() {
    if (!_hasDeferredEditRefresh ||
        _deferredEditRefreshAwaitsTextInput ||
        (_pendingTextOverlays.isEmpty && _pendingDeletionOverlays.isEmpty)) {
      return;
    }

    _deferredEditRefreshTimer?.cancel();
    _deferredEditRefreshTimer = null;
    _deferredEditRefreshAwaitsTextInput = true;
  }

  void _setCursorForPendingText(RhwpCursorPosition cursor) {
    _suppressControllerChangedSetState = true;
    try {
      _controller.cursor = cursor;
    } finally {
      _suppressControllerChangedSetState = false;
    }
  }

  void _setTableSelectionForPendingText(RhwpTableCellSelection selection) {
    _suppressControllerChangedSetState = true;
    try {
      _controller.tableCellSelection = selection;
    } finally {
      _suppressControllerChangedSetState = false;
    }
  }

  void _setPendingTextOverlays(List<_PendingTextOverlay> overlays) {
    final nextOverlays = List<_PendingTextOverlay>.unmodifiable(overlays);
    _pendingTextOverlays = nextOverlays;
    _pendingTextOverlaysListenable.value = nextOverlays;
  }

  void _recordPendingTextOverlay(RhwpCursorPosition cursor, String text) {
    if (!mounted || text.isEmpty || text.contains('\n')) {
      return;
    }

    final page = _controller.currentPage;
    final overlays = List<_PendingTextOverlay>.of(_pendingTextOverlays);
    if (overlays.isNotEmpty) {
      final last = overlays.last;
      final nextOffset = last.cursor.offset + last.text.length;
      if (last.page == page &&
          last.cursor.section == cursor.section &&
          last.cursor.paragraph == cursor.paragraph &&
          nextOffset == cursor.offset) {
        overlays[overlays.length - 1] = last.copyWith(text: last.text + text);
        _setPendingTextOverlays(overlays);
        _pendingTextRefreshRevision = null;
        return;
      }
    }

    overlays.add(_PendingTextOverlay(page: page, cursor: cursor, text: text));
    _setPendingTextOverlays(overlays);
    _pendingTextRefreshRevision = null;
  }

  void _recordPendingDeletionOverlay(RhwpSelectionRange range) {
    if (!mounted || range.isCollapsed) {
      return;
    }

    final start = range.normalizedStart;
    final end = range.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    final overlays = List<_PendingDeletionOverlay>.of(_pendingDeletionOverlays)
      ..add(
        _PendingDeletionOverlay(
          page: _controller.currentPage,
          range: RhwpSelectionRange(start: start, end: end),
        ),
      );
    setState(() {
      _pendingDeletionOverlays = List.unmodifiable(overlays);
      _pendingDeletionRefreshRevision = null;
    });
  }

  void _handlePageRendered(int page, int renderRevision) {
    final textRevision = _pendingTextRefreshRevision;
    var nextTextOverlays = _pendingTextOverlays;
    var textChanged = false;
    if (textRevision != null &&
        renderRevision == textRevision &&
        _pendingTextOverlays.isNotEmpty) {
      nextTextOverlays = _pendingTextOverlays
          .where((overlay) => overlay.page != page)
          .toList(growable: false);
      textChanged = nextTextOverlays.length != _pendingTextOverlays.length;
    }

    final deletionRevision = _pendingDeletionRefreshRevision;
    var nextDeletionOverlays = _pendingDeletionOverlays;
    var deletionChanged = false;
    if (deletionRevision != null &&
        renderRevision == deletionRevision &&
        _pendingDeletionOverlays.isNotEmpty) {
      nextDeletionOverlays = _pendingDeletionOverlays
          .where((overlay) => overlay.page != page)
          .toList(growable: false);
      deletionChanged =
          nextDeletionOverlays.length != _pendingDeletionOverlays.length;
    }

    if (!textChanged && !deletionChanged) {
      return;
    }

    if (textChanged) {
      _setPendingTextOverlays(nextTextOverlays);
    }
    if (nextTextOverlays.isEmpty) {
      _pendingTextRefreshRevision = null;
    }

    if (!deletionChanged) {
      return;
    }

    setState(() {
      if (deletionChanged) {
        _pendingDeletionOverlays = nextDeletionOverlays;
      }
      if (nextDeletionOverlays.isEmpty) {
        _pendingDeletionRefreshRevision = null;
      }
    });
  }

  void _flushDeferredEditRefresh() {
    if (!_hasDeferredEditRefresh) {
      return;
    }
    if (_deferredEditRefreshAwaitsTextInput &&
        _shouldHoldDeferredRefreshForTextInput) {
      return;
    }
    if (_shouldKeepDesktopTextEditRefreshHeld) {
      _deferredEditRefreshAwaitsTextInput = true;
      _deferredEditRefreshTimer?.cancel();
      _deferredEditRefreshTimer = null;
      _restoreDesktopTextInputAfterChurn();
      return;
    }
    _deferredEditRefreshAwaitsTextInput = false;
    if (_busy) {
      _scheduleDeferredEditRefresh();
      return;
    }
    _deferredEditRefreshTimer?.cancel();
    _deferredEditRefreshTimer = null;
    _hasDeferredEditRefresh = false;
    if (!mounted) {
      return;
    }

    setState(() {
      _renderRevision += 1;
      _pendingTextRefreshRevision = _pendingTextOverlays.isEmpty
          ? null
          : _renderRevision;
      _pendingDeletionRefreshRevision = _pendingDeletionOverlays.isEmpty
          ? null
          : _renderRevision;
    });
    _textRefreshHeldForFocusedInput = false;
    _textInputUndoBatchOpen = false;
    widget.onChanged?.call(widget.document);
  }

  Future<bool> _runEdit(
    Future<void> Function() edit, {
    bool deferRefresh = false,
    bool awaitTextInputBeforeRefresh = false,
    bool visibleBusy = true,
    bool mergeIntoTextInputUndoBatch = false,
  }) async {
    if (visibleBusy) {
      setState(() {
        _busy = true;
        _visibleBusy = true;
        _error = null;
      });
    } else {
      _busy = true;
      _visibleBusy = false;
      _error = null;
    }

    int? undoSnapshot;
    try {
      final reuseTextInputUndoSnapshot =
          mergeIntoTextInputUndoBatch &&
          _textInputUndoBatchOpen &&
          _undoSnapshots.isNotEmpty;
      if (!reuseTextInputUndoSnapshot) {
        undoSnapshot = await widget.document.saveSnapshot();
      }
      await edit();
      await _discardSnapshots(_redoSnapshots);
      _redoSnapshots.clear();
      if (undoSnapshot != null) {
        _undoSnapshots.add(undoSnapshot);
        if (mergeIntoTextInputUndoBatch) {
          _textInputUndoBatchOpen = true;
        }
        if (_undoSnapshots.length > _maxUndoSnapshots) {
          final stale = _undoSnapshots.removeAt(0);
          await widget.document.discardSnapshot(stale);
        }
      }
      if (!mergeIntoTextInputUndoBatch) {
        _textInputUndoBatchOpen = false;
      }
      if (!mounted) {
        return false;
      }
      if (!deferRefresh) {
        _cancelDeferredEditRefresh();
      }
      if (visibleBusy || !deferRefresh) {
        setState(() {
          _busy = false;
          _visibleBusy = false;
          if (!deferRefresh) {
            _renderRevision += 1;
          }
        });
      } else {
        _busy = false;
        _visibleBusy = false;
      }
      if (deferRefresh) {
        _scheduleDeferredEditRefresh(
          awaitTextInputBeforeRefresh: awaitTextInputBeforeRefresh,
        );
      } else {
        widget.onChanged?.call(widget.document);
      }
      return true;
    } catch (error) {
      _textInputUndoBatchOpen = false;
      if (undoSnapshot != null) {
        try {
          await widget.document.discardSnapshot(undoSnapshot);
        } catch (_) {
          // Keep the original edit failure visible.
        }
      }
      if (!mounted) {
        return false;
      }
      setState(() {
        _busy = false;
        _visibleBusy = false;
        _error = error;
      });
      return false;
    }
  }

  Future<void> _discardSnapshots(List<int> snapshotIds) async {
    for (final snapshotId in snapshotIds) {
      await widget.document.discardSnapshot(snapshotId);
    }
  }

  Future<void> _undoEdit() async {
    if (_busy || _undoSnapshots.isEmpty) {
      return;
    }

    final targetSnapshot = _undoSnapshots.removeLast();
    await _restoreHistorySnapshot(
      targetSnapshot: targetSnapshot,
      destinationStack: _redoSnapshots,
      rollbackStack: _undoSnapshots,
    );
  }

  Future<void> _redoEdit() async {
    if (_busy || _redoSnapshots.isEmpty) {
      return;
    }

    final targetSnapshot = _redoSnapshots.removeLast();
    await _restoreHistorySnapshot(
      targetSnapshot: targetSnapshot,
      destinationStack: _undoSnapshots,
      rollbackStack: _redoSnapshots,
    );
  }

  Future<void> _restoreHistorySnapshot({
    required int targetSnapshot,
    required List<int> destinationStack,
    required List<int> rollbackStack,
  }) async {
    _cancelDeferredEditRefresh();
    setState(() {
      _busy = true;
      _visibleBusy = true;
      _error = null;
    });

    int? currentSnapshot;
    try {
      currentSnapshot = await widget.document.saveSnapshot();
      await widget.document.restoreSnapshot(targetSnapshot);
      await widget.document.discardSnapshot(targetSnapshot);
      destinationStack.add(currentSnapshot);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _visibleBusy = false;
        _renderRevision += 1;
      });
      widget.onChanged?.call(widget.document);
    } catch (error) {
      rollbackStack.add(targetSnapshot);
      if (currentSnapshot != null) {
        try {
          await widget.document.discardSnapshot(currentSnapshot);
        } catch (_) {
          // Keep the original restore failure visible.
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _visibleBusy = false;
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

  int _parsePositive(String text, {required int max}) {
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1) {
      return 1;
    }
    return math.min(parsed, max);
  }

  _TableReference _readTableReference() {
    final ref = _TableReference(
      section: _parseNonNegative(_sectionController.text),
      paragraph: _parseNonNegative(_tableParagraphController.text),
      controlIndex: _parseNonNegative(_tableControlController.text),
      row: _parseNonNegative(_tableRowController.text),
      column: _parseNonNegative(_tableColumnController.text),
      endRow: _parseNonNegative(_tableEndRowController.text),
      endColumn: _parseNonNegative(_tableEndColumnController.text),
    );
    _setTextIfChanged(_tableParagraphController, ref.paragraph.toString());
    _setTextIfChanged(_tableControlController, ref.controlIndex.toString());
    _setTextIfChanged(_tableRowController, ref.row.toString());
    _setTextIfChanged(_tableColumnController, ref.column.toString());
    _setTextIfChanged(_tableEndRowController, ref.endRow.toString());
    _setTextIfChanged(_tableEndColumnController, ref.endColumn.toString());
    return ref;
  }

  int? _readIntResult(String resultJson, String key) {
    try {
      final decoded = jsonDecode(resultJson);
      if (decoded is Map) {
        final value = decoded[key];
        if (value is num) {
          return value.toInt();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  RhwpTableCellSelection? get _editableTableCellSelection {
    final selection = _controller.tableCellSelection;
    if (selection == null || selection.activeCellIndex == null) {
      return null;
    }
    return selection;
  }

  void _setCursorFromPage(RhwpCursorPosition cursor) {
    _controller.cursor = cursor;
  }

  void _setTableSelectionFromPage(RhwpTableCellSelection? selection) {
    if (selection == null) {
      _controller.clearTableCellSelection();
      return;
    }

    _controller.clearSelection();
    _syncTableSelectionFields(selection);
    _controller.tableCellSelection = selection;
  }

  void _setObjectSelectionFromPage(RhwpObjectSelection? selection) {
    if (selection == null) {
      _controller.clearObjectSelection();
      return;
    }

    _controller.clearSelection();
    _controller.objectSelection = selection;
  }

  void _setSelectionFromPage(RhwpSelectionRange selection) {
    _controller.selection = selection;
  }

  Future<void> _selectParagraphFromPage(RhwpCursorPosition cursor) async {
    if (_busy) {
      return;
    }

    final end = await _paragraphEndFor(cursor);
    if (!mounted || end == null) {
      return;
    }

    _controller.selection = RhwpSelectionRange(
      start: cursor.copyWith(offset: 0),
      end: end,
    );
    _focusEditor();
  }

  void _focusEditor() {
    _focusNode.requestFocus();
    _openTextInput();
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    _focusEditor();

    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    final overlaySize = overlay is RenderBox ? overlay.size : Size.zero;
    final action = await showMenu<_EditorContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        math.max(0, overlaySize.width - globalPosition.dx),
        math.max(0, overlaySize.height - globalPosition.dy),
      ),
      items: _contextMenuItems(),
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _EditorContextMenuAction.selectAll:
        await _selectAllText();
      case _EditorContextMenuAction.cut:
        await _cutSelection();
      case _EditorContextMenuAction.copy:
        await _copySelection();
      case _EditorContextMenuAction.paste:
        await _pasteClipboard();
      case _EditorContextMenuAction.bold:
        await _toggleCharFormat(bold: true);
      case _EditorContextMenuAction.italic:
        await _toggleCharFormat(italic: true);
      case _EditorContextMenuAction.underline:
        await _toggleCharFormat(underline: true);
      case _EditorContextMenuAction.strikethrough:
        await _toggleCharFormat(strikethrough: true);
      case _EditorContextMenuAction.charShape:
        await _showCharShapeDialog();
      case _EditorContextMenuAction.paraShape:
        await _showParaShapeDialog();
      case _EditorContextMenuAction.alignLeft:
        await _applyParagraphAlignment('left');
      case _EditorContextMenuAction.alignCenter:
        await _applyParagraphAlignment('center');
      case _EditorContextMenuAction.alignRight:
        await _applyParagraphAlignment('right');
      case _EditorContextMenuAction.alignJustify:
        await _applyParagraphAlignment('justify');
      case _EditorContextMenuAction.insertTable:
        await _insertTable();
      case _EditorContextMenuAction.insertTableRow:
        await _insertTableRow();
      case _EditorContextMenuAction.insertTableColumn:
        await _insertTableColumn();
      case _EditorContextMenuAction.mergeCells:
        await _mergeTableCells();
      case _EditorContextMenuAction.splitCell:
        await _splitTableCell();
      case _EditorContextMenuAction.splitCellInto:
        await _splitTableCellInto();
      case _EditorContextMenuAction.deleteObject:
        await _deleteSelectedObject();
      case _EditorContextMenuAction.bringObjectToFront:
        await _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.front);
      case _EditorContextMenuAction.sendObjectToBack:
        await _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.back);
      case _EditorContextMenuAction.moveObjectForward:
        await _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.forward);
      case _EditorContextMenuAction.moveObjectBackward:
        await _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.backward);
      case _EditorContextMenuAction.objectProperties:
        await _showObjectPropertiesDialog();
    }
  }

  List<PopupMenuEntry<_EditorContextMenuAction>> _contextMenuItems() {
    final hasSelection = !_controller.selection.isCollapsed;
    final hasTableSelection = _controller.tableCellSelection != null;
    final hasObjectSelection = _controller.objectSelection != null;

    if (hasObjectSelection) {
      return [
        _contextMenuItem(
          action: _EditorContextMenuAction.selectAll,
          icon: Icons.select_all,
          label: '모두 선택',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.cut,
          icon: Icons.content_cut,
          label: '잘라내기',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.copy,
          icon: Icons.content_copy,
          label: '복사',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.paste,
          icon: Icons.content_paste,
          label: '붙여넣기',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.objectProperties,
          icon: Icons.aspect_ratio,
          label: '개체 속성',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.bringObjectToFront,
          icon: Icons.flip_to_front,
          label: '맨 앞으로',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.moveObjectForward,
          icon: Icons.arrow_upward,
          label: '앞으로',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.moveObjectBackward,
          icon: Icons.arrow_downward,
          label: '뒤로',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.sendObjectToBack,
          icon: Icons.flip_to_back,
          label: '맨 뒤로',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.deleteObject,
          icon: Icons.delete_outline,
          label: '개체 삭제',
          enabled: !_busy,
        ),
      ];
    }

    if (hasTableSelection) {
      return [
        _contextMenuItem(
          action: _EditorContextMenuAction.selectAll,
          icon: Icons.select_all,
          label: '모두 선택',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.cut,
          icon: Icons.content_cut,
          label: '잘라내기',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.copy,
          icon: Icons.copy,
          label: '복사',
          enabled: true,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.paste,
          icon: Icons.content_paste,
          label: '붙여넣기',
          enabled: !_busy,
        ),
        const PopupMenuDivider(),
        _contextMenuItem(
          action: _EditorContextMenuAction.insertTableRow,
          icon: Icons.table_rows_outlined,
          label: '줄 삽입',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.insertTableColumn,
          icon: Icons.view_column_outlined,
          label: '칸 삽입',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.mergeCells,
          icon: Icons.call_merge_outlined,
          label: '셀 합치기',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.splitCell,
          icon: Icons.call_split_outlined,
          label: '셀 나누기',
          enabled: !_busy,
        ),
        _contextMenuItem(
          action: _EditorContextMenuAction.splitCellInto,
          icon: Icons.grid_4x4_outlined,
          label: '셀 나누기...',
          enabled: !_busy,
        ),
      ];
    }

    return [
      _contextMenuItem(
        action: _EditorContextMenuAction.selectAll,
        icon: Icons.select_all,
        label: '모두 선택',
        enabled: !_busy,
      ),
      const PopupMenuDivider(),
      _contextMenuItem(
        action: _EditorContextMenuAction.cut,
        icon: Icons.content_cut,
        label: '잘라내기',
        enabled: hasSelection && !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.copy,
        icon: Icons.copy,
        label: '복사',
        enabled: hasSelection,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.paste,
        icon: Icons.content_paste,
        label: '붙여넣기',
        enabled: !_busy,
      ),
      const PopupMenuDivider(),
      _contextMenuItem(
        action: _EditorContextMenuAction.bold,
        icon: Icons.format_bold,
        label: '굵게',
        enabled: hasSelection && !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.italic,
        icon: Icons.format_italic,
        label: '기울임',
        enabled: hasSelection && !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.underline,
        icon: Icons.format_underlined,
        label: '밑줄',
        enabled: hasSelection && !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.strikethrough,
        icon: Icons.format_strikethrough,
        label: '취소선',
        enabled: hasSelection && !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.charShape,
        icon: Icons.text_fields,
        label: '글자 모양',
        enabled: hasSelection && !_busy,
      ),
      const PopupMenuDivider(),
      _contextMenuItem(
        action: _EditorContextMenuAction.paraShape,
        icon: Icons.format_line_spacing,
        label: '문단 모양',
        enabled: !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.alignLeft,
        icon: Icons.format_align_left,
        label: '왼쪽 정렬',
        enabled: !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.alignCenter,
        icon: Icons.format_align_center,
        label: '가운데 정렬',
        enabled: !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.alignRight,
        icon: Icons.format_align_right,
        label: '오른쪽 정렬',
        enabled: !_busy,
      ),
      _contextMenuItem(
        action: _EditorContextMenuAction.alignJustify,
        icon: Icons.format_align_justify,
        label: '양쪽 정렬',
        enabled: !_busy,
      ),
      const PopupMenuDivider(),
      _contextMenuItem(
        action: _EditorContextMenuAction.insertTable,
        icon: Icons.table_chart_outlined,
        label: '표 만들기',
        enabled: !_busy,
      ),
    ];
  }

  PopupMenuItem<_EditorContextMenuAction> _contextMenuItem({
    required _EditorContextMenuAction action,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    return PopupMenuItem<_EditorContextMenuAction>(
      value: action,
      enabled: enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  void _openTextInput() {
    final connection = _textInputConnection;
    if (connection != null && connection.attached) {
      connection.show();
      return;
    }

    final nextConnection = TextInput.attach(
      this,
      const TextInputConfiguration(
        inputType: TextInputType.text,
        inputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
    _textInputConnection = nextConnection;
    nextConnection.setEditingState(_inputValue);
    nextConnection.show();
  }

  void _closeTextInput() {
    _textInputFocusReleaseTimer?.cancel();
    _textInputFocusReleaseTimer = null;
    final keepDesktopCommitHoldForDeferredRefresh =
        _isDesktopTextInputPlatform &&
        (_pendingTextInputCommits > 0 ||
            (_hasDeferredEditRefresh && _deferredEditRefreshAwaitsTextInput)) &&
        _desktopTextInputCommitHoldActive;
    if (!keepDesktopCommitHoldForDeferredRefresh) {
      _clearDesktopTextInputCommitHoldWindow();
    }
    final connection = _textInputConnection;
    if (connection != null && connection.attached) {
      connection.close();
    }
    _textInputConnection = null;
    if (!keepDesktopCommitHoldForDeferredRefresh) {
      _releaseDeferredEditRefreshFromTextInput();
    }
  }

  void _resetTextInputValue({bool notify = true}) {
    _setInputValue(TextEditingValue.empty, notify: notify);
    final connection = _textInputConnection;
    if (connection != null && connection.attached) {
      connection.setEditingState(_inputValue);
    }
  }

  void _setInputValue(TextEditingValue value, {bool notify = true}) {
    if (_inputValue == value) {
      return;
    }
    _inputValue = value;
    final composingText = _composingTextFor(value);
    if (_composingTextListenable.value != composingText) {
      _composingTextListenable.value = composingText;
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  String? get _composingText => _composingTextFor(_inputValue);

  String? _composingTextFor(TextEditingValue value) {
    final composing = value.composing;
    if (!composing.isValid || composing.isCollapsed) {
      return null;
    }

    final text = value.text;
    final start = composing.start.clamp(0, text.length);
    final end = composing.end.clamp(0, text.length);
    if (start >= end) {
      return null;
    }

    final composingText = text.substring(start, end);
    return composingText.isEmpty ? null : composingText;
  }

  bool _handleEscapeKey() {
    var handled = false;

    if (_inputValue != TextEditingValue.empty) {
      _resetTextInputValue();
      handled = true;
    }

    final tableSelection = _controller.tableCellSelection;
    if (tableSelection != null) {
      if (tableSelection.isTextEditing) {
        _controller.tableCellSelection = tableSelection.copyWith(
          isTextEditing: false,
        );
      } else {
        _controller.clearTableCellSelection();
      }
      handled = true;
    }

    if (_controller.objectSelection != null) {
      _controller.clearObjectSelection();
      handled = true;
    }

    if (!_controller.selection.isCollapsed) {
      _controller.clearSelection();
      handled = true;
    }

    if (_searchController.text.isNotEmpty ||
        _searchMatches.isNotEmpty ||
        _activeSearchMatch >= 0) {
      _clearSearch();
      handled = true;
    }

    if (_error != null) {
      setState(() {
        _error = null;
      });
      handled = true;
    }

    if (handled) {
      _focusEditor();
    }
    return handled;
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (value == _inputValue) {
      return;
    }

    if (value.composing.isValid && !value.composing.isCollapsed) {
      _setInputValue(value, notify: false);
      return;
    }

    final committedText = value.text;
    if (committedText.isEmpty) {
      _setInputValue(value, notify: false);
      return;
    }

    final hadComposingPreview = _composingText != null;
    _startTextInputActionIgnoreWindow();
    _startDesktopTextInputCommitHoldWindow();
    _resetTextInputValue(notify: hadComposingPreview);
    _queueCommittedText(committedText);
  }

  @override
  void performAction(TextInputAction action) {
    _resetTextInputValue();
    final desktopInputChurn = _shouldTreatTextInputActionAsDesktopInputChurn;
    if (_shouldIgnoreTextInputActionAfterCommit || desktopInputChurn) {
      if (desktopInputChurn) {
        _restoreDesktopTextInputAfterChurn();
      }
      return;
    }
    if (_shouldDelayDesktopTextInputFocusRelease) {
      _scheduleDesktopTextInputFocusRelease();
      return;
    }
    _releaseDeferredEditRefreshFromTextInput();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _textInputConnection?.connectionClosedReceived();
    _textInputConnection = null;
    if (_shouldTreatConnectionClosedAsDesktopInputChurn) {
      scheduleMicrotask(() {
        if (mounted && _focusNode.hasFocus) {
          _openTextInput();
        }
      });
      _restoreDesktopTextInputAfterChurn();
      return;
    }
    if (_shouldDelayDesktopTextInputFocusRelease) {
      _scheduleDesktopTextInputFocusRelease();
      return;
    }
    _releaseDeferredEditRefreshFromTextInput();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final extendSelection = HardwareKeyboard.instance.isShiftPressed;
    final wordNavigationPressed =
        HardwareKeyboard.instance.isAltPressed ||
        (HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed);
    final shortcutPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!shortcutPressed &&
        HardwareKeyboard.instance.isAltPressed &&
        event is KeyDownEvent &&
        _isCharShapeShortcut(event)) {
      unawaited(_showCharShapeDialog());
      return KeyEventResult.handled;
    }
    if (!shortcutPressed &&
        HardwareKeyboard.instance.isAltPressed &&
        event is KeyDownEvent &&
        _isParaShapeShortcut(event)) {
      unawaited(_showParaShapeDialog());
      return KeyEventResult.handled;
    }
    if (!shortcutPressed &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.insert) {
      _toggleOverwriteMode();
      return KeyEventResult.handled;
    }
    if (shortcutPressed && event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          _copySelection();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyX:
          _cutSelection();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyV:
          _pasteClipboard();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyA:
          _selectAllText();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyF:
          _focusSearchField();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyH:
          _focusReplaceField();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyG:
          unawaited(_showGoToPageDialog());
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyL:
          _applyParagraphFormat(alignment: 'left');
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyE:
          _applyParagraphFormat(alignment: 'center');
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyR:
          _applyParagraphFormat(alignment: 'right');
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyJ:
          _applyParagraphFormat(alignment: 'justify');
          return KeyEventResult.handled;
        case LogicalKeyboardKey.home:
          unawaited(
            _moveCursorToDocumentBoundary(
              end: false,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        case LogicalKeyboardKey.end:
          unawaited(
            _moveCursorToDocumentBoundary(
              end: true,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyZ:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _redoEdit();
          } else {
            _undoEdit();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyY:
          _redoEdit();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyO:
          _requestOpenFromEditor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyS:
          _exportFromEditor(
            HardwareKeyboard.instance.isShiftPressed
                ? RhwpExportFormat.hwpx
                : RhwpExportFormat.hwp,
          );
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyP:
          _exportFromEditor(RhwpExportFormat.pdf);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.equal:
        case LogicalKeyboardKey.add:
        case LogicalKeyboardKey.numpadAdd:
          _controller.zoomIn();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.minus:
        case LogicalKeyboardKey.numpadSubtract:
          _controller.zoomOut();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit0:
        case LogicalKeyboardKey.numpad0:
          _controller.resetZoom();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyB:
          _toggleCharFormat(bold: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyI:
          _toggleCharFormat(italic: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyU:
          _toggleCharFormat(underline: true);
          return KeyEventResult.handled;
      }
    }

    final objectNudgeStep = extendSelection ? 10.0 : 1.0;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        return _handleEscapeKey()
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      case LogicalKeyboardKey.f3:
        if (HardwareKeyboard.instance.isShiftPressed) {
          _searchPrevious();
        } else {
          _searchNext();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f7:
        unawaited(_showPageSetupDialog());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        unawaited(_showStylePicker());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        if (!_busy && _controller.tableCellSelection != null) {
          unawaited(_enterSelectedTableCell());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowLeft:
        if (_nudgeSelectedObject(Offset(-objectNudgeStep, 0))) {
          return KeyEventResult.handled;
        }
        if (_controller.tableCellSelection != null && !wordNavigationPressed) {
          unawaited(
            _moveTableCellSelection(
              _TableCellNavigationDirection.left,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        }
        if (wordNavigationPressed) {
          unawaited(_moveCursorByWord(-1, extendSelection: extendSelection));
        } else {
          _moveCursorHorizontally(-1, extendSelection: extendSelection);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (_nudgeSelectedObject(Offset(objectNudgeStep, 0))) {
          return KeyEventResult.handled;
        }
        if (_controller.tableCellSelection != null && !wordNavigationPressed) {
          unawaited(
            _moveTableCellSelection(
              _TableCellNavigationDirection.right,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        }
        if (wordNavigationPressed) {
          unawaited(_moveCursorByWord(1, extendSelection: extendSelection));
        } else {
          _moveCursorHorizontally(1, extendSelection: extendSelection);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (_nudgeSelectedObject(Offset(0, -objectNudgeStep))) {
          return KeyEventResult.handled;
        }
        if (_controller.tableCellSelection != null && !wordNavigationPressed) {
          unawaited(
            _moveTableCellSelection(
              _TableCellNavigationDirection.up,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        }
        unawaited(_moveCursorVertically(-1, extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_nudgeSelectedObject(Offset(0, objectNudgeStep))) {
          return KeyEventResult.handled;
        }
        if (_controller.tableCellSelection != null && !wordNavigationPressed) {
          unawaited(
            _moveTableCellSelection(
              _TableCellNavigationDirection.down,
              extendSelection: extendSelection,
            ),
          );
          return KeyEventResult.handled;
        }
        unawaited(_moveCursorVertically(1, extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        unawaited(_moveCursorByPage(-1, extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        unawaited(_moveCursorByPage(1, extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        unawaited(_moveCursorToLineStart(extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        unawaited(_moveCursorToLineEnd(extendSelection: extendSelection));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        if (_controller.tableCellSelection != null) {
          unawaited(_moveTableCellSelectionByTab(backward: extendSelection));
          return KeyEventResult.handled;
        }
        if (!_busy && !extendSelection) {
          unawaited(_insertCommittedText('\t'));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (!_busy) {
          if (shortcutPressed && _controller.tableCellSelection == null) {
            if (extendSelection) {
              _insertColumnBreak();
            } else {
              _insertPageBreak();
            }
            return KeyEventResult.handled;
          }
          if (_controller.tableCellSelection != null) {
            unawaited(_enterSelectedTableCell());
            return KeyEventResult.handled;
          }
          if (extendSelection) {
            _insertLineBreak();
          } else {
            _splitParagraph();
          }
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        if (!_busy) {
          if (wordNavigationPressed) {
            unawaited(_deleteWord(backward: true));
          } else {
            _deleteBackward();
          }
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.delete:
        if (!_busy) {
          if (wordNavigationPressed) {
            unawaited(_deleteWord(backward: false));
          } else {
            _deleteForward();
          }
        }
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isCharShapeShortcut(KeyEvent event) {
    final character = event.character;
    return event.logicalKey == LogicalKeyboardKey.keyL ||
        character == 'l' ||
        character == 'L' ||
        character == 'ㄹ';
  }

  bool _isParaShapeShortcut(KeyEvent event) {
    final character = event.character;
    return event.logicalKey == LogicalKeyboardKey.keyT ||
        character == 't' ||
        character == 'T' ||
        character == 'ㅅ';
  }

  void _moveCursorHorizontally(int delta, {required bool extendSelection}) {
    final current = _controller.selection;
    final nextOffset = math.max(0, current.end.offset + delta);
    final next = current.end.copyWith(offset: nextOffset);
    _setCursorOrSelection(current, next, extendSelection: extendSelection);
  }

  Future<void> _moveCursorByWord(
    int delta, {
    required bool extendSelection,
  }) async {
    if (delta == 0) {
      return;
    }

    final current = _controller.selection;
    final cursor = current.end;
    try {
      final paragraphText = await _paragraphTextFor(cursor);
      if (!mounted) {
        return;
      }

      final nextOffset = paragraphText == null
          ? math.max(0, cursor.offset + delta)
          : _wordBoundaryOffset(paragraphText.text, cursor.offset, delta);
      _setCursorOrSelection(
        current,
        cursor.copyWith(offset: nextOffset),
        extendSelection: extendSelection,
      );
      if (paragraphText != null) {
        unawaited(_controller.goToPage(paragraphText.page));
      }
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _moveCursorToLineStart({required bool extendSelection}) async {
    final current = _controller.selection;
    final cursor = current.end;
    try {
      final lineStart = await _lineBoundaryFor(cursor, end: false);
      if (!mounted) {
        return;
      }
      _setCursorOrSelection(
        current,
        lineStart?.position ?? cursor.copyWith(offset: 0),
        extendSelection: extendSelection,
      );
      if (lineStart != null) {
        unawaited(_controller.goToPage(lineStart.page));
      }
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _moveCursorVertically(
    int delta, {
    required bool extendSelection,
  }) async {
    if (delta == 0) {
      return;
    }

    final current = _controller.selection;
    final cursor = current.end;
    try {
      final target =
          await _verticalTextPositionFrom(cursor, delta) ??
          await _paragraphPositionRelativeTo(cursor, delta);
      if (!mounted || target == null) {
        return;
      }

      _setCursorOrSelection(
        current,
        target.position,
        extendSelection: extendSelection,
      );
      unawaited(_controller.goToPage(target.page));
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<void> _moveCursorByPage(
    int delta, {
    required bool extendSelection,
  }) async {
    if (delta == 0) {
      return;
    }

    final current = _controller.selection;
    final cursor = current.end;
    try {
      final target = await _pageTextPositionFrom(cursor, delta);
      if (!mounted || target == null) {
        return;
      }

      _setCursorOrSelection(
        current,
        target.position,
        extendSelection: extendSelection,
      );
      unawaited(_controller.goToPage(target.page));
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<({RhwpCursorPosition position, int page})?> _pageTextPositionFrom(
    RhwpCursorPosition cursor,
    int delta,
  ) async {
    final pageCount = await widget.document.pageCount;
    if (pageCount <= 0) {
      return null;
    }

    final currentRun = await _textRunContaining(cursor);
    final currentPage = currentRun?.page ?? _controller.currentPage;
    final targetPage = (currentPage + delta).clamp(0, pageCount - 1).toInt();
    if (targetPage == currentPage) {
      return null;
    }

    final targetX = currentRun?.run.pagePointForOffset(cursor.offset).dx ?? 0;
    var page = targetPage;
    while (page >= 0 && page < pageCount) {
      final tree = await widget.document.pageLayerTreeModel(page);
      final target = _nearestVerticalRun(
        tree,
        page: page,
        targetX: targetX,
        direction: delta,
      );
      if (target != null) {
        return _positionOnRun(target, targetX);
      }
      page += delta.sign;
    }

    return null;
  }

  Future<({RhwpCursorPosition position, int page})?> _verticalTextPositionFrom(
    RhwpCursorPosition cursor,
    int delta,
  ) async {
    final pageCount = await widget.document.pageCount;
    final currentRun = await _textRunContaining(cursor);

    if (currentRun == null) {
      return null;
    }

    final currentPoint = currentRun.run.pagePointForOffset(cursor.offset);
    final currentY = currentRun.run.bounds.center.dy;
    final samePageTarget = _nearestVerticalRun(
      currentRun.tree,
      page: currentRun.page,
      targetX: currentPoint.dx,
      direction: delta,
      currentY: currentY,
    );
    if (samePageTarget != null) {
      return _positionOnRun(samePageTarget, currentPoint.dx);
    }

    var page = currentRun.page + delta.sign;
    while (page >= 0 && page < pageCount) {
      final tree = await widget.document.pageLayerTreeModel(page);
      final target = _nearestVerticalRun(
        tree,
        page: page,
        targetX: currentPoint.dx,
        direction: delta,
      );
      if (target != null) {
        return _positionOnRun(target, currentPoint.dx);
      }
      page += delta.sign;
    }

    return null;
  }

  Future<({RhwpLayerTree tree, RhwpTextRunLayout run, int page})?>
  _textRunContaining(RhwpCursorPosition cursor) async {
    final pageCount = await widget.document.pageCount;
    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in _bodyTextRuns(tree)) {
        if (run.containsPosition(
          section: cursor.section,
          paragraph: cursor.paragraph,
          offset: cursor.offset,
        )) {
          return (tree: tree, run: run, page: page);
        }
      }
    }
    return null;
  }

  ({RhwpTextRunLayout run, int page})? _nearestVerticalRun(
    RhwpLayerTree tree, {
    required int page,
    required double targetX,
    required int direction,
    double? currentY,
  }) {
    ({RhwpTextRunLayout run, int page, double vertical, double horizontal})?
    best;

    for (final run in _bodyTextRuns(tree)) {
      final runY = run.bounds.center.dy;
      final vertical = currentY == null
          ? (direction > 0 ? runY : -runY)
          : (runY - currentY) * direction;
      if (currentY != null && vertical <= 0) {
        continue;
      }

      final offset = run.closestOffsetForPoint(Offset(targetX, runY));
      final horizontal = (run.pagePointForOffset(offset).dx - targetX).abs();
      final candidate = (
        run: run,
        page: page,
        vertical: vertical,
        horizontal: horizontal,
      );
      if (best == null ||
          candidate.vertical < best.vertical ||
          (candidate.vertical == best.vertical &&
              candidate.horizontal < best.horizontal)) {
        best = candidate;
      }
    }

    if (best == null) {
      return null;
    }
    return (run: best.run, page: best.page);
  }

  ({RhwpCursorPosition position, int page}) _positionOnRun(
    ({RhwpTextRunLayout run, int page}) target,
    double x,
  ) {
    final run = target.run;
    return (
      position: RhwpCursorPosition(
        section: run.section!,
        paragraph: run.paragraph!,
        offset: run.closestOffsetForPoint(Offset(x, run.bounds.center.dy)),
      ),
      page: target.page,
    );
  }

  Future<({RhwpCursorPosition position, int page})?>
  _paragraphPositionRelativeTo(RhwpCursorPosition cursor, int delta) async {
    final paragraphs = await _bodyParagraphs();
    final target = _paragraphRelativeTo(paragraphs, cursor, delta);
    if (target == null) {
      return null;
    }
    return (
      position: RhwpCursorPosition(
        section: target.section,
        paragraph: target.paragraph,
        offset: math.min(cursor.offset, target.endOffset),
      ),
      page: target.page,
    );
  }

  Future<void> _moveCursorToLineEnd({required bool extendSelection}) async {
    final current = _controller.selection;
    final cursor = current.end;
    try {
      final lineEnd = await _lineBoundaryFor(cursor, end: true);
      final paragraphEnd = lineEnd == null
          ? await _paragraphEndFor(cursor)
          : null;
      if (!mounted) {
        return;
      }
      final next = lineEnd?.position ?? paragraphEnd;
      if (next == null) {
        return;
      }
      _setCursorOrSelection(current, next, extendSelection: extendSelection);
      if (lineEnd != null) {
        unawaited(_controller.goToPage(lineEnd.page));
      }
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  Future<({RhwpCursorPosition position, int page})?> _lineBoundaryFor(
    RhwpCursorPosition cursor, {
    required bool end,
  }) async {
    final pageCount = await widget.document.pageCount;
    ({RhwpCursorPosition position, int page})? startHit;
    ({RhwpCursorPosition position, int page})? insideHit;
    ({RhwpCursorPosition position, int page})? fallbackHit;

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in _bodyTextRuns(tree)) {
        if (run.containsPosition(
          section: cursor.section,
          paragraph: cursor.paragraph,
          offset: cursor.offset,
        )) {
          final candidate = (
            position: cursor.copyWith(
              offset: end ? run.charEnd : run.charStart,
            ),
            page: page,
          );
          if (cursor.offset == run.charStart) {
            startHit ??= candidate;
            continue;
          }
          if (cursor.offset > run.charStart && cursor.offset < run.charEnd) {
            insideHit ??= candidate;
            continue;
          }
          fallbackHit ??= candidate;
        }
      }
    }
    return startHit ?? insideHit ?? fallbackHit;
  }

  Future<({String text, int page})?> _paragraphTextFor(
    RhwpCursorPosition cursor,
  ) async {
    final pageCount = await widget.document.pageCount;
    final runs = <({RhwpTextRunLayout run, int page})>[];
    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in _bodyTextRuns(tree)) {
        if (run.section == cursor.section &&
            run.paragraph == cursor.paragraph) {
          runs.add((run: run, page: page));
        }
      }
    }
    if (runs.isEmpty) {
      return null;
    }

    runs.sort((left, right) {
      final start = left.run.charStart.compareTo(right.run.charStart);
      if (start != 0) {
        return start;
      }
      return left.run.charEnd.compareTo(right.run.charEnd);
    });

    final buffer = StringBuffer();
    var offset = 0;
    for (final entry in runs) {
      final run = entry.run;
      if (run.charStart > offset) {
        buffer.write(List.filled(run.charStart - offset, ' ').join());
        offset = run.charStart;
      }
      final text = run.textForOffsets(run.charStart, run.charEnd);
      buffer.write(text);
      offset = math.max(offset, run.charEnd);
    }

    return (text: buffer.toString(), page: runs.first.page);
  }

  int _wordBoundaryOffset(String text, int offset, int delta) {
    final length = text.length;
    var cursor = offset.clamp(0, length).toInt();
    if (delta < 0) {
      while (cursor > 0 && _isWordSeparator(text.codeUnitAt(cursor - 1))) {
        cursor -= 1;
      }
      while (cursor > 0 && !_isWordSeparator(text.codeUnitAt(cursor - 1))) {
        cursor -= 1;
      }
      return cursor;
    }

    if (cursor < length && !_isWordSeparator(text.codeUnitAt(cursor))) {
      while (cursor < length && !_isWordSeparator(text.codeUnitAt(cursor))) {
        cursor += 1;
      }
      return cursor;
    }

    while (cursor < length && _isWordSeparator(text.codeUnitAt(cursor))) {
      cursor += 1;
    }
    return cursor;
  }

  bool _isWordSeparator(int codeUnit) {
    if (codeUnit <= 0x20) {
      return true;
    }
    const separators = '.,;:!?()[]{}<>/"\'`~@#\$%^&*-+=|\\';
    return separators.codeUnits.contains(codeUnit);
  }

  Future<void> _moveCursorToDocumentBoundary({
    required bool end,
    required bool extendSelection,
  }) async {
    final current = _controller.selection;
    try {
      final boundary = await _documentTextBoundary(end: end);
      if (!mounted || boundary == null) {
        return;
      }
      _setCursorOrSelection(
        current,
        boundary.position,
        extendSelection: extendSelection,
      );
      unawaited(_controller.goToPage(boundary.page));
      _focusEditor();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  ({int section, int paragraph, int endOffset, int page})? _paragraphRelativeTo(
    List<({int section, int paragraph, int endOffset, int page})> paragraphs,
    RhwpCursorPosition cursor,
    int delta,
  ) {
    if (paragraphs.isEmpty) {
      return null;
    }

    final exactIndex = paragraphs.indexWhere(
      (paragraph) =>
          paragraph.section == cursor.section &&
          paragraph.paragraph == cursor.paragraph,
    );
    if (exactIndex >= 0) {
      final targetIndex = exactIndex + delta;
      if (targetIndex < 0 || targetIndex >= paragraphs.length) {
        return null;
      }
      return paragraphs[targetIndex];
    }

    if (delta > 0) {
      for (final paragraph in paragraphs) {
        if (_compareParagraphToCursor(paragraph, cursor) > 0) {
          return paragraph;
        }
      }
      return null;
    }

    for (final paragraph in paragraphs.reversed) {
      if (_compareParagraphToCursor(paragraph, cursor) < 0) {
        return paragraph;
      }
    }
    return null;
  }

  int _compareParagraphToCursor(
    ({int section, int paragraph, int endOffset, int page}) paragraph,
    RhwpCursorPosition cursor,
  ) {
    final section = paragraph.section.compareTo(cursor.section);
    if (section != 0) {
      return section;
    }
    return paragraph.paragraph.compareTo(cursor.paragraph);
  }

  Future<({RhwpCursorPosition position, int page})?> _documentTextBoundary({
    required bool end,
  }) async {
    final pageCount = await widget.document.pageCount;
    RhwpCursorPosition? boundary;
    var boundaryPage = _controller.currentPage;

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in tree.textRuns) {
        final section = run.section;
        final paragraph = run.paragraph;
        if (section == null ||
            paragraph == null ||
            run.cellContext != null ||
            run.text.isEmpty) {
          continue;
        }

        final candidate = RhwpCursorPosition(
          section: section,
          paragraph: paragraph,
          offset: end ? run.charEnd : run.charStart,
        );
        final shouldReplace =
            boundary == null ||
            (end
                ? candidate.compareTo(boundary) > 0
                : candidate.compareTo(boundary) < 0);
        if (shouldReplace) {
          boundary = candidate;
          boundaryPage = page;
        }
      }
    }

    if (boundary == null) {
      return null;
    }
    return (position: boundary, page: boundaryPage);
  }

  Future<List<({int section, int paragraph, int endOffset, int page})>>
  _bodyParagraphs() async {
    final pageCount = await widget.document.pageCount;
    final paragraphs =
        <String, ({int section, int paragraph, int endOffset, int page})>{};

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in tree.textRuns) {
        final section = run.section;
        final paragraph = run.paragraph;
        if (section == null ||
            paragraph == null ||
            run.cellContext != null ||
            run.text.isEmpty) {
          continue;
        }

        final key = '$section/$paragraph';
        final existing = paragraphs[key];
        if (existing == null || run.charEnd > existing.endOffset) {
          paragraphs[key] = (
            section: section,
            paragraph: paragraph,
            endOffset: run.charEnd,
            page: page,
          );
        }
      }
    }

    final result = paragraphs.values.toList(growable: false);
    result.sort((left, right) {
      final section = left.section.compareTo(right.section);
      if (section != 0) {
        return section;
      }
      return left.paragraph.compareTo(right.paragraph);
    });
    return result;
  }

  Iterable<RhwpTextRunLayout> _bodyTextRuns(RhwpLayerTree tree) sync* {
    for (final run in tree.textRuns) {
      if (run.section == null ||
          run.paragraph == null ||
          run.cellContext != null ||
          run.text.isEmpty) {
        continue;
      }
      yield run;
    }
  }

  Future<RhwpCursorPosition?> _paragraphEndFor(
    RhwpCursorPosition cursor,
  ) async {
    final location = await _paragraphEndLocationFor(cursor);
    if (location == null) {
      return null;
    }
    unawaited(_controller.goToPage(location.page));
    return cursor.copyWith(offset: location.offset);
  }

  Future<int?> _paragraphEndOffsetFor(RhwpCursorPosition cursor) async {
    final location = await _paragraphEndLocationFor(cursor);
    return location?.offset;
  }

  Future<({int offset, int page})?> _paragraphEndLocationFor(
    RhwpCursorPosition cursor,
  ) async {
    final pageCount = await widget.document.pageCount;
    int? endOffset;
    var endPage = _controller.currentPage;

    for (var page = 0; page < pageCount; page += 1) {
      final tree = await widget.document.pageLayerTreeModel(page);
      for (final run in tree.textRuns) {
        if (run.cellContext != null ||
            run.section != cursor.section ||
            run.paragraph != cursor.paragraph) {
          continue;
        }
        if (endOffset == null || run.charEnd > endOffset) {
          endOffset = run.charEnd;
          endPage = page;
        }
      }
    }

    if (endOffset == null) {
      return null;
    }
    return (offset: endOffset, page: endPage);
  }

  void _setCursorOrSelection(
    RhwpSelectionRange current,
    RhwpCursorPosition next, {
    required bool extendSelection,
  }) {
    if (extendSelection) {
      _controller.selection = RhwpSelectionRange(
        start: current.start,
        end: next,
      );
    } else {
      _controller.cursor = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditorToolbar(
          key: _toolbarKey,
          busy: _visibleBusy || _searching,
          error: _error,
          textController: _textController,
          sectionController: _sectionController,
          paragraphController: _paragraphController,
          offsetController: _offsetController,
          tableRowsController: _tableRowsController,
          tableColumnsController: _tableColumnsController,
          tableParagraphController: _tableParagraphController,
          tableControlController: _tableControlController,
          tableRowController: _tableRowController,
          tableColumnController: _tableColumnController,
          tableEndRowController: _tableEndRowController,
          tableEndColumnController: _tableEndColumnController,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          replaceController: _replaceController,
          replaceFocusNode: _replaceFocusNode,
          tableCellSelection: _controller.tableCellSelection,
          objectSelection: _controller.objectSelection,
          pendingCharFormat: _pendingCharFormat,
          currentCharFormat: _currentCharFormat,
          currentParaFormat: _currentParaFormat,
          currentPage: _controller.currentPage,
          pageCount: _pageCountValue,
          zoom: _controller.zoom,
          showParagraphMarks: _showParagraphMarks,
          showTransparentTableBorders: _showTransparentTableBorders,
          canOpen: widget.onOpenRequested != null,
          canInsertPicture: widget.onImageRequested != null,
          canExport: widget.onExported != null,
          searchMatchCount: _searchMatches.length,
          activeSearchMatch: _activeSearchMatch,
          onInsert: _insertText,
          onOpen: _requestOpenFromEditor,
          onDocumentInfo: _showDocumentInfoDialog,
          onSaveHwp: () => _exportFromEditor(RhwpExportFormat.hwp),
          onSaveHwpx: () => _exportFromEditor(RhwpExportFormat.hwpx),
          onExportPdf: () => _exportFromEditor(RhwpExportFormat.pdf),
          onDeleteBackward: _deleteBackward,
          onInsertTable: _insertTable,
          onInsertFootnote: _insertFootnote,
          onInsertEquation: _showInsertEquationDialog,
          onInsertPicture: _insertPicture,
          onInsertShape: _insertShape,
          onInsertPageBreak: _insertPageBreak,
          onInsertColumnBreak: _insertColumnBreak,
          onInsertTableRow: _insertTableRow,
          onInsertTableColumn: _insertTableColumn,
          onDeleteTableRow: _deleteTableRow,
          onDeleteTableColumn: _deleteTableColumn,
          onMergeTableCells: _mergeTableCells,
          onSplitTableCell: _splitTableCell,
          onSplitTableCellInto: _splitTableCellInto,
          onCellFillColor: (fillColor) =>
              _applyTableCellStyle(fillColor: fillColor),
          onCellBorder: () => _applyTableCellStyle(
            borderColor: '#475569',
            borderWidth: 1,
            borderType: 1,
          ),
          onClearCellFill: () => _applyTableCellStyle(clearFill: true),
          onCellVerticalAlignTop: () => _applyTableCellStyle(verticalAlign: 0),
          onCellVerticalAlignCenter: () =>
              _applyTableCellStyle(verticalAlign: 1),
          onCellVerticalAlignBottom: () =>
              _applyTableCellStyle(verticalAlign: 2),
          onDeleteObject: _deleteSelectedObject,
          onObjectBringToFront: () =>
              _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.front),
          onObjectSendToBack: () =>
              _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.back),
          onObjectMoveForward: () =>
              _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.forward),
          onObjectMoveBackward: () =>
              _changeSelectedObjectZOrder(RhwpObjectZOrderOperation.backward),
          onObjectProperties: _showObjectPropertiesDialog,
          onCut: _cutSelection,
          onCopy: _copySelection,
          onPaste: _pasteClipboard,
          onSelectAll: _selectAllText,
          canUndo: _undoSnapshots.isNotEmpty,
          canRedo: _redoSnapshots.isNotEmpty,
          onUndo: _undoEdit,
          onRedo: _redoEdit,
          onBold: () => _toggleCharFormat(bold: true),
          onItalic: () => _toggleCharFormat(italic: true),
          onUnderline: () => _toggleCharFormat(underline: true),
          onStrikethrough: () => _toggleCharFormat(strikethrough: true),
          onSuperscript: () => _toggleCharFormat(superscript: true),
          onSubscript: () => _toggleCharFormat(subscript: true),
          onEmboss: () => _toggleCharFormat(emboss: true),
          onEngrave: () => _toggleCharFormat(engrave: true),
          onFontFamily: (fontFamily) =>
              _applyCharFormat(fontFamily: fontFamily),
          onFontSize: (fontSize) => _applyCharFormat(fontSize: fontSize),
          onTextColor: (textColor) => _applyCharFormat(textColor: textColor),
          onShadeColor: (shadeColor) =>
              _applyCharFormat(shadeColor: shadeColor),
          onCharShape: _showCharShapeDialog,
          onParaShape: _showParaShapeDialog,
          onStylePicker: _showStylePicker,
          onAlignLeft: () => _applyParagraphAlignment('left'),
          onAlignCenter: () => _applyParagraphAlignment('center'),
          onAlignRight: () => _applyParagraphAlignment('right'),
          onAlignJustify: () => _applyParagraphAlignment('justify'),
          onLineSpacing: (lineSpacing) => _applyParagraphFormat(
            lineSpacing: lineSpacing,
            lineSpacingType: 'Percent',
          ),
          onFind: _runSearch,
          onSearchTextChanged: _handleSearchInputChanged,
          onSearchPrevious: _searchPrevious,
          onSearchNext: _searchNext,
          onClearSearch: _clearSearch,
          onReplace: _replaceActiveSearchMatch,
          onReplaceAll: _replaceAllSearchMatches,
          onCompare: _showCompareDialog,
          onPageSetup: _showPageSetupDialog,
          onInsertNewNumber: _showInsertNewNumberDialog,
          onCreateHeader: () => _createHeaderFooter(isHeader: true),
          onCreateFooter: () => _createHeaderFooter(isHeader: false),
          onInsertHeaderText: () => _showHeaderFooterTextDialog(isHeader: true),
          onInsertFooterText: () =>
              _showHeaderFooterTextDialog(isHeader: false),
          onPreviousPage: () => unawaited(_controller.previousPage()),
          onNextPage: () => unawaited(_controller.nextPage()),
          onGoToPage: _showGoToPageDialog,
          onZoomOut: _controller.zoomOut,
          onZoomIn: _controller.zoomIn,
          onResetZoom: _controller.resetZoom,
          onZoomPreset: (zoom) => _controller.zoom = zoom,
          onToggleParagraphMarks: _toggleParagraphMarks,
          onToggleTransparentTableBorders: _toggleTransparentTableBorders,
        ),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: _handlePointerSignal,
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: RhwpViewer(
                document: widget.document,
                controller: _controller,
                renderRevision: _renderRevision,
                onPageRendered: _handlePageRendered,
                ignorePageOverlayPointer: false,
                pageOverlayBuilder: (context, page, _) {
                  return _EditorSelectionOverlay(
                    document: widget.document,
                    page: page,
                    selection: _controller.selection,
                    tableCellSelection: _controller.tableCellSelection,
                    objectSelection: _controller.objectSelection,
                    showParagraphMarks: _showParagraphMarks,
                    showTransparentTableBorders: _showTransparentTableBorders,
                    composingTextListenable: _composingTextListenable,
                    pendingTextOverlaysListenable:
                        _pendingTextOverlaysListenable,
                    pendingDeletionOverlays: _pendingDeletionOverlays
                        .where((overlay) => overlay.page == page)
                        .toList(growable: false),
                    searchMatches: _searchMatches
                        .where((match) => match.page == page)
                        .toList(growable: false),
                    layerRevision: _renderRevision,
                    activeSearchMatch: _activeSearchMatch < 0
                        ? null
                        : _searchMatches[_activeSearchMatch],
                    fallbackEnabled: page == 0,
                    onCursorPosition: _setCursorFromPage,
                    onSelectionRange: _setSelectionFromPage,
                    onParagraphSelection: _selectParagraphFromPage,
                    onTableCellSelection: _setTableSelectionFromPage,
                    onObjectSelection: _setObjectSelectionFromPage,
                    onObjectBoundsChange: _commitObjectBoundsChange,
                    onFocusRequested: _focusEditor,
                    onContextMenuRequested: _showContextMenu,
                  );
                },
              ),
            ),
          ),
        ),
        _EditorStatusBar(
          selection: _controller.selection,
          tableCellSelection: _controller.tableCellSelection,
          objectSelection: _controller.objectSelection,
          overwriteMode: _overwriteMode,
          busy: _visibleBusy,
          currentPage: _controller.currentPage,
          pageCount: _pageCountValue,
          zoom: _controller.zoom,
          onZoomOut: _controller.zoomOut,
          onZoomIn: _controller.zoomIn,
          onZoomPreset: (zoom) => _controller.zoom = zoom,
        ),
      ],
    );
  }
}

enum _ObjectDragHandle {
  move,
  lineStart,
  lineEnd,
  northWest,
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
}

class _ObjectDragSession {
  _ObjectDragSession({
    required this.handle,
    required this.startPagePoint,
    required this.originalSelection,
  }) : currentSelection = originalSelection;

  final _ObjectDragHandle handle;
  final Offset startPagePoint;
  final RhwpObjectSelection originalSelection;
  RhwpObjectSelection currentSelection;
}

class _ObjectHandleAnchor {
  const _ObjectHandleAnchor(this.handle, this.center);

  final _ObjectDragHandle handle;
  final Offset center;
}

List<_ObjectHandleAnchor> _objectHandleAnchors(Rect rect) {
  return [
    _ObjectHandleAnchor(_ObjectDragHandle.northWest, rect.topLeft),
    _ObjectHandleAnchor(_ObjectDragHandle.north, rect.topCenter),
    _ObjectHandleAnchor(_ObjectDragHandle.northEast, rect.topRight),
    _ObjectHandleAnchor(_ObjectDragHandle.east, rect.centerRight),
    _ObjectHandleAnchor(_ObjectDragHandle.southEast, rect.bottomRight),
    _ObjectHandleAnchor(_ObjectDragHandle.south, rect.bottomCenter),
    _ObjectHandleAnchor(_ObjectDragHandle.southWest, rect.bottomLeft),
    _ObjectHandleAnchor(_ObjectDragHandle.west, rect.centerLeft),
  ];
}

class _EditorSelectionOverlay extends StatefulWidget {
  const _EditorSelectionOverlay({
    required this.document,
    required this.page,
    required this.selection,
    required this.tableCellSelection,
    required this.objectSelection,
    required this.showParagraphMarks,
    required this.showTransparentTableBorders,
    required this.composingTextListenable,
    required this.pendingTextOverlaysListenable,
    required this.pendingDeletionOverlays,
    required this.searchMatches,
    required this.layerRevision,
    required this.activeSearchMatch,
    required this.fallbackEnabled,
    required this.onCursorPosition,
    required this.onSelectionRange,
    required this.onParagraphSelection,
    required this.onTableCellSelection,
    required this.onObjectSelection,
    required this.onObjectBoundsChange,
    required this.onFocusRequested,
    required this.onContextMenuRequested,
  });

  final RhwpDocument document;
  final int page;
  final RhwpSelectionRange selection;
  final RhwpTableCellSelection? tableCellSelection;
  final RhwpObjectSelection? objectSelection;
  final bool showParagraphMarks;
  final bool showTransparentTableBorders;
  final ValueListenable<String?> composingTextListenable;
  final ValueListenable<List<_PendingTextOverlay>>
  pendingTextOverlaysListenable;
  final List<_PendingDeletionOverlay> pendingDeletionOverlays;
  final List<_EditorSearchMatch> searchMatches;
  final int layerRevision;
  final _EditorSearchMatch? activeSearchMatch;
  final bool fallbackEnabled;
  final ValueChanged<RhwpCursorPosition> onCursorPosition;
  final ValueChanged<RhwpSelectionRange> onSelectionRange;
  final Future<void> Function(RhwpCursorPosition cursor) onParagraphSelection;
  final ValueChanged<RhwpTableCellSelection?> onTableCellSelection;
  final ValueChanged<RhwpObjectSelection?> onObjectSelection;
  final Future<void> Function(
    RhwpObjectSelection original,
    RhwpObjectSelection updated,
  )
  onObjectBoundsChange;
  final VoidCallback onFocusRequested;
  final ValueChanged<Offset> onContextMenuRequested;

  @override
  State<_EditorSelectionOverlay> createState() =>
      _EditorSelectionOverlayState();
}

class _EditorSelectionOverlayState extends State<_EditorSelectionOverlay> {
  late Future<RhwpLayerTree?> _layerTree;
  RhwpCursorPosition? _dragAnchor;
  RhwpTableCellLayout? _tableDragAnchor;
  _ObjectDragSession? _objectDrag;
  Timer? _caretBlinkTimer;
  bool _caretVisible = true;
  Duration? _lastPrimaryClickTime;
  Offset? _lastPrimaryClickPosition;
  int _primaryClickCount = 0;

  static const _pageInset = 24.0;
  static const _lineHeight = 24.0;
  static const _characterWidth = 8.0;
  static const _objectHandleSize = 10.0;
  static const _objectHandleHitSize = 18.0;
  static const _minimumObjectExtent = 8.0;
  static const _doubleClickTimeout = Duration(milliseconds: 500);
  static const _doubleClickDistance = 18.0;
  static const _caretBlinkInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _layerTree = _loadLayerTree();
    widget.pendingTextOverlaysListenable.addListener(
      _handlePendingTextOverlaysChanged,
    );
    widget.composingTextListenable.addListener(_handleComposingTextChanged);
    _restartCaretBlink();
  }

  @override
  void didUpdateWidget(covariant _EditorSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.page != widget.page ||
        oldWidget.layerRevision != widget.layerRevision) {
      _layerTree = _loadLayerTree();
    }
    if (oldWidget.pendingTextOverlaysListenable !=
        widget.pendingTextOverlaysListenable) {
      oldWidget.pendingTextOverlaysListenable.removeListener(
        _handlePendingTextOverlaysChanged,
      );
      widget.pendingTextOverlaysListenable.addListener(
        _handlePendingTextOverlaysChanged,
      );
    }
    if (oldWidget.composingTextListenable != widget.composingTextListenable) {
      oldWidget.composingTextListenable.removeListener(
        _handleComposingTextChanged,
      );
      widget.composingTextListenable.addListener(_handleComposingTextChanged);
    }
    if (oldWidget.selection.end != widget.selection.end ||
        oldWidget.page != widget.page ||
        oldWidget.layerRevision != widget.layerRevision) {
      _restartCaretBlink();
    }
  }

  @override
  void dispose() {
    widget.pendingTextOverlaysListenable.removeListener(
      _handlePendingTextOverlaysChanged,
    );
    widget.composingTextListenable.removeListener(_handleComposingTextChanged);
    _caretBlinkTimer?.cancel();
    super.dispose();
  }

  List<_PendingTextOverlay> get _pendingTextOverlays {
    return [
      for (final overlay in widget.pendingTextOverlaysListenable.value)
        if (overlay.page == widget.page) overlay,
    ];
  }

  void _handlePendingTextOverlaysChanged() {
    if (mounted) {
      setState(() {
        _restartCaretBlink();
      });
    }
  }

  void _handleComposingTextChanged() {
    if (mounted) {
      setState(() {
        _restartCaretBlink();
      });
    }
  }

  void _restartCaretBlink() {
    _caretBlinkTimer?.cancel();
    _caretVisible = true;
    _caretBlinkTimer = Timer.periodic(_caretBlinkInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _caretVisible = !_caretVisible;
      });
    });
  }

  Future<RhwpLayerTree?> _loadLayerTree() async {
    try {
      return await widget.document.pageLayerTreeModel(widget.page);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RhwpLayerTree?>(
      future: _layerTree,
      builder: (context, snapshot) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final tree = snapshot.data;
            Widget child;
            if (tree != null) {
              final layerOverlay = _buildLayerOverlay(
                context,
                constraints,
                tree,
              );
              if (layerOverlay != null) {
                child = layerOverlay;
              } else if (widget.fallbackEnabled) {
                child = _buildFallbackOverlay(context, constraints);
              } else {
                child = const SizedBox.expand();
              }
            } else if (widget.fallbackEnabled) {
              child = _buildFallbackOverlay(context, constraints);
            } else {
              child = const SizedBox.expand();
            }

            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (event.buttons == kSecondaryMouseButton) {
                  _handleSecondaryPointerDown(
                    event.localPosition,
                    constraints,
                    tree,
                  );
                  widget.onContextMenuRequested(event.position);
                  return;
                }
                _handlePointerDown(event, constraints, tree);
              },
              onPointerMove: (event) {
                _handlePointerMove(event.localPosition, constraints, tree);
              },
              onPointerUp: (_) {
                _finishObjectDrag();
                _dragAnchor = null;
                _tableDragAnchor = null;
              },
              onPointerCancel: (_) {
                _objectDrag = null;
                _dragAnchor = null;
                _tableDragAnchor = null;
              },
              child: SizedBox.expand(child: child),
            );
          },
        );
      },
    );
  }

  void _handlePointerDown(
    PointerDownEvent event,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final localPosition = event.localPosition;
    final objectDragHandle = _objectDragHandleForPoint(
      localPosition,
      constraints,
      tree,
    );
    if (objectDragHandle != null) {
      _startObjectDrag(objectDragHandle, localPosition, constraints, tree);
      return;
    }

    final tableCell = _tableCellForPoint(localPosition, constraints, tree);
    if (tableCell != null) {
      final textHit = _textHitForPoint(localPosition, constraints, tree);
      final tableTextHit = textHit?.cellContext == null ? null : textHit;
      final currentSelection = widget.tableCellSelection;
      _tableDragAnchor = tableCell;
      _dragAnchor = null;
      if (HardwareKeyboard.instance.isShiftPressed &&
          currentSelection != null) {
        _tableDragAnchor = null;
        _primaryClickCount = 0;
        _lastPrimaryClickTime = null;
        _lastPrimaryClickPosition = null;
        widget.onTableCellSelection(
          RhwpTableCellSelection.fromSelectionAndCell(
            currentSelection,
            tableCell,
          ),
        );
        widget.onFocusRequested();
        return;
      }

      widget.onTableCellSelection(
        tableTextHit == null
            ? RhwpTableCellSelection.fromCell(tableCell)
            : RhwpTableCellSelection.fromCellTextHit(tableCell, tableTextHit),
      );
      widget.onFocusRequested();
      return;
    }

    final object = _objectForPoint(localPosition, constraints, tree);
    if (object != null) {
      _tableDragAnchor = null;
      _dragAnchor = null;
      widget.onTableCellSelection(null);
      widget.onObjectSelection(
        RhwpObjectSelection.fromLayout(widget.page, object),
      );
      widget.onFocusRequested();
      return;
    }

    _tableDragAnchor = null;
    widget.onTableCellSelection(null);
    widget.onObjectSelection(null);

    final textHit = _textHitForPoint(localPosition, constraints, tree);
    final cursor = _cursorForTextHitOrPoint(
      textHit,
      localPosition,
      constraints,
      tree,
    );
    if (HardwareKeyboard.instance.isShiftPressed && cursor != null) {
      _primaryClickCount = 0;
      _lastPrimaryClickTime = null;
      _lastPrimaryClickPosition = null;
      widget.onFocusRequested();
      _dragAnchor = widget.selection.start;
      widget.onSelectionRange(
        RhwpSelectionRange(start: widget.selection.start, end: cursor),
      );
      return;
    }

    final clickCount = _recordPrimaryClick(event, textHit);
    if (clickCount >= 3) {
      _primaryClickCount = 0;
      _lastPrimaryClickTime = null;
      _lastPrimaryClickPosition = null;
      if (textHit != null && textHit.cellContext == null) {
        widget.onFocusRequested();
        _dragAnchor = null;
        unawaited(
          widget.onParagraphSelection(
            RhwpCursorPosition(
              section: textHit.section,
              paragraph: textHit.paragraph,
              offset: textHit.offset,
            ),
          ),
        );
        return;
      }
    }

    if (clickCount == 2) {
      final wordSelection = _wordSelectionForHit(textHit);
      if (wordSelection != null) {
        widget.onFocusRequested();
        _dragAnchor = null;
        widget.onSelectionRange(wordSelection);
        return;
      }
    }

    if (cursor != null) {
      widget.onFocusRequested();
      _dragAnchor = cursor;
      widget.onCursorPosition(cursor);
    }
  }

  int _recordPrimaryClick(PointerDownEvent event, RhwpTextHitResult? hit) {
    if (hit == null || hit.cellContext != null) {
      _primaryClickCount = 0;
      _lastPrimaryClickTime = null;
      _lastPrimaryClickPosition = null;
      return 1;
    }

    final lastTime = _lastPrimaryClickTime;
    final lastPosition = _lastPrimaryClickPosition;
    final continuesClickSequence =
        lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime <= _doubleClickTimeout &&
        (event.localPosition - lastPosition).distance <= _doubleClickDistance;
    _primaryClickCount = continuesClickSequence ? _primaryClickCount + 1 : 1;
    _lastPrimaryClickTime = event.timeStamp;
    _lastPrimaryClickPosition = event.localPosition;
    return _primaryClickCount;
  }

  RhwpSelectionRange? _wordSelectionForHit(RhwpTextHitResult? hit) {
    if (hit == null || hit.cellContext != null) {
      return null;
    }

    final run = hit.run;
    if (run.text.isEmpty) {
      return null;
    }

    var localOffset = (hit.offset - run.charStart)
        .clamp(0, run.text.length)
        .toInt();
    if (localOffset == run.text.length && localOffset > 0) {
      localOffset -= 1;
    } else if (localOffset < run.text.length &&
        !_isWordCodeUnit(run.text.codeUnitAt(localOffset)) &&
        localOffset > 0 &&
        _isWordCodeUnit(run.text.codeUnitAt(localOffset - 1))) {
      localOffset -= 1;
    }

    if (localOffset < 0 ||
        localOffset >= run.text.length ||
        !_isWordCodeUnit(run.text.codeUnitAt(localOffset))) {
      return null;
    }

    var start = localOffset;
    while (start > 0 && _isWordCodeUnit(run.text.codeUnitAt(start - 1))) {
      start -= 1;
    }

    var end = localOffset + 1;
    while (end < run.text.length && _isWordCodeUnit(run.text.codeUnitAt(end))) {
      end += 1;
    }

    return RhwpSelectionRange(
      start: RhwpCursorPosition(
        section: hit.section,
        paragraph: hit.paragraph,
        offset: run.charStart + start,
      ),
      end: RhwpCursorPosition(
        section: hit.section,
        paragraph: hit.paragraph,
        offset: run.charStart + end,
      ),
    );
  }

  bool _isWordCodeUnit(int codeUnit) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      return true;
    }
    if (codeUnit >= 0x41 && codeUnit <= 0x5a) {
      return true;
    }
    if (codeUnit >= 0x61 && codeUnit <= 0x7a) {
      return true;
    }
    if (codeUnit == 0x5f) {
      return true;
    }

    // Treat Hangul and common CJK ranges as word text for Korean HWP documents.
    return (codeUnit >= 0x1100 && codeUnit <= 0x11ff) ||
        (codeUnit >= 0x3130 && codeUnit <= 0x318f) ||
        (codeUnit >= 0xac00 && codeUnit <= 0xd7af) ||
        (codeUnit >= 0x3400 && codeUnit <= 0x9fff);
  }

  void _handleSecondaryPointerDown(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final tableCell = _tableCellForPoint(localPosition, constraints, tree);
    if (tableCell != null) {
      final textHit = _textHitForPoint(localPosition, constraints, tree);
      final tableTextHit = textHit?.cellContext == null ? null : textHit;
      _tableDragAnchor = null;
      _dragAnchor = null;
      widget.onTableCellSelection(
        tableTextHit == null
            ? RhwpTableCellSelection.fromCell(tableCell)
            : RhwpTableCellSelection.fromCellTextHit(tableCell, tableTextHit),
      );
      widget.onFocusRequested();
      return;
    }

    final object = _objectForPoint(localPosition, constraints, tree);
    if (object != null) {
      _tableDragAnchor = null;
      _dragAnchor = null;
      widget.onTableCellSelection(null);
      widget.onObjectSelection(
        RhwpObjectSelection.fromLayout(widget.page, object),
      );
      widget.onFocusRequested();
      return;
    }

    _tableDragAnchor = null;
    final textHit = _textHitForPoint(localPosition, constraints, tree);
    if (textHit != null && _selectionContainsTextHit(textHit)) {
      widget.onTableCellSelection(null);
      widget.onObjectSelection(null);
      widget.onFocusRequested();
      return;
    }

    widget.onTableCellSelection(null);
    widget.onObjectSelection(null);
    final cursor = _cursorForPoint(localPosition, constraints, tree);
    if (cursor != null) {
      _dragAnchor = null;
      widget.onCursorPosition(cursor);
    }
    widget.onFocusRequested();
  }

  void _handlePointerMove(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final objectDrag = _objectDrag;
    if (objectDrag != null) {
      _updateObjectDrag(objectDrag, localPosition, constraints, tree);
      return;
    }

    final tableAnchor = _tableDragAnchor;
    if (tableAnchor != null) {
      final tableCell = _tableCellForPoint(localPosition, constraints, tree);
      if (tableCell != null) {
        widget.onTableCellSelection(
          RhwpTableCellSelection.fromCells(tableAnchor, tableCell),
        );
      }
      return;
    }

    final anchor = _dragAnchor;
    final cursor = _cursorForPoint(localPosition, constraints, tree);
    if (anchor != null && cursor != null) {
      widget.onSelectionRange(RhwpSelectionRange(start: anchor, end: cursor));
    }
  }

  void _startObjectDrag(
    _ObjectDragHandle handle,
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final selection = widget.objectSelection;
    if (selection == null || tree == null) {
      return;
    }

    _tableDragAnchor = null;
    _dragAnchor = null;
    _objectDrag = _ObjectDragSession(
      handle: handle,
      startPagePoint: _pagePointFromOverlayPoint(
        localPosition,
        constraints,
        tree,
      ),
      originalSelection: selection,
    );
    widget.onTableCellSelection(null);
    widget.onFocusRequested();
  }

  void _updateObjectDrag(
    _ObjectDragSession drag,
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (tree == null) {
      return;
    }

    final pagePoint = _pagePointFromOverlayPoint(
      localPosition,
      constraints,
      tree,
    );
    final delta = pagePoint - drag.startPagePoint;
    if (drag.handle == _ObjectDragHandle.lineStart ||
        drag.handle == _ObjectDragHandle.lineEnd) {
      final originalStart = _lineStartForSelection(drag.originalSelection);
      final originalEnd = _lineEndForSelection(drag.originalSelection);
      final start = drag.handle == _ObjectDragHandle.lineStart
          ? _clampPointToPage(originalStart + delta, tree.pageSize)
          : originalStart;
      final end = drag.handle == _ObjectDragHandle.lineEnd
          ? _clampPointToPage(originalEnd + delta, tree.pageSize)
          : originalEnd;
      final updated = drag.originalSelection.copyWith(
        bounds: _lineBoundsFromEndpoints(start, end),
        lineStart: start,
        lineEnd: end,
      );
      drag.currentSelection = updated;
      widget.onObjectSelection(updated);
      return;
    }

    final bounds = _objectBoundsForDrag(
      original: drag.originalSelection.bounds,
      handle: drag.handle,
      delta: delta,
      pageSize: tree.pageSize,
      preserveAspectRatio: HardwareKeyboard.instance.isShiftPressed,
    );
    final updated = drag.originalSelection.isLineObject
        ? drag.originalSelection.copyWith(
            bounds: bounds,
            lineStart:
                _lineStartForSelection(drag.originalSelection) +
                (bounds.topLeft - drag.originalSelection.bounds.topLeft),
            lineEnd:
                _lineEndForSelection(drag.originalSelection) +
                (bounds.topLeft - drag.originalSelection.bounds.topLeft),
          )
        : drag.originalSelection.copyWith(bounds: bounds);
    drag.currentSelection = updated;
    widget.onObjectSelection(updated);
  }

  void _finishObjectDrag() {
    final drag = _objectDrag;
    if (drag == null) {
      return;
    }

    _objectDrag = null;
    if (drag.currentSelection != drag.originalSelection) {
      unawaited(
        widget.onObjectBoundsChange(
          drag.originalSelection,
          drag.currentSelection,
        ),
      );
    }
  }

  _ObjectDragHandle? _objectDragHandleForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final selection = widget.objectSelection;
    if (selection == null || tree == null || selection.page != widget.page) {
      return null;
    }

    final overlaySize = _overlaySize(constraints, tree);
    final rect = _scalePageRect(selection.bounds, tree, overlaySize);
    final hitRadius = _objectHandleHitSize / 2;
    if (selection.isLineObject) {
      final start = _scalePagePoint(
        _lineStartForSelection(selection),
        tree,
        overlaySize,
      );
      if ((start - localPosition).distance <= hitRadius) {
        return _ObjectDragHandle.lineStart;
      }

      final end = _scalePagePoint(
        _lineEndForSelection(selection),
        tree,
        overlaySize,
      );
      if ((end - localPosition).distance <= hitRadius) {
        return _ObjectDragHandle.lineEnd;
      }

      if (rect.inflate(hitRadius).contains(localPosition)) {
        return _ObjectDragHandle.move;
      }
      return null;
    }

    for (final anchor in _objectHandleAnchors(rect)) {
      if ((anchor.center - localPosition).distance <= hitRadius) {
        return anchor.handle;
      }
    }

    if (rect.inflate(hitRadius).contains(localPosition)) {
      return _ObjectDragHandle.move;
    }
    return null;
  }

  Rect _objectBoundsForDrag({
    required Rect original,
    required _ObjectDragHandle handle,
    required Offset delta,
    required Size? pageSize,
    bool preserveAspectRatio = false,
  }) {
    if (handle == _ObjectDragHandle.move) {
      return _clampMovedObjectBounds(
        original.shift(delta),
        original.size,
        pageSize,
      );
    }

    var left = original.left;
    var top = original.top;
    var right = original.right;
    var bottom = original.bottom;

    switch (handle) {
      case _ObjectDragHandle.lineStart:
      case _ObjectDragHandle.lineEnd:
        break;
      case _ObjectDragHandle.northWest:
        left += delta.dx;
        top += delta.dy;
      case _ObjectDragHandle.north:
        top += delta.dy;
      case _ObjectDragHandle.northEast:
        right += delta.dx;
        top += delta.dy;
      case _ObjectDragHandle.east:
        right += delta.dx;
      case _ObjectDragHandle.southEast:
        right += delta.dx;
        bottom += delta.dy;
      case _ObjectDragHandle.south:
        bottom += delta.dy;
      case _ObjectDragHandle.southWest:
        left += delta.dx;
        bottom += delta.dy;
      case _ObjectDragHandle.west:
        left += delta.dx;
      case _ObjectDragHandle.move:
        break;
    }

    if (right - left < _minimumObjectExtent) {
      if (_handleMovesLeft(handle)) {
        left = right - _minimumObjectExtent;
      } else {
        right = left + _minimumObjectExtent;
      }
    }
    if (bottom - top < _minimumObjectExtent) {
      if (_handleMovesTop(handle)) {
        top = bottom - _minimumObjectExtent;
      } else {
        bottom = top + _minimumObjectExtent;
      }
    }

    if (preserveAspectRatio && _isCornerHandle(handle)) {
      final adjusted = _preserveObjectAspectRatio(
        original: original,
        handle: handle,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
      left = adjusted.left;
      top = adjusted.top;
      right = adjusted.right;
      bottom = adjusted.bottom;
    }

    left = math.max(0, left);
    top = math.max(0, top);
    if (pageSize != null) {
      right = math.min(pageSize.width, right);
      bottom = math.min(pageSize.height, bottom);
      left = math.min(left, pageSize.width - _minimumObjectExtent);
      top = math.min(top, pageSize.height - _minimumObjectExtent);
    }
    right = math.max(left + _minimumObjectExtent, right);
    bottom = math.max(top + _minimumObjectExtent, bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _preserveObjectAspectRatio({
    required Rect original,
    required _ObjectDragHandle handle,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    if (original.width <= 0 || original.height <= 0) {
      return Rect.fromLTRB(left, top, right, bottom);
    }

    final aspectRatio = original.width / original.height;
    var width = math.max(_minimumObjectExtent, right - left);
    var height = math.max(_minimumObjectExtent, bottom - top);
    final widthScale = width / original.width;
    final heightScale = height / original.height;

    if ((widthScale - 1).abs() >= (heightScale - 1).abs()) {
      height = width / aspectRatio;
    } else {
      width = height * aspectRatio;
    }

    return switch (handle) {
      _ObjectDragHandle.northWest => Rect.fromLTRB(
        right - width,
        bottom - height,
        right,
        bottom,
      ),
      _ObjectDragHandle.northEast => Rect.fromLTRB(
        left,
        bottom - height,
        left + width,
        bottom,
      ),
      _ObjectDragHandle.southEast => Rect.fromLTRB(
        left,
        top,
        left + width,
        top + height,
      ),
      _ObjectDragHandle.southWest => Rect.fromLTRB(
        right - width,
        top,
        right,
        top + height,
      ),
      _ => Rect.fromLTRB(left, top, right, bottom),
    };
  }

  Offset _clampPointToPage(Offset point, Size? pageSize) {
    if (pageSize == null) {
      return Offset(math.max(0, point.dx), math.max(0, point.dy));
    }
    return Offset(
      point.dx.clamp(0.0, pageSize.width).toDouble(),
      point.dy.clamp(0.0, pageSize.height).toDouble(),
    );
  }

  Rect _clampMovedObjectBounds(Rect bounds, Size size, Size? pageSize) {
    if (pageSize == null) {
      return Rect.fromLTWH(
        math.max(0, bounds.left),
        math.max(0, bounds.top),
        bounds.width,
        bounds.height,
      );
    }

    final left = bounds.left.clamp(
      0.0,
      math.max(0.0, pageSize.width - size.width),
    );
    final top = bounds.top.clamp(
      0.0,
      math.max(0.0, pageSize.height - size.height),
    );
    return Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      size.width,
      size.height,
    );
  }

  bool _handleMovesLeft(_ObjectDragHandle handle) {
    return switch (handle) {
      _ObjectDragHandle.northWest ||
      _ObjectDragHandle.southWest ||
      _ObjectDragHandle.west => true,
      _ => false,
    };
  }

  bool _handleMovesTop(_ObjectDragHandle handle) {
    return switch (handle) {
      _ObjectDragHandle.northWest ||
      _ObjectDragHandle.north ||
      _ObjectDragHandle.northEast => true,
      _ => false,
    };
  }

  bool _isCornerHandle(_ObjectDragHandle handle) {
    return switch (handle) {
      _ObjectDragHandle.northWest ||
      _ObjectDragHandle.northEast ||
      _ObjectDragHandle.southEast ||
      _ObjectDragHandle.southWest => true,
      _ => false,
    };
  }

  RhwpTableCellLayout? _tableCellForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (tree == null) {
      return null;
    }

    final pagePoint = _pagePointFromOverlayPoint(
      localPosition,
      constraints,
      tree,
    );
    return tree.tableCellForPoint(pagePoint);
  }

  RhwpObjectLayout? _objectForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (tree == null) {
      return null;
    }

    final pagePoint = _pagePointFromOverlayPoint(
      localPosition,
      constraints,
      tree,
    );
    return tree.objectForPoint(pagePoint);
  }

  RhwpCursorPosition? _cursorForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final hit = _textHitForPoint(localPosition, constraints, tree);
    if (hit != null) {
      return RhwpCursorPosition(
        section: hit.section,
        paragraph: hit.paragraph,
        offset: hit.offset,
      );
    }

    if (widget.fallbackEnabled) {
      return _fallbackCursorFor(localPosition);
    }

    return null;
  }

  RhwpCursorPosition? _cursorForTextHitOrPoint(
    RhwpTextHitResult? hit,
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (hit != null) {
      return RhwpCursorPosition(
        section: hit.section,
        paragraph: hit.paragraph,
        offset: hit.offset,
      );
    }

    if (widget.fallbackEnabled) {
      return _fallbackCursorFor(localPosition);
    }

    return null;
  }

  RhwpTextHitResult? _textHitForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (tree == null) {
      return null;
    }

    final pagePoint = _pagePointFromOverlayPoint(
      localPosition,
      constraints,
      tree,
    );
    return tree.textPositionForPoint(pagePoint, verticalTolerance: 12);
  }

  bool _selectionContainsTextHit(RhwpTextHitResult hit) {
    final selection = widget.selection;
    if (selection.isCollapsed) {
      return false;
    }

    final position = RhwpCursorPosition(
      section: hit.section,
      paragraph: hit.paragraph,
      offset: hit.offset,
    );
    return selection.normalizedStart.compareTo(position) <= 0 &&
        position.compareTo(selection.normalizedEnd) <= 0;
  }

  RhwpCursorPosition _fallbackCursorFor(Offset localPosition) {
    final paragraph = math.max(
      0,
      ((localPosition.dy - _pageInset) / _lineHeight).round(),
    );
    final offset = math.max(
      0,
      ((localPosition.dx - _pageInset) / _characterWidth).round(),
    );
    return RhwpCursorPosition(paragraph: paragraph, offset: offset);
  }

  Widget? _buildLayerOverlay(
    BuildContext context,
    BoxConstraints constraints,
    RhwpLayerTree tree,
  ) {
    final overlaySize = _overlaySize(constraints, tree);
    final tableSelectionRects = _tableSelectionRects(tree, overlaySize);
    final objectSelectionRects = _objectSelectionRects(tree, overlaySize);
    final searchRects = _searchRects(tree, overlaySize);
    final pendingDeletionRects = _pendingDeletionRects(tree, overlaySize);
    final pendingTextRects = _pendingTextRects(tree, overlaySize);
    final pendingTextCaretRect = _pendingTextCaretRect(tree, overlaySize);
    final composingText = widget.composingTextListenable.value;
    final transparentTableBorderRects = widget.showTransparentTableBorders
        ? _transparentTableBorderRects(tree, overlaySize)
        : const <Rect>[];
    final paragraphMarkRects = widget.showParagraphMarks
        ? _paragraphMarkRects(tree, overlaySize)
        : const <Rect>[];
    final caretRect = tree.caretRectFor(
      section: widget.selection.end.section,
      paragraph: widget.selection.end.paragraph,
      offset: widget.selection.end.offset,
    );
    if (caretRect == null &&
        tableSelectionRects.isEmpty &&
        objectSelectionRects.isEmpty &&
        searchRects.isEmpty &&
        pendingDeletionRects.isEmpty &&
        pendingTextRects.isEmpty &&
        transparentTableBorderRects.isEmpty &&
        paragraphMarkRects.isEmpty) {
      return null;
    }

    final color = Theme.of(context).colorScheme.primary;
    final searchColor = Colors.amber.shade600;
    final selectionRects = _layerSelectionRects(tree, overlaySize);
    final displayedCaretRect =
        pendingTextCaretRect ??
        (caretRect == null
            ? null
            : _scalePageRect(caretRect, tree, overlaySize, caret: true));
    final scaledCaretRect = caretRect == null
        ? null
        : _scalePageRect(caretRect, tree, overlaySize);

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (index, rect) in transparentTableBorderRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-transparent-table-border')
                : ValueKey('rhwp-editor-transparent-table-border-$index'),
            rect: rect,
            constraints: constraints,
            child: _TransparentTableBorder(color: color),
          ),
        for (final (index, rect) in objectSelectionRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-object-selection')
                : ValueKey('rhwp-editor-object-selection-$index'),
            rect: rect,
            constraints: constraints,
            child: _objectSelectionOverlayForRect(
              context,
              tree,
              overlaySize,
              rect,
              color,
            ),
          ),
        for (final (index, rect) in tableSelectionRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-table-cell-selection')
                : ValueKey('rhwp-editor-table-cell-selection-$index'),
            rect: rect,
            constraints: constraints,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                border: Border.all(
                  color: color.withValues(alpha: 0.82),
                  width: 2,
                ),
              ),
            ),
          ),
        for (final (index, result) in searchRects.indexed)
          _positionedRect(
            key: result.active
                ? const ValueKey('rhwp-editor-search-active')
                : ValueKey('rhwp-editor-search-highlight-$index'),
            rect: result.rect,
            constraints: constraints,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: result.active
                    ? searchColor.withValues(alpha: 0.45)
                    : searchColor.withValues(alpha: 0.25),
                border: result.active
                    ? Border.all(
                        color: searchColor.withValues(alpha: 0.95),
                        width: 1.5,
                      )
                    : null,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        for (final (index, rect) in pendingDeletionRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-pending-delete-mask')
                : ValueKey('rhwp-editor-pending-delete-mask-$index'),
            rect: rect,
            constraints: constraints,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.white),
            ),
          ),
        if (!widget.selection.isCollapsed)
          for (final (index, rect) in selectionRects.indexed)
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
        for (final (index, pending) in pendingTextRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-pending-text-preview')
                : ValueKey('rhwp-editor-pending-text-preview-$index'),
            rect: pending.rect,
            constraints: constraints,
            child: _PendingTextPreview(
              text: pending.text,
              height: pending.rect.height,
            ),
          ),
        for (final (index, rect) in paragraphMarkRects.indexed)
          _positionedRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-paragraph-mark')
                : ValueKey('rhwp-editor-paragraph-mark-$index'),
            rect: rect,
            constraints: constraints,
            child: _ParagraphMarkGlyph(height: rect.height),
          ),
        if (displayedCaretRect != null)
          _positionedRect(
            key: const ValueKey('rhwp-editor-caret'),
            rect: displayedCaretRect,
            constraints: constraints,
            child: _EditorCaret(color: color, visible: _caretVisible),
          ),
        if (composingText != null && scaledCaretRect != null)
          _positionedRect(
            key: const ValueKey('rhwp-editor-composing-preview'),
            rect: Rect.fromLTWH(
              scaledCaretRect.left,
              scaledCaretRect.top,
              180,
              32,
            ),
            constraints: constraints,
            child: _ComposingPreview(text: composingText),
          ),
      ],
    );
  }

  Widget _buildFallbackOverlay(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    final start = widget.selection.normalizedStart;
    final end = widget.selection.normalizedEnd;
    final top = _pageInset + start.paragraph * _lineHeight;
    final left = _pageInset + start.offset * _characterWidth;
    final caretLeft =
        _pageInset + widget.selection.end.offset * _characterWidth;
    final height = math.max(18.0, _lineHeight);
    final selectionWidth = _selectionWidth(start, end);
    final boundedTop = _bound(top, constraints.maxHeight, height);
    final boundedCaretLeft = _bound(caretLeft, constraints.maxWidth, 2);
    final fallbackDeletionRects = _fallbackDeletionRects(constraints, height);
    final composingText = widget.composingTextListenable.value;

    return Stack(
      children: [
        for (final (index, rect) in fallbackDeletionRects.indexed)
          Positioned.fromRect(
            key: index == 0
                ? const ValueKey('rhwp-editor-pending-delete-mask')
                : ValueKey('rhwp-editor-pending-delete-mask-$index'),
            rect: rect,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.white),
            ),
          ),
        if (!widget.selection.isCollapsed)
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
          left: boundedCaretLeft,
          top: boundedTop,
          width: 2,
          height: height,
          child: _EditorCaret(color: color, visible: _caretVisible),
        ),
        for (final (index, overlay) in _pendingTextOverlays.indexed)
          Positioned(
            key: index == 0
                ? const ValueKey('rhwp-editor-pending-text-preview')
                : ValueKey('rhwp-editor-pending-text-preview-$index'),
            left: _bound(
              _pageInset + overlay.cursor.offset * _characterWidth,
              constraints.maxWidth,
              math.max(12, overlay.text.length * _characterWidth),
            ),
            top: _bound(
              _pageInset + overlay.cursor.paragraph * _lineHeight,
              constraints.maxHeight,
              height,
            ),
            width: math.max(12, overlay.text.length * _characterWidth),
            height: height,
            child: _PendingTextPreview(text: overlay.text, height: height),
          ),
        if (composingText != null)
          Positioned(
            key: const ValueKey('rhwp-editor-composing-preview'),
            left: _bound(boundedCaretLeft, constraints.maxWidth, 180),
            top: _bound(boundedTop, constraints.maxHeight, 32),
            width: 180,
            height: 32,
            child: _ComposingPreview(text: composingText),
          ),
        if (widget.showParagraphMarks)
          Positioned(
            key: const ValueKey('rhwp-editor-paragraph-mark'),
            left: _bound(caretLeft + 6, constraints.maxWidth, 18),
            top: boundedTop,
            width: 18,
            height: height,
            child: _ParagraphMarkGlyph(height: height),
          ),
      ],
    );
  }

  double _selectionWidth(RhwpCursorPosition start, RhwpCursorPosition end) {
    if (start.section != end.section || start.paragraph != end.paragraph) {
      return 160;
    }

    final selectedCharacters = math.max(1, end.offset - start.offset);
    return math.max(8.0, selectedCharacters * _characterWidth);
  }

  List<Rect> _layerSelectionRects(RhwpLayerTree tree, Size overlaySize) {
    if (widget.selection.isCollapsed) {
      return const [];
    }

    final start = widget.selection.normalizedStart;
    final end = widget.selection.normalizedEnd;

    return [
      for (final rect in tree.selectionRectsForRange(
        startSection: start.section,
        startParagraph: start.paragraph,
        startOffset: start.offset,
        endSection: end.section,
        endParagraph: end.paragraph,
        endOffset: end.offset,
      ))
        _scalePageRect(rect, tree, overlaySize),
    ];
  }

  List<Rect> _tableSelectionRects(RhwpLayerTree tree, Size overlaySize) {
    final tableSelection = widget.tableCellSelection;
    if (tableSelection == null) {
      return const [];
    }

    return [
      for (final cell in tree.tableCells)
        if (tableSelection.containsCell(cell))
          _scalePageRect(cell.bounds, tree, overlaySize),
    ];
  }

  List<Rect> _transparentTableBorderRects(
    RhwpLayerTree tree,
    Size overlaySize,
  ) {
    return [
      for (final cell in tree.tableCells)
        _scalePageRect(cell.bounds, tree, overlaySize),
    ];
  }

  List<Rect> _objectSelectionRects(RhwpLayerTree tree, Size overlaySize) {
    final objectSelection = widget.objectSelection;
    if (objectSelection == null || objectSelection.page != widget.page) {
      return const [];
    }

    return [_scalePageRect(objectSelection.bounds, tree, overlaySize)];
  }

  Widget _objectSelectionOverlayForRect(
    BuildContext context,
    RhwpLayerTree tree,
    Size overlaySize,
    Rect rect,
    Color color,
  ) {
    final selection = widget.objectSelection;
    if (selection == null || !selection.isLineObject) {
      return _ObjectSelectionBox(color: color);
    }

    final start = _scalePagePoint(
      _lineStartForSelection(selection),
      tree,
      overlaySize,
    );
    final end = _scalePagePoint(
      _lineEndForSelection(selection),
      tree,
      overlaySize,
    );
    return _LineObjectSelectionBox(
      color: color,
      start: start - rect.topLeft,
      end: end - rect.topLeft,
    );
  }

  List<Rect> _pendingDeletionRects(RhwpLayerTree tree, Size overlaySize) {
    if (widget.pendingDeletionOverlays.isEmpty) {
      return const [];
    }

    final rects = <Rect>[];
    for (final overlay in widget.pendingDeletionOverlays) {
      final start = overlay.range.normalizedStart;
      final end = overlay.range.normalizedEnd;
      for (final rect in tree.selectionRectsForRange(
        startSection: start.section,
        startParagraph: start.paragraph,
        startOffset: start.offset,
        endSection: end.section,
        endParagraph: end.paragraph,
        endOffset: end.offset,
      )) {
        rects.add(_scalePageRect(rect.inflate(1), tree, overlaySize));
      }
    }
    return rects;
  }

  List<({String text, Rect rect})> _pendingTextRects(
    RhwpLayerTree tree,
    Size overlaySize,
  ) {
    final pendingTextOverlays = _pendingTextOverlays;
    if (pendingTextOverlays.isEmpty) {
      return const [];
    }

    final rects = <({String text, Rect rect})>[];
    for (final overlay in pendingTextOverlays) {
      final caretRect = tree.caretRectFor(
        section: overlay.cursor.section,
        paragraph: overlay.cursor.paragraph,
        offset: overlay.cursor.offset,
      );
      if (caretRect == null) {
        continue;
      }

      final scaled = _scalePageRect(caretRect, tree, overlaySize);
      final textWidth = _pendingTextWidth(overlay.text, scaled.height);
      rects.add((
        text: overlay.text,
        rect: Rect.fromLTWH(scaled.left, scaled.top, textWidth, scaled.height),
      ));
    }
    return rects;
  }

  List<Rect> _paragraphMarkRects(RhwpLayerTree tree, Size overlaySize) {
    final lastRunByParagraph = <String, RhwpTextRunLayout>{};
    for (final run in tree.textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null) {
        continue;
      }

      final key = _paragraphMarkKey(run);
      final previous = lastRunByParagraph[key];
      if (previous == null ||
          run.charEnd > previous.charEnd ||
          (run.charEnd == previous.charEnd &&
              run.bounds.bottom > previous.bounds.bottom)) {
        lastRunByParagraph[key] = run;
      }
    }

    final rects = <Rect>[];
    for (final run in lastRunByParagraph.values) {
      final endPoint = run.pagePointForOffset(run.charEnd);
      final height = math.max(12.0, run.bounds.height);
      final width = math.max(10.0, height * 0.75);
      rects.add(
        _scalePageRect(
          Rect.fromLTWH(endPoint.dx + 3, run.bounds.top, width, height),
          tree,
          overlaySize,
        ),
      );
    }
    return rects;
  }

  String _paragraphMarkKey(RhwpTextRunLayout run) {
    final cell = run.cellContext;
    if (cell == null) {
      return '${run.section}:${run.paragraph}';
    }
    return '${run.section}:${run.paragraph}:cell:${cell.parentParagraph}:'
        '${cell.controlIndex}:${cell.cellIndex}:${cell.cellParagraph}';
  }

  Rect? _pendingTextCaretRect(RhwpLayerTree tree, Size overlaySize) {
    final pendingTextOverlays = _pendingTextOverlays;
    if (pendingTextOverlays.isEmpty) {
      return null;
    }

    final overlay = pendingTextOverlays.last;
    final caretRect = tree.caretRectFor(
      section: overlay.cursor.section,
      paragraph: overlay.cursor.paragraph,
      offset: overlay.cursor.offset,
    );
    if (caretRect == null) {
      return null;
    }

    final scaled = _scalePageRect(caretRect, tree, overlaySize, caret: true);
    final textWidth = _pendingTextWidth(overlay.text, scaled.height);
    return Rect.fromLTWH(
      scaled.left + textWidth,
      scaled.top,
      scaled.width,
      scaled.height,
    );
  }

  double _pendingTextWidth(String text, double height) {
    return math.max(
      12.0,
      text.length.toDouble() * math.max(8.0, height * 0.55),
    );
  }

  List<Rect> _fallbackDeletionRects(BoxConstraints constraints, double height) {
    if (widget.pendingDeletionOverlays.isEmpty) {
      return const [];
    }

    final rects = <Rect>[];
    for (final overlay in widget.pendingDeletionOverlays) {
      final start = overlay.range.normalizedStart;
      final end = overlay.range.normalizedEnd;
      if (start.section != end.section || start.paragraph != end.paragraph) {
        continue;
      }

      final width = math.max(
        8.0,
        (end.offset - start.offset) * _characterWidth,
      );
      rects.add(
        Rect.fromLTWH(
          _bound(
            _pageInset + start.offset * _characterWidth,
            constraints.maxWidth,
            width,
          ),
          _bound(
            _pageInset + start.paragraph * _lineHeight,
            constraints.maxHeight,
            height,
          ),
          width,
          height,
        ),
      );
    }
    return rects;
  }

  List<({Rect rect, bool active})> _searchRects(
    RhwpLayerTree tree,
    Size overlaySize,
  ) {
    if (widget.searchMatches.isEmpty) {
      return const [];
    }

    final rects = <({Rect rect, bool active})>[];
    for (final match in widget.searchMatches) {
      for (final run in tree.textRuns) {
        if (!match.matchesRun(run)) {
          continue;
        }
        final rect = run.selectionRectForOffsets(
          match.startOffset,
          match.endOffset,
        );
        if (rect == null) {
          continue;
        }
        rects.add((
          rect: _scalePageRect(rect, tree, overlaySize),
          active: identical(match, widget.activeSearchMatch),
        ));
      }
    }
    return rects;
  }

  Size _overlaySize(BoxConstraints constraints, RhwpLayerTree tree) {
    final fallbackSize = tree.pageSize ?? Size.zero;
    return Size(
      constraints.maxWidth.isFinite ? constraints.maxWidth : fallbackSize.width,
      constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : fallbackSize.height,
    );
  }

  Offset _pagePointFromOverlayPoint(
    Offset point,
    BoxConstraints constraints,
    RhwpLayerTree tree,
  ) {
    final pageSize = tree.pageSize;
    if (pageSize == null || pageSize.width <= 0 || pageSize.height <= 0) {
      return point;
    }

    final overlaySize = _overlaySize(constraints, tree);
    if (overlaySize.width <= 0 || overlaySize.height <= 0) {
      return point;
    }

    return Offset(
      point.dx * pageSize.width / overlaySize.width,
      point.dy * pageSize.height / overlaySize.height,
    );
  }

  Rect _scalePageRect(
    Rect rect,
    RhwpLayerTree tree,
    Size overlaySize, {
    bool caret = false,
  }) {
    final pageSize = tree.pageSize;
    final scaleX = pageSize == null || pageSize.width <= 0
        ? 1.0
        : overlaySize.width / pageSize.width;
    final scaleY = pageSize == null || pageSize.height <= 0
        ? 1.0
        : overlaySize.height / pageSize.height;
    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      math.max(caret ? 2.0 : 4.0, rect.width * scaleX),
      math.max(12.0, rect.height * scaleY),
    );
  }

  Offset _scalePagePoint(Offset point, RhwpLayerTree tree, Size overlaySize) {
    final pageSize = tree.pageSize;
    final scaleX = pageSize == null || pageSize.width <= 0
        ? 1.0
        : overlaySize.width / pageSize.width;
    final scaleY = pageSize == null || pageSize.height <= 0
        ? 1.0
        : overlaySize.height / pageSize.height;
    return Offset(point.dx * scaleX, point.dy * scaleY);
  }

  Positioned _positionedRect({
    required Key key,
    required Rect rect,
    required BoxConstraints constraints,
    required Widget child,
  }) {
    return Positioned(
      key: key,
      left: _bound(rect.left, constraints.maxWidth, rect.width),
      top: _bound(rect.top, constraints.maxHeight, rect.height),
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

class _ObjectSelectionBox extends StatelessWidget {
  const _ObjectSelectionBox({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = Rect.fromLTWH(
          0,
          0,
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  border: Border.all(
                    color: color.withValues(alpha: 0.88),
                    width: 2,
                  ),
                ),
              ),
            ),
            for (final anchor in _objectHandleAnchors(rect))
              Positioned(
                key: ValueKey(
                  'rhwp-editor-object-resize-${anchor.handle.name}',
                ),
                left:
                    anchor.center.dx -
                    _EditorSelectionOverlayState._objectHandleSize / 2,
                top:
                    anchor.center.dy -
                    _EditorSelectionOverlayState._objectHandleSize / 2,
                width: _EditorSelectionOverlayState._objectHandleSize,
                height: _EditorSelectionOverlayState._objectHandleSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: color.withValues(alpha: 0.95),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LineObjectSelectionBox extends StatelessWidget {
  const _LineObjectSelectionBox({
    required this.color,
    required this.start,
    required this.end,
  });

  final Color color;
  final Offset start;
  final Offset end;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LineObjectSelectionPainter(
              color: color,
              start: start,
              end: end,
            ),
          ),
        ),
        _lineHandle(
          context,
          key: const ValueKey('rhwp-editor-object-line-start'),
          center: start,
        ),
        _lineHandle(
          context,
          key: const ValueKey('rhwp-editor-object-line-end'),
          center: end,
        ),
      ],
    );
  }

  Widget _lineHandle(
    BuildContext context, {
    required Key key,
    required Offset center,
  }) {
    return Positioned(
      key: key,
      left: center.dx - _EditorSelectionOverlayState._objectHandleSize / 2,
      top: center.dy - _EditorSelectionOverlayState._objectHandleSize / 2,
      width: _EditorSelectionOverlayState._objectHandleSize,
      height: _EditorSelectionOverlayState._objectHandleSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: color.withValues(alpha: 0.95), width: 1.5),
        ),
      ),
    );
  }
}

class _LineObjectSelectionPainter extends CustomPainter {
  const _LineObjectSelectionPainter({
    required this.color,
    required this.start,
    required this.end,
  });

  final Color color;
  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.04);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.40);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.95);

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
    canvas.drawLine(start, end, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineObjectSelectionPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.start != start ||
        oldDelegate.end != end;
  }
}

class _TransparentTableBorder extends StatelessWidget {
  const _TransparentTableBorder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _TransparentTableBorderPainter(color: color)),
    );
  }
}

class _TransparentTableBorderPainter extends CustomPainter {
  const _TransparentTableBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.44);
    final rect = (Offset.zero & size).deflate(0.5);
    const dash = 4.0;
    const gap = 3.0;

    void drawDashedLine(Offset start, Offset end) {
      final delta = end - start;
      final distance = delta.distance;
      if (distance <= 0) {
        return;
      }
      final direction = delta / distance;
      var traveled = 0.0;
      while (traveled < distance) {
        final segmentEnd = math.min(traveled + dash, distance);
        canvas.drawLine(
          start + direction * traveled,
          start + direction * segmentEnd,
          paint,
        );
        traveled += dash + gap;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _TransparentTableBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

enum _EditorTab { file, edit, view, insert, format, page, table, tools }

enum _EditorShapePreset {
  rectangle(
    label: 'Rectangle',
    shapeType: 'rectangle',
    icon: Icons.crop_square,
    width: 9000,
    height: 6750,
  ),
  ellipse(
    label: 'Ellipse',
    shapeType: 'ellipse',
    icon: Icons.radio_button_unchecked,
    width: 9000,
    height: 6750,
  ),
  line(
    label: 'Line',
    shapeType: 'line',
    icon: Icons.show_chart,
    width: 9000,
    height: 3000,
  ),
  textBox(
    label: 'Text box',
    shapeType: 'textbox',
    icon: Icons.text_fields,
    width: 12000,
    height: 6000,
    treatAsChar: true,
    textWrap: 'Square',
  );

  const _EditorShapePreset({
    required this.label,
    required this.shapeType,
    required this.icon,
    required this.width,
    required this.height,
    this.treatAsChar = false,
    this.textWrap = 'InFrontOfText',
  });

  final String label;
  final String shapeType;
  final IconData icon;
  final int width;
  final int height;
  final bool treatAsChar;
  final String textWrap;

  int get horzOffset => 0;
  int get vertOffset => 0;
  bool get lineFlipX => false;
  bool get lineFlipY => false;
}

class _EditorToolbar extends StatefulWidget {
  const _EditorToolbar({
    super.key,
    required this.busy,
    required this.error,
    required this.textController,
    required this.sectionController,
    required this.paragraphController,
    required this.offsetController,
    required this.tableRowsController,
    required this.tableColumnsController,
    required this.tableParagraphController,
    required this.tableControlController,
    required this.tableRowController,
    required this.tableColumnController,
    required this.tableEndRowController,
    required this.tableEndColumnController,
    required this.searchController,
    required this.searchFocusNode,
    required this.replaceController,
    required this.replaceFocusNode,
    required this.tableCellSelection,
    required this.objectSelection,
    required this.pendingCharFormat,
    required this.currentCharFormat,
    required this.currentParaFormat,
    required this.currentPage,
    required this.pageCount,
    required this.zoom,
    required this.showParagraphMarks,
    required this.showTransparentTableBorders,
    required this.canOpen,
    required this.canInsertPicture,
    required this.canExport,
    required this.searchMatchCount,
    required this.activeSearchMatch,
    required this.onInsert,
    required this.onOpen,
    required this.onDocumentInfo,
    required this.onSaveHwp,
    required this.onSaveHwpx,
    required this.onExportPdf,
    required this.onDeleteBackward,
    required this.onInsertTable,
    required this.onInsertFootnote,
    required this.onInsertEquation,
    required this.onInsertPicture,
    required this.onInsertShape,
    required this.onInsertPageBreak,
    required this.onInsertColumnBreak,
    required this.onInsertTableRow,
    required this.onInsertTableColumn,
    required this.onDeleteTableRow,
    required this.onDeleteTableColumn,
    required this.onMergeTableCells,
    required this.onSplitTableCell,
    required this.onSplitTableCellInto,
    required this.onCellFillColor,
    required this.onCellBorder,
    required this.onClearCellFill,
    required this.onCellVerticalAlignTop,
    required this.onCellVerticalAlignCenter,
    required this.onCellVerticalAlignBottom,
    required this.onDeleteObject,
    required this.onObjectBringToFront,
    required this.onObjectSendToBack,
    required this.onObjectMoveForward,
    required this.onObjectMoveBackward,
    required this.onObjectProperties,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrikethrough,
    required this.onSuperscript,
    required this.onSubscript,
    required this.onEmboss,
    required this.onEngrave,
    required this.onFontFamily,
    required this.onFontSize,
    required this.onTextColor,
    required this.onShadeColor,
    required this.onCharShape,
    required this.onParaShape,
    required this.onStylePicker,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onAlignJustify,
    required this.onLineSpacing,
    required this.onFind,
    required this.onSearchTextChanged,
    required this.onSearchPrevious,
    required this.onSearchNext,
    required this.onClearSearch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onCompare,
    required this.onPageSetup,
    required this.onInsertNewNumber,
    required this.onCreateHeader,
    required this.onCreateFooter,
    required this.onInsertHeaderText,
    required this.onInsertFooterText,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onGoToPage,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetZoom,
    required this.onZoomPreset,
    required this.onToggleParagraphMarks,
    required this.onToggleTransparentTableBorders,
  });

  final bool busy;
  final Object? error;
  final TextEditingController textController;
  final TextEditingController sectionController;
  final TextEditingController paragraphController;
  final TextEditingController offsetController;
  final TextEditingController tableRowsController;
  final TextEditingController tableColumnsController;
  final TextEditingController tableParagraphController;
  final TextEditingController tableControlController;
  final TextEditingController tableRowController;
  final TextEditingController tableColumnController;
  final TextEditingController tableEndRowController;
  final TextEditingController tableEndColumnController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final TextEditingController replaceController;
  final FocusNode replaceFocusNode;
  final RhwpTableCellSelection? tableCellSelection;
  final RhwpObjectSelection? objectSelection;
  final _PendingCharFormat pendingCharFormat;
  final _PendingCharFormat currentCharFormat;
  final _CurrentParaFormat currentParaFormat;
  final int currentPage;
  final int? pageCount;
  final double zoom;
  final bool showParagraphMarks;
  final bool showTransparentTableBorders;
  final bool canOpen;
  final bool canInsertPicture;
  final bool canExport;
  final int searchMatchCount;
  final int activeSearchMatch;
  final VoidCallback onInsert;
  final VoidCallback onOpen;
  final VoidCallback onDocumentInfo;
  final VoidCallback onSaveHwp;
  final VoidCallback onSaveHwpx;
  final VoidCallback onExportPdf;
  final VoidCallback onDeleteBackward;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertFootnote;
  final VoidCallback onInsertEquation;
  final VoidCallback onInsertPicture;
  final ValueChanged<_EditorShapePreset> onInsertShape;
  final VoidCallback onInsertPageBreak;
  final VoidCallback onInsertColumnBreak;
  final VoidCallback onInsertTableRow;
  final VoidCallback onInsertTableColumn;
  final VoidCallback onDeleteTableRow;
  final VoidCallback onDeleteTableColumn;
  final VoidCallback onMergeTableCells;
  final VoidCallback onSplitTableCell;
  final VoidCallback onSplitTableCellInto;
  final ValueChanged<String> onCellFillColor;
  final VoidCallback onCellBorder;
  final VoidCallback onClearCellFill;
  final VoidCallback onCellVerticalAlignTop;
  final VoidCallback onCellVerticalAlignCenter;
  final VoidCallback onCellVerticalAlignBottom;
  final VoidCallback onDeleteObject;
  final VoidCallback onObjectBringToFront;
  final VoidCallback onObjectSendToBack;
  final VoidCallback onObjectMoveForward;
  final VoidCallback onObjectMoveBackward;
  final VoidCallback onObjectProperties;
  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrikethrough;
  final VoidCallback onSuperscript;
  final VoidCallback onSubscript;
  final VoidCallback onEmboss;
  final VoidCallback onEngrave;
  final ValueChanged<String> onFontFamily;
  final ValueChanged<int> onFontSize;
  final ValueChanged<String> onTextColor;
  final ValueChanged<String> onShadeColor;
  final VoidCallback onCharShape;
  final VoidCallback onParaShape;
  final VoidCallback onStylePicker;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onAlignJustify;
  final ValueChanged<int> onLineSpacing;
  final VoidCallback onFind;
  final ValueChanged<String> onSearchTextChanged;
  final VoidCallback onSearchPrevious;
  final VoidCallback onSearchNext;
  final VoidCallback onClearSearch;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onCompare;
  final VoidCallback onPageSetup;
  final VoidCallback onInsertNewNumber;
  final VoidCallback onCreateHeader;
  final VoidCallback onCreateFooter;
  final VoidCallback onInsertHeaderText;
  final VoidCallback onInsertFooterText;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onGoToPage;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;
  final ValueChanged<double> onZoomPreset;
  final VoidCallback onToggleParagraphMarks;
  final VoidCallback onToggleTransparentTableBorders;

  @override
  State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  var _activeTab = _EditorTab.insert;
  final _toolbarFontSizeController = TextEditingController(text: '10.0');
  var _toolbarFontFamily = _fontFamilyOptions.first;
  var _toolbarLineSpacing = 160;
  var _toolbarTextColor = '#000000';
  var _toolbarShadeColor = '#ffffff';

  void activateTab(_EditorTab tab) {
    if (_activeTab == tab) {
      return;
    }
    setState(() {
      _activeTab = tab;
    });
  }

  @override
  void dispose() {
    _toolbarFontSizeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _EditorToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCurrentFormatFields();
    if (oldWidget.tableCellSelection == null &&
        widget.tableCellSelection != null &&
        _activeTab != _EditorTab.tools) {
      _activeTab = _EditorTab.table;
    } else if (oldWidget.objectSelection == null &&
        widget.objectSelection != null &&
        _activeTab != _EditorTab.tools) {
      _activeTab = _EditorTab.edit;
    }
  }

  void _syncCurrentFormatFields() {
    final format = widget.pendingCharFormat.withFallback(
      widget.currentCharFormat,
    );
    final fontFamily = format.fontFamily;
    if (fontFamily != null && _fontFamilyOptions.contains(fontFamily)) {
      _toolbarFontFamily = fontFamily;
    }

    final fontSize = format.fontSize;
    if (fontSize != null) {
      final text = _hwpFontSizeToPointText(fontSize);
      if (_toolbarFontSizeController.text != text) {
        _toolbarFontSizeController.text = text;
      }
    }

    final textColor = format.textColor;
    if (textColor != null) {
      _toolbarTextColor = textColor;
    }

    final shadeColor = format.shadeColor;
    if (shadeColor != null) {
      _toolbarShadeColor = shadeColor;
    }

    final paraFormat = widget.currentParaFormat;
    final lineSpacing = paraFormat.lineSpacing;
    if (paraFormat.lineSpacingType == 'Percent' &&
        lineSpacing != null &&
        _lineSpacingPresets.contains(lineSpacing)) {
      _toolbarLineSpacing = lineSpacing;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final tab in _EditorTab.values)
                    _EditorTabButton(
                      tab: tab,
                      selected: tab == _activeTab,
                      onPressed: () {
                        activateTab(tab);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _ribbonChildren(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _ribbonChildren() {
    final groups = switch (_activeTab) {
      _EditorTab.file => _fileGroups(),
      _EditorTab.edit => _editGroups(),
      _EditorTab.view => _viewGroups(),
      _EditorTab.insert => _insertGroups(),
      _EditorTab.format => _formatGroups(),
      _EditorTab.page => _pageGroups(),
      _EditorTab.table => _tableGroups(),
      _EditorTab.tools => _toolsGroups(),
    };

    return [
      for (final (index, group) in groups.indexed) ...[
        if (index > 0) const _ToolbarDivider(),
        group,
      ],
      ..._stateIndicators(),
    ];
  }

  List<Widget> _fileGroups() {
    return [
      _RibbonGroup(
        label: '파일',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Open',
              buttonKey: const ValueKey('rhwp-editor-open'),
              icon: Icons.folder_open,
              onPressed: widget.busy || !widget.canOpen ? null : widget.onOpen,
            ),
            _ToolbarIconButton(
              tooltip: 'Document info',
              buttonKey: const ValueKey('rhwp-editor-document-info'),
              icon: Icons.info_outline,
              onPressed: widget.busy ? null : widget.onDocumentInfo,
            ),
            _ToolbarIconButton(
              tooltip: 'Save HWP',
              buttonKey: const ValueKey('rhwp-editor-save-hwp'),
              icon: Icons.save_outlined,
              onPressed: widget.busy || !widget.canExport
                  ? null
                  : widget.onSaveHwp,
            ),
            _ToolbarIconButton(
              tooltip: 'Save HWPX',
              buttonKey: const ValueKey('rhwp-editor-save-hwpx'),
              icon: Icons.save_as_outlined,
              onPressed: widget.busy || !widget.canExport
                  ? null
                  : widget.onSaveHwpx,
            ),
            _ToolbarIconButton(
              tooltip: 'Export PDF',
              buttonKey: const ValueKey('rhwp-editor-export-pdf'),
              icon: Icons.picture_as_pdf_outlined,
              onPressed: widget.busy || !widget.canExport
                  ? null
                  : widget.onExportPdf,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _editGroups() {
    return [
      _RibbonGroup(
        label: '실행',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Undo',
              buttonKey: const ValueKey('rhwp-editor-undo'),
              icon: Icons.undo,
              onPressed: widget.busy || !widget.canUndo ? null : widget.onUndo,
            ),
            _ToolbarIconButton(
              tooltip: 'Redo',
              buttonKey: const ValueKey('rhwp-editor-redo'),
              icon: Icons.redo,
              onPressed: widget.busy || !widget.canRedo ? null : widget.onRedo,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '클립보드',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Cut',
              icon: Icons.content_cut,
              onPressed: widget.busy ? null : widget.onCut,
            ),
            _ToolbarIconButton(
              tooltip: 'Copy',
              icon: Icons.copy,
              onPressed: widget.busy ? null : widget.onCopy,
            ),
            _ToolbarIconButton(
              tooltip: 'Paste',
              icon: Icons.content_paste,
              onPressed: widget.busy ? null : widget.onPaste,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '선택',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Select all',
              buttonKey: const ValueKey('rhwp-editor-select-all'),
              icon: Icons.select_all,
              onPressed: widget.busy ? null : widget.onSelectAll,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '개체 배치',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Object properties',
              buttonKey: const ValueKey('rhwp-editor-object-properties'),
              icon: Icons.aspect_ratio,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onObjectProperties,
            ),
            _ToolbarIconButton(
              tooltip: 'Bring object to front',
              buttonKey: const ValueKey('rhwp-editor-object-front'),
              icon: Icons.flip_to_front,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onObjectBringToFront,
            ),
            _ToolbarIconButton(
              tooltip: 'Move object forward',
              buttonKey: const ValueKey('rhwp-editor-object-forward'),
              icon: Icons.arrow_upward,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onObjectMoveForward,
            ),
            _ToolbarIconButton(
              tooltip: 'Move object backward',
              buttonKey: const ValueKey('rhwp-editor-object-backward'),
              icon: Icons.arrow_downward,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onObjectMoveBackward,
            ),
            _ToolbarIconButton(
              tooltip: 'Send object to back',
              buttonKey: const ValueKey('rhwp-editor-object-back'),
              icon: Icons.flip_to_back,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onObjectSendToBack,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '삭제',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Delete backward',
              icon: Icons.backspace_outlined,
              onPressed: widget.busy ? null : widget.onDeleteBackward,
            ),
            _ToolbarIconButton(
              tooltip: 'Delete selected object',
              buttonKey: const ValueKey('rhwp-editor-delete-object'),
              icon: Icons.delete_outline,
              onPressed: widget.busy || widget.objectSelection == null
                  ? null
                  : widget.onDeleteObject,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _viewGroups() {
    return [
      _RibbonGroup(
        label: '위치',
        child: Row(children: _cursorFields()),
      ),
      _RibbonGroup(
        label: '쪽 이동',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Previous page',
              buttonKey: const ValueKey('rhwp-editor-previous-page'),
              icon: Icons.keyboard_arrow_up,
              onPressed: widget.currentPage <= 0 ? null : widget.onPreviousPage,
            ),
            _ToolbarIconButton(
              tooltip: 'Next page',
              buttonKey: const ValueKey('rhwp-editor-next-page'),
              icon: Icons.keyboard_arrow_down,
              onPressed:
                  widget.pageCount != null &&
                      widget.currentPage >= widget.pageCount! - 1
                  ? null
                  : widget.onNextPage,
            ),
            _ToolbarIconButton(
              tooltip: 'Go to page',
              buttonKey: const ValueKey('rhwp-editor-go-to-page'),
              icon: Icons.find_in_page_outlined,
              onPressed:
                  widget.busy ||
                      widget.pageCount == null ||
                      widget.pageCount! <= 0
                  ? null
                  : widget.onGoToPage,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  widget.pageCount == null
                      ? '${widget.currentPage + 1} / ?'
                      : '${widget.currentPage + 1} / ${widget.pageCount}',
                  key: const ValueKey('rhwp-editor-page-count'),
                ),
              ),
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '확대',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Zoom out',
              buttonKey: const ValueKey('rhwp-editor-toolbar-zoom-out'),
              icon: Icons.zoom_out,
              onPressed: widget.zoom <= RhwpViewerController.minZoom
                  ? null
                  : widget.onZoomOut,
            ),
            SizedBox(
              width: 64,
              child: _ZoomPresetMenuButton(
                buttonKey: const ValueKey('rhwp-editor-toolbar-zoom-menu'),
                textKey: const ValueKey('rhwp-editor-toolbar-zoom'),
                zoom: widget.zoom,
                onSelected: widget.onZoomPreset,
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Reset zoom',
              buttonKey: const ValueKey('rhwp-editor-reset-zoom'),
              icon: Icons.center_focus_strong,
              onPressed: widget.zoom == 1.0 ? null : widget.onResetZoom,
            ),
            _ToolbarIconButton(
              tooltip: 'Zoom in',
              buttonKey: const ValueKey('rhwp-editor-toolbar-zoom-in'),
              icon: Icons.zoom_in,
              onPressed: widget.zoom >= RhwpViewerController.maxZoom
                  ? null
                  : widget.onZoomIn,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '표시',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Paragraph marks',
              buttonKey: const ValueKey('rhwp-editor-toggle-paragraph-marks'),
              icon: Icons.keyboard_return,
              selected: widget.showParagraphMarks,
              onPressed: widget.onToggleParagraphMarks,
            ),
            _ToolbarIconButton(
              tooltip: 'Transparent table borders',
              buttonKey: const ValueKey(
                'rhwp-editor-toggle-transparent-table-borders',
              ),
              icon: Icons.border_clear_outlined,
              selected: widget.showTransparentTableBorders,
              onPressed: widget.onToggleTransparentTableBorders,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _insertGroups() {
    return [
      _RibbonGroup(
        label: '위치',
        child: Row(children: _cursorFields()),
      ),
      _RibbonGroup(
        label: '글자 입력',
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                key: const ValueKey('rhwp-editor-text-field'),
                controller: widget.textController,
                minLines: 1,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Text',
                ),
                onSubmitted: (_) {
                  if (!widget.busy) {
                    widget.onInsert();
                  }
                },
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Insert',
              icon: Icons.keyboard_return,
              filled: true,
              onPressed: widget.busy ? null : widget.onInsert,
            ),
            _ToolbarIconButton(
              tooltip: 'Delete backward',
              icon: Icons.backspace_outlined,
              onPressed: widget.busy ? null : widget.onDeleteBackward,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert footnote',
              buttonKey: const ValueKey('rhwp-editor-insert-footnote'),
              icon: Icons.notes_outlined,
              onPressed: widget.busy ? null : widget.onInsertFootnote,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert equation',
              buttonKey: const ValueKey('rhwp-editor-insert-equation'),
              icon: Icons.functions,
              onPressed: widget.busy ? null : widget.onInsertEquation,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert picture',
              buttonKey: const ValueKey('rhwp-editor-insert-picture'),
              icon: Icons.image_outlined,
              onPressed: widget.busy || !widget.canInsertPicture
                  ? null
                  : widget.onInsertPicture,
            ),
            _ToolbarShapeMenu(
              enabled: !widget.busy,
              onSelected: widget.onInsertShape,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert page break',
              buttonKey: const ValueKey('rhwp-editor-insert-page-break'),
              icon: Icons.article_outlined,
              onPressed: widget.busy ? null : widget.onInsertPageBreak,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert column break',
              buttonKey: const ValueKey('rhwp-editor-insert-column-break'),
              icon: Icons.view_column_outlined,
              onPressed: widget.busy ? null : widget.onInsertColumnBreak,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '표 만들기',
        child: Row(
          children: [
            _NumberField(label: 'Rows', controller: widget.tableRowsController),
            const SizedBox(width: 6),
            _NumberField(
              label: 'Cols',
              controller: widget.tableColumnsController,
            ),
            const SizedBox(width: 6),
            _ToolbarIconButton(
              tooltip: 'Insert table',
              buttonKey: const ValueKey('rhwp-editor-insert-table'),
              icon: Icons.table_chart_outlined,
              onPressed: widget.busy ? null : widget.onInsertTable,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _formatGroups() {
    final charFormat = widget.pendingCharFormat.withFallback(
      widget.currentCharFormat,
    );
    final fontFamilyValue =
        charFormat.fontFamily != null &&
            _fontFamilyOptions.contains(charFormat.fontFamily)
        ? charFormat.fontFamily!
        : _toolbarFontFamily;
    return [
      _RibbonGroup(
        label: '스타일',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Style',
              buttonKey: const ValueKey('rhwp-editor-style-picker'),
              icon: Icons.style_outlined,
              onPressed: widget.busy ? null : widget.onStylePicker,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '글자 모양',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Bold',
              icon: Icons.format_bold,
              selected: charFormat.bold == true,
              onPressed: widget.busy ? null : widget.onBold,
            ),
            _ToolbarIconButton(
              tooltip: 'Italic',
              icon: Icons.format_italic,
              selected: charFormat.italic == true,
              onPressed: widget.busy ? null : widget.onItalic,
            ),
            _ToolbarIconButton(
              tooltip: 'Underline',
              icon: Icons.format_underlined,
              selected: charFormat.underline == true,
              onPressed: widget.busy ? null : widget.onUnderline,
            ),
            _ToolbarIconButton(
              tooltip: 'Strikethrough',
              icon: Icons.format_strikethrough,
              selected: charFormat.strikethrough == true,
              onPressed: widget.busy ? null : widget.onStrikethrough,
            ),
            _ToolbarIconButton(
              tooltip: 'Superscript',
              buttonKey: const ValueKey('rhwp-editor-superscript'),
              icon: Icons.superscript,
              selected: charFormat.superscript == true,
              onPressed: widget.busy ? null : widget.onSuperscript,
            ),
            _ToolbarIconButton(
              tooltip: 'Subscript',
              buttonKey: const ValueKey('rhwp-editor-subscript'),
              icon: Icons.subscript,
              selected: charFormat.subscript == true,
              onPressed: widget.busy ? null : widget.onSubscript,
            ),
            _ToolbarIconButton(
              tooltip: 'Emboss',
              buttonKey: const ValueKey('rhwp-editor-emboss'),
              icon: Icons.layers_outlined,
              selected: charFormat.emboss == true,
              onPressed: widget.busy ? null : widget.onEmboss,
            ),
            _ToolbarIconButton(
              tooltip: 'Engrave',
              buttonKey: const ValueKey('rhwp-editor-engrave'),
              icon: Icons.layers_clear_outlined,
              selected: charFormat.engrave == true,
              onPressed: widget.busy ? null : widget.onEngrave,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('rhwp-editor-font-family-field'),
                initialValue: fontFamilyValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final family in _fontFamilyOptions)
                    DropdownMenuItem(value: family, child: Text(family)),
                ],
                onChanged: widget.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          _applyToolbarFontFamily(value);
                        }
                      },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 86,
              child: TextField(
                key: const ValueKey('rhwp-editor-font-size-field'),
                controller: _toolbarFontSizeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixText: 'pt',
                ),
                onSubmitted: (_) {
                  if (!widget.busy) {
                    _applyToolbarFontSize();
                  }
                },
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Apply font size',
              buttonKey: const ValueKey('rhwp-editor-apply-font-size'),
              icon: Icons.format_size,
              onPressed: widget.busy ? null : _applyToolbarFontSize,
            ),
            const SizedBox(width: 4),
            for (final swatch in _charColorSwatches)
              _ColorSwatchButton(
                key: ValueKey('rhwp-editor-text-color-${swatch.value}'),
                tooltip: 'Text color ${swatch.label}',
                color: swatch.color,
                selected:
                    (charFormat.textColor ?? _toolbarTextColor) == swatch.value,
                onPressed: widget.busy
                    ? null
                    : () => _applyToolbarTextColor(swatch.value),
              ),
            const SizedBox(width: 8),
            for (final swatch in _charShadeSwatches)
              _ColorSwatchButton(
                key: ValueKey('rhwp-editor-shade-color-${swatch.value}'),
                tooltip: 'Text background ${swatch.label}',
                color: swatch.color,
                selected:
                    (charFormat.shadeColor ?? _toolbarShadeColor) ==
                    swatch.value,
                onPressed: widget.busy
                    ? null
                    : () => _applyToolbarShadeColor(swatch.value),
              ),
            _ToolbarIconButton(
              tooltip: 'Character shape',
              buttonKey: const ValueKey('rhwp-editor-character-shape'),
              icon: Icons.text_fields,
              onPressed: widget.busy ? null : widget.onCharShape,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '문단 모양',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Align left',
              icon: Icons.format_align_left,
              selected: widget.currentParaFormat.isAlignment('left'),
              onPressed: widget.busy ? null : widget.onAlignLeft,
            ),
            _ToolbarIconButton(
              tooltip: 'Align center',
              icon: Icons.format_align_center,
              selected: widget.currentParaFormat.isAlignment('center'),
              onPressed: widget.busy ? null : widget.onAlignCenter,
            ),
            _ToolbarIconButton(
              tooltip: 'Align right',
              icon: Icons.format_align_right,
              selected: widget.currentParaFormat.isAlignment('right'),
              onPressed: widget.busy ? null : widget.onAlignRight,
            ),
            _ToolbarIconButton(
              tooltip: 'Justify',
              icon: Icons.format_align_justify,
              selected: widget.currentParaFormat.isAlignment('justify'),
              onPressed: widget.busy ? null : widget.onAlignJustify,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 98,
              child: DropdownButtonFormField<int>(
                key: const ValueKey('rhwp-editor-line-spacing-field'),
                initialValue: _toolbarLineSpacing,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                items: [
                  for (final spacing in _lineSpacingPresets)
                    DropdownMenuItem(value: spacing, child: Text('$spacing')),
                ],
                onChanged: widget.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          _applyToolbarLineSpacing(value);
                        }
                      },
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Paragraph shape',
              buttonKey: const ValueKey('rhwp-editor-paragraph-shape'),
              icon: Icons.format_line_spacing,
              onPressed: widget.busy ? null : widget.onParaShape,
            ),
          ],
        ),
      ),
    ];
  }

  void _applyToolbarFontSize() {
    widget.onFontSize(
      _hwpFontSizeFromPointText(_toolbarFontSizeController.text),
    );
  }

  void _applyToolbarFontFamily(String value) {
    setState(() {
      _toolbarFontFamily = value;
    });
    widget.onFontFamily(value);
  }

  void _applyToolbarLineSpacing(int value) {
    setState(() {
      _toolbarLineSpacing = value;
    });
    widget.onLineSpacing(value);
  }

  void _applyToolbarTextColor(String value) {
    setState(() {
      _toolbarTextColor = value;
    });
    widget.onTextColor(value);
  }

  void _applyToolbarShadeColor(String value) {
    setState(() {
      _toolbarShadeColor = value;
    });
    widget.onShadeColor(value);
  }

  List<Widget> _pageGroups() {
    return [
      _RibbonGroup(
        label: '쪽',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Page setup',
              buttonKey: const ValueKey('rhwp-editor-page-setup'),
              icon: Icons.description_outlined,
              onPressed: widget.busy ? null : widget.onPageSetup,
            ),
            _ToolbarIconButton(
              tooltip: 'Start new page number',
              buttonKey: const ValueKey('rhwp-editor-insert-new-number'),
              icon: Icons.format_list_numbered,
              onPressed: widget.busy ? null : widget.onInsertNewNumber,
            ),
            _ToolbarIconButton(
              tooltip: 'Header',
              buttonKey: const ValueKey('rhwp-editor-create-header'),
              icon: Icons.vertical_align_top,
              onPressed: widget.busy ? null : widget.onCreateHeader,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert header text',
              buttonKey: const ValueKey('rhwp-editor-insert-header-text'),
              icon: Icons.text_increase,
              onPressed: widget.busy ? null : widget.onInsertHeaderText,
            ),
            _ToolbarIconButton(
              tooltip: 'Footer',
              buttonKey: const ValueKey('rhwp-editor-create-footer'),
              icon: Icons.vertical_align_bottom,
              onPressed: widget.busy ? null : widget.onCreateFooter,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert footer text',
              buttonKey: const ValueKey('rhwp-editor-insert-footer-text'),
              icon: Icons.text_decrease,
              onPressed: widget.busy ? null : widget.onInsertFooterText,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _tableGroups() {
    final canStyleCell = !widget.busy && widget.tableCellSelection != null;
    return [
      _RibbonGroup(
        label: '표 위치',
        child: Row(
          children: [
            _NumberField(label: 'Sec', controller: widget.sectionController),
            const SizedBox(width: 6),
            _NumberField(
              label: 'TPara',
              controller: widget.tableParagraphController,
            ),
            const SizedBox(width: 6),
            _NumberField(
              label: 'Ctrl',
              controller: widget.tableControlController,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '셀 글자',
        child: Row(
          children: [
            _NumberField(label: 'Offset', controller: widget.offsetController),
            const SizedBox(width: 6),
            SizedBox(
              width: 180,
              child: TextField(
                key: const ValueKey('rhwp-editor-text-field'),
                controller: widget.textController,
                minLines: 1,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Text',
                ),
                onSubmitted: (_) {
                  if (!widget.busy) {
                    widget.onInsert();
                  }
                },
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Insert',
              icon: Icons.keyboard_return,
              filled: true,
              onPressed: widget.busy ? null : widget.onInsert,
            ),
            _ToolbarIconButton(
              tooltip: 'Delete backward',
              icon: Icons.backspace_outlined,
              onPressed: widget.busy ? null : widget.onDeleteBackward,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '셀 범위',
        child: Row(
          children: [
            _NumberField(label: 'Row', controller: widget.tableRowController),
            const SizedBox(width: 6),
            _NumberField(
              label: 'Col',
              controller: widget.tableColumnController,
            ),
            const SizedBox(width: 6),
            _NumberField(
              label: 'EndR',
              controller: widget.tableEndRowController,
            ),
            const SizedBox(width: 6),
            _NumberField(
              label: 'EndC',
              controller: widget.tableEndColumnController,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '줄/칸',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Insert row below',
              buttonKey: const ValueKey('rhwp-editor-insert-row-below'),
              icon: Icons.table_rows_outlined,
              onPressed: widget.busy ? null : widget.onInsertTableRow,
            ),
            _ToolbarIconButton(
              tooltip: 'Insert column right',
              buttonKey: const ValueKey('rhwp-editor-insert-column-right'),
              icon: Icons.view_column_outlined,
              onPressed: widget.busy ? null : widget.onInsertTableColumn,
            ),
            _ToolbarIconButton(
              tooltip: 'Delete table row',
              buttonKey: const ValueKey('rhwp-editor-delete-table-row'),
              icon: Icons.indeterminate_check_box_outlined,
              onPressed: widget.busy ? null : widget.onDeleteTableRow,
            ),
            _ToolbarIconButton(
              tooltip: 'Delete table column',
              buttonKey: const ValueKey('rhwp-editor-delete-table-column'),
              icon: Icons.disabled_by_default_outlined,
              onPressed: widget.busy ? null : widget.onDeleteTableColumn,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '셀',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Merge cells',
              buttonKey: const ValueKey('rhwp-editor-merge-cells'),
              icon: Icons.call_merge_outlined,
              onPressed: widget.busy ? null : widget.onMergeTableCells,
            ),
            _ToolbarIconButton(
              tooltip: 'Split cell',
              buttonKey: const ValueKey('rhwp-editor-split-cell'),
              icon: Icons.call_split_outlined,
              onPressed: widget.busy ? null : widget.onSplitTableCell,
            ),
            _ToolbarIconButton(
              tooltip: 'Split cell into',
              buttonKey: const ValueKey('rhwp-editor-split-cell-into'),
              icon: Icons.grid_4x4_outlined,
              onPressed: widget.busy ? null : widget.onSplitTableCellInto,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '셀 정렬',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Cell vertical top',
              buttonKey: const ValueKey('rhwp-editor-cell-align-top'),
              icon: Icons.vertical_align_top,
              onPressed: canStyleCell ? widget.onCellVerticalAlignTop : null,
            ),
            _ToolbarIconButton(
              tooltip: 'Cell vertical center',
              buttonKey: const ValueKey('rhwp-editor-cell-align-center'),
              icon: Icons.vertical_align_center,
              onPressed: canStyleCell ? widget.onCellVerticalAlignCenter : null,
            ),
            _ToolbarIconButton(
              tooltip: 'Cell vertical bottom',
              buttonKey: const ValueKey('rhwp-editor-cell-align-bottom'),
              icon: Icons.vertical_align_bottom,
              onPressed: canStyleCell ? widget.onCellVerticalAlignBottom : null,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '셀 배경',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Clear cell fill',
              buttonKey: const ValueKey('rhwp-editor-clear-cell-fill'),
              icon: Icons.format_color_reset,
              onPressed: canStyleCell ? widget.onClearCellFill : null,
            ),
            const SizedBox(width: 4),
            for (final swatch in _cellFillSwatches)
              _ColorSwatchButton(
                key: ValueKey('rhwp-editor-cell-fill-${swatch.value}'),
                tooltip: 'Cell fill ${swatch.label}',
                color: swatch.color,
                selected: false,
                onPressed: canStyleCell
                    ? () => widget.onCellFillColor(swatch.value)
                    : null,
              ),
            const SizedBox(width: 6),
            _ToolbarIconButton(
              tooltip: 'Cell border',
              buttonKey: const ValueKey('rhwp-editor-cell-border'),
              icon: Icons.border_all,
              onPressed: canStyleCell ? widget.onCellBorder : null,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _toolsGroups() {
    return [
      _RibbonGroup(
        label: '찾기',
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: Focus(
                onKeyEvent: _handleSearchFieldKeyEvent,
                child: TextField(
                  key: const ValueKey('rhwp-editor-search-field'),
                  controller: widget.searchController,
                  focusNode: widget.searchFocusNode,
                  minLines: 1,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Find',
                  ),
                  onSubmitted: (_) {
                    _submitSearchField(
                      backward: HardwareKeyboard.instance.isShiftPressed,
                    );
                  },
                  onChanged: widget.onSearchTextChanged,
                ),
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Find',
              buttonKey: const ValueKey('rhwp-editor-find'),
              icon: Icons.search,
              filled: true,
              onPressed: widget.busy ? null : widget.onFind,
            ),
            _ToolbarIconButton(
              tooltip: 'Previous match',
              buttonKey: const ValueKey('rhwp-editor-search-previous'),
              icon: Icons.keyboard_arrow_up,
              onPressed: widget.searchMatchCount == 0
                  ? null
                  : widget.onSearchPrevious,
            ),
            _ToolbarIconButton(
              tooltip: 'Next match',
              buttonKey: const ValueKey('rhwp-editor-search-next'),
              icon: Icons.keyboard_arrow_down,
              onPressed: widget.searchMatchCount == 0
                  ? null
                  : widget.onSearchNext,
            ),
            _ToolbarIconButton(
              tooltip: 'Clear search',
              buttonKey: const ValueKey('rhwp-editor-search-clear'),
              icon: Icons.close,
              onPressed: widget.busy ? null : widget.onClearSearch,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  widget.searchMatchCount == 0
                      ? '0 / 0'
                      : '${widget.activeSearchMatch + 1} / ${widget.searchMatchCount}',
                  key: const ValueKey('rhwp-editor-search-count'),
                ),
              ),
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '바꾸기',
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                key: const ValueKey('rhwp-editor-replace-field'),
                controller: widget.replaceController,
                focusNode: widget.replaceFocusNode,
                minLines: 1,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Replace',
                ),
                onSubmitted: (_) {
                  if (!widget.busy && widget.searchMatchCount > 0) {
                    widget.onReplace();
                  }
                },
              ),
            ),
            _ToolbarIconButton(
              tooltip: 'Replace match',
              buttonKey: const ValueKey('rhwp-editor-replace'),
              icon: Icons.find_replace,
              filled: true,
              onPressed: widget.busy || widget.searchMatchCount == 0
                  ? null
                  : widget.onReplace,
            ),
            _ToolbarIconButton(
              tooltip: 'Replace all',
              buttonKey: const ValueKey('rhwp-editor-replace-all'),
              icon: Icons.done_all,
              onPressed: widget.busy || widget.searchMatchCount == 0
                  ? null
                  : widget.onReplaceAll,
            ),
          ],
        ),
      ),
      _RibbonGroup(
        label: '검토',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Compare',
              buttonKey: const ValueKey('rhwp-editor-compare'),
              icon: Icons.difference_outlined,
              onPressed: widget.busy ? null : widget.onCompare,
            ),
          ],
        ),
      ),
    ];
  }

  KeyEventResult _handleSearchFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.busy) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _submitSearchField(backward: HardwareKeyboard.instance.isShiftPressed);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onClearSearch();
        widget.searchFocusNode.unfocus();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _submitSearchField({required bool backward}) {
    if (widget.busy) {
      return;
    }
    if (widget.searchMatchCount == 0) {
      widget.onFind();
      return;
    }
    if (backward) {
      widget.onSearchPrevious();
    } else {
      widget.onSearchNext();
    }
  }

  List<Widget> _stateIndicators() {
    if (!widget.busy && widget.error == null) {
      return const [];
    }

    return [
      const _ToolbarDivider(),
      _RibbonGroup(
        label: '상태',
        child: Row(
          children: [
            if (widget.busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (widget.error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  widget.error.toString(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _cursorFields() {
    return [
      _NumberField(label: 'Sec', controller: widget.sectionController),
      const SizedBox(width: 6),
      _NumberField(label: 'Para', controller: widget.paragraphController),
      const SizedBox(width: 6),
      _NumberField(label: 'Offset', controller: widget.offsetController),
    ];
  }
}

class _SplitTableCellIntoDialog extends StatefulWidget {
  const _SplitTableCellIntoDialog();

  @override
  State<_SplitTableCellIntoDialog> createState() =>
      _SplitTableCellIntoDialogState();
}

class _SplitTableCellIntoDialogState extends State<_SplitTableCellIntoDialog> {
  final _rowsController = TextEditingController(text: '2');
  final _columnsController = TextEditingController(text: '2');
  bool _equalRowHeight = true;
  bool _mergeFirst = false;

  @override
  void dispose() {
    _rowsController.dispose();
    _columnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('셀 나누기'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('rhwp-split-cell-rows-field'),
                    controller: _rowsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rows',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('rhwp-split-cell-columns-field'),
                    controller: _columnsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Columns',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('rhwp-split-cell-equal-height'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Equal row height'),
              value: _equalRowHeight,
              onChanged: (value) => setState(() => _equalRowHeight = value),
            ),
            SwitchListTile(
              key: const ValueKey('rhwp-split-cell-merge-first'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Merge first'),
              value: _mergeFirst,
              onChanged: (value) => setState(() => _mergeFirst = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-split-cell-confirm'),
          onPressed: () {
            Navigator.of(context).pop(
              _SplitTableCellIntoDialogResult(
                rows: _parseDialogPositive(_rowsController.text, max: 64),
                columns: _parseDialogPositive(_columnsController.text, max: 64),
                equalRowHeight: _equalRowHeight,
                mergeFirst: _mergeFirst,
              ),
            );
          },
          child: const Text('Split'),
        ),
      ],
    );
  }

  static int _parseDialogPositive(String text, {required int max}) {
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1) {
      return 1;
    }
    return math.min(parsed, max);
  }
}

class _DocumentInfoDialog extends StatelessWidget {
  const _DocumentInfoDialog({required this.metadata});

  final RhwpDocumentMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final fileName = metadata.fileName?.trim();
    return AlertDialog(
      title: const Text('Document info'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: 'File',
              value: fileName == null || fileName.isEmpty
                  ? 'Untitled'
                  : fileName,
              valueKey: const ValueKey('rhwp-document-info-file-name'),
            ),
            _InfoRow(
              label: 'Format',
              value: metadata.sourceFormat.toUpperCase(),
              valueKey: const ValueKey('rhwp-document-info-format'),
            ),
            _InfoRow(
              label: 'Pages',
              value: metadata.pageCount.toString(),
              valueKey: const ValueKey('rhwp-document-info-page-count'),
            ),
            const SizedBox(height: 12),
            Text('Raw', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  metadata.rawJson,
                  key: const ValueKey('rhwp-document-info-raw-json'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: SelectableText(value, key: valueKey)),
        ],
      ),
    );
  }
}

class _CompareDialog extends StatefulWidget {
  const _CompareDialog({required this.sourceText});

  final String sourceText;

  @override
  State<_CompareDialog> createState() => _CompareDialogState();
}

class _CompareDialogState extends State<_CompareDialog> {
  final _targetController = TextEditingController();
  _CompareSummary? _summary;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return AlertDialog(
      title: const Text('Compare'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('rhwp-compare-target-field'),
              controller: _targetController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Comparison text',
              ),
            ),
            const SizedBox(height: 12),
            if (summary != null) _CompareSummaryView(summary: summary),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const ValueKey('rhwp-compare-run'),
          onPressed: _runCompare,
          icon: const Icon(Icons.difference_outlined),
          label: const Text('Compare'),
        ),
      ],
    );
  }

  void _runCompare() {
    setState(() {
      _summary = _CompareSummary.fromTexts(
        widget.sourceText,
        _targetController.text,
      );
    });
  }
}

class _CompareSummaryView extends StatelessWidget {
  const _CompareSummaryView({required this.summary});

  final _CompareSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CompareMetric(
              label: 'Same',
              value: summary.same,
              valueKey: const ValueKey('rhwp-compare-same-count'),
            ),
            _CompareMetric(
              label: 'Changed',
              value: summary.changed,
              valueKey: const ValueKey('rhwp-compare-changed-count'),
            ),
            _CompareMetric(
              label: 'Added',
              value: summary.added,
              valueKey: const ValueKey('rhwp-compare-added-count'),
            ),
            _CompareMetric(
              label: 'Removed',
              value: summary.removed,
              valueKey: const ValueKey('rhwp-compare-removed-count'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: summary.preview.length,
            itemBuilder: (context, index) {
              return _ComparePreviewTile(line: summary.preview[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _CompareMetric extends StatelessWidget {
  const _CompareMetric({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final int value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value.toString(),
                key: valueKey,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparePreviewTile extends StatelessWidget {
  const _ComparePreviewTile({required this.line});

  final _ComparePreviewLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (line.type) {
      _CompareLineType.same => colorScheme.surface,
      _CompareLineType.changed => colorScheme.tertiaryContainer,
      _CompareLineType.added => colorScheme.primaryContainer,
      _CompareLineType.removed => colorScheme.errorContainer,
    };
    final icon = switch (line.type) {
      _CompareLineType.same => Icons.check,
      _CompareLineType.changed => Icons.compare_arrows,
      _CompareLineType.added => Icons.add,
      _CompareLineType.removed => Icons.remove,
    };
    return ColoredBox(
      color: color.withValues(alpha: 0.42),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.text.isEmpty ? ' ' : line.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareSummary {
  const _CompareSummary({
    required this.same,
    required this.changed,
    required this.added,
    required this.removed,
    required this.preview,
  });

  factory _CompareSummary.fromTexts(String source, String target) {
    final sourceLines = _splitCompareLines(source);
    final targetLines = _splitCompareLines(target);
    final preview = <_ComparePreviewLine>[];
    var same = 0;
    var changed = 0;
    var added = 0;
    var removed = 0;
    final maxLength = math.max(sourceLines.length, targetLines.length);

    for (var index = 0; index < maxLength; index += 1) {
      final sourceLine = index < sourceLines.length ? sourceLines[index] : null;
      final targetLine = index < targetLines.length ? targetLines[index] : null;
      if (sourceLine == targetLine) {
        same += 1;
        preview.add(
          _ComparePreviewLine(_CompareLineType.same, sourceLine ?? ''),
        );
      } else if (sourceLine == null) {
        added += 1;
        preview.add(
          _ComparePreviewLine(_CompareLineType.added, targetLine ?? ''),
        );
      } else if (targetLine == null) {
        removed += 1;
        preview.add(_ComparePreviewLine(_CompareLineType.removed, sourceLine));
      } else {
        changed += 1;
        preview.add(
          _ComparePreviewLine(
            _CompareLineType.changed,
            '$sourceLine  ->  $targetLine',
          ),
        );
      }
    }

    return _CompareSummary(
      same: same,
      changed: changed,
      added: added,
      removed: removed,
      preview: List.unmodifiable(preview.take(80)),
    );
  }

  final int same;
  final int changed;
  final int added;
  final int removed;
  final List<_ComparePreviewLine> preview;
}

class _ComparePreviewLine {
  const _ComparePreviewLine(this.type, this.text);

  final _CompareLineType type;
  final String text;
}

enum _CompareLineType { same, changed, added, removed }

List<String> _splitCompareLines(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.isEmpty) {
    return const [];
  }
  return normalized.split('\n');
}

class _StylePickerDialog extends StatelessWidget {
  const _StylePickerDialog({required this.styles});

  final List<RhwpStyleInfo> styles;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('스타일'),
      content: SizedBox(
        width: 360,
        height: math.min(360, math.max(96, styles.length * 64)).toDouble(),
        child: ListView.builder(
          itemCount: styles.length,
          itemBuilder: (context, index) {
            final style = styles[index];
            return ListTile(
              key: ValueKey('rhwp-style-${style.id}'),
              leading: const Icon(Icons.style_outlined),
              title: Text(style.displayName),
              subtitle: Text('ID ${style.id} - Type ${style.type}'),
              onTap: () => Navigator.of(context).pop(style.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CharShapeDialog extends StatefulWidget {
  const _CharShapeDialog({required this.initialFormat});

  final _PendingCharFormat initialFormat;

  @override
  State<_CharShapeDialog> createState() => _CharShapeDialogState();
}

class _CharShapeDialogState extends State<_CharShapeDialog> {
  late final TextEditingController _fontSizeController;
  late String _fontFamily;
  late bool _bold;
  late bool _italic;
  late bool _underline;
  late bool _strikethrough;
  late bool _superscript;
  late bool _subscript;
  late bool _emboss;
  late bool _engrave;
  late String _textColor;
  late String _shadeColor;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFormat;
    final fontFamily = initial.fontFamily;
    _fontFamily = fontFamily != null && _fontFamilyOptions.contains(fontFamily)
        ? fontFamily
        : _fontFamilyOptions.first;
    _fontSizeController = TextEditingController(
      text: _hwpFontSizeToPointText(initial.fontSize ?? 1000),
    );
    _bold = initial.bold ?? false;
    _italic = initial.italic ?? false;
    _underline = initial.underline ?? false;
    _strikethrough = initial.strikethrough ?? false;
    _superscript = initial.superscript ?? false;
    _subscript = initial.subscript ?? false;
    _emboss = initial.emboss ?? false;
    _engrave = initial.engrave ?? false;
    _textColor = initial.textColor ?? '#000000';
    _shadeColor = initial.shadeColor ?? '#ffffff';
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('글자 모양'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('rhwp-char-shape-font-family-field'),
                initialValue: _fontFamily,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Font family',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final family in _fontFamilyOptions)
                    DropdownMenuItem(value: family, child: Text(family)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _fontFamily = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('rhwp-char-shape-font-size-field'),
                controller: _fontSizeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Font size',
                  suffixText: 'pt',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-bold'),
                    selected: _bold,
                    label: const Text('Bold'),
                    avatar: const Icon(Icons.format_bold),
                    onSelected: (value) => setState(() => _bold = value),
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-italic'),
                    selected: _italic,
                    label: const Text('Italic'),
                    avatar: const Icon(Icons.format_italic),
                    onSelected: (value) => setState(() => _italic = value),
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-underline'),
                    selected: _underline,
                    label: const Text('Underline'),
                    avatar: const Icon(Icons.format_underlined),
                    onSelected: (value) => setState(() => _underline = value),
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-strikethrough'),
                    selected: _strikethrough,
                    label: const Text('Strike'),
                    avatar: const Icon(Icons.format_strikethrough),
                    onSelected: (value) =>
                        setState(() => _strikethrough = value),
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-superscript'),
                    selected: _superscript,
                    label: const Text('Superscript'),
                    avatar: const Icon(Icons.superscript),
                    onSelected: (value) {
                      setState(() {
                        _superscript = value;
                        if (value) {
                          _subscript = false;
                        }
                      });
                    },
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-subscript'),
                    selected: _subscript,
                    label: const Text('Subscript'),
                    avatar: const Icon(Icons.subscript),
                    onSelected: (value) {
                      setState(() {
                        _subscript = value;
                        if (value) {
                          _superscript = false;
                        }
                      });
                    },
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-emboss'),
                    selected: _emboss,
                    label: const Text('Emboss'),
                    avatar: const Icon(Icons.layers_outlined),
                    onSelected: (value) {
                      setState(() {
                        _emboss = value;
                        if (value) {
                          _engrave = false;
                        }
                      });
                    },
                  ),
                  FilterChip(
                    key: const ValueKey('rhwp-char-shape-engrave'),
                    selected: _engrave,
                    label: const Text('Engrave'),
                    avatar: const Icon(Icons.layers_clear_outlined),
                    onSelected: (value) {
                      setState(() {
                        _engrave = value;
                        if (value) {
                          _emboss = false;
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Text color',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final swatch in _charColorSwatches)
                    Tooltip(
                      message: swatch.label,
                      child: InkWell(
                        key: ValueKey('rhwp-char-shape-color-${swatch.value}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            _textColor = swatch.value;
                          });
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _textColor == swatch.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              width: _textColor == swatch.value ? 3 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: swatch.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Text background',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final swatch in _charShadeSwatches)
                    Tooltip(
                      message: swatch.label,
                      child: InkWell(
                        key: ValueKey('rhwp-char-shape-shade-${swatch.value}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            _shadeColor = swatch.value;
                          });
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _shadeColor == swatch.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              width: _shadeColor == swatch.value ? 3 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: swatch.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-char-shape-apply'),
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _CharShapeDialogResult(
        bold: _bold,
        italic: _italic,
        underline: _underline,
        strikethrough: _strikethrough,
        superscript: _superscript,
        subscript: _subscript,
        emboss: _emboss,
        engrave: _engrave,
        fontFamily: _fontFamily,
        fontSize: _hwpFontSizeFromPointText(_fontSizeController.text),
        textColor: _textColor,
        shadeColor: _shadeColor,
      ),
    );
  }
}

class _EquationDialog extends StatefulWidget {
  const _EquationDialog();

  @override
  State<_EquationDialog> createState() => _EquationDialogState();
}

class _EquationDialogState extends State<_EquationDialog> {
  final _scriptController = TextEditingController(text: 'x^2 + y^2');
  final _fontSizeController = TextEditingController(text: '10.0');
  var _color = '#000000';

  @override
  void dispose() {
    _scriptController.dispose();
    _fontSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('수식 넣기'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('rhwp-equation-script-field'),
              controller: _scriptController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Equation script',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('rhwp-equation-font-size-field'),
              controller: _fontSizeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Font size',
                suffixText: 'pt',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final swatch in _charColorSwatches)
                  Tooltip(
                    message: swatch.label,
                    child: InkWell(
                      key: ValueKey('rhwp-equation-color-${swatch.value}'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _color = swatch.value;
                        });
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == swatch.value
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: _color == swatch.value ? 3 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: swatch.color,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-equation-apply'),
          onPressed: _apply,
          child: const Text('Insert'),
        ),
      ],
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _EquationDialogResult(
        script: _scriptController.text,
        fontSize: _hwpFontSizeFromPointText(_fontSizeController.text),
        color: _equationColorFromHex(_color),
      ),
    );
  }
}

int _equationColorFromHex(String value) {
  final hex = value.replaceFirst('#', '');
  return int.tryParse(hex, radix: 16) ?? 0;
}

Future<_ResolvedEditorImage> _resolveEditorImage(RhwpEditorImage image) async {
  var naturalWidthPx = image.naturalWidthPx;
  var naturalHeightPx = image.naturalHeightPx;

  if (naturalWidthPx == null || naturalHeightPx == null) {
    try {
      final codec = await ui.instantiateImageCodec(image.bytes);
      try {
        final frame = await codec.getNextFrame();
        naturalWidthPx = frame.image.width;
        naturalHeightPx = frame.image.height;
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      naturalWidthPx ??= 1;
      naturalHeightPx ??= 1;
    }
  }

  naturalWidthPx = math.max(1, naturalWidthPx);
  naturalHeightPx = math.max(1, naturalHeightPx);

  var width = image.width;
  var height = image.height;
  if (width == null || height == null) {
    final scaled = _defaultPictureSize(
      naturalWidthPx: naturalWidthPx,
      naturalHeightPx: naturalHeightPx,
    );
    width ??= scaled.width;
    height ??= scaled.height;
  }

  return _ResolvedEditorImage(
    bytes: image.bytes,
    extension: _normalizeImageExtension(image.extension),
    width: math.max(1, width),
    height: math.max(1, height),
    naturalWidthPx: naturalWidthPx,
    naturalHeightPx: naturalHeightPx,
    description: image.description,
  );
}

({int width, int height}) _defaultPictureSize({
  required int naturalWidthPx,
  required int naturalHeightPx,
}) {
  const hwpUnitsPerPixelAt96Dpi = 75;
  const maxDefaultExtent = 36000;
  var width = math.max(1, naturalWidthPx * hwpUnitsPerPixelAt96Dpi);
  var height = math.max(1, naturalHeightPx * hwpUnitsPerPixelAt96Dpi);
  final maxExtent = math.max(width, height);
  if (maxExtent > maxDefaultExtent) {
    final scale = maxDefaultExtent / maxExtent;
    width = math.max(1, (width * scale).round());
    height = math.max(1, (height * scale).round());
  }
  return (width: width, height: height);
}

String _normalizeImageExtension(String extension) {
  final normalized = extension.trim().toLowerCase().replaceFirst('.', '');
  return normalized.isEmpty ? 'png' : normalized;
}

class _NewNumberDialog extends StatefulWidget {
  const _NewNumberDialog();

  @override
  State<_NewNumberDialog> createState() => _NewNumberDialogState();
}

class _NewNumberDialogState extends State<_NewNumberDialog> {
  final _startNumberController = TextEditingController(text: '1');

  @override
  void dispose() {
    _startNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 번호로 시작'),
      content: SizedBox(
        width: 260,
        child: TextField(
          key: const ValueKey('rhwp-new-number-start-field'),
          controller: _startNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Start number',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-new-number-apply'),
          onPressed: _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _submit() {
    final parsed = int.tryParse(_startNumberController.text.trim()) ?? 1;
    final startNumber = parsed.clamp(1, 65535).toInt();
    Navigator.of(context).pop(_NewNumberDialogResult(startNumber: startNumber));
  }
}

class _HeaderFooterTextDialog extends StatefulWidget {
  const _HeaderFooterTextDialog({
    required this.isHeader,
    required this.initialInfo,
  });

  final bool isHeader;
  final RhwpHeaderFooterInfo? initialInfo;

  @override
  State<_HeaderFooterTextDialog> createState() =>
      _HeaderFooterTextDialogState();
}

class _HeaderFooterTextDialogState extends State<_HeaderFooterTextDialog> {
  late final TextEditingController _textController;
  final _paragraphController = TextEditingController(text: '0');
  final _offsetController = TextEditingController(text: '0');
  late int _applyTo;
  late bool _replaceExisting;

  @override
  void initState() {
    super.initState();
    final initialInfo = widget.initialInfo;
    _applyTo = initialInfo?.applyTo ?? 0;
    _replaceExisting = initialInfo?.exists ?? false;
    _textController = TextEditingController(text: initialInfo?.text ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _paragraphController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isHeader ? 'Header text' : 'Footer text';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('rhwp-header-footer-text-field'),
              controller: _textController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('rhwp-header-footer-replace-existing'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Replace existing text'),
              value: _replaceExisting,
              onChanged: (value) {
                setState(() {
                  _replaceExisting = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('rhwp-header-footer-apply-to-field'),
                    initialValue: _applyTo,
                    decoration: const InputDecoration(
                      labelText: 'Apply to',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Both')),
                      DropdownMenuItem(value: 1, child: Text('Even')),
                      DropdownMenuItem(value: 2, child: Text('Odd')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _applyTo = value ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 94,
                  child: TextField(
                    key: const ValueKey('rhwp-header-footer-paragraph-field'),
                    controller: _paragraphController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Para',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 94,
                  child: TextField(
                    key: const ValueKey('rhwp-header-footer-offset-field'),
                    controller: _offsetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Offset',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-header-footer-apply'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _HeaderFooterTextDialogResult(
        text: _textController.text,
        applyTo: _applyTo,
        paragraph: _parseDialogNonNegative(_paragraphController.text),
        offset: _parseDialogNonNegative(_offsetController.text),
        replaceExisting: _replaceExisting,
      ),
    );
  }

  int _parseDialogNonNegative(String text) {
    final parsed = int.tryParse(text.trim()) ?? 0;
    return math.max(0, parsed);
  }
}

class _PageSetupDialog extends StatefulWidget {
  const _PageSetupDialog({required this.initial});

  final RhwpPageSetup initial;

  @override
  State<_PageSetupDialog> createState() => _PageSetupDialogState();
}

class _PageSetupDialogState extends State<_PageSetupDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _marginLeftController;
  late final TextEditingController _marginRightController;
  late final TextEditingController _marginTopController;
  late final TextEditingController _marginBottomController;
  late final TextEditingController _marginHeaderController;
  late final TextEditingController _marginFooterController;
  late final TextEditingController _marginGutterController;
  late bool _landscape;
  late int _binding;

  static const _bindingTypes = [
    (label: 'Single sided', value: 0),
    (label: 'Duplex sided', value: 1),
    (label: 'Top flip', value: 2),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _widthController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.width),
    );
    _heightController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.height),
    );
    _marginLeftController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginLeft),
    );
    _marginRightController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginRight),
    );
    _marginTopController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginTop),
    );
    _marginBottomController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginBottom),
    );
    _marginHeaderController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginHeader),
    );
    _marginFooterController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginFooter),
    );
    _marginGutterController = TextEditingController(
      text: _formatHwpUnitMillimeters(initial.marginGutter),
    );
    _landscape = initial.landscape;
    _binding = initial.binding.clamp(0, 2).toInt();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
    _marginTopController.dispose();
    _marginBottomController.dispose();
    _marginHeaderController.dispose();
    _marginFooterController.dispose();
    _marginGutterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('쪽 설정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey('rhwp-page-setup-width-field'),
                      label: 'Width',
                      controller: _widthController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey('rhwp-page-setup-height-field'),
                      label: 'Height',
                      controller: _heightController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-left-field',
                      ),
                      label: 'Left',
                      controller: _marginLeftController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-right-field',
                      ),
                      label: 'Right',
                      controller: _marginRightController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-top-field',
                      ),
                      label: 'Top',
                      controller: _marginTopController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-bottom-field',
                      ),
                      label: 'Bottom',
                      controller: _marginBottomController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-header-field',
                      ),
                      label: 'Header',
                      controller: _marginHeaderController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-footer-field',
                      ),
                      label: 'Footer',
                      controller: _marginFooterController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageSetupNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-page-setup-margin-gutter-field',
                      ),
                      label: 'Gutter',
                      controller: _marginGutterController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('rhwp-page-setup-landscape'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Landscape'),
                value: _landscape,
                onChanged: (value) => setState(() => _landscape = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('rhwp-page-setup-binding-field'),
                initialValue: _binding,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Binding',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final binding in _bindingTypes)
                    DropdownMenuItem<int>(
                      value: binding.value,
                      child: Text(binding.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _binding = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-page-setup-apply'),
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _apply() {
    final initial = widget.initial;
    Navigator.of(context).pop(
      _PageSetupDialogResult(
        width: _hwpUnitFromMillimeters(
          _widthController.text,
          fallback: initial.width,
        ),
        height: _hwpUnitFromMillimeters(
          _heightController.text,
          fallback: initial.height,
        ),
        marginLeft: _hwpUnitFromMillimeters(
          _marginLeftController.text,
          fallback: initial.marginLeft,
        ),
        marginRight: _hwpUnitFromMillimeters(
          _marginRightController.text,
          fallback: initial.marginRight,
        ),
        marginTop: _hwpUnitFromMillimeters(
          _marginTopController.text,
          fallback: initial.marginTop,
        ),
        marginBottom: _hwpUnitFromMillimeters(
          _marginBottomController.text,
          fallback: initial.marginBottom,
        ),
        marginHeader: _hwpUnitFromMillimeters(
          _marginHeaderController.text,
          fallback: initial.marginHeader,
        ),
        marginFooter: _hwpUnitFromMillimeters(
          _marginFooterController.text,
          fallback: initial.marginFooter,
        ),
        marginGutter: _hwpUnitFromMillimeters(
          _marginGutterController.text,
          fallback: initial.marginGutter,
        ),
        landscape: _landscape,
        binding: _binding,
      ),
    );
  }
}

const _hwpUnitsPerMillimeter = 283.465;

String _formatHwpUnitMillimeters(int value) {
  return (value / _hwpUnitsPerMillimeter).toStringAsFixed(1);
}

int _hwpUnitFromMillimeters(String source, {required int fallback}) {
  final parsed = double.tryParse(source.trim().replaceAll(',', '.'));
  if (parsed == null) {
    return fallback;
  }
  if (parsed <= 0) {
    return 0;
  }
  return (parsed * _hwpUnitsPerMillimeter).round();
}

class _PageSetupNumberField extends StatelessWidget {
  const _PageSetupNumberField({
    required this.fieldKey,
    required this.label,
    required this.controller,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ObjectPropertiesDialog extends StatefulWidget {
  const _ObjectPropertiesDialog({required this.properties});

  final RhwpObjectProperties properties;

  @override
  State<_ObjectPropertiesDialog> createState() =>
      _ObjectPropertiesDialogState();
}

class _ObjectPropertiesDialogState extends State<_ObjectPropertiesDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _horzOffsetController;
  late final TextEditingController _vertOffsetController;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: _initialValue(widget.properties.width),
    );
    _heightController = TextEditingController(
      text: _initialValue(widget.properties.height),
    );
    _horzOffsetController = TextEditingController(
      text: _initialValue(widget.properties.horzOffset),
    );
    _vertOffsetController = TextEditingController(
      text: _initialValue(widget.properties.vertOffset),
    );
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _horzOffsetController.dispose();
    _vertOffsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('개체 속성'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ObjectPropertiesNumberField(
                    fieldKey: const ValueKey('rhwp-object-width-field'),
                    label: '너비',
                    controller: _widthController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ObjectPropertiesNumberField(
                    fieldKey: const ValueKey('rhwp-object-height-field'),
                    label: '높이',
                    controller: _heightController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ObjectPropertiesNumberField(
                    fieldKey: const ValueKey('rhwp-object-horz-offset-field'),
                    label: '가로 위치',
                    controller: _horzOffsetController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ObjectPropertiesNumberField(
                    fieldKey: const ValueKey('rhwp-object-vert-offset-field'),
                    label: '세로 위치',
                    controller: _vertOffsetController,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-object-properties-apply'),
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _ObjectPropertiesDialogResult(
        width: _readNonNegative(
          _widthController,
          fallback: widget.properties.width,
        ),
        height: _readNonNegative(
          _heightController,
          fallback: widget.properties.height,
        ),
        horzOffset: _readNonNegative(
          _horzOffsetController,
          fallback: widget.properties.horzOffset,
        ),
        vertOffset: _readNonNegative(
          _vertOffsetController,
          fallback: widget.properties.vertOffset,
        ),
      ),
    );
  }

  String _initialValue(int? value) {
    return (value ?? 0).toString();
  }

  int _readNonNegative(TextEditingController controller, {int? fallback}) {
    final parsed = int.tryParse(controller.text.trim()) ?? fallback ?? 0;
    return math.max(0, parsed);
  }
}

class _ObjectPropertiesNumberField extends StatelessWidget {
  const _ObjectPropertiesNumberField({
    required this.fieldKey,
    required this.label,
    required this.controller,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'hwp',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ParaShapeDialog extends StatefulWidget {
  const _ParaShapeDialog({required this.initialFormat});

  final _CurrentParaFormat initialFormat;

  @override
  State<_ParaShapeDialog> createState() => _ParaShapeDialogState();
}

class _ParaShapeDialogState extends State<_ParaShapeDialog> {
  late final TextEditingController _lineSpacingController;
  late final TextEditingController _indentController;
  late final TextEditingController _marginLeftController;
  late final TextEditingController _marginRightController;
  late final TextEditingController _spacingBeforeController;
  late final TextEditingController _spacingAfterController;
  late String _alignment;
  late String _lineSpacingType;

  static const _alignments = [
    (label: 'Left', value: 'left'),
    (label: 'Center', value: 'center'),
    (label: 'Right', value: 'right'),
    (label: 'Justify', value: 'justify'),
    (label: 'Distribute', value: 'distribute'),
  ];

  static const _lineSpacingTypes = [
    (label: 'Percent', value: 'Percent'),
    (label: 'Fixed', value: 'Fixed'),
    (label: 'Space only', value: 'SpaceOnly'),
    (label: 'Minimum', value: 'Minimum'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFormat;
    _alignment = _validAlignment(initial.alignment);
    _lineSpacingType = _validLineSpacingType(initial.lineSpacingType);
    _lineSpacingController = TextEditingController(
      text: (initial.lineSpacing ?? 160).toString(),
    );
    _indentController = TextEditingController(
      text: (initial.indent ?? 0).toString(),
    );
    _marginLeftController = TextEditingController(
      text: (initial.marginLeft ?? 0).toString(),
    );
    _marginRightController = TextEditingController(
      text: (initial.marginRight ?? 0).toString(),
    );
    _spacingBeforeController = TextEditingController(
      text: (initial.spacingBefore ?? 0).toString(),
    );
    _spacingAfterController = TextEditingController(
      text: (initial.spacingAfter ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _lineSpacingController.dispose();
    _indentController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
    _spacingBeforeController.dispose();
    _spacingAfterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('문단 모양'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('rhwp-para-shape-alignment-field'),
                initialValue: _alignment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Alignment',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final alignment in _alignments)
                    DropdownMenuItem<String>(
                      value: alignment.value,
                      child: Text(alignment.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _alignment = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey(
                        'rhwp-para-shape-line-spacing-type-field',
                      ),
                      initialValue: _lineSpacingType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Line spacing type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final type in _lineSpacingTypes)
                          DropdownMenuItem<String>(
                            value: type.value,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _lineSpacingType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-para-shape-line-spacing-field',
                      ),
                      label: 'Line spacing',
                      controller: _lineSpacingController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey('rhwp-para-shape-indent-field'),
                      label: 'Indent',
                      controller: _indentController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-para-shape-margin-left-field',
                      ),
                      label: 'Left margin',
                      controller: _marginLeftController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-para-shape-margin-right-field',
                      ),
                      label: 'Right margin',
                      controller: _marginRightController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-para-shape-spacing-before-field',
                      ),
                      label: 'Before',
                      controller: _spacingBeforeController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ParaShapeNumberField(
                      fieldKey: const ValueKey(
                        'rhwp-para-shape-spacing-after-field',
                      ),
                      label: 'After',
                      controller: _spacingAfterController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-para-shape-apply'),
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _ParaShapeDialogResult(
        alignment: _alignment,
        lineSpacing: _readInt(_lineSpacingController, fallback: 160),
        lineSpacingType: _lineSpacingType,
        indent: _readInt(_indentController),
        marginLeft: _readInt(_marginLeftController),
        marginRight: _readInt(_marginRightController),
        spacingBefore: _readInt(_spacingBeforeController),
        spacingAfter: _readInt(_spacingAfterController),
      ),
    );
  }

  int _readInt(TextEditingController controller, {int fallback = 0}) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  String _validAlignment(String? value) {
    if (_alignments.any((alignment) => alignment.value == value)) {
      return value!;
    }
    return 'justify';
  }

  String _validLineSpacingType(String? value) {
    if (_lineSpacingTypes.any((type) => type.value == value)) {
      return value!;
    }
    return 'Percent';
  }
}

class _ParaShapeNumberField extends StatelessWidget {
  const _ParaShapeNumberField({
    required this.fieldKey,
    required this.label,
    required this.controller,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ComposingPreview extends StatelessWidget {
  const _ComposingPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.primary, width: 2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1f000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _PendingTextPreview extends StatelessWidget {
  const _PendingTextPreview({required this.text, required this.height});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.86),
          border: Border(bottom: BorderSide(color: colors.primary, width: 1)),
        ),
        child: Text(
          text.replaceAll('\t', '    '),
          overflow: TextOverflow.visible,
          softWrap: false,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontSize: math.max(10, height * 0.78),
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _EditorCaret extends StatelessWidget {
  const _EditorCaret({required this.color, required this.visible});

  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: const ValueKey('rhwp-editor-caret-opacity'),
      opacity: visible ? 1 : 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _ParagraphMarkGlyph extends StatelessWidget {
  const _ParagraphMarkGlyph({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        '¶',
        overflow: TextOverflow.visible,
        softWrap: false,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.primary.withValues(alpha: 0.72),
          fontSize: math.max(10, height * 0.82),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _EditorTabButton extends StatelessWidget {
  const _EditorTabButton({
    required this.tab,
    required this.selected,
    required this.onPressed,
  });

  final _EditorTab tab;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
      child: Text(_tabLabel(tab)),
    );
  }

  String _tabLabel(_EditorTab tab) {
    return switch (tab) {
      _EditorTab.file => '파일',
      _EditorTab.edit => '편집',
      _EditorTab.view => '보기',
      _EditorTab.insert => '입력',
      _EditorTab.format => '서식',
      _EditorTab.page => '쪽',
      _EditorTab.table => '표',
      _EditorTab.tools => '도구',
    };
  }
}

class _RibbonGroup extends StatelessWidget {
  const _RibbonGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(alignment: Alignment.center, child: child),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    this.filled = false,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool filled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      isSelected: selected,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: const Size.square(36),
        fixedSize: const Size.square(36),
        padding: EdgeInsets.zero,
      ),
    );

    if (!filled) {
      return button;
    }

    return IconButton.filled(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: const Size.square(36),
        fixedSize: const Size.square(36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ToolbarShapeMenu extends StatelessWidget {
  const _ToolbarShapeMenu({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<_EditorShapePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_EditorShapePreset>(
      key: const ValueKey('rhwp-editor-insert-shape'),
      tooltip: 'Insert shape',
      enabled: enabled,
      icon: const Icon(Icons.category_outlined),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final preset in _EditorShapePreset.values)
          PopupMenuItem<_EditorShapePreset>(
            key: ValueKey('rhwp-editor-shape-${preset.shapeType}'),
            value: preset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(preset.icon, size: 18),
                const SizedBox(width: 10),
                Text(preset.label),
              ],
            ),
          ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    super.key,
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: onPressed == null
                          ? color.withValues(alpha: 0.35)
                          : color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _pageController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialPage = (widget.currentPage + 1)
        .clamp(1, widget.pageCount)
        .toInt();
    _pageController = TextEditingController(text: initialPage.toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Page 1 - ${widget.pageCount}'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('rhwp-go-to-page-field'),
              controller: _pageController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Page',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rhwp-go-to-page-apply'),
          onPressed: _submit,
          child: const Text('Go'),
        ),
      ],
    );
  }

  void _submit() {
    final value = int.tryParse(_pageController.text);
    if (value == null || value < 1 || value > widget.pageCount) {
      setState(() {
        _errorText = 'Enter a page from 1 to ${widget.pageCount}.';
      });
      return;
    }

    Navigator.of(context).pop(value);
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).dividerColor,
    );
  }
}

class _EditorStatusBar extends StatelessWidget {
  const _EditorStatusBar({
    required this.selection,
    required this.tableCellSelection,
    required this.objectSelection,
    required this.overwriteMode,
    required this.busy,
    required this.currentPage,
    required this.pageCount,
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onZoomPreset,
  });

  final RhwpSelectionRange selection;
  final RhwpTableCellSelection? tableCellSelection;
  final RhwpObjectSelection? objectSelection;
  final bool overwriteMode;
  final bool busy;
  final int currentPage;
  final int? pageCount;
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final ValueChanged<double> onZoomPreset;

  @override
  Widget build(BuildContext context) {
    final statusText = _positionStatusText();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SizedBox(
          height: 28,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  statusText,
                  key: const ValueKey('rhwp-editor-status-position'),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const VerticalDivider(width: 24),
              Text(
                _pageStatusText(),
                key: const ValueKey('rhwp-editor-status-page'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const VerticalDivider(width: 24),
              Text(
                selection.isCollapsed
                    ? (overwriteMode ? 'Overwrite' : 'Insert')
                    : 'Selection',
                key: const ValueKey('rhwp-editor-status-input-mode'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              _StatusBarIconButton(
                tooltip: 'Zoom out',
                buttonKey: const ValueKey('rhwp-editor-status-zoom-out'),
                icon: Icons.zoom_out,
                onPressed: zoom <= RhwpViewerController.minZoom
                    ? null
                    : onZoomOut,
              ),
              SizedBox(
                width: 58,
                child: _ZoomPresetMenuButton(
                  buttonKey: const ValueKey('rhwp-editor-status-zoom-menu'),
                  textKey: const ValueKey('rhwp-editor-status-zoom'),
                  zoom: zoom,
                  onSelected: onZoomPreset,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _StatusBarIconButton(
                tooltip: 'Zoom in',
                buttonKey: const ValueKey('rhwp-editor-status-zoom-in'),
                icon: Icons.zoom_in,
                onPressed: zoom >= RhwpViewerController.maxZoom
                    ? null
                    : onZoomIn,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _pageStatusText() {
    final count = pageCount;
    if (count == null) {
      return 'Page ${currentPage + 1} / ?';
    }
    return 'Page ${currentPage + 1} / $count';
  }

  String _positionStatusText() {
    final activeTableCellSelection = tableCellSelection;
    if (activeTableCellSelection != null) {
      final start =
          'R${activeTableCellSelection.startRow + 1}C${activeTableCellSelection.startColumn + 1}';
      final end =
          'R${activeTableCellSelection.endRow + 1}C${activeTableCellSelection.endColumn + 1}';
      if (activeTableCellSelection.isTextEditing) {
        return 'Cell $start / Para ${activeTableCellSelection.activeCellParagraph} / Offset ${activeTableCellSelection.activeOffset}';
      }
      return start == end ? 'Cell $start' : 'Cells $start:$end';
    }

    final activeObjectSelection = objectSelection;
    if (activeObjectSelection != null) {
      final objectLabel = activeObjectSelection.objectIndex == null
          ? activeObjectSelection.type
          : '${activeObjectSelection.type} #${activeObjectSelection.objectIndex}';
      final controlLabel = activeObjectSelection.controlIndex == null
          ? ''
          : ' / Control ${activeObjectSelection.controlIndex}';
      return 'Object $objectLabel / Page ${activeObjectSelection.page + 1}$controlLabel';
    }

    final cursor = selection.end;
    return 'Sec ${cursor.section} / Para ${cursor.paragraph} / Offset ${cursor.offset}';
  }
}

class _StatusBarIconButton extends StatelessWidget {
  const _StatusBarIconButton({
    required this.tooltip,
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        minimumSize: const Size.square(26),
        fixedSize: const Size.square(26),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ZoomPresetMenuButton extends StatelessWidget {
  const _ZoomPresetMenuButton({
    required this.buttonKey,
    required this.textKey,
    required this.zoom,
    required this.onSelected,
    this.textStyle,
  });

  final Key buttonKey;
  final Key textKey;
  final double zoom;
  final ValueChanged<double> onSelected;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      key: buttonKey,
      tooltip: 'Zoom presets',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final preset in RhwpViewerController.zoomSteps)
          PopupMenuItem<double>(
            key: ValueKey('rhwp-editor-zoom-preset-${(preset * 100).round()}'),
            value: preset,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: _isSelectedZoomPreset(zoom, preset)
                      ? const Icon(Icons.check, size: 16)
                      : null,
                ),
                Text(_formatEditorZoom(preset)),
              ],
            ),
          ),
      ],
      child: Center(
        child: Text(
          _formatEditorZoom(zoom),
          key: textKey,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ),
    );
  }
}

bool _isSelectedZoomPreset(double zoom, double preset) {
  return (zoom - preset).abs() < 0.0001;
}

String _formatEditorZoom(double zoom) => '${(zoom * 100).round()}%';

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
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
