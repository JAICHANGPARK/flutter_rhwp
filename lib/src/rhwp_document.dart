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

/// Z-order operations for selected object/control editing.
enum RhwpObjectZOrderOperation { front, back, forward, backward }

extension RhwpObjectZOrderOperationMetadata on RhwpObjectZOrderOperation {
  String get commandValue {
    return switch (this) {
      RhwpObjectZOrderOperation.front => 'front',
      RhwpObjectZOrderOperation.back => 'back',
      RhwpObjectZOrderOperation.forward => 'forward',
      RhwpObjectZOrderOperation.backward => 'backward',
    };
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

class RhwpObjectProperties {
  const RhwpObjectProperties({
    this.width,
    this.height,
    this.horzOffset,
    this.vertOffset,
    required this.rawJson,
    this.raw,
  });

  factory RhwpObjectProperties.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpObjectProperties(
      width: _intFromJson(decoded?['width']),
      height: _intFromJson(decoded?['height']),
      horzOffset: _intFromJson(decoded?['horzOffset']),
      vertOffset: _intFromJson(decoded?['vertOffset']),
      rawJson: source,
      raw: decoded,
    );
  }

  final int? width;
  final int? height;
  final int? horzOffset;
  final int? vertOffset;
  final String rawJson;
  final Map<String, Object?>? raw;
}

int? _intFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
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

  factory RhwpCommand.insertTextInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required String text,
  }) = RhwpInsertTextInTableCellCommand;

  factory RhwpCommand.deleteTextInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required int count,
  }) = RhwpDeleteTextInTableCellCommand;

  factory RhwpCommand.applyCharFormatInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int startOffset,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) = RhwpApplyCharFormatInTableCellCommand;

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

  factory RhwpCommand.insertTable({
    required int section,
    required int paragraph,
    required int offset,
    required int rows,
    required int columns,
  }) = RhwpInsertTableCommand;

  factory RhwpCommand.insertTableRow({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required bool below,
  }) = RhwpInsertTableRowCommand;

  factory RhwpCommand.insertTableColumn({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int column,
    required bool right,
  }) = RhwpInsertTableColumnCommand;

  factory RhwpCommand.deleteTableRow({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
  }) = RhwpDeleteTableRowCommand;

  factory RhwpCommand.deleteTableColumn({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int column,
  }) = RhwpDeleteTableColumnCommand;

  factory RhwpCommand.mergeTableCells({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
  }) = RhwpMergeTableCellsCommand;

  factory RhwpCommand.splitTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
  }) = RhwpSplitTableCellCommand;

  factory RhwpCommand.deleteObjectControl({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
  }) = RhwpDeleteObjectControlCommand;

  factory RhwpCommand.changeObjectZOrder({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
    required RhwpObjectZOrderOperation operation,
  }) = RhwpChangeObjectZOrderCommand;

  factory RhwpCommand.getObjectProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
  }) = RhwpGetObjectPropertiesCommand;

  factory RhwpCommand.setObjectProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
    int? width,
    int? height,
    int? horzOffset,
    int? vertOffset,
  }) = RhwpSetObjectPropertiesCommand;

  factory RhwpCommand.applyCharFormat({
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) = RhwpApplyCharFormatCommand;

  factory RhwpCommand.applyCharFormatRange({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) = RhwpApplyCharFormatRangeCommand;

  factory RhwpCommand.applyParaFormat({
    required int section,
    required int paragraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) = RhwpApplyParaFormatCommand;

  factory RhwpCommand.applyParaFormatRange({
    required int section,
    required int startParagraph,
    required int endParagraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) = RhwpApplyParaFormatRangeCommand;

  factory RhwpCommand.applyParaFormatInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) = RhwpApplyParaFormatInTableCellCommand;

  factory RhwpCommand.applyTableCellStyle({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    String? fillColor,
    bool clearFill,
    String? borderColor,
    int? borderWidth,
    int? borderType,
  }) = RhwpApplyTableCellStyleCommand;

  factory RhwpCommand.createHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
  }) = RhwpCreateHeaderFooterCommand;

  factory RhwpCommand.saveSnapshot() = RhwpSaveSnapshotCommand;

  factory RhwpCommand.restoreSnapshot(int snapshotId) =
      RhwpRestoreSnapshotCommand;

  factory RhwpCommand.discardSnapshot(int snapshotId) =
      RhwpDiscardSnapshotCommand;

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

class RhwpInsertTextInTableCellCommand extends RhwpCommand {
  const RhwpInsertTextInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    required this.text,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTextInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'text': text,
  };
}

