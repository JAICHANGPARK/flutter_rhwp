import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'src/local_file_writer.dart';

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
typedef RhwpExampleSaveFile =
    Future<String?> Function({
      required RhwpExportedDocument exported,
      required String dialogTitle,
      required List<String> allowedExtensions,
    });

enum _UnsavedChangesDecision { save, discard, cancel }

class _WriteExportedDocumentResult {
  const _WriteExportedDocumentResult({
    required this.status,
    required this.completed,
    this.path,
  });

  final String status;
  final bool completed;
  final String? path;
}

class RhwpExampleApp extends StatefulWidget {
  const RhwpExampleApp({
    super.key,
    this.controller,
    this.autoOpenSample = true,
    this.startInNativeEditor = false,
    this.initialDocument,
    this.initialFileName,
    this.initialSourceBytes,
    this.initialFilePath,
    this.webEditorModuleUrl = _webEditorModuleUrl,
    this.sampleBytesLoader,
    this.saveFile,
  });

  final RhwpExampleAppController? controller;
  final bool autoOpenSample;
  final bool startInNativeEditor;
  final RhwpDocument? initialDocument;
  final String? initialFileName;
  final Uint8List? initialSourceBytes;
  final String? initialFilePath;
  final String webEditorModuleUrl;
  final RhwpSampleBytesLoader? sampleBytesLoader;
  final RhwpExampleSaveFile? saveFile;

  @override
  State<RhwpExampleApp> createState() => _RhwpExampleAppState();
}

class RhwpExampleAppController {
  _RhwpExampleAppState? _state;

  bool get isAttached => _state != null;

  bool get usesFullEditor => _state?._usesFullEditor ?? false;

  bool get hasDocument => _state?._document != null;

  Object? get error => _state?._error;

  String? get status => _state?._status;

  Future<void> saveAsHwp() {
    return _state?._saveExport(_ExportKind.hwp) ?? Future<void>.value();
  }

  Future<void> saveAsHwpx() {
    return _state?._saveExport(_ExportKind.hwpx) ?? Future<void>.value();
  }

  void _attach(_RhwpExampleAppState state) {
    _state = state;
  }

  void _detach(_RhwpExampleAppState state) {
    if (_state == state) {
      _state = null;
    }
  }
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
  String? _filePath;
  String? _status;
  late _EditorMode _editorMode;
  bool _busy = false;
  bool _documentDirty = false;

