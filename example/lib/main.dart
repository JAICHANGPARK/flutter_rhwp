import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const RhwpExampleApp());
}

const _sampleAssetPath = 'assets/korea_ai_action_plan_2026_2028.hwp';
const _sampleFileName = 'korea_ai_action_plan_2026_2028.hwp';
const _webEditorModuleUrl = String.fromEnvironment(
  'RHWP_EDITOR_MODULE_URL',
  defaultValue: RhwpWebEditor.defaultModuleUrl,
);

bool get _supportsFullEditorHost {
  if (kIsWeb) {
    return true;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    TargetPlatform.fuchsia => false,
  };
}

typedef RhwpSampleBytesLoader = Future<Uint8List> Function();

class RhwpExampleApp extends StatefulWidget {
  const RhwpExampleApp({
    super.key,
    this.autoOpenSample = true,
    this.webEditorModuleUrl = _webEditorModuleUrl,
    this.sampleBytesLoader,
  });

  final bool autoOpenSample;
  final String webEditorModuleUrl;
  final RhwpSampleBytesLoader? sampleBytesLoader;

  @override
  State<RhwpExampleApp> createState() => _RhwpExampleAppState();
}

class _RhwpExampleAppState extends State<RhwpExampleApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _editorController = RhwpEditorController();
  final _fullEditorController = RhwpFullEditorController();
  Key _viewerKey = UniqueKey();
  RhwpDocument? _document;
  RhwpDocumentMetadata? _metadata;
  Uint8List? _sourceBytes;
  Object? _error;
  String? _fileName;
  String? _status;
  _EditorMode _editorMode = _supportsFullEditorHost
      ? _EditorMode.fullEditor
      : _EditorMode.nativeEditor;
  bool _busy = false;

  bool get _usesFullEditor => _editorMode == _EditorMode.fullEditor;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenSample) {
      _openSampleDocument();
    }
  }

  @override
  void dispose() {
    _document?.close();
    _editorController.dispose();
    _fullEditorController.dispose();
    super.dispose();
  }

  Future<void> _createBlankDocument() async {
    await _run('New document', () async {
      if (_usesFullEditor) {
        await _replaceWebEditorSource(fileName: 'blank.hwp');
        return 'Created blank.hwp in full editor';
      }

      final next = await Rhwp.createEmpty(fileName: 'blank.hwp');
      final bytes = await next.exportHwp();
      await _replaceDocument(next, fileName: 'blank.hwp', sourceBytes: bytes);
      return 'Created blank.hwp';
    });
  }

  Future<void> _openSampleDocument() async {
    await _run('Open sample asset', () async {
      final bytes = await _loadSampleBytes();
      if (_usesFullEditor) {
        await _replaceWebEditorSource(
          fileName: _sampleFileName,
          sourceBytes: bytes,
        );
        return 'Opened bundled sample in full editor';
      }

      final next = await Rhwp.open(bytes, fileName: _sampleFileName);
      await _replaceDocument(
        next,
        fileName: _sampleFileName,
        sourceBytes: bytes,
      );
      return 'Opened bundled sample';
    });
  }

  Future<Uint8List> _loadSampleBytes() async {
    final loader = widget.sampleBytesLoader;
    if (loader != null) {
      return loader();
    }

    final data = await rootBundle.load(_sampleAssetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _openDocument() async {
    await _run('Open document', () async {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Open HWP/HWPX',
        type: FileType.custom,
        allowedExtensions: const ['hwp', 'hwpx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.single;
      final bytes = await file.xFile.readAsBytes();
      if (_usesFullEditor) {
        await _replaceWebEditorSource(fileName: file.name, sourceBytes: bytes);
        return 'Opened ${file.name} in full editor';
      }

      final next = await Rhwp.open(bytes, fileName: file.name);
      await _replaceDocument(next, fileName: file.name, sourceBytes: bytes);
      return 'Opened ${file.name}';
    });
  }

  Future<RhwpEditorImage?> _pickEditorImage() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Insert picture',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = await file.xFile.readAsBytes();
    final extension = file.extension ?? file.name.split('.').last;
    return RhwpEditorImage(
      bytes: bytes,
      extension: extension,
      description: file.name,
    );
  }

  Future<void> _saveExport(_ExportKind kind) async {
    final document = _document;
    if (document == null && !_usesFullEditor) {
      _showStatus('No document is open');
      return;
    }

    await _run('Export ${kind.extension.toUpperCase()}', () async {
      final exported = await _exportFor(kind, document: document);
      return _writeExportedDocument(exported, dialogLabel: kind.label);
    });
  }

  Future<void> _saveEditorExport(RhwpExportedDocument exported) async {
    await _run('Save ${exported.fileName}', () {
      return _writeExportedDocument(exported);
    });
  }

  Future<String> _writeExportedDocument(
    RhwpExportedDocument exported, {
    String? dialogLabel,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle:
          'Save ${dialogLabel ?? exported.format.fileExtension.toUpperCase()}',
      fileName: exported.fileName,
      type: FileType.custom,
      allowedExtensions: [exported.format.fileExtension],
      bytes: exported.bytes,
    );

    if (path == null) {
      return 'Started ${exported.fileName} download';
    }
    return 'Saved $path';
  }

  Future<void> _insertDemoText() async {
    final document = _document;
    if (document == null) {
      _showStatus(
        _usesFullEditor
            ? 'Use the full editor toolbar for direct edits'
            : 'No document is open',
      );
      return;
    }

    await _run('Insert text', () async {
      await document.insertText(
        section: 0,
        paragraph: 0,
        offset: 0,
        text: 'flutter_rhwp ',
      );
      _viewerKey = UniqueKey();
      _metadata = await document.metadata();
      _sourceBytes = await document.exportHwp();
      return 'Inserted text at section 0, paragraph 0';
    });
  }

  Future<RhwpExportedDocument> _exportFor(
    _ExportKind kind, {
    required RhwpDocument? document,
  }) async {
    if (_usesFullEditor) {
      return _fullEditorController.exportDocument(
        kind.format,
        sourceFileName: _fileName,
        page: kind.defaultPage,
      );
    }
    if (document == null) {
      throw StateError('No document is open');
    }
    return document.exportDocument(
      kind.format,
      sourceFileName: _fileName,
      page: kind.defaultPage,
    );
  }

  Future<void> _replaceDocument(
    RhwpDocument next, {
    required String fileName,
    Uint8List? sourceBytes,
  }) async {
    final previous = _document;
    final metadata = await next.metadata();
    setState(() {
      _document = next;
      _metadata = metadata;
      _sourceBytes = sourceBytes;
      _fileName = fileName;
      _viewerKey = UniqueKey();
    });
    await previous?.close();
  }

  Future<void> _replaceWebEditorSource({
    required String fileName,
    Uint8List? sourceBytes,
  }) async {
    final previous = _document;
    setState(() {
      _document = null;
      _metadata = null;
      _sourceBytes = sourceBytes;
      _fileName = fileName;
      _viewerKey = UniqueKey();
    });
    await previous?.close();
  }

  Future<void> _setEditorMode(_EditorMode mode) async {
    if (mode == _editorMode) {
      return;
    }
    if (mode == _EditorMode.fullEditor && !_supportsFullEditorHost) {
      _showStatus('The rhwp full editor is not available on this platform');
      return;
    }

    final sourceBytes = _sourceBytes;
    if (mode == _EditorMode.nativeEditor &&
        _document == null &&
        sourceBytes != null) {
      await _run('Open native editor', () async {
        final next = await Rhwp.open(
          sourceBytes,
          fileName: _fileName ?? 'document.hwp',
        );
        await _replaceDocument(
          next,
          fileName: _fileName ?? 'document.hwp',
          sourceBytes: sourceBytes,
        );
        setState(() {
          _editorMode = mode;
        });
        return 'Switched to native editor';
      });
      return;
    }

    if (mode == _EditorMode.nativeEditor && _document == null) {
      _showStatus('Open a HWP/HWPX file before switching to native editor');
      return;
    }

    setState(() {
      _editorMode = mode;
    });
  }

  Future<void> _run(String label, Future<String?> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = label;
    });

    try {
      final status = await task();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = status ?? 'Ready';
      });
      if (status != null) {
        _showStatus(status);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error;
        _status = 'Failed';
      });
      _showStatus(error.toString());
    }
  }

  void _showStatus(String message) {
    if (!mounted) {
      return;
    }
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final canShowWebEditor =
        _usesFullEditor && (_fileName != null || _sourceBytes != null);
    final canExport = document != null || canShowWebEditor;

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_rhwp'),
          actions: [
            IconButton(
              tooltip: 'Open bundled sample',
              onPressed: _busy ? null : _openSampleDocument,
              icon: const Icon(Icons.article_outlined),
            ),
            IconButton(
              tooltip: 'Open',
              onPressed: _busy ? null : _openDocument,
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: 'New',
              onPressed: _busy ? null : _createBlankDocument,
              icon: const Icon(Icons.note_add_outlined),
            ),
            IconButton(
              tooltip: 'Insert text command',
              onPressed: _busy || document == null ? null : _insertDemoText,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<_ExportKind>(
              tooltip: 'Export',
              enabled: !_busy && canExport,
              icon: const Icon(Icons.ios_share),
              onSelected: _saveExport,
              itemBuilder: (context) => const [
                PopupMenuItem(value: _ExportKind.hwp, child: Text('HWP')),
                PopupMenuItem(value: _ExportKind.hwpx, child: Text('HWPX')),
                PopupMenuItem(value: _ExportKind.pdf, child: Text('PDF')),
                PopupMenuItem(value: _ExportKind.docx, child: Text('DOCX')),
                PopupMenuItem(value: _ExportKind.svg, child: Text('SVG')),
                PopupMenuItem(value: _ExportKind.text, child: Text('Text')),
                PopupMenuItem(
                  value: _ExportKind.markdown,
                  child: Text('Markdown'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: _editorController.zoomOut,
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: _editorController.zoomIn,
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
        body: Column(
          children: [
            _StatusBar(
              busy: _busy,
              fileName: _fileName,
              metadata: _metadata,
              status: _status,
              error: _error,
              editorMode: _editorMode,
              onEditorModeChanged: _supportsFullEditorHost && !_busy
                  ? _setEditorMode
                  : null,
            ),
            Expanded(
              child: _busy && !canExport
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && !canExport
                  ? Center(child: Text(_error.toString()))
                  : canShowWebEditor
                  ? RhwpFullEditor(
                      key: ValueKey(
                        'full-editor-${_fileName ?? 'document'}-${_sourceBytes?.length ?? 0}-${_viewerKey.hashCode}',
                      ),
                      controller: _fullEditorController,
                      moduleUrl: widget.webEditorModuleUrl,
                      initialBytes: _sourceBytes,
                      fileName: _fileName,
                    )
                  : document == null
                  ? const SizedBox.shrink()
                  : RhwpNativeEditor(
                      key: _viewerKey,
                      document: document,
                      controller: _editorController,
                      editRefreshDelay: const Duration(milliseconds: 1200),
                      onOpenRequested: _busy ? null : _openDocument,
                      onImageRequested: _busy ? null : _pickEditorImage,
                      onExported: _busy ? null : _saveEditorExport,
                      onChanged: (_) async {
                        final metadata = await document.metadata();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _metadata = metadata;
                        });
                        try {
                          final bytes = await document.exportHwp();
                          if (mounted) {
                            setState(() {
                              _sourceBytes = bytes;
                            });
                          }
                        } catch (_) {
                          // Keep editing responsive even if snapshot export is
                          // unavailable for the current document state.
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.busy,
    required this.fileName,
    required this.metadata,
    required this.status,
    required this.error,
    required this.editorMode,
    required this.onEditorModeChanged,
  });

  final bool busy;
  final String? fileName;
  final RhwpDocumentMetadata? metadata;
  final String? status;
  final Object? error;
  final _EditorMode editorMode;
  final ValueChanged<_EditorMode>? onEditorModeChanged;

  @override
  Widget build(BuildContext context) {
    final text = [
      fileName ?? 'No file',
      if (metadata != null) '${metadata!.pageCount} page(s)',
      if (metadata != null) metadata!.sourceFormat.toUpperCase(),
      if (error != null) 'Error',
      ?status,
    ].join('  |  ');

    return Material(
      color: error == null ? const Color(0xfff8fafc) : const Color(0xfffffbfa),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onEditorModeChanged != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SegmentedButton<_EditorMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _EditorMode.nativeEditor,
                      icon: Icon(Icons.integration_instructions_outlined),
                      label: Text('Native editor'),
                    ),
                    ButtonSegment(
                      value: _EditorMode.fullEditor,
                      icon: Icon(Icons.web_asset_outlined),
                      label: Text('Full editor'),
                    ),
                  ],
                  selected: {editorMode},
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      onEditorModeChanged!(selected.first);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ExportKind {
  hwp('HWP', RhwpExportFormat.hwp),
  hwpx('HWPX', RhwpExportFormat.hwpx),
  pdf('PDF', RhwpExportFormat.pdf),
  docx('DOCX', RhwpExportFormat.docx),
  svg('SVG', RhwpExportFormat.svg, defaultPage: 0),
  text('text', RhwpExportFormat.text),
  markdown('Markdown', RhwpExportFormat.markdown);

  const _ExportKind(this.label, this.format, {this.defaultPage});

  final String label;
  final RhwpExportFormat format;
  final int? defaultPage;

  String get extension => format.fileExtension;
}

enum _EditorMode { nativeEditor, fullEditor }