class RhwpDeleteTextInTableCellCommand extends RhwpCommand {
  const RhwpDeleteTextInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    required this.count,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final int count;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTextInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'count': count,
  };
}

class RhwpApplyCharFormatInTableCellCommand extends RhwpCommand {
  const RhwpApplyCharFormatInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.startOffset,
    required this.endOffset,
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.fontSize,
    this.textColor,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int startOffset;
  final int endOffset;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final int? fontSize;
  final String? textColor;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyCharFormatInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'properties': {
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
    },
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

class RhwpInsertTableCommand extends RhwpCommand {
  const RhwpInsertTableCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.rows,
    required this.columns,
  });

  final int section;
  final int paragraph;
  final int offset;
  final int rows;
  final int columns;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTable',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'rows': rows,
    'columns': columns,
  };
}

class RhwpInsertTableRowCommand extends RhwpCommand {
  const RhwpInsertTableRowCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    this.below = true,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;
  final bool below;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTableRow',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'row': row,
    'below': below,
  };
}

class RhwpInsertTableColumnCommand extends RhwpCommand {
  const RhwpInsertTableColumnCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.column,
    this.right = true,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int column;
  final bool right;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTableColumn',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'column': column,
    'right': right,
  };
}

class RhwpDeleteTableRowCommand extends RhwpCommand {
  const RhwpDeleteTableRowCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTableRow',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'row': row,
  };
}

class RhwpDeleteTableColumnCommand extends RhwpCommand {
  const RhwpDeleteTableColumnCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.column,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int column;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTableColumn',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'column': column,
  };
}

class RhwpMergeTableCellsCommand extends RhwpCommand {
  const RhwpMergeTableCellsCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;

  @override
  Map<String, Object?> toJson() => {
    'type': 'mergeTableCells',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'startRow': startRow,
    'startColumn': startColumn,
    'endRow': endRow,
    'endColumn': endColumn,
  };
}

class RhwpSplitTableCellCommand extends RhwpCommand {
  const RhwpSplitTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    required this.column,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;
  final int column;

  @override
  Map<String, Object?> toJson() => {
    'type': 'splitTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'row': row,
    'column': column,
  };
}

class RhwpDeleteObjectControlCommand extends RhwpCommand {
  const RhwpDeleteObjectControlCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.objectType,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String objectType;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteObjectControl',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'objectType': objectType,
  };
}

class RhwpChangeObjectZOrderCommand extends RhwpCommand {
  const RhwpChangeObjectZOrderCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.objectType,
    required this.operation,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String objectType;
  final RhwpObjectZOrderOperation operation;

  @override
  Map<String, Object?> toJson() => {
    'type': 'changeObjectZOrder',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'objectType': objectType,
    'operation': operation.commandValue,
  };
}

class RhwpGetObjectPropertiesCommand extends RhwpCommand {
  const RhwpGetObjectPropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.objectType,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String objectType;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getObjectProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'objectType': objectType,
  };
}

class RhwpSetObjectPropertiesCommand extends RhwpCommand {
  const RhwpSetObjectPropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.objectType,
    this.width,
    this.height,
    this.horzOffset,
    this.vertOffset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String objectType;
  final int? width;
  final int? height;
  final int? horzOffset;
  final int? vertOffset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setObjectProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'objectType': objectType,
    'properties': {
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (horzOffset != null) 'horzOffset': horzOffset,
      if (vertOffset != null) 'vertOffset': vertOffset,
    },
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
    this.strikethrough,
    this.fontSize,
    this.textColor,
  });

  final int section;
  final int paragraph;
  final int startOffset;
  final int endOffset;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final int? fontSize;
  final String? textColor;

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
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
    },
  };
}

class RhwpApplyCharFormatRangeCommand extends RhwpCommand {
  const RhwpApplyCharFormatRangeCommand({
    required this.section,
    required this.startParagraph,
    required this.startOffset,
    required this.endParagraph,
    required this.endOffset,
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.fontSize,
    this.textColor,
  });

