import 'dart:convert';
import 'dart:math' as math;

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

/// Controller for the Flutter-native command editor overlay.
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
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;

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
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;

  @override
  Widget build(BuildContext context) {
    return RhwpEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
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
  });

  final RhwpDocument document;
  final RhwpEditorController? controller;
  final ValueChanged<RhwpDocument>? onChanged;

  @override
  Widget build(BuildContext context) {
    return RhwpNativeEditor(
      document: document,
      controller: controller,
      onChanged: onChanged,
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
  TextInputConnection? _textInputConnection;
  TextEditingValue _inputValue = TextEditingValue.empty;
  Key _viewerKey = UniqueKey();
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpEditorController();
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    _syncCursorFields();
  }

  @override
  void didUpdateWidget(covariant RhwpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _viewerKey = UniqueKey();
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
    super.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _inputValue;

  @override
  AutofillScope? get currentAutofillScope => null;

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

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _openTextInput();
    } else {
      _closeTextInput();
    }
  }

  Future<void> _insertText() async {
    final text = _textController.text;
    if (text.isEmpty) {
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

  Future<void> _insertCommittedText(String text) async {
    if (text.isEmpty || _busy) {
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
      _controller.cursor = RhwpCursorPosition(
        section: cursor.section,
        paragraph: tableParagraph + 1,
      );
    });
  }

  Future<void> _applyCharFormat({
    bool? bold,
    bool? italic,
    bool? underline,
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
      );
      _controller.selection = RhwpSelectionRange(start: start, end: end);
    });
  }

  Future<void> _applyParagraphAlignment(String alignment) async {
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

  int _parsePositive(String text, {required int max}) {
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1) {
      return 1;
    }
    return math.min(parsed, max);
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

  void _setCursorFromPage(RhwpCursorPosition cursor) {
    _controller.cursor = cursor;
  }

  void _setSelectionFromPage(RhwpSelectionRange selection) {
    _controller.selection = selection;
  }

  void _focusEditor() {
    _focusNode.requestFocus();
    _openTextInput();
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
          busy: _busy,
          error: _error,
          textController: _textController,
          sectionController: _sectionController,
          paragraphController: _paragraphController,
          offsetController: _offsetController,
          tableRowsController: _tableRowsController,
          tableColumnsController: _tableColumnsController,
          onInsert: _insertText,
          onDeleteBackward: _deleteBackward,
          onInsertTable: _insertTable,
          onCut: _cutSelection,
          onCopy: _copySelection,
          onPaste: _pasteClipboard,
          onBold: () => _applyCharFormat(bold: true),
          onItalic: () => _applyCharFormat(italic: true),
          onUnderline: () => _applyCharFormat(underline: true),
          onAlignLeft: () => _applyParagraphAlignment('left'),
          onAlignCenter: () => _applyParagraphAlignment('center'),
          onAlignRight: () => _applyParagraphAlignment('right'),
          onAlignJustify: () => _applyParagraphAlignment('justify'),
          onZoomOut: _controller.zoomOut,
          onZoomIn: _controller.zoomIn,
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
                  composingText: _composingText,
                  fallbackEnabled: page == 0,
                  onCursorPosition: _setCursorFromPage,
                  onSelectionRange: _setSelectionFromPage,
                  onFocusRequested: _focusEditor,
                );
              },
            ),
          ),
        ),
        _EditorStatusBar(selection: _controller.selection, busy: _busy),
      ],
    );
  }
}

class _EditorSelectionOverlay extends StatefulWidget {
  const _EditorSelectionOverlay({
    required this.document,
    required this.page,
    required this.selection,
    required this.composingText,
    required this.fallbackEnabled,
    required this.onCursorPosition,
    required this.onSelectionRange,
    required this.onFocusRequested,
  });

  final RhwpDocument document;
  final int page;
  final RhwpSelectionRange selection;
  final String? composingText;
  final bool fallbackEnabled;
  final ValueChanged<RhwpCursorPosition> onCursorPosition;
  final ValueChanged<RhwpSelectionRange> onSelectionRange;
  final VoidCallback onFocusRequested;

  @override
  State<_EditorSelectionOverlay> createState() =>
      _EditorSelectionOverlayState();
}

