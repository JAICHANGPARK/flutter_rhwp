import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        other.activeOffset == activeOffset;
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
  );

  @override
  String toString() {
    return 'RhwpTableCellSelection(section: $section, paragraph: $paragraph, controlIndex: $controlIndex, startRow: $startRow, startColumn: $startColumn, endRow: $endRow, endColumn: $endColumn, activeCellIndex: $activeCellIndex, activeCellParagraph: $activeCellParagraph, activeOffset: $activeOffset)';
  }
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
}

class _CharShapeDialogResult {
  const _CharShapeDialogResult({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.fontSize,
    required this.textColor,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final int fontSize;
  final String textColor;
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

class _EditorSearchMatch {
  const _EditorSearchMatch({
    required this.page,
    required this.section,
    required this.paragraph,
    required this.startOffset,
    required this.endOffset,
  });

  final int page;
  final int section;
  final int paragraph;
  final int startOffset;
  final int endOffset;

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
}

/// Controller for the Flutter-native command editor overlay.
class RhwpEditorController extends RhwpViewerController {
  RhwpEditorController({super.zoom})
    : _cursor = const RhwpCursorPosition(),
      _selection = RhwpSelectionRange.collapsed(const RhwpCursorPosition());

  RhwpCursorPosition _cursor;
  RhwpSelectionRange _selection;
  RhwpTableCellSelection? _tableCellSelection;

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

  /// The active table cell selection for page overlay and table commands.
  RhwpTableCellSelection? get tableCellSelection => _tableCellSelection;

  set tableCellSelection(RhwpTableCellSelection? value) {
    if (value == _tableCellSelection) {
      return;
    }
    _tableCellSelection = value;
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
    this.onExported,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;

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
    this.onExported,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;

  @override
  Widget build(BuildContext context) {
    return RhwpEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
      onOpenRequested: onOpenRequested,
      onExported: onExported,
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
    this.onExported,
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;
  final FutureOr<void> Function()? onOpenRequested;
  final FutureOr<void> Function(RhwpExportedDocument document)? onExported;

  @override
  Widget build(BuildContext context) {
    return RhwpNativeEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
      onOpenRequested: onOpenRequested,
      onExported: onExported,
    );
  }
}

class _RhwpEditorState extends State<RhwpEditor> with TextInputClient {
  late final RhwpEditorController _controller;
  late final bool _ownsController;
  final _focusNode = FocusNode(debugLabel: 'RhwpNativeEditor');
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
  TextEditingValue _inputValue = TextEditingValue.empty;
  Key _viewerKey = UniqueKey();
  List<_EditorSearchMatch> _searchMatches = const [];
  int _activeSearchMatch = -1;
  int? _pageCountValue;
  final _undoSnapshots = <int>[];
  final _redoSnapshots = <int>[];
  bool _busy = false;
  bool _searching = false;
  Object? _error;

  static const _maxUndoSnapshots = 100;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpEditorController();
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    _syncCursorFields();
    _loadPageCount();
  }

  @override
  void didUpdateWidget(covariant RhwpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _viewerKey = UniqueKey();
      _pageCountValue = null;
      _loadPageCount();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _closeTextInput();
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
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
      _syncCursorFields();
    } else {
      _syncTableSelectionFields(tableSelection);
    }
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

  void _setTextIfChanged(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _openTextInput();
    } else {
      _closeTextInput();
    }
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
      }
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

  Future<void> _exportFromEditor(RhwpExportFormat format) async {
    final onExported = widget.onExported;
    if (_busy || onExported == null) {
      return;
    }

    setState(() {
      _busy = true;
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
        });
      }
    }
  }