  final int section;
  final int startParagraph;
  final int startOffset;
  final int endParagraph;
  final int endOffset;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final int? fontSize;
  final String? textColor;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyCharFormatRange',
    'section': section,
    'startParagraph': startParagraph,
    'startOffset': startOffset,
    'endParagraph': endParagraph,
    'endOffset': endOffset,
    'properties': {
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
    },
  };
}

class RhwpApplyParaFormatCommand extends RhwpCommand {
  const RhwpApplyParaFormatCommand({
    required this.section,
    required this.paragraph,
    this.alignment,
    this.lineSpacing,
    this.lineSpacingType,
    this.indent,
    this.marginLeft,
    this.marginRight,
    this.spacingBefore,
    this.spacingAfter,
  });

  final int section;
  final int paragraph;
  final String? alignment;
  final int? lineSpacing;
  final String? lineSpacingType;
  final int? indent;
  final int? marginLeft;
  final int? marginRight;
  final int? spacingBefore;
  final int? spacingAfter;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyParaFormat',
    'section': section,
    'paragraph': paragraph,
    'properties': _paraFormatProperties(
      alignment: alignment,
      lineSpacing: lineSpacing,
      lineSpacingType: lineSpacingType,
      indent: indent,
      marginLeft: marginLeft,
      marginRight: marginRight,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
    ),
  };
}

class RhwpApplyParaFormatRangeCommand extends RhwpCommand {
  const RhwpApplyParaFormatRangeCommand({
    required this.section,
    required this.startParagraph,
    required this.endParagraph,
    this.alignment,
    this.lineSpacing,
    this.lineSpacingType,
    this.indent,
    this.marginLeft,
    this.marginRight,
    this.spacingBefore,
    this.spacingAfter,
  });

  final int section;
  final int startParagraph;
  final int endParagraph;
  final String? alignment;
  final int? lineSpacing;
  final String? lineSpacingType;
  final int? indent;
  final int? marginLeft;
  final int? marginRight;
  final int? spacingBefore;
  final int? spacingAfter;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyParaFormatRange',
    'section': section,
    'startParagraph': startParagraph,
    'endParagraph': endParagraph,
    'properties': _paraFormatProperties(
      alignment: alignment,
      lineSpacing: lineSpacing,
      lineSpacingType: lineSpacingType,
      indent: indent,
      marginLeft: marginLeft,
      marginRight: marginRight,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
    ),
  };
}

class RhwpApplyParaFormatInTableCellCommand extends RhwpCommand {
  const RhwpApplyParaFormatInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    this.alignment,
    this.lineSpacing,
    this.lineSpacingType,
    this.indent,
    this.marginLeft,
    this.marginRight,
    this.spacingBefore,
    this.spacingAfter,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final String? alignment;
  final int? lineSpacing;
  final String? lineSpacingType;
  final int? indent;
  final int? marginLeft;
  final int? marginRight;
  final int? spacingBefore;
  final int? spacingAfter;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyParaFormatInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'properties': _paraFormatProperties(
      alignment: alignment,
      lineSpacing: lineSpacing,
      lineSpacingType: lineSpacingType,
      indent: indent,
      marginLeft: marginLeft,
      marginRight: marginRight,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
    ),
  };
}

class RhwpApplyTableCellStyleCommand extends RhwpCommand {
  const RhwpApplyTableCellStyleCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    this.fillColor,
    this.clearFill = false,
    this.borderColor,
    this.borderWidth,
    this.borderType,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final String? fillColor;
  final bool clearFill;
  final String? borderColor;
  final int? borderWidth;
  final int? borderType;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyTableCellStyle',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'properties': _tableCellStyleProperties(
      fillColor: fillColor,
      clearFill: clearFill,
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderType: borderType,
    ),
  };
}

Map<String, Object?> _paraFormatProperties({
  String? alignment,
  int? lineSpacing,
  String? lineSpacingType,
  int? indent,
  int? marginLeft,
  int? marginRight,
  int? spacingBefore,
  int? spacingAfter,
}) {
  final properties = <String, Object?>{};
  if (alignment != null) properties['alignment'] = alignment;
  if (lineSpacing != null) properties['lineSpacing'] = lineSpacing;
  if (lineSpacingType != null) {
    properties['lineSpacingType'] = lineSpacingType;
  }
  if (indent != null) properties['indent'] = indent;
  if (marginLeft != null) properties['marginLeft'] = marginLeft;
  if (marginRight != null) properties['marginRight'] = marginRight;
  if (spacingBefore != null) properties['spacingBefore'] = spacingBefore;
  if (spacingAfter != null) properties['spacingAfter'] = spacingAfter;
  return properties;
}

