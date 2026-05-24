import 'package:flutter/material.dart';

import 'rhwp_document.dart';
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

  RhwpCursorPosition copyWith({int? section, int? paragraph, int? offset}) {
    return RhwpCursorPosition(
      section: section ?? this.section,
      paragraph: paragraph ?? this.paragraph,
      offset: offset ?? this.offset,
    );
  }
}

class RhwpEditorController extends RhwpViewerController {
  RhwpEditorController({super.zoom}) : _cursor = const RhwpCursorPosition();

  RhwpCursorPosition _cursor;

  RhwpCursorPosition get cursor => _cursor;

  set cursor(RhwpCursorPosition value) {
    if (value.section == _cursor.section &&
        value.paragraph == _cursor.paragraph &&
        value.offset == _cursor.offset) {
      return;
    }
    _cursor = value;
    notifyListeners();
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
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RhwpEditorController();
    _controller.addListener(_syncCursorFields);
    _syncCursorFields();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncCursorFields);
    if (_ownsController) {
      _controller.dispose();
    }
    _textController.dispose();
    _sectionController.dispose();
    _paragraphController.dispose();
    _offsetController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RhwpViewer(
          key: _viewerKey,
          document: widget.document,
          controller: _controller,
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