  Future<void> _insertCommittedText(String text) async {
    if (text.isEmpty || _busy) {
      return;
    }

    if (_editableTableCellSelection != null) {
      await _insertTextInSelectedTableCell(text);
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
      await widget.document.insertText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        text: text,
      );
      _controller.cursor = cursor.copyWith(offset: cursor.offset + text.length);
    });
  }

  Future<void> _insertTextInSelectedTableCell(
    String text, {
    bool clearTextController = false,
  }) async {
    final tableSelection = _editableTableCellSelection;
    if (tableSelection == null || _busy) {
      return;
    }

    final offset = _parseNonNegative(_offsetController.text);
    await _runEdit(() async {
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
      );
      if (clearTextController) {
        _textController.clear();
      }
    });
  }

  Future<void> _copySelection() async {
    final text = await _selectedText();
    if (text == null || text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _cutSelection() async {
    final text = await _selectedText();
    if (text == null || text.isEmpty || _busy) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    await _runEdit(() async {
      await _deleteSelectedText(_controller.selection);
    });
  }

  Future<void> _pasteClipboard() async {
    if (_busy) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    await _insertCommittedText(text);
  }

  Future<void> _selectAllText() async {
    if (_busy || _searching) {
      return;
    }

    setState(() {
      _busy = true;
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
        });
      }
    }
  }

  Future<void> _insertLineBreak() async {
    await _insertCommittedText('\n');
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

  Future<void> _applyCharFormat({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) async {
    if (_busy) {
      return;
    }

    final selection = _controller.selection;
    if (selection.isCollapsed) {
      return;
    }

    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    await _runEdit(() async {
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
        fontSize: fontSize,
        textColor: textColor,
      );
      _controller.selection = RhwpSelectionRange(start: start, end: end);
    });
  }

  Future<void> _showCharShapeDialog() async {
    if (_busy || _controller.selection.isCollapsed) {
      return;
    }

    final result = await showDialog<_CharShapeDialogResult>(
      context: context,
      builder: (context) => const _CharShapeDialog(),
    );
    if (result == null) {
      return;
    }

    await _applyCharFormat(
      bold: result.bold,
      italic: result.italic,
      underline: result.underline,
      strikethrough: result.strikethrough,
      fontSize: result.fontSize,
      textColor: result.textColor,
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
      builder: (context) => const _ParaShapeDialog(),
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

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    if (_searching) {
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

  List<_EditorSearchMatch> _searchTree(RhwpLayerTree tree, String query) {
    final foldedQuery = query.toLowerCase();
    final matches = <_EditorSearchMatch>[];
    for (final run in tree.textRuns) {
      final section = run.section;
      final paragraph = run.paragraph;
      if (section == null || paragraph == null || run.cellContext != null) {
        continue;
      }

      final foldedText = run.text.toLowerCase();
      var index = foldedText.indexOf(foldedQuery);
      while (index >= 0) {
        matches.add(
          _EditorSearchMatch(
            page: tree.page,
            section: section,
            paragraph: paragraph,
            startOffset: run.charStart + index,
            endOffset: run.charStart + index + query.length,
          ),
        );
        index = foldedText.indexOf(foldedQuery, index + foldedQuery.length);
      }
    }
    return matches;
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

    _controller.clearTableCellSelection();
    final match = _searchMatches[_activeSearchMatch];
    _controller.selection = match.selection;
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
    final replacementStart = RhwpCursorPosition(
      section: match.section,
      paragraph: match.paragraph,
      offset: match.startOffset,
    );
    final replacementEnd = replacementStart.copyWith(
      offset: match.startOffset + replacement.length,
    );

    final replaced = await _runEdit(() async {
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
      _controller.selection = RhwpSelectionRange(
        start: replacementStart,
        end: replacementEnd,
      );
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
    final replacementStart = RhwpCursorPosition(
      section: firstMatch.section,
      paragraph: firstMatch.paragraph,
      offset: firstMatch.startOffset,
    );
    final replacementEnd = replacementStart.copyWith(
      offset: firstMatch.startOffset + replacement.length,
    );

    final replaced = await _runEdit(() async {
      for (final match in matches) {
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
      _controller.selection = RhwpSelectionRange(
        start: replacementStart,
        end: replacementEnd,
      );
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
    return right.startOffset.compareTo(left.startOffset);
  }

  _EditorSearchMatch _shiftSearchMatchAfterReplacement(
    _EditorSearchMatch candidate,
    _EditorSearchMatch replaced,
  ) {
    if (candidate.section != replaced.section ||
        candidate.paragraph != replaced.paragraph ||
        candidate.startOffset < replaced.endOffset) {
      return candidate;
    }

    final delta =
        _replaceController.text.length -
        (replaced.endOffset - replaced.startOffset);
    if (delta == 0) {
      return candidate;
    }

    return _EditorSearchMatch(
      page: candidate.page,
      section: candidate.section,
      paragraph: candidate.paragraph,
      startOffset: candidate.startOffset + delta,
      endOffset: candidate.endOffset + delta,
    );
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

    final selection = _controller.selection;
    final start = selection.normalizedStart;
    final end = selection.normalizedEnd;
    if (start.section != end.section) {
      return;
    }

    await _runEdit(() async {
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

  Future<void> _deleteBackward() async {
    if (_editableTableCellSelection != null) {
      await _deleteTextInSelectedTableCell(backward: true);
      return;
    }

    await _runEdit(() async {
      if (await _deleteSelectedText(_controller.selection)) {
        return;
      }
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

  Future<void> _deleteForward() async {
    if (_editableTableCellSelection != null) {
      await _deleteTextInSelectedTableCell(backward: false);
      return;
    }

    await _runEdit(() async {
      if (await _deleteSelectedText(_controller.selection)) {
        return;
      }
      final cursor = _readCursor();
      await widget.document.deleteText(
        section: cursor.section,
        paragraph: cursor.paragraph,
        offset: cursor.offset,
        count: 1,
      );
      _controller.cursor = cursor;
    });
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
      );
    });
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

  Future<bool> _runEdit(Future<void> Function() edit) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    int? undoSnapshot;
    try {
      undoSnapshot = await widget.document.saveSnapshot();
      await edit();
      await _discardSnapshots(_redoSnapshots);
      _redoSnapshots.clear();
      _undoSnapshots.add(undoSnapshot);
      if (_undoSnapshots.length > _maxUndoSnapshots) {
        final stale = _undoSnapshots.removeAt(0);
        await widget.document.discardSnapshot(stale);
      }
      if (!mounted) {
        return false;
      }
      setState(() {
        _busy = false;
        _viewerKey = UniqueKey();
      });
      widget.onChanged?.call(widget.document);
      return true;
    } catch (error) {
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
    setState(() {
      _busy = true;
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
        _viewerKey = UniqueKey();
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

  void _setSelectionFromPage(RhwpSelectionRange selection) {
    _controller.selection = selection;
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
        await _applyCharFormat(bold: true);
      case _EditorContextMenuAction.italic:
        await _applyCharFormat(italic: true);
      case _EditorContextMenuAction.underline:
        await _applyCharFormat(underline: true);
      case _EditorContextMenuAction.strikethrough:
        await _applyCharFormat(strikethrough: true);
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
    }
  }

  List<PopupMenuEntry<_EditorContextMenuAction>> _contextMenuItems() {
    final hasSelection = !_controller.selection.isCollapsed;
    final hasTableSelection = _controller.tableCellSelection != null;

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
    final connection = _textInputConnection;
    if (connection != null && connection.attached) {
      connection.close();
    }
    _textInputConnection = null;
  }

  void _resetTextInputValue() {
    _setInputValue(TextEditingValue.empty);
    final connection = _textInputConnection;
    if (connection != null && connection.attached) {
      connection.setEditingState(_inputValue);
    }
  }

  void _setInputValue(TextEditingValue value) {
    if (_inputValue == value) {
      return;
    }
    _inputValue = value;
    if (mounted) {
      setState(() {});
    }
  }

  String? get _composingText {
    final composing = _inputValue.composing;
    if (!composing.isValid || composing.isCollapsed) {
      return null;
    }

    final text = _inputValue.text;
    final start = composing.start.clamp(0, text.length);
    final end = composing.end.clamp(0, text.length);
    if (start >= end) {
      return null;
    }

    final composingText = text.substring(start, end);
    return composingText.isEmpty ? null : composingText;
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (value == _inputValue) {
      return;
    }

    _setInputValue(value);
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }

    final committedText = value.text;
    if (committedText.isEmpty) {
      return;
    }

    _resetTextInputValue();
    _insertCommittedText(committedText);
  }

  @override
  void performAction(TextInputAction action) {
    _resetTextInputValue();
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
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final extendSelection = HardwareKeyboard.instance.isShiftPressed;
    final shortcutPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
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
          _exportFromEditor(RhwpExportFormat.hwp);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyB:
          _applyCharFormat(bold: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyI:
          _applyCharFormat(italic: true);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyU:
          _applyCharFormat(underline: true);
          return KeyEventResult.handled;
      }
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _moveCursorHorizontally(-1, extendSelection: extendSelection);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveCursorHorizontally(1, extendSelection: extendSelection);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _moveCursorToLineStart(extendSelection: extendSelection);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (!_busy) {
          if (extendSelection) {
            _insertLineBreak();
          } else {
            _splitParagraph();
          }
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        if (!_busy) {
          _deleteBackward();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.delete:
        if (!_busy) {
          _deleteForward();
        }
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _moveCursorHorizontally(int delta, {required bool extendSelection}) {
    final current = _controller.selection;
    final nextOffset = math.max(0, current.end.offset + delta);
    final next = current.end.copyWith(offset: nextOffset);
    _setCursorOrSelection(current, next, extendSelection: extendSelection);
  }

  void _moveCursorToLineStart({required bool extendSelection}) {
    final current = _controller.selection;
    final next = current.end.copyWith(offset: 0);
    _setCursorOrSelection(current, next, extendSelection: extendSelection);
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
          busy: _busy || _searching,
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
          replaceController: _replaceController,
          tableCellSelection: _controller.tableCellSelection,
          currentPage: _controller.currentPage,
          pageCount: _pageCountValue,
          zoom: _controller.zoom,
          canOpen: widget.onOpenRequested != null,
          canExport: widget.onExported != null,
          searchMatchCount: _searchMatches.length,
          activeSearchMatch: _activeSearchMatch,
          onInsert: _insertText,
          onOpen: _requestOpenFromEditor,
          onSaveHwp: () => _exportFromEditor(RhwpExportFormat.hwp),
          onSaveHwpx: () => _exportFromEditor(RhwpExportFormat.hwpx),
          onExportPdf: () => _exportFromEditor(RhwpExportFormat.pdf),
          onDeleteBackward: _deleteBackward,
          onInsertTable: _insertTable,
          onInsertTableRow: _insertTableRow,
          onInsertTableColumn: _insertTableColumn,
          onDeleteTableRow: _deleteTableRow,
          onDeleteTableColumn: _deleteTableColumn,
          onMergeTableCells: _mergeTableCells,
          onSplitTableCell: _splitTableCell,
          onCut: _cutSelection,
          onCopy: _copySelection,
          onPaste: _pasteClipboard,
          onSelectAll: _selectAllText,
          canUndo: _undoSnapshots.isNotEmpty,
          canRedo: _redoSnapshots.isNotEmpty,
          onUndo: _undoEdit,
          onRedo: _redoEdit,
          onBold: () => _applyCharFormat(bold: true),
          onItalic: () => _applyCharFormat(italic: true),
          onUnderline: () => _applyCharFormat(underline: true),
          onStrikethrough: () => _applyCharFormat(strikethrough: true),
          onCharShape: _showCharShapeDialog,
          onParaShape: _showParaShapeDialog,
          onAlignLeft: () => _applyParagraphAlignment('left'),
          onAlignCenter: () => _applyParagraphAlignment('center'),
          onAlignRight: () => _applyParagraphAlignment('right'),
          onAlignJustify: () => _applyParagraphAlignment('justify'),
          onFind: _runSearch,
          onSearchPrevious: _searchPrevious,
          onSearchNext: _searchNext,
          onClearSearch: _clearSearch,
          onReplace: _replaceActiveSearchMatch,
          onReplaceAll: _replaceAllSearchMatches,
          onCreateHeader: () => _createHeaderFooter(isHeader: true),
          onCreateFooter: () => _createHeaderFooter(isHeader: false),
          onPreviousPage: () => unawaited(_controller.previousPage()),
          onNextPage: () => unawaited(_controller.nextPage()),
          onZoomOut: _controller.zoomOut,
          onZoomIn: _controller.zoomIn,
          onResetZoom: _controller.resetZoom,
        ),
        Expanded(
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: RhwpViewer(
              key: _viewerKey,
              document: widget.document,
              controller: _controller,
              ignorePageOverlayPointer: false,
              pageOverlayBuilder: (context, page, _) {
                return _EditorSelectionOverlay(
                  document: widget.document,
                  page: page,
                  selection: _controller.selection,
                  tableCellSelection: _controller.tableCellSelection,
                  composingText: _composingText,
                  searchMatches: _searchMatches
                      .where((match) => match.page == page)
                      .toList(growable: false),
                  activeSearchMatch: _activeSearchMatch < 0
                      ? null
                      : _searchMatches[_activeSearchMatch],
                  fallbackEnabled: page == 0,
                  onCursorPosition: _setCursorFromPage,
                  onSelectionRange: _setSelectionFromPage,
                  onTableCellSelection: _setTableSelectionFromPage,
                  onFocusRequested: _focusEditor,
                  onContextMenuRequested: _showContextMenu,
                );
              },
            ),
          ),
        ),
        _EditorStatusBar(
          selection: _controller.selection,
          busy: _busy,
          zoom: _controller.zoom,
          onZoomOut: _controller.zoomOut,
          onZoomIn: _controller.zoomIn,
        ),
      ],
    );
  }
}

class _EditorSelectionOverlay extends StatefulWidget {
  const _EditorSelectionOverlay({
    required this.document,
    required this.page,
    required this.selection,
    required this.tableCellSelection,
    required this.composingText,
    required this.searchMatches,
    required this.activeSearchMatch,
    required this.fallbackEnabled,
    required this.onCursorPosition,
    required this.onSelectionRange,
    required this.onTableCellSelection,
    required this.onFocusRequested,
    required this.onContextMenuRequested,
  });

  final RhwpDocument document;
  final int page;
  final RhwpSelectionRange selection;
  final RhwpTableCellSelection? tableCellSelection;
  final String? composingText;
  final List<_EditorSearchMatch> searchMatches;
  final _EditorSearchMatch? activeSearchMatch;
  final bool fallbackEnabled;
  final ValueChanged<RhwpCursorPosition> onCursorPosition;
  final ValueChanged<RhwpSelectionRange> onSelectionRange;
  final ValueChanged<RhwpTableCellSelection?> onTableCellSelection;
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

  static const _pageInset = 24.0;
  static const _lineHeight = 24.0;
  static const _characterWidth = 8.0;

  @override
  void initState() {
    super.initState();
    _layerTree = _loadLayerTree();
  }

  @override
  void didUpdateWidget(covariant _EditorSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.page != widget.page) {
      _layerTree = _loadLayerTree();
    }
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
                _handlePointerDown(event.localPosition, constraints, tree);
              },
              onPointerMove: (event) {
                _handlePointerMove(event.localPosition, constraints, tree);
              },
              onPointerUp: (_) {
                _dragAnchor = null;
                _tableDragAnchor = null;
              },
              onPointerCancel: (_) {
                _dragAnchor = null;
                _tableDragAnchor = null;
              },
              child: child,
            );
          },
        );
      },
    );
  }

  void _handlePointerDown(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final tableCell = _tableCellForPoint(localPosition, constraints, tree);
    if (tableCell != null) {
      final textHit = _textHitForPoint(localPosition, constraints, tree);
      final tableTextHit = textHit?.cellContext == null ? null : textHit;
      _tableDragAnchor = tableCell;
      _dragAnchor = null;
      widget.onTableCellSelection(
        tableTextHit == null
            ? RhwpTableCellSelection.fromCell(tableCell)
            : RhwpTableCellSelection.fromCellTextHit(tableCell, tableTextHit),
      );
      widget.onFocusRequested();
      return;
    }

    _tableDragAnchor = null;
    widget.onTableCellSelection(null);

    final cursor = _cursorForPoint(localPosition, constraints, tree);
    if (cursor != null) {
      widget.onFocusRequested();
      _dragAnchor = cursor;
      widget.onCursorPosition(cursor);
    }
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

    _tableDragAnchor = null;
    final textHit = _textHitForPoint(localPosition, constraints, tree);
    if (textHit != null && _selectionContainsTextHit(textHit)) {
      widget.onTableCellSelection(null);
      widget.onFocusRequested();
      return;
    }

    widget.onTableCellSelection(null);
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
    final searchRects = _searchRects(tree, overlaySize);
    final caretRect = tree.caretRectFor(
      section: widget.selection.end.section,
      paragraph: widget.selection.end.paragraph,
      offset: widget.selection.end.offset,
    );
    if (caretRect == null &&
        tableSelectionRects.isEmpty &&
        searchRects.isEmpty) {
      return null;
    }

    final color = Theme.of(context).colorScheme.primary;
    final searchColor = Colors.amber.shade600;
    final selectionRects = _layerSelectionRects(tree, overlaySize);
    final scaledCaretRect = caretRect == null
        ? null
        : _scalePageRect(caretRect, tree, overlaySize);

    return Stack(
      children: [
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
        if (caretRect != null)
          _positionedRect(
            key: const ValueKey('rhwp-editor-caret'),
            rect: _scalePageRect(caretRect, tree, overlaySize, caret: true),
            constraints: constraints,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        if (widget.composingText != null && scaledCaretRect != null)
          _positionedRect(
            key: const ValueKey('rhwp-editor-composing-preview'),
            rect: Rect.fromLTWH(
              scaledCaretRect.left,
              scaledCaretRect.top,
              180,
              32,
            ),
            constraints: constraints,
            child: _ComposingPreview(text: widget.composingText!),
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

    return Stack(
      children: [
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        if (widget.composingText != null)
          Positioned(
            key: const ValueKey('rhwp-editor-composing-preview'),
            left: _bound(boundedCaretLeft, constraints.maxWidth, 180),
            top: _bound(boundedTop, constraints.maxHeight, 32),
            width: 180,
            height: 32,
            child: _ComposingPreview(text: widget.composingText!),
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

  List<({Rect rect, bool active})> _searchRects(
    RhwpLayerTree tree,
    Size overlaySize,
  ) {
    if (widget.searchMatches.isEmpty) {
      return const [];
    }

    final rects = <({Rect rect, bool active})>[];
    for (final match in widget.searchMatches) {
      for (final rect in tree.selectionRectsForRange(
        startSection: match.section,
        startParagraph: match.paragraph,
        startOffset: match.startOffset,
        endSection: match.section,
        endParagraph: match.paragraph,
        endOffset: match.endOffset,
      )) {
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

enum _EditorTab { file, edit, view, insert, format, page, table, tools }

class _EditorToolbar extends StatefulWidget {
  const _EditorToolbar({
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
    required this.replaceController,
    required this.tableCellSelection,
    required this.currentPage,
    required this.pageCount,
    required this.zoom,
    required this.canOpen,
    required this.canExport,
    required this.searchMatchCount,
    required this.activeSearchMatch,
    required this.onInsert,
    required this.onOpen,
    required this.onSaveHwp,
    required this.onSaveHwpx,
    required this.onExportPdf,
    required this.onDeleteBackward,
    required this.onInsertTable,
    required this.onInsertTableRow,
    required this.onInsertTableColumn,
    required this.onDeleteTableRow,
    required this.onDeleteTableColumn,
    required this.onMergeTableCells,
    required this.onSplitTableCell,
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
    required this.onCharShape,
    required this.onParaShape,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onAlignJustify,
    required this.onFind,
    required this.onSearchPrevious,
    required this.onSearchNext,
    required this.onClearSearch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onCreateHeader,
    required this.onCreateFooter,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetZoom,
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
  final TextEditingController replaceController;
  final RhwpTableCellSelection? tableCellSelection;
  final int currentPage;
  final int? pageCount;
  final double zoom;
  final bool canOpen;
  final bool canExport;
  final int searchMatchCount;
  final int activeSearchMatch;
  final VoidCallback onInsert;
  final VoidCallback onOpen;
  final VoidCallback onSaveHwp;
  final VoidCallback onSaveHwpx;
  final VoidCallback onExportPdf;
  final VoidCallback onDeleteBackward;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertTableRow;
  final VoidCallback onInsertTableColumn;
  final VoidCallback onDeleteTableRow;
  final VoidCallback onDeleteTableColumn;
  final VoidCallback onMergeTableCells;
  final VoidCallback onSplitTableCell;
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
  final VoidCallback onCharShape;
  final VoidCallback onParaShape;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onAlignJustify;
  final VoidCallback onFind;
  final VoidCallback onSearchPrevious;
  final VoidCallback onSearchNext;
  final VoidCallback onClearSearch;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onCreateHeader;
  final VoidCallback onCreateFooter;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;

  @override
  State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  var _activeTab = _EditorTab.insert;

  @override
  void didUpdateWidget(covariant _EditorToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableCellSelection == null &&
        widget.tableCellSelection != null) {
      _activeTab = _EditorTab.table;
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
                        setState(() {
                          _activeTab = tab;
                        });
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
        label: '삭제',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Delete backward',
              icon: Icons.backspace_outlined,
              onPressed: widget.busy ? null : widget.onDeleteBackward,
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
              onPressed: widget.zoom <= 0.25 ? null : widget.onZoomOut,
            ),
            SizedBox(
              width: 52,
              child: Center(
                child: Text(
                  _formatEditorZoom(widget.zoom),
                  key: const ValueKey('rhwp-editor-toolbar-zoom'),
                  textAlign: TextAlign.center,
                ),
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
              onPressed: widget.zoom >= 6.0 ? null : widget.onZoomIn,
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
    return [
      _RibbonGroup(
        label: '글자 모양',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Bold',
              icon: Icons.format_bold,
              onPressed: widget.busy ? null : widget.onBold,
            ),
            _ToolbarIconButton(
              tooltip: 'Italic',
              icon: Icons.format_italic,
              onPressed: widget.busy ? null : widget.onItalic,
            ),
            _ToolbarIconButton(
              tooltip: 'Underline',
              icon: Icons.format_underlined,
              onPressed: widget.busy ? null : widget.onUnderline,
            ),
            _ToolbarIconButton(
              tooltip: 'Strikethrough',
              icon: Icons.format_strikethrough,
              onPressed: widget.busy ? null : widget.onStrikethrough,
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
              onPressed: widget.busy ? null : widget.onAlignLeft,
            ),
            _ToolbarIconButton(
              tooltip: 'Align center',
              icon: Icons.format_align_center,
              onPressed: widget.busy ? null : widget.onAlignCenter,
            ),
            _ToolbarIconButton(
              tooltip: 'Align right',
              icon: Icons.format_align_right,
              onPressed: widget.busy ? null : widget.onAlignRight,
            ),
            _ToolbarIconButton(
              tooltip: 'Justify',
              icon: Icons.format_align_justify,
              onPressed: widget.busy ? null : widget.onAlignJustify,
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

  List<Widget> _pageGroups() {
    return [
      _RibbonGroup(
        label: '쪽',
        child: Row(
          children: [
            _ToolbarIconButton(
              tooltip: 'Page setup',
              icon: Icons.description_outlined,
              onPressed: null,
            ),
            _ToolbarIconButton(
              tooltip: 'Header',
              buttonKey: const ValueKey('rhwp-editor-create-header'),
              icon: Icons.vertical_align_top,
              onPressed: widget.busy ? null : widget.onCreateHeader,
            ),
            _ToolbarIconButton(
              tooltip: 'Footer',
              buttonKey: const ValueKey('rhwp-editor-create-footer'),
              icon: Icons.vertical_align_bottom,
              onPressed: widget.busy ? null : widget.onCreateFooter,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _tableGroups() {
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
              child: TextField(
                key: const ValueKey('rhwp-editor-search-field'),
                controller: widget.searchController,
                minLines: 1,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Find',
                ),
                onSubmitted: (_) {
                  if (!widget.busy) {
                    widget.onFind();
                  }
                },
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
              icon: Icons.difference_outlined,
              onPressed: null,
            ),
          ],
        ),
      ),
    ];
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

class _CharShapeDialog extends StatefulWidget {
  const _CharShapeDialog();

  @override
  State<_CharShapeDialog> createState() => _CharShapeDialogState();
}

class _CharShapeDialogState extends State<_CharShapeDialog> {
  final _fontSizeController = TextEditingController(text: '10.0');
  var _bold = false;
  var _italic = false;
  var _underline = false;
  var _strikethrough = false;
  var _textColor = '#000000';

  static const _swatches = [
    (label: '검정', color: Color(0xff000000), value: '#000000'),
    (label: '빨강', color: Color(0xffdc2626), value: '#dc2626'),
    (label: '파랑', color: Color(0xff2563eb), value: '#2563eb'),
    (label: '초록', color: Color(0xff16a34a), value: '#16a34a'),
  ];

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  onSelected: (value) => setState(() => _strikethrough = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Text color', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final swatch in _swatches)
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
          ],
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
    final points = double.tryParse(_fontSizeController.text.trim()) ?? 10.0;
    final clampedPoints = points.clamp(1.0, 200.0);
    Navigator.of(context).pop(
      _CharShapeDialogResult(
        bold: _bold,
        italic: _italic,
        underline: _underline,
        strikethrough: _strikethrough,
        fontSize: (clampedPoints * 100).round(),
        textColor: _textColor,
      ),
    );
  }
}

class _ParaShapeDialog extends StatefulWidget {
  const _ParaShapeDialog();

  @override
  State<_ParaShapeDialog> createState() => _ParaShapeDialogState();
}

class _ParaShapeDialogState extends State<_ParaShapeDialog> {
  final _lineSpacingController = TextEditingController(text: '160');
  final _indentController = TextEditingController(text: '0');
  final _marginLeftController = TextEditingController(text: '0');
  final _marginRightController = TextEditingController(text: '0');
  final _spacingBeforeController = TextEditingController(text: '0');
  final _spacingAfterController = TextEditingController(text: '0');
  var _alignment = 'justify';
  var _lineSpacingType = 'Percent';

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
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
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
    required this.busy,
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final RhwpSelectionRange selection;
  final bool busy;
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    final cursor = selection.end;
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
              Text(
                'Sec ${cursor.section} / Para ${cursor.paragraph} / Offset ${cursor.offset}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const VerticalDivider(width: 24),
              Text(
                selection.isCollapsed ? 'Insert' : 'Selection',
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
                onPressed: zoom <= 0.25 ? null : onZoomOut,
              ),
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    _formatEditorZoom(zoom),
                    key: const ValueKey('rhwp-editor-status-zoom'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              _StatusBarIconButton(
                tooltip: 'Zoom in',
                buttonKey: const ValueKey('rhwp-editor-status-zoom-in'),
                icon: Icons.zoom_in,
                onPressed: zoom >= 6.0 ? null : onZoomIn,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
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