Map<String, Object?> _tableCellStyleProperties({
  String? fillColor,
  bool clearFill = false,
  String? borderColor,
  int? borderWidth,
  int? borderType,
}) {
  final properties = <String, Object?>{};
  if (clearFill) {
    properties['fillType'] = 'none';
  } else if (fillColor != null) {
    properties['fillType'] = 'solid';
    properties['fillColor'] = fillColor;
  }

  if (borderColor != null) {
    Map<String, Object?> border() => {
      'type': borderType ?? 1,
      'width': borderWidth ?? 1,
      'color': borderColor,
    };
    properties['borderLeft'] = border();
    properties['borderRight'] = border();
    properties['borderTop'] = border();
    properties['borderBottom'] = border();
  }
  return properties;
}

class RhwpSetFileNameCommand extends RhwpCommand {
  const RhwpSetFileNameCommand(this.name);

  final String name;

  @override
  Map<String, Object?> toJson() => {'type': 'setFileName', 'name': name};
}

class RhwpCreateHeaderFooterCommand extends RhwpCommand {
  const RhwpCreateHeaderFooterCommand({
    required this.section,
    required this.isHeader,
    this.applyTo = 0,
  });

  final int section;
  final bool isHeader;

  /// 0 applies to both pages, 1 to even pages, and 2 to odd pages.
  final int applyTo;

  @override
  Map<String, Object?> toJson() => {
    'type': 'createHeaderFooter',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
  };
}

class RhwpSaveSnapshotCommand extends RhwpCommand {
  const RhwpSaveSnapshotCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'saveSnapshot'};
}

class RhwpRestoreSnapshotCommand extends RhwpCommand {
  const RhwpRestoreSnapshotCommand(this.snapshotId);

  final int snapshotId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'restoreSnapshot',
    'snapshotId': snapshotId,
  };
}

class RhwpDiscardSnapshotCommand extends RhwpCommand {
  const RhwpDiscardSnapshotCommand(this.snapshotId);