  bool get _usesFullEditor => _editorMode == _EditorMode.fullEditor;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _editorMode = widget.startInNativeEditor || !_supportsFullEditorHost
        ? _EditorMode.nativeEditor
        : _EditorMode.fullEditor;
    final initialDocument = widget.initialDocument;
    if (initialDocument != null) {
      _document = initialDocument;
      _sourceBytes = widget.initialSourceBytes;
      _fileName = widget.initialFileName;
      _filePath = widget.initialFilePath;
      _loadInitialDocumentMetadata(initialDocument);
    } else if (widget.autoOpenSample) {
      _openSampleDocument();
    }
  }

  Future<void> _loadInitialDocumentMetadata(RhwpDocument document) async {
    try {
      final metadata = await document.metadata();
      if (!mounted || _document != document) {
        return;
      }
      setState(() {
        _metadata = metadata;
        _fileName ??= metadata.fileName;
      });
    } catch (error) {
      if (!mounted || _document != document) {
        return;
      }
      setState(() {
        _error = error;
        _status = 'Failed';
      });
    }
  }

  @override
  void didUpdateWidget(covariant RhwpExampleApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _document?.close();
    _editorController.dispose();
    _fullEditorController.dispose();
    super.dispose();
  }

  Future<void> _createBlankDocument() async {
    if (!await _confirmUnsavedChanges(RhwpEditorFileAction.newDocument)) {
      return;
    }
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
    if (!await _confirmUnsavedChanges(RhwpEditorFileAction.openDocument)) {
      return;
    }
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
    if (!await _confirmUnsavedChanges(RhwpEditorFileAction.openDocument)) {
      return;
    }
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
        await _replaceWebEditorSource(
          fileName: file.name,
          sourceBytes: bytes,
          filePath: file.path,
        );
        return 'Opened ${file.name} in full editor';
      }

      final next = await Rhwp.open(bytes, fileName: file.name);
      await _replaceDocument(
        next,
        fileName: file.name,
        sourceBytes: bytes,
        filePath: file.path,
      );
      return 'Opened ${file.name}';
    });
  }

  Future<void> _closeDocument() async {
    if (!await _confirmUnsavedChanges(RhwpEditorFileAction.closeDocument)) {
      return;
    }
    await _run('Close document', () async {
      final previous = _document;
      setState(() {
        _document = null;
        _metadata = null;
        _sourceBytes = null;
        _fileName = null;
        _filePath = null;
        _documentDirty = false;
        _viewerKey = UniqueKey();
      });
      _editorController.markClean();
      _fullEditorController.markClean();
      await previous?.close();
      return 'Closed document';
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
      final intent = kind.isPrimaryDocument
          ? RhwpExportIntent.saveAs
          : RhwpExportIntent.export;
      final exported = await _exportFor(
        kind,
        document: document,
        intent: intent,
      );
      final status = await _writeExportedDocument(
        exported,
        dialogLabel: kind.label,
      );
      if (status.completed && kind.isPrimaryDocument) {
        await _recordSavedDocument(exported, status);
      }
      return status.status;
    });
  }

  Future<void> _saveEditorExport(RhwpExportedDocument exported) async {
    await _run('Save ${exported.fileName}', () async {
      final result = await _writeExportedDocument(
        exported,
        currentPath: exported.intent == RhwpExportIntent.save
            ? _filePath
            : null,
      );
      if (result.completed && exported.format.isPrimaryDocument) {
        await _recordSavedDocument(exported, result);
      }
      return result.status;
    });
  }

  Future<bool> _confirmUnsavedChanges(RhwpEditorFileAction action) async {
    if (!_documentDirty &&
        !_editorController.dirty &&
        !_fullEditorController.dirty) {
      return true;
    }

    final decision = await showDialog<_UnsavedChangesDecision>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content: Text(
          'The current document has unsaved changes. Save before ${_fileActionLabel(action)}?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('rhwp-unsaved-cancel'),
            onPressed: () =>
                Navigator.of(context).pop(_UnsavedChangesDecision.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('rhwp-unsaved-discard'),
            onPressed: () =>
                Navigator.of(context).pop(_UnsavedChangesDecision.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey('rhwp-unsaved-save'),
            onPressed: () =>
                Navigator.of(context).pop(_UnsavedChangesDecision.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return false;
    }

    return switch (decision) {
      _UnsavedChangesDecision.save => _saveCurrentDocumentBeforeFileAction(),
      _UnsavedChangesDecision.discard => _discardCurrentDocumentChanges(),
      _UnsavedChangesDecision.cancel || null => false,
    };
  }

  String _fileActionLabel(RhwpEditorFileAction action) {
    return switch (action) {
      RhwpEditorFileAction.newDocument => 'creating a new document',
      RhwpEditorFileAction.openDocument => 'opening another document',
      RhwpEditorFileAction.closeDocument => 'closing the document',
    };
  }

  _ExportKind _currentPrimaryExportKind() {
    return _currentPrimaryExportKindForName(_fileName);
  }

  Future<bool> _saveCurrentDocumentBeforeFileAction() async {
    try {
      final saveKind = _currentPrimaryExportKind();
      final exported = await _exportFor(
        saveKind,
        document: _document,
        intent: RhwpExportIntent.save,
      );
      final result = await _writeExportedDocument(
        exported,
        dialogLabel: saveKind.label,
        currentPath: _filePath,
      );
      if (!mounted) {
        return false;
      }
      _showStatus(result.status);
      if (!result.completed) {
        return false;
      }
      await _recordSavedDocument(exported, result);
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _error = error;
        _status = 'Failed';
      });
      _showStatus(error.toString());
      return false;
    }
  }

  bool _discardCurrentDocumentChanges() {
    setState(() {
      _documentDirty = false;
    });
    _editorController.markClean();
    _fullEditorController.markClean();
    return true;
  }

  Future<void> _printEditorDocument(RhwpExportedDocument exported) async {
    await _run('Print ${exported.fileName}', () async {
      final result = await _writeExportedDocument(
        exported,
        dialogLabel: 'Print PDF',
      );
      return result.status;
    });
  }

  Future<_WriteExportedDocumentResult> _writeExportedDocument(
    RhwpExportedDocument exported, {
    String? dialogLabel,
    String? currentPath,
  }) async {
    final targetPath = currentPath?.trim();
    if (exported.intent == RhwpExportIntent.save &&
        supportsLocalFileWrite &&
        targetPath != null &&
        targetPath.isNotEmpty) {
      await writeLocalFile(targetPath, exported.bytes);
      return _WriteExportedDocumentResult(
        status: 'Saved $targetPath',
        completed: true,
        path: targetPath,
      );
    }

    final dialogTitle =
        '${exported.intent.dialogTitleVerb} ${dialogLabel ?? exported.format.fileExtension.toUpperCase()}';
    final allowedExtensions = [exported.format.fileExtension];
    final saveFile = widget.saveFile;
    final path = saveFile == null
        ? await FilePicker.saveFile(
            dialogTitle: dialogTitle,
            fileName: exported.fileName,
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
            bytes: exported.bytes,
          )
        : await saveFile(
            exported: exported,
            dialogTitle: dialogTitle,
            allowedExtensions: allowedExtensions,
          );

    if (path == null) {
      if (kIsWeb) {
        return _WriteExportedDocumentResult(
          status: 'Started ${exported.fileName} download',
          completed: true,
        );
      }
      return const _WriteExportedDocumentResult(
        status: 'Save cancelled',
        completed: false,
      );
    }
    return _WriteExportedDocumentResult(
      status: 'Saved $path',
      completed: true,
      path: path,
    );
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
      return 'Inserted text at section 0, paragraph 0';
    });
  }

  Future<RhwpExportedDocument> _exportFor(
    _ExportKind kind, {
    required RhwpDocument? document,
    RhwpExportIntent intent = RhwpExportIntent.export,
  }) async {
    if (_usesFullEditor) {
      return _fullEditorController.exportDocument(
        kind.format,
        sourceFileName: _fileName,
        page: kind.defaultPage,
        intent: intent,
      );
    }
    if (document == null) {
      throw StateError('No document is open');
    }
    return document.exportDocument(
      kind.format,
      sourceFileName: _fileName,
      page: kind.defaultPage,
      intent: intent,
    );
  }

  Future<void> _replaceDocument(
    RhwpDocument next, {
    required String fileName,
    Uint8List? sourceBytes,
    String? filePath,
    bool dirty = false,
  }) async {
    final previous = _document;
    final metadata = await next.metadata();
    setState(() {
      _document = next;
      _metadata = metadata;
      _sourceBytes = sourceBytes;
      _fileName = fileName;
      _filePath = filePath;
      _documentDirty = dirty;
      _viewerKey = UniqueKey();
    });
    _editorController.dirty = dirty;
    _fullEditorController.markClean();
    await previous?.close();
  }

  Future<void> _replaceWebEditorSource({
    required String fileName,
    Uint8List? sourceBytes,
    String? filePath,
    bool dirty = false,
  }) async {
    final previous = _document;
    setState(() {
      _document = null;
      _metadata = null;
      _sourceBytes = sourceBytes;
      _fileName = fileName;
      _filePath = filePath;
      _documentDirty = dirty;
      _viewerKey = UniqueKey();
    });
    _editorController.dirty = dirty;
    _fullEditorController.dirty = dirty;
    await previous?.close();
  }

  Future<void> _recordSavedDocument(
    RhwpExportedDocument exported,
    _WriteExportedDocumentResult result,
  ) async {
    final savedFileName = _fileNameFromPath(result.path) ?? exported.fileName;
    final document = _document;
    var sourceBytes = exported.bytes;
    RhwpDocumentMetadata? metadata;

    if (document != null && exported.format.isPrimaryDocument) {
      final currentMetadata = await document.metadata();
      if (currentMetadata.fileName != savedFileName) {
        await document.setFileName(savedFileName);
      }
      metadata = await document.metadata();
      if (widget.saveFile == null &&
          result.path != null &&
          supportsLocalFileWrite) {
        final updatedExport = await document.exportDocument(
          exported.format,
          sourceFileName: savedFileName,
          intent: RhwpExportIntent.save,
        );
        sourceBytes = updatedExport.bytes;
        await writeLocalFile(result.path!, sourceBytes);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _metadata = metadata ?? _metadata;
      _sourceBytes = sourceBytes;
      _fileName = savedFileName;
      _filePath = result.path ?? _filePath;
      _documentDirty = false;
    });
    _editorController.markClean();
    _fullEditorController.markClean();
  }

  Future<Uint8List> _sourceBytesForNativeEditor() async {
    if (_usesFullEditor && _fullEditorController.isAttached) {
      final exported = await _fullEditorController.exportDocument(
        RhwpExportFormat.hwp,
        sourceFileName: _fileName,
      );
      return exported.bytes;
    }

    final sourceBytes = _sourceBytes;
    if (sourceBytes == null) {
      throw StateError('No HWP/HWPX bytes are available for native editor');
    }
    return sourceBytes;
  }

  Future<void> _setEditorMode(_EditorMode mode) async {
    if (mode == _editorMode) {
      return;
    }
    if (mode == _EditorMode.fullEditor && !_supportsFullEditorHost) {
      _showStatus('The rhwp full editor is not available on this platform');
      return;
    }

    final nativeDocument = _document;
    if (mode == _EditorMode.fullEditor && nativeDocument != null) {
      await _run('Open full editor', () async {
        final dirty =
            _documentDirty ||
            _editorController.dirty ||
            _fullEditorController.dirty;
        final sourceBytes = await nativeDocument.exportHwp();
        await _replaceWebEditorSource(
          fileName: _fileName ?? 'document.hwp',
          sourceBytes: sourceBytes,
          dirty: dirty,
        );
        setState(() {
          _editorMode = mode;
        });
        return 'Switched to full editor';
      });
      return;
    }

    if (mode == _EditorMode.nativeEditor &&
        _document == null &&
        _sourceBytes == null &&
        !_fullEditorController.isAttached) {
      _showStatus('Open a HWP/HWPX file before switching to native editor');
      return;
    }

    if (mode == _EditorMode.nativeEditor && _document == null) {
      await _run('Open native editor', () async {
        final sourceBytes = await _sourceBytesForNativeEditor();
        final dirty = _documentDirty || _fullEditorController.dirty;
        final next = await Rhwp.open(
          sourceBytes,
          fileName: _fileName ?? 'document.hwp',
        );
        await _replaceDocument(
          next,
          fileName: _fileName ?? 'document.hwp',
          sourceBytes: sourceBytes,
          dirty: dirty,
        );
        setState(() {
          _editorMode = mode;
        });
        return 'Switched to native editor';
      });
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
              dirty: _documentDirty,
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
                      onDirtyChanged: (dirty) {
                        setState(() {
                          _documentDirty = dirty;
                        });
                      },
                    )
                  : document == null
                  ? const SizedBox.shrink()
                  : RhwpNativeEditor(
                      key: _viewerKey,
                      document: document,
                      controller: _editorController,
                      editRefreshDelay: const Duration(seconds: 5),
                      holdTextRefreshWhileFocused: true,
                      onNewRequested: _busy ? null : _createBlankDocument,
                      onOpenRequested: _busy ? null : _openDocument,
                      onCloseRequested: _busy ? null : _closeDocument,
                      onUnsavedChanges: _confirmUnsavedChanges,
                      onImageRequested: _busy ? null : _pickEditorImage,
                      onExported: _busy ? null : _saveEditorExport,
                      onPrintRequested: _busy ? null : _printEditorDocument,
                      onDirtyChanged: (dirty) {
                        setState(() {
                          _documentDirty = dirty;
                        });
                      },
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
    required this.dirty,
    required this.status,
    required this.error,
    required this.editorMode,
    required this.onEditorModeChanged,
  });

  final bool busy;
  final String? fileName;
  final RhwpDocumentMetadata? metadata;
  final bool dirty;
  final String? status;
  final Object? error;
  final _EditorMode editorMode;
  final ValueChanged<_EditorMode>? onEditorModeChanged;

  @override
  Widget build(BuildContext context) {
    final text = [
      '${fileName ?? 'No file'}${dirty ? ' *' : ''}',
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

  bool get isPrimaryDocument => format.isPrimaryDocument;
}

enum _EditorMode { nativeEditor, fullEditor }

_ExportKind _currentPrimaryExportKindForName(String? fileName) {
  final normalized = fileName?.trim().toLowerCase() ?? '';
  return normalized.endsWith('.hwpx') ? _ExportKind.hwpx : _ExportKind.hwp;
}

extension on RhwpExportFormat {
  bool get isPrimaryDocument {
    return this == RhwpExportFormat.hwp || this == RhwpExportFormat.hwpx;
  }
}

extension on RhwpExportIntent {
  String get dialogTitleVerb {
    return switch (this) {
      RhwpExportIntent.save => 'Save',
      RhwpExportIntent.saveAs => 'Save As',
      RhwpExportIntent.export => 'Export',
    };
  }
}

String? _fileNameFromPath(String? path) {
  final trimmed = path?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final fileName = trimmed.split(RegExp(r'[/\\]')).last.trim();
  return fileName.isEmpty ? null : fileName;
}
