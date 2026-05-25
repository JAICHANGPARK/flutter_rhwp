import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'rhwp_exception.dart';
import 'rhwp_layer_tree.dart';
import 'rust/api/rhwp.dart' as rust;

/// Supported output formats for document export.
enum RhwpExportFormat { hwp, hwpx, pdf, docx, text, markdown, svg }

/// Save metadata for [RhwpExportFormat] values.
extension RhwpExportFormatMetadata on RhwpExportFormat {
  /// The default file extension without a leading dot.
  String get fileExtension {
    return switch (this) {
      RhwpExportFormat.hwp => 'hwp',
      RhwpExportFormat.hwpx => 'hwpx',
      RhwpExportFormat.pdf => 'pdf',
      RhwpExportFormat.docx => 'docx',
      RhwpExportFormat.text => 'txt',
      RhwpExportFormat.markdown => 'md',
      RhwpExportFormat.svg => 'svg',
    };
  }

  /// The MIME type to use for saves and browser downloads.
  String get mimeType {
    return switch (this) {
      RhwpExportFormat.hwp => 'application/x-hwp',
      RhwpExportFormat.hwpx => 'application/vnd.hancom.hwpx',
      RhwpExportFormat.pdf => 'application/pdf',
      RhwpExportFormat.docx =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      RhwpExportFormat.text => 'text/plain; charset=utf-8',
      RhwpExportFormat.markdown => 'text/markdown; charset=utf-8',
      RhwpExportFormat.svg => 'image/svg+xml',
    };
  }
}

/// Export bytes bundled with metadata needed by save and download UIs.
class RhwpExportedDocument {
  /// Creates an export result from explicit values.
  const RhwpExportedDocument({
    required this.format,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Creates an export result and derives save metadata from [format].
  ///
  /// [sourceFileName] may be a plain file name or a platform path. When [page]
  /// is supplied, the generated file name includes a one-based page suffix such
  /// as `sample-page-1.svg`.
  factory RhwpExportedDocument.fromBytes({
    required RhwpExportFormat format,
    required Uint8List bytes,
    String? sourceFileName,
    int? page,
  }) {
    return RhwpExportedDocument(
      format: format,
      bytes: bytes,
      fileName: defaultFileName(
        format: format,
        sourceFileName: sourceFileName,
        page: page,
      ),
      mimeType: format.mimeType,
    );
  }

  /// The format used to produce [bytes].
  final RhwpExportFormat format;

  /// The exported document bytes.
  final Uint8List bytes;

  /// The suggested file name for save and download prompts.
  final String fileName;

  /// The MIME type for [bytes].
  final String mimeType;

  /// The default save name for [format] and optional source context.
  ///
  /// Empty names, extension-only names, and paths without a usable basename fall
  /// back to `document`.
  static String defaultFileName({
    required RhwpExportFormat format,
    String? sourceFileName,
    int? page,
  }) {
    final baseName = _stem(sourceFileName);
    final pageSuffix = page == null ? '' : '-page-${page + 1}';
    return '$baseName$pageSuffix.${format.fileExtension}';
  }

  static String _stem(String? name) {
    final normalized = (name ?? '').trim().split(RegExp(r'[/\\]')).last;
    if (normalized.isEmpty) {
      return 'document';
    }

    if (normalized.startsWith('.')) {
      return 'document';
    }

    final dot = normalized.lastIndexOf('.');
    final stem = dot < 0 ? normalized : normalized.substring(0, dot);
    final trimmed = stem.trim();
    return trimmed.isEmpty ? 'document' : trimmed;
  }
}

class RhwpDocumentMetadata {
  const RhwpDocumentMetadata({
    required this.pageCount,
    required this.sourceFormat,
    required this.rawJson,
    this.fileName,
    this.raw,
  });

  final int pageCount;
  final String sourceFormat;
  final String? fileName;
  final String rawJson;
  final Map<String, Object?>? raw;
}

abstract class RhwpCommand {
  const RhwpCommand();

  Map<String, Object?> toJson();

  factory RhwpCommand.insertText({
    required int section,
    required int paragraph,
    required int offset,
    required String text,
  }) = RhwpInsertTextCommand;

  factory RhwpCommand.deleteText({
    required int section,
    required int paragraph,
    required int offset,
    required int count,
  }) = RhwpDeleteTextCommand;

  factory RhwpCommand.deleteRange({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
  }) = RhwpDeleteRangeCommand;

  factory RhwpCommand.splitParagraph({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpSplitParagraphCommand;

  factory RhwpCommand.applyCharFormat({
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
  }) = RhwpApplyCharFormatCommand;

  factory RhwpCommand.setFileName(String name) = RhwpSetFileNameCommand;
}

class RhwpInsertTextCommand extends RhwpCommand {
  const RhwpInsertTextCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.text,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertText',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'text': text,
  };
}

class RhwpDeleteTextCommand extends RhwpCommand {
  const RhwpDeleteTextCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.count,
  });

  final int section;
  final int paragraph;
  final int offset;
  final int count;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteText',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'count': count,
  };
}