  final int snapshotId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'discardSnapshot',
    'snapshotId': snapshotId,
  };
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

  Future<String> insertTextInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertTextInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        text: text,
      ),
    );
  }

  Future<String> deleteTextInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required int count,
  }) {
    return apply(
      RhwpCommand.deleteTextInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        count: count,
      ),
    );
  }

  Future<String> applyCharFormatInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int startOffset,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) {
    return apply(
      RhwpCommand.applyCharFormatInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        startOffset: startOffset,
        endOffset: endOffset,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        fontSize: fontSize,
        textColor: textColor,
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

  Future<String> insertTable({
    required int section,
    required int paragraph,
    required int offset,
    required int rows,
    required int columns,
  }) {
    return apply(
      RhwpCommand.insertTable(
        section: section,
        paragraph: paragraph,
        offset: offset,
        rows: rows,
        columns: columns,
      ),
    );
  }

  Future<String> insertTableRow({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    bool below = true,
  }) {
    return apply(
      RhwpCommand.insertTableRow(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        row: row,
        below: below,
      ),
    );
  }

  Future<String> insertTableColumn({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int column,
    bool right = true,
  }) {
    return apply(
      RhwpCommand.insertTableColumn(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        column: column,
        right: right,
      ),
    );
  }

  Future<String> deleteTableRow({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
  }) {
    return apply(
      RhwpCommand.deleteTableRow(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        row: row,
      ),
    );
  }

  Future<String> deleteTableColumn({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int column,
  }) {
    return apply(
      RhwpCommand.deleteTableColumn(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        column: column,
      ),
    );
  }

  Future<String> mergeTableCells({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
  }) {
    return apply(
      RhwpCommand.mergeTableCells(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        startRow: startRow,
        startColumn: startColumn,
        endRow: endRow,
        endColumn: endColumn,
      ),
    );
  }

  Future<String> splitTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
  }) {
    return apply(
      RhwpCommand.splitTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        row: row,
        column: column,
      ),
    );
  }

  Future<String> deleteObjectControl({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
  }) {
    return apply(
      RhwpCommand.deleteObjectControl(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: objectType,
      ),
    );
  }

  Future<String> changeObjectZOrder({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
    required RhwpObjectZOrderOperation operation,
  }) {
    return apply(
      RhwpCommand.changeObjectZOrder(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: objectType,
        operation: operation,
      ),
    );
  }

  Future<RhwpObjectProperties> objectProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
  }) async {
    final json = await apply(
      RhwpCommand.getObjectProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: objectType,
      ),
    );
    return RhwpObjectProperties.fromJsonString(json);
  }

  Future<String> setObjectProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
    int? width,
    int? height,
    int? horzOffset,
    int? vertOffset,
  }) {
    return apply(
      RhwpCommand.setObjectProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        objectType: objectType,
        width: width,
        height: height,
        horzOffset: horzOffset,
        vertOffset: vertOffset,
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
    bool? strikethrough,
    int? fontSize,
    String? textColor,
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
        strikethrough: strikethrough,
        fontSize: fontSize,
        textColor: textColor,
      ),
    );
  }

  Future<String> applyCharFormatRange({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    int? fontSize,
    String? textColor,
  }) {
    return apply(
      RhwpCommand.applyCharFormatRange(
        section: section,
        startParagraph: startParagraph,
        startOffset: startOffset,
        endParagraph: endParagraph,
        endOffset: endOffset,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        fontSize: fontSize,
        textColor: textColor,
      ),
    );
  }

  Future<String> applyParaFormat({
    required int section,
    required int paragraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) {
    return apply(
      RhwpCommand.applyParaFormat(
        section: section,
        paragraph: paragraph,
        alignment: alignment,
        lineSpacing: lineSpacing,
        lineSpacingType: lineSpacingType,
        indent: indent,
        marginLeft: marginLeft,
        marginRight: marginRight,
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
      ),
    );
  }

  Future<String> applyParaFormatRange({
    required int section,
    required int startParagraph,
    required int endParagraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) {
    return apply(
      RhwpCommand.applyParaFormatRange(
        section: section,
        startParagraph: startParagraph,
        endParagraph: endParagraph,
        alignment: alignment,
        lineSpacing: lineSpacing,
        lineSpacingType: lineSpacingType,
        indent: indent,
        marginLeft: marginLeft,
        marginRight: marginRight,
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
      ),
    );
  }

  Future<String> applyParaFormatInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    String? alignment,
    int? lineSpacing,
    String? lineSpacingType,
    int? indent,
    int? marginLeft,
    int? marginRight,
    int? spacingBefore,
    int? spacingAfter,
  }) {
    return apply(
      RhwpCommand.applyParaFormatInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        alignment: alignment,
        lineSpacing: lineSpacing,
        lineSpacingType: lineSpacingType,
        indent: indent,
        marginLeft: marginLeft,
        marginRight: marginRight,
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
      ),
    );
  }

  Future<String> applyTableCellStyle({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    String? fillColor,
    bool clearFill = false,
    String? borderColor,
    int? borderWidth,
    int? borderType,
  }) {
    return apply(
      RhwpCommand.applyTableCellStyle(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        fillColor: fillColor,
        clearFill: clearFill,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderType: borderType,
      ),
    );
  }

  Future<String> createHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo = 0,
  }) {
    return apply(
      RhwpCommand.createHeaderFooter(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
      ),
    );
  }

  Future<String> createHeader({required int section, int applyTo = 0}) {
    return createHeaderFooter(
      section: section,
      isHeader: true,
      applyTo: applyTo,
    );
  }

  Future<String> createFooter({required int section, int applyTo = 0}) {
    return createHeaderFooter(
      section: section,
      isHeader: false,
      applyTo: applyTo,
    );
  }

  Future<int> saveSnapshot() async {
    final result = await apply(RhwpCommand.saveSnapshot());
    final decoded = _tryDecodeObject(result);
    final snapshotId = decoded?['snapshotId'];
    if (snapshotId is num) {
      return snapshotId.toInt();
    }
    throw RhwpException('Snapshot command did not return a snapshotId.');
  }

  Future<String> restoreSnapshot(int snapshotId) {
    return apply(RhwpCommand.restoreSnapshot(snapshotId));
  }

  Future<String> discardSnapshot(int snapshotId) {
    return apply(RhwpCommand.discardSnapshot(snapshotId));
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