class _EditorSelectionOverlayState extends State<_EditorSelectionOverlay> {
  late Future<RhwpLayerTree?> _layerTree;
  RhwpCursorPosition? _dragAnchor;

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
                _handlePointerDown(event.localPosition, constraints, tree);
              },
              onPointerMove: (event) {
                _handlePointerMove(event.localPosition, constraints, tree);
              },
              onPointerUp: (_) {
                _dragAnchor = null;
              },
              onPointerCancel: (_) {
                _dragAnchor = null;
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
    final cursor = _cursorForPoint(localPosition, constraints, tree);
    if (cursor != null) {
      widget.onFocusRequested();
      _dragAnchor = cursor;
      widget.onCursorPosition(cursor);
    }
  }

  void _handlePointerMove(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    final anchor = _dragAnchor;
    final cursor = _cursorForPoint(localPosition, constraints, tree);
    if (anchor != null && cursor != null) {
      widget.onSelectionRange(RhwpSelectionRange(start: anchor, end: cursor));
    }
  }

  RhwpCursorPosition? _cursorForPoint(
    Offset localPosition,
    BoxConstraints constraints,
    RhwpLayerTree? tree,
  ) {
    if (tree != null) {
      final pagePoint = _pagePointFromOverlayPoint(
        localPosition,
        constraints,
        tree,
      );
      final hit = tree.textPositionForPoint(pagePoint, verticalTolerance: 12);
      if (hit != null) {
        return RhwpCursorPosition(
          section: hit.section,
          paragraph: hit.paragraph,
          offset: hit.offset,
        );
      }
    }

    if (widget.fallbackEnabled) {
      return _fallbackCursorFor(localPosition);
    }

    return null;
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
    final caretRect = tree.caretRectFor(
      section: widget.selection.end.section,
      paragraph: widget.selection.end.paragraph,
      offset: widget.selection.end.offset,
    );
    if (caretRect == null) {
      return null;
    }

    final color = Theme.of(context).colorScheme.primary;
    final overlaySize = _overlaySize(constraints, tree);
    final selectionRects = _layerSelectionRects(tree, overlaySize);
    final scaledCaretRect = _scalePageRect(caretRect, tree, overlaySize);

    return Stack(
      children: [
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
        if (widget.composingText != null)
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
    required this.onInsert,
    required this.onDeleteBackward,
    required this.onInsertTable,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onAlignJustify,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final bool busy;
  final Object? error;
  final TextEditingController textController;
  final TextEditingController sectionController;
  final TextEditingController paragraphController;
  final TextEditingController offsetController;
  final TextEditingController tableRowsController;
  final TextEditingController tableColumnsController;
  final VoidCallback onInsert;
  final VoidCallback onDeleteBackward;
  final VoidCallback onInsertTable;
  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onAlignJustify;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  var _activeTab = _EditorTab.edit;

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _NumberField(
                    label: 'Sec',
                    controller: widget.sectionController,
                  ),
                  const SizedBox(width: 6),
                  _NumberField(
                    label: 'Para',
                    controller: widget.paragraphController,
                  ),
                  const SizedBox(width: 6),
                  _NumberField(
                    label: 'Offset',
                    controller: widget.offsetController,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: TextField(
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
                  const _ToolbarDivider(),
                  _NumberField(
                    label: 'Rows',
                    controller: widget.tableRowsController,
                  ),
                  const SizedBox(width: 6),
                  _NumberField(
                    label: 'Cols',
                    controller: widget.tableColumnsController,
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    tooltip: 'Insert table',
                    icon: Icons.table_chart_outlined,
                    onPressed: widget.busy ? null : widget.onInsertTable,
                  ),
                  const _ToolbarDivider(),
                  _ToolbarIconButton(
                    tooltip: 'Open',
                    icon: Icons.folder_open,
                    onPressed: null,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Save',
                    icon: Icons.save_outlined,
                    onPressed: null,
                  ),
                  const _ToolbarDivider(),
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
                  const _ToolbarDivider(),
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
                  const _ToolbarDivider(),
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
                  const _ToolbarDivider(),
                  _ToolbarIconButton(
                    tooltip: 'Zoom out',
                    icon: Icons.zoom_out,
                    onPressed: widget.onZoomOut,
                  ),
                  _ToolbarIconButton(
                    tooltip: 'Zoom in',
                    icon: Icons.zoom_in,
                    onPressed: widget.onZoomIn,
                  ),
                  if (widget.busy) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                  if (widget.error != null) ...[
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        widget.error.toString(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
      _EditorTab.file => 'File',
      _EditorTab.edit => 'Edit',
      _EditorTab.view => 'View',
      _EditorTab.insert => 'Insert',
      _EditorTab.format => 'Format',
      _EditorTab.page => 'Page',
      _EditorTab.table => 'Table',
      _EditorTab.tools => 'Tools',
    };
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
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
  const _EditorStatusBar({required this.selection, required this.busy});

  final RhwpSelectionRange selection;
  final bool busy;

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
              const Text('100%'),
              const SizedBox(width: 12),
            ],
          ),
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