class RhwpDeleteRangeCommand extends RhwpCommand {
  const RhwpDeleteRangeCommand({
    required this.section,
    required this.startParagraph,
    required this.startOffset,
    required this.endParagraph,
    required this.endOffset,
  });

  final int section;
  final int startParagraph;
  final int startOffset;
  final int endParagraph;
  final int endOffset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteRange',
    'section': section,
    'startParagraph': startParagraph,
    'startOffset': startOffset,
    'endParagraph': endParagraph,
    'endOffset': endOffset,
  };
}

class RhwpSplitParagraphCommand extends RhwpCommand {
  const RhwpSplitParagraphCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'splitParagraph',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpApplyCharFormatCommand extends RhwpCommand {
  const RhwpApplyCharFormatCommand({
    required this.section,
    required this.paragraph,
    required this.startOffset,
    required this.endOffset,
    this.bold,
    this.italic,
    this.underline,
  });

  final int section;
  final int paragraph;
  final int startOffset;
  final int endOffset;
  final bool? bold;
  final bool? italic;
  final bool? underline;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyCharFormat',
    'section': section,
    'paragraph': paragraph,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'properties': {
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
    },
  };
}

class RhwpSetFileNameCommand extends RhwpCommand {
  const RhwpSetFileNameCommand(this.name);

  final String name;

  @override
  Map<String, Object?> toJson() => {'type': 'setFileName', 'name': name};
}

class RhwpDocument {
  RhwpDocument.fromSession(this._session);

  final rust.RhwpSession _session;
  bool _closed = false;

  bool get isClosed => _closed || _session.isDisposed;

  Future<int> get pageCount async {
    _ensureOpen();
    return _session.pageCount();
  }

  Future<RhwpDocumentMetadata> metadata() async {
    _ensureOpen();
    final info = await _session.documentInfo();
    return RhwpDocumentMetadata(
      pageCount: info.pageCount,
      sourceFormat: info.sourceFormat,
      fileName: info.fileName,
      rawJson: info.rawJson,
      raw: _tryDecodeObject(info.rawJson),
    );
  }

  Future<String> renderPageSvg(int page) {
    _ensureOpen();
    _checkPageIndex(page);
    return _session.renderPageSvg(page: page);
  }

  Future<String> pageLayerTree(int page) {
    _ensureOpen();
    _checkPageIndex(page);
    return _session.pageLayerTree(page: page);
  }

  /// Reads and parses the rhwp page layer tree for [page].
  Future<RhwpLayerTree> pageLayerTreeModel(int page) async {
    final json = await pageLayerTree(page);
    return RhwpLayerTree.fromJsonString(page, json);
  }

  Future<String> extractText({int? page}) {
    _ensureOpen();
    _checkOptionalPageIndex(page);
    return _session.extractText(page: page);
  }

  Future<String> extractMarkdown({int? page}) {
    _ensureOpen();
    _checkOptionalPageIndex(page);
    return _session.extractMarkdown(page: page);
  }

