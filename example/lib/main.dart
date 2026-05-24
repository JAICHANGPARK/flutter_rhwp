import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class RhwpExampleApp extends StatefulWidget {
  const RhwpExampleApp({super.key, this.autoOpenSample = true});

  final bool autoOpenSample;

  @override
  State<RhwpExampleApp> createState() => _RhwpExampleAppState();
}

class _RhwpExampleAppState extends State<RhwpExampleApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _editorController = RhwpEditorController();
  Key _viewerKey = UniqueKey();
  RhwpDocument? _document;
  RhwpDocumentMetadata? _metadata;
  Uint8List? _sourceBytes;
  Object? _error;
  String? _fileName;
  String? _status;
  _EditorMode _editorMode = _EditorMode.flutterBridge;
  bool _busy = false;

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
    super.dispose();
  }

  Future<void> _createBlankDocument() async {
    await _run('New document', () async {
      final next = await Rhwp.createEmpty(fileName: 'blank.hwp');
      final bytes = await next.exportHwp();
      await _replaceDocument(next, fileName: 'blank.hwp', sourceBytes: bytes);
      return 'Created blank.hwp';
    });
  }

  Future<void> _openSampleDocument() async {
    await _run('Open sample asset', () async {
      final data = await rootBundle.load(_sampleAssetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final next = await Rhwp.open(bytes, fileName: _sampleFileName);
      await _replaceDocument(
        next,
        fileName: _sampleFileName,
        sourceBytes: bytes,
      );
      return 'Opened bundled sample';
    });
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
      final next = await Rhwp.open(bytes, fileName: file.name);
      await _replaceDocument(next, fileName: file.name, sourceBytes: bytes);
      return 'Opened ${file.name}';
    });
  }

  Future<void> _saveExport(_ExportKind kind) async {
    final document = _document;
    if (document == null) {
      _showStatus('No document is open');
      return;
    }

    await _run('Export ${kind.extension.toUpperCase()}', () async {
      final bytes = await _bytesFor(document, kind);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save ${kind.label}',
        fileName: _defaultExportName(kind),
        type: FileType.custom,
        allowedExtensions: [kind.extension],
        bytes: bytes,
      );

      if (path == null) {
        return 'Started ${kind.label} download';
      }
      return 'Saved $path';
    });
  }

  Future<void> _insertDemoText() async {
    final document = _document;
    if (document == null) {
      _showStatus('No document is open');
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

  Future<Uint8List> _bytesFor(RhwpDocument document, _ExportKind kind) async {
    return switch (kind) {
      _ExportKind.hwp => document.export(RhwpExportFormat.hwp),
      _ExportKind.hwpx => document.export(RhwpExportFormat.hwpx),
      _ExportKind.pdf => document.export(RhwpExportFormat.pdf),
      _ExportKind.docx => document.export(RhwpExportFormat.docx),
      _ExportKind.text => document.export(RhwpExportFormat.text),
      _ExportKind.markdown => document.export(RhwpExportFormat.markdown),
      _ExportKind.svg => document.export(RhwpExportFormat.svg),
    };
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

  void _setEditorMode(_EditorMode mode) {
    if (mode == _editorMode) {
      return;
    }
    if (mode == _EditorMode.upstreamWeb && !kIsWeb) {
      _showStatus('The upstream rhwp Web editor is only available on Web');
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

  String _defaultExportName(_ExportKind kind) {
    final baseName = _stem(_fileName ?? 'document');
    return '$baseName.${kind.extension}';
  }

  String _stem(String name) {
    final normalized = name.split(RegExp(r'[/\\]')).last;
    final dot = normalized.lastIndexOf('.');
    if (dot <= 0) {
      return normalized;
    }
    return normalized.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;

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
              tooltip: 'Insert text',
              onPressed: _busy || document == null ? null : _insertDemoText,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<_ExportKind>(
              tooltip: 'Export',
              enabled: !_busy && document != null,
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
              onEditorModeChanged: kIsWeb && !_busy ? _setEditorMode : null,
            ),
            Expanded(
              child: _busy && document == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && document == null
                  ? Center(child: Text(_error.toString()))
                  : document == null
                  ? const SizedBox.shrink()
                  : kIsWeb && _editorMode == _EditorMode.upstreamWeb
                  ? RhwpWebEditor(
                      key: ValueKey(
                        'web-editor-${_fileName ?? 'document'}-${_sourceBytes?.length ?? 0}-${_viewerKey.hashCode}',
                      ),
                      moduleUrl: _webEditorModuleUrl,
                      initialBytes: _sourceBytes,
                      fileName: _fileName,
                    )
                  : RhwpEditor(
                      key: _viewerKey,
                      document: document,
                      controller: _editorController,
                      onChanged: (_) async {
                        final metadata = await document.metadata();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _metadata = metadata;
                        });
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
                      value: _EditorMode.flutterBridge,
                      icon: Icon(Icons.integration_instructions_outlined),
                      label: Text('Flutter'),
                    ),
                    ButtonSegment(
                      value: _EditorMode.upstreamWeb,
                      icon: Icon(Icons.web_asset_outlined),
                      label: Text('Web editor'),
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
  hwp('HWP', 'hwp'),
  hwpx('HWPX', 'hwpx'),
  pdf('PDF', 'pdf'),
  docx('DOCX', 'docx'),
  svg('SVG', 'svg'),
  text('text', 'txt'),
  markdown('Markdown', 'md');

  const _ExportKind(this.label, this.extension);

  final String label;
  final String extension;
}

enum _EditorMode { flutterBridge, upstreamWeb }