  Future<Uint8List> export(RhwpExportFormat format, {int? page}) async {
    _ensureOpen();
    return switch (format) {
      RhwpExportFormat.hwp => await _session.exportHwp(),
      RhwpExportFormat.hwpx => await _session.exportHwpx(),
      RhwpExportFormat.pdf => await _exportPdf(),
      RhwpExportFormat.docx => await _session.exportDocx(),
      RhwpExportFormat.text => Uint8List.fromList(
        utf8.encode(await extractText(page: page)),
      ),
      RhwpExportFormat.markdown => Uint8List.fromList(
        utf8.encode(await extractMarkdown(page: page)),
      ),
      RhwpExportFormat.svg => Uint8List.fromList(
        utf8.encode(await renderPageSvg(page ?? 0)),
      ),
    };
  }

  /// Exports the document with bytes and save metadata.
  ///
  /// This is the preferred API for app save/download flows because it returns a
  /// [RhwpExportedDocument] containing bytes, a suggested file name, and MIME
  /// type. Pass [page] for page-scoped formats such as [RhwpExportFormat.svg].
  ///
  /// Throws [RhwpUnsupportedPlatformException] when the selected [format] is not
  /// supported on the current platform, such as native PDF export on Web/WASM.
  Future<RhwpExportedDocument> exportDocument(
    RhwpExportFormat format, {
    int? page,
    String? sourceFileName,
  }) async {
    _ensureOpen();
    final metadata = await this.metadata();
    final bytes = await export(format, page: page);
    return RhwpExportedDocument.fromBytes(
      format: format,
      bytes: bytes,
      sourceFileName: sourceFileName ?? metadata.fileName,
      page: page,
    );
  }

  Future<Uint8List> exportHwp() => export(RhwpExportFormat.hwp);

  Future<Uint8List> exportHwpx() => export(RhwpExportFormat.hwpx);

  Future<Uint8List> exportPdf() => export(RhwpExportFormat.pdf);

  Future<Uint8List> exportDocx() => export(RhwpExportFormat.docx);

  Future<Uint8List> exportText({int? page}) {
    return export(RhwpExportFormat.text, page: page);
  }

  Future<Uint8List> exportMarkdown({int? page}) {
    return export(RhwpExportFormat.markdown, page: page);
  }

  Future<Uint8List> exportPageSvg({int page = 0}) {
    return export(RhwpExportFormat.svg, page: page);
  }

  Future<String> apply(RhwpCommand command) {
    _ensureOpen();
    return _session.applyCommand(commandJson: jsonEncode(command.toJson()));
  }

  Future<String> insertText({
    required int section,
    required int paragraph,
    required int offset,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertText(
        section: section,
        paragraph: paragraph,
        offset: offset,
        text: text,
      ),
    );
  }

  Future<String> deleteText({
    required int section,
    required int paragraph,
    required int offset,
    required int count,
  }) {
    return apply(
      RhwpCommand.deleteText(
        section: section,
        paragraph: paragraph,
        offset: offset,
        count: count,
      ),
    );
  }

  Future<String> deleteRange({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
  }) {
    return apply(
      RhwpCommand.deleteRange(
        section: section,
        startParagraph: startParagraph,
        startOffset: startOffset,
        endParagraph: endParagraph,
        endOffset: endOffset,
      ),
    );
  }

  Future<String> splitParagraph({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.splitParagraph(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<String> applyCharFormat({
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
  }) {
    return apply(
      RhwpCommand.applyCharFormat(
        section: section,
        paragraph: paragraph,
        startOffset: startOffset,
        endOffset: endOffset,
        bold: bold,
        italic: italic,
        underline: underline,
      ),
    );
  }

  Future<String> setFileName(String name) {
    return apply(RhwpCommand.setFileName(name));
  }

  Future<Uint8List> _exportPdf() {
    if (kIsWeb) {
      throw const RhwpUnsupportedPlatformException(
        'PDF export is not supported on Web/WASM yet.',
      );
    }
    return _session.exportPdf();
  }

  Future<void> close() async {
    if (isClosed) {
      _closed = true;
      return;
    }

    await _session.close();
    _session.dispose();
    _closed = true;
  }

  void _ensureOpen() {
    if (isClosed) {
      throw const RhwpClosedException();
    }
  }

  static void _checkOptionalPageIndex(int? page) {
    if (page != null) {
      _checkPageIndex(page);
    }
  }

  static void _checkPageIndex(int page) {
    if (page < 0) {
      throw RhwpException('Page index must be zero or greater: $page');
    }
  }

  static Map<String, Object?>? _tryDecodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
