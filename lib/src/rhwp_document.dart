import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'rhwp_exception.dart';
import 'rhwp_layer_tree.dart';
import 'rust/api/rhwp.dart' as rust;

/// Supported output formats for document export.
enum RhwpExportFormat { hwp, hwpx, pdf, docx, text, markdown, svg }

/// The user-facing reason an exported artifact was requested.
enum RhwpExportIntent {
  /// Save back to the current document destination when the host app has one.
  save,

  /// Ask the user for a new destination/name for a primary document save.
  saveAs,

  /// Produce a secondary artifact such as PDF, DOCX, text, Markdown, or SVG.
  export,
}

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
    this.intent = RhwpExportIntent.export,
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
    RhwpExportIntent intent = RhwpExportIntent.export,
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
      intent: intent,
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

  /// The host-app save/export flow that produced this artifact.
  final RhwpExportIntent intent;

  /// Returns this artifact with selected metadata replaced.
  RhwpExportedDocument copyWith({
    RhwpExportFormat? format,
    Uint8List? bytes,
    String? fileName,
    String? mimeType,
    RhwpExportIntent? intent,
  }) {
    return RhwpExportedDocument(
      format: format ?? this.format,
      bytes: bytes ?? this.bytes,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      intent: intent ?? this.intent,
    );
  }

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

/// Multi-column layout mode for a document section.
enum RhwpColumnType { normal, distribute, parallel }

extension RhwpColumnTypeMetadata on RhwpColumnType {
  int get commandValue {
    return switch (this) {
      RhwpColumnType.normal => 0,
      RhwpColumnType.distribute => 1,
      RhwpColumnType.parallel => 2,
    };
  }
}

RhwpColumnType _columnTypeFromCommandValue(int value) {
  return switch (value) {
    1 => RhwpColumnType.distribute,
    2 => RhwpColumnType.parallel,
    _ => RhwpColumnType.normal,
  };
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
    this.rotationAngle,
    this.horzFlip,
    this.vertFlip,
    this.hasCaption,
    this.captionDirection,
    this.captionVerticalAlign,
    this.captionWidth,
    this.captionSpacing,
    this.captionIncludeMargin,
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
      rotationAngle: _intFromJson(decoded?['rotationAngle']),
      horzFlip: _boolFromJson(decoded?['horzFlip']),
      vertFlip: _boolFromJson(decoded?['vertFlip']),
      hasCaption: _boolFromJson(decoded?['hasCaption']),
      captionDirection: _stringFromJson(decoded?['captionDirection']),
      captionVerticalAlign: _stringFromJson(decoded?['captionVertAlign']),
      captionWidth: _intFromJson(decoded?['captionWidth']),
      captionSpacing: _intFromJson(decoded?['captionSpacing']),
      captionIncludeMargin: _boolFromJson(decoded?['captionIncludeMargin']),
      rawJson: source,
      raw: decoded,
    );
  }

  final int? width;
  final int? height;
  final int? horzOffset;
  final int? vertOffset;
  final int? rotationAngle;
  final bool? horzFlip;
  final bool? vertFlip;
  final bool? hasCaption;
  final String? captionDirection;
  final String? captionVerticalAlign;
  final int? captionWidth;
  final int? captionSpacing;
  final bool? captionIncludeMargin;
  final String rawJson;
  final Map<String, Object?>? raw;

  bool get supportsCaption {
    return hasCaption != null ||
        captionDirection != null ||
        captionVerticalAlign != null ||
        captionWidth != null ||
        captionSpacing != null ||
        captionIncludeMargin != null;
  }

  bool get supportsTransform {
    return rotationAngle != null || horzFlip != null || vertFlip != null;
  }
}

class RhwpTableProperties {
  const RhwpTableProperties({
    this.cellSpacing,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.pageBreak,
    this.repeatHeader,
    this.hasCaption,
    this.captionDirection,
    this.captionVerticalAlign,
    this.captionWidth,
    this.captionSpacing,
    required this.rawJson,
    this.raw,
  });

  factory RhwpTableProperties.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpTableProperties(
      cellSpacing: _intFromJson(decoded?['cellSpacing']),
      paddingLeft: _intFromJson(decoded?['paddingLeft']),
      paddingRight: _intFromJson(decoded?['paddingRight']),
      paddingTop: _intFromJson(decoded?['paddingTop']),
      paddingBottom: _intFromJson(decoded?['paddingBottom']),
      pageBreak: _intFromJson(decoded?['pageBreak']),
      repeatHeader: decoded?['repeatHeader'] is bool
          ? decoded!['repeatHeader'] as bool
          : null,
      hasCaption: _boolFromJson(decoded?['hasCaption']),
      captionDirection: _intFromJson(decoded?['captionDirection']),
      captionVerticalAlign: _intFromJson(decoded?['captionVertAlign']),
      captionWidth: _intFromJson(decoded?['captionWidth']),
      captionSpacing: _intFromJson(decoded?['captionSpacing']),
      rawJson: source,
      raw: decoded,
    );
  }

  final int? cellSpacing;
  final int? paddingLeft;
  final int? paddingRight;
  final int? paddingTop;
  final int? paddingBottom;
  final int? pageBreak;
  final bool? repeatHeader;
  final bool? hasCaption;
  final int? captionDirection;
  final int? captionVerticalAlign;
  final int? captionWidth;
  final int? captionSpacing;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpCellProperties {
  const RhwpCellProperties({
    this.width,
    this.height,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.verticalAlign,
    this.textDirection,
    this.isHeader,
    this.cellProtect,
    required this.rawJson,
    this.raw,
  });

  factory RhwpCellProperties.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpCellProperties(
      width: _intFromJson(decoded?['width']),
      height: _intFromJson(decoded?['height']),
      paddingLeft: _intFromJson(decoded?['paddingLeft']),
      paddingRight: _intFromJson(decoded?['paddingRight']),
      paddingTop: _intFromJson(decoded?['paddingTop']),
      paddingBottom: _intFromJson(decoded?['paddingBottom']),
      verticalAlign: _intFromJson(decoded?['verticalAlign']),
      textDirection: _intFromJson(decoded?['textDirection']),
      isHeader: decoded?['isHeader'] is bool
          ? decoded!['isHeader'] as bool
          : null,
      cellProtect: decoded?['cellProtect'] is bool
          ? decoded!['cellProtect'] as bool
          : null,
      rawJson: source,
      raw: decoded,
    );
  }

  final int? width;
  final int? height;
  final int? paddingLeft;
  final int? paddingRight;
  final int? paddingTop;
  final int? paddingBottom;
  final int? verticalAlign;
  final int? textDirection;
  final bool? isHeader;
  final bool? cellProtect;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpTableCellResize {
  const RhwpTableCellResize({
    required this.cellIndex,
    this.widthDelta = 0,
    this.heightDelta = 0,
  });

  final int cellIndex;
  final int widthDelta;
  final int heightDelta;

  Map<String, Object?> toJson() => {
    'cellIdx': cellIndex,
    if (widthDelta != 0) 'widthDelta': widthDelta,
    if (heightDelta != 0) 'heightDelta': heightDelta,
  };
}

class RhwpStyleInfo {
  const RhwpStyleInfo({
    required this.id,
    required this.name,
    required this.englishName,
    required this.type,
    required this.nextStyleId,
    required this.paraShapeId,
    required this.charShapeId,
    this.raw,
  });

  factory RhwpStyleInfo.fromJson(Map<String, Object?> json) {
    return RhwpStyleInfo(
      id: _intFromJson(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      englishName: json['englishName']?.toString() ?? '',
      type: _intFromJson(json['type']) ?? 0,
      nextStyleId: _intFromJson(json['nextStyleId']) ?? 0,
      paraShapeId: _intFromJson(json['paraShapeId']) ?? 0,
      charShapeId: _intFromJson(json['charShapeId']) ?? 0,
      raw: json,
    );
  }

  final int id;
  final String name;
  final String englishName;
  final int type;
  final int nextStyleId;
  final int paraShapeId;
  final int charShapeId;
  final Map<String, Object?>? raw;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name;
    }
    if (englishName.trim().isNotEmpty) {
      return englishName;
    }
    return 'Style $id';
  }
}

class RhwpBookmark {
  const RhwpBookmark({
    required this.name,
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.charPosition,
    this.raw,
  });

  factory RhwpBookmark.fromJson(Map<String, Object?> json) {
    return RhwpBookmark(
      name: json['name']?.toString() ?? '',
      section: _intFromJson(json['sec']) ?? 0,
      paragraph: _intFromJson(json['para']) ?? 0,
      controlIndex: _intFromJson(json['ctrlIdx']) ?? 0,
      charPosition: _intFromJson(json['charPos']) ?? 0,
      raw: json,
    );
  }

  final String name;
  final int section;
  final int paragraph;
  final int controlIndex;
  final int charPosition;
  final Map<String, Object?>? raw;
}

class RhwpFootnoteHit {
  const RhwpFootnoteHit({
    required this.hit,
    this.section,
    this.paragraph,
    this.controlIndex,
    this.charOffset,
    this.footnoteNumber,
    this.raw,
  });

  factory RhwpFootnoteHit.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source) ?? const {};
    return RhwpFootnoteHit(
      hit: decoded['hit'] == true,
      section: _intFromJson(decoded['sectionIndex']),
      paragraph: _intFromJson(decoded['paragraphIndex']),
      controlIndex: _intFromJson(decoded['controlIndex']),
      charOffset: _intFromJson(decoded['charOffset']),
      footnoteNumber: _intFromJson(decoded['footnoteNumber']),
      raw: decoded,
    );
  }

  final bool hit;
  final int? section;
  final int? paragraph;
  final int? controlIndex;
  final int? charOffset;
  final int? footnoteNumber;
  final Map<String, Object?>? raw;
}

class RhwpFootnoteInfo {
  const RhwpFootnoteInfo({
    required this.ok,
    required this.paragraphCount,
    required this.totalTextLength,
    required this.number,
    required this.texts,
    required this.rawJson,
    this.raw,
  });

  factory RhwpFootnoteInfo.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source) ?? const {};
    final texts = decoded['texts'];
    return RhwpFootnoteInfo(
      ok: decoded['ok'] == true,
      paragraphCount: _intFromJson(decoded['paraCount']) ?? 0,
      totalTextLength: _intFromJson(decoded['totalTextLen']) ?? 0,
      number: _intFromJson(decoded['number']) ?? 0,
      texts: texts is List
          ? [for (final text in texts) text?.toString() ?? '']
          : const [],
      rawJson: source,
      raw: decoded,
    );
  }

  final bool ok;
  final int paragraphCount;
  final int totalTextLength;
  final int number;
  final List<String> texts;
  final String rawJson;
  final Map<String, Object?>? raw;

  String get plainText => texts.join('\n');
}

class RhwpFieldInfo {
  const RhwpFieldInfo({
    required this.fieldId,
    required this.fieldType,
    required this.name,
    required this.guide,
    required this.command,
    required this.value,
    this.location,
    this.raw,
  });

  factory RhwpFieldInfo.fromJson(Map<String, Object?> json) {
    final location = json['location'];
    return RhwpFieldInfo(
      fieldId: _intFromJson(json['fieldId']) ?? 0,
      fieldType: json['fieldType']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      guide: json['guide']?.toString() ?? '',
      command: json['command']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      location: location is Map ? location.cast<String, Object?>() : null,
      raw: json,
    );
  }

  final int fieldId;
  final String fieldType;
  final String name;
  final String guide;
  final String command;
  final String value;
  final Map<String, Object?>? location;
  final Map<String, Object?>? raw;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name;
    }
    if (guide.trim().isNotEmpty) {
      return guide;
    }
    return 'Field $fieldId';
  }
}

class RhwpFieldRangeInfo {
  const RhwpFieldRangeInfo({
    required this.inField,
    this.fieldId,
    this.fieldType,
    this.startCharIndex,
    this.endCharIndex,
    this.isGuide = false,
    this.guideName,
    this.raw,
  });

  factory RhwpFieldRangeInfo.fromJson(Map<String, Object?> json) {
    return RhwpFieldRangeInfo(
      inField: json['inField'] == true,
      fieldId: _intFromJson(json['fieldId']),
      fieldType: json['fieldType']?.toString(),
      startCharIndex: _intFromJson(json['startCharIdx']),
      endCharIndex: _intFromJson(json['endCharIdx']),
      isGuide: _boolFromJson(json['isGuide']) ?? false,
      guideName: json['guideName']?.toString(),
      raw: json,
    );
  }

  final bool inField;
  final int? fieldId;
  final String? fieldType;
  final int? startCharIndex;
  final int? endCharIndex;
  final bool isGuide;
  final String? guideName;
  final Map<String, Object?>? raw;
}

class RhwpClickHereProperties {
  const RhwpClickHereProperties({
    required this.ok,
    required this.guide,
    required this.memo,
    required this.name,
    required this.editable,
    this.raw,
  });

  factory RhwpClickHereProperties.fromJson(Map<String, Object?> json) {
    return RhwpClickHereProperties(
      ok: json['ok'] == true,
      guide: json['guide']?.toString() ?? '',
      memo: json['memo']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      editable: _boolFromJson(json['editable']) ?? false,
      raw: json,
    );
  }

  final bool ok;
  final String guide;
  final String memo;
  final String name;
  final bool editable;
  final Map<String, Object?>? raw;
}

class RhwpCharProperties {
  const RhwpCharProperties({
    required this.rawJson,
    this.fontFamily,
    this.fontSize,
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.superscript,
    this.subscript,
    this.emboss,
    this.engrave,
    this.textColor,
    this.shadeColor,
    this.raw,
  });

  factory RhwpCharProperties.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpCharProperties(
      rawJson: source,
      fontFamily: decoded?['fontFamily']?.toString(),
      fontSize: _intFromJson(decoded?['fontSize']),
      bold: _boolFromJson(decoded?['bold']),
      italic: _boolFromJson(decoded?['italic']),
      underline: _boolFromJson(decoded?['underline']),
      strikethrough: _boolFromJson(decoded?['strikethrough']),
      superscript: _boolFromJson(decoded?['superscript']),
      subscript: _boolFromJson(decoded?['subscript']),
      emboss: _boolFromJson(decoded?['emboss']),
      engrave: _boolFromJson(decoded?['engrave']),
      textColor: decoded?['textColor']?.toString(),
      shadeColor: decoded?['shadeColor']?.toString(),
      raw: decoded,
    );
  }

  final String rawJson;
  final String? fontFamily;
  final int? fontSize;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final bool? superscript;
  final bool? subscript;
  final bool? emboss;
  final bool? engrave;
  final String? textColor;
  final String? shadeColor;
  final Map<String, Object?>? raw;
}

class RhwpParaProperties {
  const RhwpParaProperties({
    required this.rawJson,
    this.alignment,
    this.lineSpacing,
    this.lineSpacingType,
    this.indent,
    this.marginLeft,
    this.marginRight,
    this.spacingBefore,
    this.spacingAfter,
    this.paraShapeId,
    this.raw,
  });

  factory RhwpParaProperties.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpParaProperties(
      rawJson: source,
      alignment: decoded?['alignment']?.toString(),
      lineSpacing: _intFromJson(decoded?['lineSpacing']),
      lineSpacingType: decoded?['lineSpacingType']?.toString(),
      indent: _intFromJson(decoded?['indent']),
      marginLeft: _intFromJson(decoded?['marginLeft']),
      marginRight: _intFromJson(decoded?['marginRight']),
      spacingBefore: _intFromJson(decoded?['spacingBefore']),
      spacingAfter: _intFromJson(decoded?['spacingAfter']),
      paraShapeId: _intFromJson(decoded?['paraShapeId']),
      raw: decoded,
    );
  }

  final String rawJson;
  final String? alignment;
  final int? lineSpacing;
  final String? lineSpacingType;
  final int? indent;
  final int? marginLeft;
  final int? marginRight;
  final int? spacingBefore;
  final int? spacingAfter;
  final int? paraShapeId;
  final Map<String, Object?>? raw;
}

class RhwpPageSetup {
  const RhwpPageSetup({
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
    required this.rawJson,
    this.raw,
  });

  factory RhwpPageSetup.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpPageSetup(
      width: _intFromJson(decoded?['width']) ?? 0,
      height: _intFromJson(decoded?['height']) ?? 0,
      marginLeft: _intFromJson(decoded?['marginLeft']) ?? 0,
      marginRight: _intFromJson(decoded?['marginRight']) ?? 0,
      marginTop: _intFromJson(decoded?['marginTop']) ?? 0,
      marginBottom: _intFromJson(decoded?['marginBottom']) ?? 0,
      marginHeader: _intFromJson(decoded?['marginHeader']) ?? 0,
      marginFooter: _intFromJson(decoded?['marginFooter']) ?? 0,
      marginGutter: _intFromJson(decoded?['marginGutter']) ?? 0,
      landscape: _boolFromJson(decoded?['landscape']) ?? false,
      binding: _intFromJson(decoded?['binding']) ?? 0,
      rawJson: source,
      raw: decoded,
    );
  }

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

  /// 0 is single-sided, 1 is duplex, and 2 is top-flip binding.
  final int binding;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpBorderLine {
  const RhwpBorderLine({
    required this.type,
    required this.width,
    required this.color,
  });

  factory RhwpBorderLine.fromJson(Object? source) {
    if (source is! Map) {
      return const RhwpBorderLine(type: 0, width: 0, color: '#000000');
    }
    final decoded = source.cast<String, Object?>();
    return RhwpBorderLine(
      type: _intFromJson(decoded['type']) ?? 0,
      width: _intFromJson(decoded['width']) ?? 0,
      color: decoded['color']?.toString() ?? '#000000',
    );
  }

  final int type;
  final int width;
  final String color;

  Map<String, Object?> toJson() => {
    'type': type,
    'width': width,
    'color': color,
  };
}

class RhwpPageBorderFill {
  const RhwpPageBorderFill({
    required this.attr,
    required this.spacingLeft,
    required this.spacingRight,
    required this.spacingTop,
    required this.spacingBottom,
    required this.borderFillId,
    required this.borderLeft,
    required this.borderRight,
    required this.borderTop,
    required this.borderBottom,
    required this.fillType,
    required this.fillColor,
    required this.patternColor,
    required this.patternType,
    required this.rawJson,
    this.raw,
  });

  factory RhwpPageBorderFill.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpPageBorderFill(
      attr: _intFromJson(decoded?['attr']) ?? 0,
      spacingLeft: _intFromJson(decoded?['spacingLeft']) ?? 0,
      spacingRight: _intFromJson(decoded?['spacingRight']) ?? 0,
      spacingTop: _intFromJson(decoded?['spacingTop']) ?? 0,
      spacingBottom: _intFromJson(decoded?['spacingBottom']) ?? 0,
      borderFillId: _intFromJson(decoded?['borderFillId']) ?? 0,
      borderLeft: RhwpBorderLine.fromJson(decoded?['borderLeft']),
      borderRight: RhwpBorderLine.fromJson(decoded?['borderRight']),
      borderTop: RhwpBorderLine.fromJson(decoded?['borderTop']),
      borderBottom: RhwpBorderLine.fromJson(decoded?['borderBottom']),
      fillType: decoded?['fillType']?.toString() ?? 'none',
      fillColor: decoded?['fillColor']?.toString() ?? '#ffffff',
      patternColor: decoded?['patternColor']?.toString() ?? '#000000',
      patternType: _intFromJson(decoded?['patternType']) ?? 0,
      rawJson: source,
      raw: decoded,
    );
  }

  final int attr;
  final int spacingLeft;
  final int spacingRight;
  final int spacingTop;
  final int spacingBottom;
  final int borderFillId;
  final RhwpBorderLine borderLeft;
  final RhwpBorderLine borderRight;
  final RhwpBorderLine borderTop;
  final RhwpBorderLine borderBottom;
  final String fillType;
  final String fillColor;
  final String patternColor;
  final int patternType;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpColumnDef {
  const RhwpColumnDef({
    required this.columnCount,
    required this.columnType,
    required this.sameWidth,
    required this.spacing,
    required this.rawJson,
    this.raw,
  });

  factory RhwpColumnDef.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    final columnType = _intFromJson(decoded?['columnType']) ?? 0;
    return RhwpColumnDef(
      columnCount: _intFromJson(decoded?['columnCount']) ?? 1,
      columnType: _columnTypeFromCommandValue(columnType),
      sameWidth: _boolFromJson(decoded?['sameWidth']) ?? true,
      spacing: _intFromJson(decoded?['spacing']) ?? 0,
      rawJson: source,
      raw: decoded,
    );
  }

  final int columnCount;
  final RhwpColumnType columnType;
  final bool sameWidth;
  final int spacing;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpSectionDef {
  const RhwpSectionDef({
    required this.pageNumber,
    required this.pageNumberType,
    required this.pictureNumber,
    required this.tableNumber,
    required this.equationNumber,
    required this.columnSpacing,
    required this.defaultTabSpacing,
    required this.hideHeader,
    required this.hideFooter,
    required this.hideMasterPage,
    required this.hideBorder,
    required this.hideFill,
    required this.hideEmptyLine,
    required this.rawJson,
    this.raw,
  });

  factory RhwpSectionDef.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpSectionDef(
      pageNumber: _intFromJson(decoded?['pageNum']) ?? 1,
      pageNumberType: _intFromJson(decoded?['pageNumType']) ?? 0,
      pictureNumber: _intFromJson(decoded?['pictureNum']) ?? 1,
      tableNumber: _intFromJson(decoded?['tableNum']) ?? 1,
      equationNumber: _intFromJson(decoded?['equationNum']) ?? 1,
      columnSpacing: _intFromJson(decoded?['columnSpacing']) ?? 0,
      defaultTabSpacing: _intFromJson(decoded?['defaultTabSpacing']) ?? 8000,
      hideHeader: _boolFromJson(decoded?['hideHeader']) ?? false,
      hideFooter: _boolFromJson(decoded?['hideFooter']) ?? false,
      hideMasterPage: _boolFromJson(decoded?['hideMasterPage']) ?? false,
      hideBorder: _boolFromJson(decoded?['hideBorder']) ?? false,
      hideFill: _boolFromJson(decoded?['hideFill']) ?? false,
      hideEmptyLine: _boolFromJson(decoded?['hideEmptyLine']) ?? false,
      rawJson: source,
      raw: decoded,
    );
  }

  final int pageNumber;
  final int pageNumberType;
  final int pictureNumber;
  final int tableNumber;
  final int equationNumber;
  final int columnSpacing;
  final int defaultTabSpacing;
  final bool hideHeader;
  final bool hideFooter;
  final bool hideMasterPage;
  final bool hideBorder;
  final bool hideFill;
  final bool hideEmptyLine;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpPageHide {
  const RhwpPageHide({
    required this.exists,
    required this.hideHeader,
    required this.hideFooter,
    required this.hideMasterPage,
    required this.hideBorder,
    required this.hideFill,
    required this.hidePageNumber,
    required this.rawJson,
    this.raw,
  });

  factory RhwpPageHide.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpPageHide(
      exists: _boolFromJson(decoded?['exists']) ?? false,
      hideHeader: _boolFromJson(decoded?['hideHeader']) ?? false,
      hideFooter: _boolFromJson(decoded?['hideFooter']) ?? false,
      hideMasterPage: _boolFromJson(decoded?['hideMasterPage']) ?? false,
      hideBorder: _boolFromJson(decoded?['hideBorder']) ?? false,
      hideFill: _boolFromJson(decoded?['hideFill']) ?? false,
      hidePageNumber: _boolFromJson(decoded?['hidePageNum']) ?? false,
      rawJson: source,
      raw: decoded,
    );
  }

  final bool exists;
  final bool hideHeader;
  final bool hideFooter;
  final bool hideMasterPage;
  final bool hideBorder;
  final bool hideFill;
  final bool hidePageNumber;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpHeaderFooterInfo {
  const RhwpHeaderFooterInfo({
    required this.exists,
    required this.rawJson,
    this.kind,
    this.applyTo,
    this.label,
    this.paragraphIndex,
    this.controlIndex,
    this.paragraphCount,
    this.text,
    this.raw,
  });

  factory RhwpHeaderFooterInfo.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    return RhwpHeaderFooterInfo(
      exists: _boolFromJson(decoded?['exists']) ?? false,
      kind: decoded?['kind']?.toString(),
      applyTo: _intFromJson(decoded?['applyTo']),
      label: decoded?['label']?.toString(),
      paragraphIndex: _intFromJson(decoded?['paraIndex']),
      controlIndex: _intFromJson(decoded?['controlIndex']),
      paragraphCount: _intFromJson(decoded?['paraCount']),
      text: decoded?['text']?.toString(),
      rawJson: source,
      raw: decoded,
    );
  }

  final bool exists;
  final String? kind;
  final int? applyTo;
  final String? label;
  final int? paragraphIndex;
  final int? controlIndex;
  final int? paragraphCount;
  final String? text;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpHeaderFooterList {
  const RhwpHeaderFooterList({
    required this.items,
    required this.currentIndex,
    required this.rawJson,
    this.raw,
  });

  factory RhwpHeaderFooterList.fromJsonString(String source) {
    final decoded = RhwpDocument._tryDecodeObject(source);
    final rawItems = decoded?['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => RhwpHeaderFooterListItem.fromJson(item))
              .toList(growable: false)
        : const <RhwpHeaderFooterListItem>[];
    return RhwpHeaderFooterList(
      items: items,
      currentIndex: _intFromJson(decoded?['currentIndex']) ?? -1,
      rawJson: source,
      raw: decoded,
    );
  }

  final List<RhwpHeaderFooterListItem> items;
  final int currentIndex;
  final String rawJson;
  final Map<String, Object?>? raw;
}

class RhwpHeaderFooterListItem {
  const RhwpHeaderFooterListItem({
    required this.section,
    required this.isHeader,
    required this.applyTo,
    required this.label,
    this.raw,
  });

  factory RhwpHeaderFooterListItem.fromJson(Map<Object?, Object?> json) {
    return RhwpHeaderFooterListItem(
      section: _intFromJson(json['sectionIdx']) ?? 0,
      isHeader: _boolFromJson(json['isHeader']) ?? false,
      applyTo: _intFromJson(json['applyTo']) ?? 0,
      label: json['label']?.toString() ?? '',
      raw: json.cast<String, Object?>(),
    );
  }

  final int section;
  final bool isHeader;
  final int applyTo;
  final String label;
  final Map<String, Object?>? raw;

  String get displayLabel {
    if (label.trim().isNotEmpty) {
      return label;
    }
    return isHeader ? 'Header' : 'Footer';
  }

  String get applyLabel {
    return switch (applyTo) {
      1 => 'Even',
      2 => 'Odd',
      _ => 'Both',
    };
  }
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

bool? _boolFromJson(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

String? _stringFromJson(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  factory RhwpCommand.getTextInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required int count,
  }) = RhwpGetTextInTableCellCommand;

  factory RhwpCommand.deleteRangeInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int startCellParagraph,
    required int startOffset,
    required int endCellParagraph,
    required int endOffset,
  }) = RhwpDeleteRangeInTableCellCommand;

  factory RhwpCommand.splitParagraphInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
  }) = RhwpSplitParagraphInTableCellCommand;

  factory RhwpCommand.mergeParagraphInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) = RhwpMergeParagraphInTableCellCommand;

  factory RhwpCommand.getCellParagraphCount({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
  }) = RhwpGetCellParagraphCountCommand;

  factory RhwpCommand.getCellParagraphLength({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) = RhwpGetCellParagraphLengthCommand;

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
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
  }) = RhwpApplyCharFormatInTableCellCommand;

  factory RhwpCommand.deleteRange({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
  }) = RhwpDeleteRangeCommand;

  factory RhwpCommand.insertFootnote({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpInsertFootnoteCommand;

  factory RhwpCommand.getFootnoteAtCursor({
    required int section,
    required int paragraph,
    required int offset,
    required String direction,
  }) = RhwpGetFootnoteAtCursorCommand;

  factory RhwpCommand.getFootnoteInfo({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpGetFootnoteInfoCommand;

  factory RhwpCommand.deleteFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpDeleteFootnoteCommand;

  factory RhwpCommand.insertTextInFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int footnoteParagraph,
    required int offset,
    required String text,
  }) = RhwpInsertTextInFootnoteCommand;

  factory RhwpCommand.deleteTextInFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int footnoteParagraph,
    required int offset,
    required int count,
  }) = RhwpDeleteTextInFootnoteCommand;

  factory RhwpCommand.insertEquation({
    required int section,
    required int paragraph,
    required int offset,
    required String script,
    int fontSize,
    int color,
  }) = RhwpInsertEquationCommand;

  factory RhwpCommand.insertHyperlink({
    required int section,
    required int paragraph,
    required int offset,
    required String url,
    required String text,
  }) = RhwpInsertHyperlinkCommand;

  factory RhwpCommand.updateHyperlink({
    required int fieldId,
    required String url,
    required String text,
  }) = RhwpUpdateHyperlinkCommand;

  factory RhwpCommand.insertHiddenComment({
    required int section,
    required int paragraph,
    required int offset,
    required String text,
  }) = RhwpInsertHiddenCommentCommand;

  factory RhwpCommand.insertPicture({
    required int section,
    required int paragraph,
    required int offset,
    required Uint8List imageData,
    required int width,
    required int height,
    required int naturalWidthPx,
    required int naturalHeightPx,
    required String extension,
    String description,
  }) = RhwpInsertPictureCommand;

  factory RhwpCommand.insertShape({
    required int section,
    required int paragraph,
    required int offset,
    int width,
    int height,
    int horzOffset,
    int vertOffset,
    String shapeType,
    bool treatAsChar,
    String textWrap,
    bool lineFlipX,
    bool lineFlipY,
  }) = RhwpInsertShapeCommand;

  factory RhwpCommand.splitParagraph({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpSplitParagraphCommand;

  factory RhwpCommand.insertParagraph({
    required int section,
    required int paragraph,
  }) = RhwpInsertParagraphCommand;

  factory RhwpCommand.deleteParagraph({
    required int section,
    required int paragraph,
  }) = RhwpDeleteParagraphCommand;

  factory RhwpCommand.mergeParagraph({
    required int section,
    required int paragraph,
  }) = RhwpMergeParagraphCommand;

  factory RhwpCommand.getSectionCount() = RhwpGetSectionCountCommand;

  factory RhwpCommand.getParagraphCount({required int section}) =
      RhwpGetParagraphCountCommand;

  factory RhwpCommand.getParagraphLength({
    required int section,
    required int paragraph,
  }) = RhwpGetParagraphLengthCommand;

  factory RhwpCommand.insertPageBreak({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpInsertPageBreakCommand;

  factory RhwpCommand.insertColumnBreak({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpInsertColumnBreakCommand;

  factory RhwpCommand.getColumnDef({required int section}) =
      RhwpGetColumnDefCommand;

  factory RhwpCommand.setColumnDef({
    required int section,
    required int columnCount,
    required RhwpColumnType columnType,
    required bool sameWidth,
    required int spacing,
  }) = RhwpSetColumnDefCommand;

  factory RhwpCommand.getSectionDef({required int section}) =
      RhwpGetSectionDefCommand;

  factory RhwpCommand.setSectionDef({
    required int section,
    required Map<String, Object?> properties,
  }) = RhwpSetSectionDefCommand;

  factory RhwpCommand.insertNewNumber({
    required int section,
    required int paragraph,
    required int offset,
    required int startNumber,
  }) = RhwpInsertNewNumberCommand;

  factory RhwpCommand.getPageOfPosition({
    required int section,
    required int paragraph,
  }) = RhwpGetPageOfPositionCommand;

  factory RhwpCommand.getBookmarks() = RhwpGetBookmarksCommand;

  factory RhwpCommand.addBookmark({
    required int section,
    required int paragraph,
    required int offset,
    required String name,
  }) = RhwpAddBookmarkCommand;

  factory RhwpCommand.deleteBookmark({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpDeleteBookmarkCommand;

  factory RhwpCommand.renameBookmark({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String name,
  }) = RhwpRenameBookmarkCommand;

  factory RhwpCommand.getFieldList() = RhwpGetFieldListCommand;

  factory RhwpCommand.getFieldValue(int fieldId) = RhwpGetFieldValueCommand;

  factory RhwpCommand.getFieldValueByName(String name) =
      RhwpGetFieldValueByNameCommand;

  factory RhwpCommand.setFieldValue({
    required int fieldId,
    required String value,
  }) = RhwpSetFieldValueCommand;

  factory RhwpCommand.setFieldValueByName({
    required String name,
    required String value,
  }) = RhwpSetFieldValueByNameCommand;

  factory RhwpCommand.getFieldInfoAt({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpGetFieldInfoAtCommand;

  factory RhwpCommand.getFieldInfoAtInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox,
  }) = RhwpGetFieldInfoAtInTableCellCommand;

  factory RhwpCommand.setActiveField({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpSetActiveFieldCommand;

  factory RhwpCommand.setActiveFieldInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox,
  }) = RhwpSetActiveFieldInTableCellCommand;

  factory RhwpCommand.clearActiveField() = RhwpClearActiveFieldCommand;

  factory RhwpCommand.removeFieldAt({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpRemoveFieldAtCommand;

  factory RhwpCommand.removeFieldAtInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox,
  }) = RhwpRemoveFieldAtInTableCellCommand;

  factory RhwpCommand.getClickHereProperties(int fieldId) =
      RhwpGetClickHerePropertiesCommand;

  factory RhwpCommand.updateClickHereProperties({
    required int fieldId,
    required String guide,
    required String memo,
    required String name,
    required bool editable,
  }) = RhwpUpdateClickHerePropertiesCommand;

  factory RhwpCommand.insertTable({
    required int section,
    required int paragraph,
    required int offset,
    required int rows,
    required int columns,
  }) = RhwpInsertTableCommand;

  factory RhwpCommand.createTableEx({
    required int section,
    required int paragraph,
    required int offset,
    required int rows,
    required int columns,
    bool treatAsChar,
    List<int> columnWidths,
  }) = RhwpCreateTableExCommand;

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

  factory RhwpCommand.splitTableCellInto({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
    required int rows,
    required int columns,
    required bool equalRowHeight,
    required bool mergeFirst,
  }) = RhwpSplitTableCellIntoCommand;

  factory RhwpCommand.splitTableCellsInRange({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
    required int rows,
    required int columns,
    required bool equalRowHeight,
  }) = RhwpSplitTableCellsInRangeCommand;

  factory RhwpCommand.getTableProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpGetTablePropertiesCommand;

  factory RhwpCommand.setTableProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    int? cellSpacing,
    int? paddingLeft,
    int? paddingRight,
    int? paddingTop,
    int? paddingBottom,
    int? pageBreak,
    bool? repeatHeader,
    bool? hasCaption,
    int? captionDirection,
    int? captionVerticalAlign,
    int? captionWidth,
    int? captionSpacing,
  }) = RhwpSetTablePropertiesCommand;

  factory RhwpCommand.getCellProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
  }) = RhwpGetCellPropertiesCommand;

  factory RhwpCommand.setCellProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    int? width,
    int? height,
    int? paddingLeft,
    int? paddingRight,
    int? paddingTop,
    int? paddingBottom,
    int? verticalAlign,
    int? textDirection,
    bool? isHeader,
    bool? cellProtect,
  }) = RhwpSetCellPropertiesCommand;

  factory RhwpCommand.resizeTableCells({
    required int section,
    required int paragraph,
    required int controlIndex,
    required List<RhwpTableCellResize> updates,
  }) = RhwpResizeTableCellsCommand;

  factory RhwpCommand.evaluateTableFormula({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
    required String formula,
    bool writeResult = true,
  }) {
    return RhwpEvaluateTableFormulaCommand(
      section: section,
      paragraph: paragraph,
      controlIndex: controlIndex,
      row: row,
      column: column,
      formula: formula,
      writeResult: writeResult,
    );
  }

  factory RhwpCommand.deleteTableControl({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpDeleteTableControlCommand;

  factory RhwpCommand.moveTableOffset({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int deltaH,
    required int deltaV,
  }) = RhwpMoveTableOffsetCommand;

  factory RhwpCommand.deleteObjectControl({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String objectType,
  }) = RhwpDeleteObjectControlCommand;

  factory RhwpCommand.copyObjectControl({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpCopyObjectControlCommand;

  factory RhwpCommand.clipboardHasObjectControl() =
      RhwpClipboardHasObjectControlCommand;

  factory RhwpCommand.pasteObjectControl({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpPasteObjectControlCommand;

  factory RhwpCommand.exportSelectionHtml({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
  }) = RhwpExportSelectionHtmlCommand;

  factory RhwpCommand.exportSelectionInCellHtml({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int startCellParagraph,
    required int startOffset,
    required int endCellParagraph,
    required int endOffset,
  }) = RhwpExportSelectionInCellHtmlCommand;

  factory RhwpCommand.exportControlHtml({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) = RhwpExportControlHtmlCommand;

  factory RhwpCommand.pasteHtml({
    required int section,
    required int paragraph,
    required int offset,
    required String html,
  }) = RhwpPasteHtmlCommand;

  factory RhwpCommand.pasteHtmlInCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required String html,
  }) = RhwpPasteHtmlInCellCommand;

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
    int? rotationAngle,
    bool? horzFlip,
    bool? vertFlip,
    bool? hasCaption,
    String? captionDirection,
    String? captionVerticalAlign,
    int? captionWidth,
    int? captionSpacing,
    bool? captionIncludeMargin,
  }) = RhwpSetObjectPropertiesCommand;

  factory RhwpCommand.moveLineEndpoint({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startX,
    required int startY,
    required int endX,
    required int endY,
  }) = RhwpMoveLineEndpointCommand;

  factory RhwpCommand.applyCharFormat({
    required int section,
    required int paragraph,
    required int startOffset,
    required int endOffset,
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
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
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
    int? verticalAlign,
  }) = RhwpApplyTableCellStyleCommand;

  factory RhwpCommand.getStyleList() = RhwpGetStyleListCommand;

  factory RhwpCommand.getCharPropertiesAt({
    required int section,
    required int paragraph,
    required int offset,
  }) = RhwpGetCharPropertiesAtCommand;

  factory RhwpCommand.getCellCharPropertiesAt({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
  }) = RhwpGetCellCharPropertiesAtCommand;

  factory RhwpCommand.getParaPropertiesAt({
    required int section,
    required int paragraph,
  }) = RhwpGetParaPropertiesAtCommand;

  factory RhwpCommand.getCellParaPropertiesAt({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) = RhwpGetCellParaPropertiesAtCommand;

  factory RhwpCommand.applyStyle({
    required int section,
    required int paragraph,
    required int styleId,
  }) = RhwpApplyStyleCommand;

  factory RhwpCommand.applyCellStyle({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int styleId,
  }) = RhwpApplyCellStyleCommand;

  factory RhwpCommand.createHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
  }) = RhwpCreateHeaderFooterCommand;

  factory RhwpCommand.getHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
  }) = RhwpGetHeaderFooterCommand;

  factory RhwpCommand.getHeaderFooterList({
    required int section,
    required bool isHeader,
    int applyTo,
  }) = RhwpGetHeaderFooterListCommand;

  factory RhwpCommand.deleteHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
  }) = RhwpDeleteHeaderFooterCommand;

  factory RhwpCommand.insertTextInHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
    required int paragraph,
    required int offset,
    required String text,
  }) = RhwpInsertTextInHeaderFooterCommand;

  factory RhwpCommand.deleteTextInHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo,
    required int paragraph,
    required int offset,
    required int count,
  }) = RhwpDeleteTextInHeaderFooterCommand;

  factory RhwpCommand.getPageSetup({required int section}) =
      RhwpGetPageSetupCommand;

  factory RhwpCommand.setPageSetup({
    required int section,
    int? width,
    int? height,
    int? marginLeft,
    int? marginRight,
    int? marginTop,
    int? marginBottom,
    int? marginHeader,
    int? marginFooter,
    int? marginGutter,
    bool? landscape,
    int? binding,
  }) = RhwpSetPageSetupCommand;

  factory RhwpCommand.getPageBorderFill({required int section}) =
      RhwpGetPageBorderFillCommand;

  factory RhwpCommand.setPageBorderFill({
    required int section,
    required Map<String, Object?> properties,
  }) = RhwpSetPageBorderFillCommand;

  factory RhwpCommand.getPageHide({
    required int section,
    required int paragraph,
  }) = RhwpGetPageHideCommand;

  factory RhwpCommand.setPageHide({
    required int section,
    required int paragraph,
    bool hideHeader,
    bool hideFooter,
    bool hideMasterPage,
    bool hideBorder,
    bool hideFill,
    bool hidePageNumber,
  }) = RhwpSetPageHideCommand;

  factory RhwpCommand.saveSnapshot() = RhwpSaveSnapshotCommand;

  factory RhwpCommand.restoreSnapshot(int snapshotId) =
      RhwpRestoreSnapshotCommand;

  factory RhwpCommand.discardSnapshot(int snapshotId) =
      RhwpDiscardSnapshotCommand;

  factory RhwpCommand.convertToEditable() = RhwpConvertToEditableCommand;

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

class RhwpGetTextInTableCellCommand extends RhwpCommand {
  const RhwpGetTextInTableCellCommand({
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
    'type': 'getTextInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'count': count,
  };
}

class RhwpDeleteRangeInTableCellCommand extends RhwpCommand {
  const RhwpDeleteRangeInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.startCellParagraph,
    required this.startOffset,
    required this.endCellParagraph,
    required this.endOffset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int startCellParagraph;
  final int startOffset;
  final int endCellParagraph;
  final int endOffset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteRangeInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'startCellParagraph': startCellParagraph,
    'startOffset': startOffset,
    'endCellParagraph': endCellParagraph,
    'endOffset': endOffset,
  };
}

class RhwpSplitParagraphInTableCellCommand extends RhwpCommand {
  const RhwpSplitParagraphInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'splitParagraphInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
  };
}

class RhwpMergeParagraphInTableCellCommand extends RhwpCommand {
  const RhwpMergeParagraphInTableCellCommand({
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

  @override
  Map<String, Object?> toJson() => {
    'type': 'mergeParagraphInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
  };
}

class RhwpGetCellParagraphCountCommand extends RhwpCommand {
  const RhwpGetCellParagraphCountCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCellParagraphCount',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
  };
}

class RhwpGetCellParagraphLengthCommand extends RhwpCommand {
  const RhwpGetCellParagraphLengthCommand({
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

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCellParagraphLength',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
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
    this.superscript,
    this.subscript,
    this.emboss,
    this.engrave,
    this.fontFamily,
    this.fontSize,
    this.textColor,
    this.shadeColor,
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
  final bool? superscript;
  final bool? subscript;
  final bool? emboss;
  final bool? engrave;
  final String? fontFamily;
  final int? fontSize;
  final String? textColor;
  final String? shadeColor;

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
      if (superscript != null) 'superscript': superscript,
      if (subscript != null) 'subscript': subscript,
      if (emboss != null) 'emboss': emboss,
      if (engrave != null) 'engrave': engrave,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
      if (shadeColor != null) 'shadeColor': shadeColor,
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

class RhwpInsertFootnoteCommand extends RhwpCommand {
  const RhwpInsertFootnoteCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertFootnote',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpGetFootnoteAtCursorCommand extends RhwpCommand {
  const RhwpGetFootnoteAtCursorCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.direction,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String direction;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFootnoteAtCursor',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'direction': direction,
  };
}

class RhwpGetFootnoteInfoCommand extends RhwpCommand {
  const RhwpGetFootnoteInfoCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFootnoteInfo',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpDeleteFootnoteCommand extends RhwpCommand {
  const RhwpDeleteFootnoteCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteFootnote',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpInsertTextInFootnoteCommand extends RhwpCommand {
  const RhwpInsertTextInFootnoteCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.footnoteParagraph,
    required this.offset,
    required this.text,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int footnoteParagraph;
  final int offset;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTextInFootnote',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'footnoteParagraph': footnoteParagraph,
    'offset': offset,
    'text': text,
  };
}

class RhwpDeleteTextInFootnoteCommand extends RhwpCommand {
  const RhwpDeleteTextInFootnoteCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.footnoteParagraph,
    required this.offset,
    required this.count,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int footnoteParagraph;
  final int offset;
  final int count;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTextInFootnote',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'footnoteParagraph': footnoteParagraph,
    'offset': offset,
    'count': count,
  };
}

class RhwpInsertEquationCommand extends RhwpCommand {
  const RhwpInsertEquationCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.script,
    this.fontSize = 1000,
    this.color = 0,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String script;
  final int fontSize;
  final int color;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertEquation',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'script': script,
    'fontSize': fontSize,
    'color': color,
  };
}

class RhwpInsertHyperlinkCommand extends RhwpCommand {
  const RhwpInsertHyperlinkCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.url,
    required this.text,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String url;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertHyperlink',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'url': url,
    'text': text,
  };
}

class RhwpUpdateHyperlinkCommand extends RhwpCommand {
  const RhwpUpdateHyperlinkCommand({
    required this.fieldId,
    required this.url,
    required this.text,
  });

  final int fieldId;
  final String url;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'updateHyperlink',
    'fieldId': fieldId,
    'url': url,
    'text': text,
  };
}

class RhwpInsertHiddenCommentCommand extends RhwpCommand {
  const RhwpInsertHiddenCommentCommand({
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
    'type': 'insertHiddenComment',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'text': text,
  };
}

class RhwpInsertPictureCommand extends RhwpCommand {
  const RhwpInsertPictureCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.imageData,
    required this.width,
    required this.height,
    required this.naturalWidthPx,
    required this.naturalHeightPx,
    required this.extension,
    this.description = '',
  });

  final int section;
  final int paragraph;
  final int offset;
  final Uint8List imageData;
  final int width;
  final int height;
  final int naturalWidthPx;
  final int naturalHeightPx;
  final String extension;
  final String description;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertPicture',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'imageData': imageData.toList(growable: false),
    'width': width,
    'height': height,
    'naturalWidthPx': naturalWidthPx,
    'naturalHeightPx': naturalHeightPx,
    'extension': extension,
    'description': description,
  };
}

class RhwpInsertShapeCommand extends RhwpCommand {
  const RhwpInsertShapeCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    this.width = 9000,
    this.height = 6750,
    this.horzOffset = 0,
    this.vertOffset = 0,
    this.shapeType = 'rectangle',
    this.treatAsChar = false,
    this.textWrap = 'InFrontOfText',
    this.lineFlipX = false,
    this.lineFlipY = false,
  });

  final int section;
  final int paragraph;
  final int offset;
  final int width;
  final int height;
  final int horzOffset;
  final int vertOffset;
  final String shapeType;
  final bool treatAsChar;
  final String textWrap;
  final bool lineFlipX;
  final bool lineFlipY;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertShape',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'width': width,
    'height': height,
    'horzOffset': horzOffset,
    'vertOffset': vertOffset,
    'shapeType': shapeType,
    'treatAsChar': treatAsChar,
    'textWrap': textWrap,
    'lineFlipX': lineFlipX,
    'lineFlipY': lineFlipY,
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

class RhwpInsertParagraphCommand extends RhwpCommand {
  const RhwpInsertParagraphCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertParagraph',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpDeleteParagraphCommand extends RhwpCommand {
  const RhwpDeleteParagraphCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteParagraph',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpMergeParagraphCommand extends RhwpCommand {
  const RhwpMergeParagraphCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'mergeParagraph',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpGetSectionCountCommand extends RhwpCommand {
  const RhwpGetSectionCountCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'getSectionCount'};
}

class RhwpGetParagraphCountCommand extends RhwpCommand {
  const RhwpGetParagraphCountCommand({required this.section});

  final int section;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getParagraphCount',
    'section': section,
  };
}

class RhwpGetParagraphLengthCommand extends RhwpCommand {
  const RhwpGetParagraphLengthCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getParagraphLength',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpInsertPageBreakCommand extends RhwpCommand {
  const RhwpInsertPageBreakCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertPageBreak',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpInsertColumnBreakCommand extends RhwpCommand {
  const RhwpInsertColumnBreakCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertColumnBreak',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpGetColumnDefCommand extends RhwpCommand {
  const RhwpGetColumnDefCommand({required this.section});

  final int section;

  @override
  Map<String, Object?> toJson() => {'type': 'getColumnDef', 'section': section};
}

class RhwpSetColumnDefCommand extends RhwpCommand {
  const RhwpSetColumnDefCommand({
    required this.section,
    required this.columnCount,
    this.columnType = RhwpColumnType.normal,
    this.sameWidth = true,
    this.spacing = 283,
  });

  final int section;
  final int columnCount;
  final RhwpColumnType columnType;
  final bool sameWidth;
  final int spacing;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setColumnDef',
    'section': section,
    'columnCount': columnCount,
    'columnType': columnType.commandValue,
    'sameWidth': sameWidth,
    'spacing': spacing,
  };
}

class RhwpGetSectionDefCommand extends RhwpCommand {
  const RhwpGetSectionDefCommand({required this.section});

  final int section;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getSectionDef',
    'section': section,
  };
}

class RhwpSetSectionDefCommand extends RhwpCommand {
  const RhwpSetSectionDefCommand({
    required this.section,
    required this.properties,
  });

  final int section;
  final Map<String, Object?> properties;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setSectionDef',
    'section': section,
    'properties': properties,
  };
}

class RhwpInsertNewNumberCommand extends RhwpCommand {
  const RhwpInsertNewNumberCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.startNumber,
  });

  final int section;
  final int paragraph;
  final int offset;
  final int startNumber;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertNewNumber',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'startNumber': startNumber,
  };
}

class RhwpGetBookmarksCommand extends RhwpCommand {
  const RhwpGetBookmarksCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'getBookmarks'};
}

class RhwpGetPageOfPositionCommand extends RhwpCommand {
  const RhwpGetPageOfPositionCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getPageOfPosition',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpAddBookmarkCommand extends RhwpCommand {
  const RhwpAddBookmarkCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.name,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String name;

  @override
  Map<String, Object?> toJson() => {
    'type': 'addBookmark',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'name': name,
  };
}

class RhwpDeleteBookmarkCommand extends RhwpCommand {
  const RhwpDeleteBookmarkCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteBookmark',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpRenameBookmarkCommand extends RhwpCommand {
  const RhwpRenameBookmarkCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.name,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String name;

  @override
  Map<String, Object?> toJson() => {
    'type': 'renameBookmark',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'name': name,
  };
}

class RhwpGetFieldListCommand extends RhwpCommand {
  const RhwpGetFieldListCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'getFieldList'};
}

class RhwpGetFieldValueCommand extends RhwpCommand {
  const RhwpGetFieldValueCommand(this.fieldId);

  final int fieldId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFieldValue',
    'fieldId': fieldId,
  };
}

class RhwpGetFieldValueByNameCommand extends RhwpCommand {
  const RhwpGetFieldValueByNameCommand(this.name);

  final String name;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFieldValueByName',
    'name': name,
  };
}

class RhwpSetFieldValueCommand extends RhwpCommand {
  const RhwpSetFieldValueCommand({required this.fieldId, required this.value});

  final int fieldId;
  final String value;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setFieldValue',
    'fieldId': fieldId,
    'value': value,
  };
}

class RhwpSetFieldValueByNameCommand extends RhwpCommand {
  const RhwpSetFieldValueByNameCommand({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setFieldValueByName',
    'name': name,
    'value': value,
  };
}

class RhwpGetFieldInfoAtCommand extends RhwpCommand {
  const RhwpGetFieldInfoAtCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFieldInfoAt',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpGetFieldInfoAtInTableCellCommand extends RhwpCommand {
  const RhwpGetFieldInfoAtInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    this.isTextBox = false,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final bool isTextBox;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getFieldInfoAtInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'isTextBox': isTextBox,
  };
}

class RhwpSetActiveFieldCommand extends RhwpCommand {
  const RhwpSetActiveFieldCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setActiveField',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpSetActiveFieldInTableCellCommand extends RhwpCommand {
  const RhwpSetActiveFieldInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    this.isTextBox = false,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final bool isTextBox;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setActiveFieldInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'isTextBox': isTextBox,
  };
}

class RhwpClearActiveFieldCommand extends RhwpCommand {
  const RhwpClearActiveFieldCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'clearActiveField'};
}

class RhwpRemoveFieldAtCommand extends RhwpCommand {
  const RhwpRemoveFieldAtCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'removeFieldAt',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpRemoveFieldAtInTableCellCommand extends RhwpCommand {
  const RhwpRemoveFieldAtInTableCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    this.isTextBox = false,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final bool isTextBox;

  @override
  Map<String, Object?> toJson() => {
    'type': 'removeFieldAtInTableCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'isTextBox': isTextBox,
  };
}

class RhwpGetClickHerePropertiesCommand extends RhwpCommand {
  const RhwpGetClickHerePropertiesCommand(this.fieldId);

  final int fieldId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getClickHereProperties',
    'fieldId': fieldId,
  };
}

class RhwpUpdateClickHerePropertiesCommand extends RhwpCommand {
  const RhwpUpdateClickHerePropertiesCommand({
    required this.fieldId,
    required this.guide,
    required this.memo,
    required this.name,
    required this.editable,
  });

  final int fieldId;
  final String guide;
  final String memo;
  final String name;
  final bool editable;

  @override
  Map<String, Object?> toJson() => {
    'type': 'updateClickHereProperties',
    'fieldId': fieldId,
    'guide': guide,
    'memo': memo,
    'name': name,
    'editable': editable,
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

class RhwpCreateTableExCommand extends RhwpCommand {
  const RhwpCreateTableExCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.rows,
    required this.columns,
    this.treatAsChar = false,
    this.columnWidths = const [],
  });

  final int section;
  final int paragraph;
  final int offset;
  final int rows;
  final int columns;
  final bool treatAsChar;
  final List<int> columnWidths;

  @override
  Map<String, Object?> toJson() => {
    'type': 'createTableEx',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'rows': rows,
    'columns': columns,
    'treatAsChar': treatAsChar,
    if (columnWidths.isNotEmpty)
      'columnWidths': columnWidths.toList(growable: false),
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

class RhwpSplitTableCellIntoCommand extends RhwpCommand {
  const RhwpSplitTableCellIntoCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    required this.column,
    required this.rows,
    required this.columns,
    required this.equalRowHeight,
    required this.mergeFirst,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;
  final int column;
  final int rows;
  final int columns;
  final bool equalRowHeight;
  final bool mergeFirst;

  @override
  Map<String, Object?> toJson() => {
    'type': 'splitTableCellInto',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'row': row,
    'column': column,
    'rows': rows,
    'columns': columns,
    'equalRowHeight': equalRowHeight,
    'mergeFirst': mergeFirst,
  };
}

class RhwpSplitTableCellsInRangeCommand extends RhwpCommand {
  const RhwpSplitTableCellsInRangeCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
    required this.rows,
    required this.columns,
    required this.equalRowHeight,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;
  final int rows;
  final int columns;
  final bool equalRowHeight;

  @override
  Map<String, Object?> toJson() => {
    'type': 'splitTableCellsInRange',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'startRow': startRow,
    'startColumn': startColumn,
    'endRow': endRow,
    'endColumn': endColumn,
    'rows': rows,
    'columns': columns,
    'equalRowHeight': equalRowHeight,
  };
}

class RhwpGetTablePropertiesCommand extends RhwpCommand {
  const RhwpGetTablePropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getTableProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpSetTablePropertiesCommand extends RhwpCommand {
  const RhwpSetTablePropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    this.cellSpacing,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.pageBreak,
    this.repeatHeader,
    this.hasCaption,
    this.captionDirection,
    this.captionVerticalAlign,
    this.captionWidth,
    this.captionSpacing,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int? cellSpacing;
  final int? paddingLeft;
  final int? paddingRight;
  final int? paddingTop;
  final int? paddingBottom;
  final int? pageBreak;
  final bool? repeatHeader;
  final bool? hasCaption;
  final int? captionDirection;
  final int? captionVerticalAlign;
  final int? captionWidth;
  final int? captionSpacing;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setTableProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'properties': {
      if (cellSpacing != null) 'cellSpacing': cellSpacing,
      if (paddingLeft != null) 'paddingLeft': paddingLeft,
      if (paddingRight != null) 'paddingRight': paddingRight,
      if (paddingTop != null) 'paddingTop': paddingTop,
      if (paddingBottom != null) 'paddingBottom': paddingBottom,
      if (pageBreak != null) 'pageBreak': pageBreak,
      if (repeatHeader != null) 'repeatHeader': repeatHeader,
      if (hasCaption != null) 'hasCaption': hasCaption,
      if (captionDirection != null) 'captionDirection': captionDirection,
      if (captionVerticalAlign != null)
        'captionVertAlign': captionVerticalAlign,
      if (captionWidth != null) 'captionWidth': captionWidth,
      if (captionSpacing != null) 'captionSpacing': captionSpacing,
    },
  };
}

class RhwpGetCellPropertiesCommand extends RhwpCommand {
  const RhwpGetCellPropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCellProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
  };
}

class RhwpSetCellPropertiesCommand extends RhwpCommand {
  const RhwpSetCellPropertiesCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    this.width,
    this.height,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.verticalAlign,
    this.textDirection,
    this.isHeader,
    this.cellProtect,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int? width;
  final int? height;
  final int? paddingLeft;
  final int? paddingRight;
  final int? paddingTop;
  final int? paddingBottom;
  final int? verticalAlign;
  final int? textDirection;
  final bool? isHeader;
  final bool? cellProtect;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setCellProperties',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'properties': {
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (paddingLeft != null) 'paddingLeft': paddingLeft,
      if (paddingRight != null) 'paddingRight': paddingRight,
      if (paddingTop != null) 'paddingTop': paddingTop,
      if (paddingBottom != null) 'paddingBottom': paddingBottom,
      if (verticalAlign != null) 'verticalAlign': verticalAlign,
      if (textDirection != null) 'textDirection': textDirection,
      if (isHeader != null) 'isHeader': isHeader,
      if (cellProtect != null) 'cellProtect': cellProtect,
    },
  };
}

class RhwpResizeTableCellsCommand extends RhwpCommand {
  const RhwpResizeTableCellsCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.updates,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final List<RhwpTableCellResize> updates;

  @override
  Map<String, Object?> toJson() => {
    'type': 'resizeTableCells',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'updates': [for (final update in updates) update.toJson()],
  };
}

class RhwpEvaluateTableFormulaCommand extends RhwpCommand {
  const RhwpEvaluateTableFormulaCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.row,
    required this.column,
    required this.formula,
    this.writeResult = true,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int row;
  final int column;
  final String formula;
  final bool writeResult;

  @override
  Map<String, Object?> toJson() => {
    'type': 'evaluateTableFormula',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'row': row,
    'column': column,
    'formula': formula,
    'writeResult': writeResult,
  };
}

class RhwpDeleteTableControlCommand extends RhwpCommand {
  const RhwpDeleteTableControlCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTableControl',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpMoveTableOffsetCommand extends RhwpCommand {
  const RhwpMoveTableOffsetCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.deltaH,
    required this.deltaV,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int deltaH;
  final int deltaV;

  @override
  Map<String, Object?> toJson() => {
    'type': 'moveTableOffset',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'deltaH': deltaH,
    'deltaV': deltaV,
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

class RhwpCopyObjectControlCommand extends RhwpCommand {
  const RhwpCopyObjectControlCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'copyObjectControl',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpClipboardHasObjectControlCommand extends RhwpCommand {
  const RhwpClipboardHasObjectControlCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'clipboardHasObjectControl'};
}

class RhwpPasteObjectControlCommand extends RhwpCommand {
  const RhwpPasteObjectControlCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'pasteObjectControl',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpExportSelectionHtmlCommand extends RhwpCommand {
  const RhwpExportSelectionHtmlCommand({
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
    'type': 'exportSelectionHtml',
    'section': section,
    'startParagraph': startParagraph,
    'startOffset': startOffset,
    'endParagraph': endParagraph,
    'endOffset': endOffset,
  };
}

class RhwpExportSelectionInCellHtmlCommand extends RhwpCommand {
  const RhwpExportSelectionInCellHtmlCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.startCellParagraph,
    required this.startOffset,
    required this.endCellParagraph,
    required this.endOffset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int startCellParagraph;
  final int startOffset;
  final int endCellParagraph;
  final int endOffset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'exportSelectionInCellHtml',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'startCellParagraph': startCellParagraph,
    'startOffset': startOffset,
    'endCellParagraph': endCellParagraph,
    'endOffset': endOffset,
  };
}

class RhwpExportControlHtmlCommand extends RhwpCommand {
  const RhwpExportControlHtmlCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
  });

  final int section;
  final int paragraph;
  final int controlIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'exportControlHtml',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
  };
}

class RhwpPasteHtmlCommand extends RhwpCommand {
  const RhwpPasteHtmlCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
    required this.html,
  });

  final int section;
  final int paragraph;
  final int offset;
  final String html;

  @override
  Map<String, Object?> toJson() => {
    'type': 'pasteHtml',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
    'html': html,
  };
}

class RhwpPasteHtmlInCellCommand extends RhwpCommand {
  const RhwpPasteHtmlInCellCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
    required this.html,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;
  final String html;

  @override
  Map<String, Object?> toJson() => {
    'type': 'pasteHtmlInCell',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
    'html': html,
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
    this.rotationAngle,
    this.horzFlip,
    this.vertFlip,
    this.hasCaption,
    this.captionDirection,
    this.captionVerticalAlign,
    this.captionWidth,
    this.captionSpacing,
    this.captionIncludeMargin,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final String objectType;
  final int? width;
  final int? height;
  final int? horzOffset;
  final int? vertOffset;
  final int? rotationAngle;
  final bool? horzFlip;
  final bool? vertFlip;
  final bool? hasCaption;
  final String? captionDirection;
  final String? captionVerticalAlign;
  final int? captionWidth;
  final int? captionSpacing;
  final bool? captionIncludeMargin;

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
      if (rotationAngle != null) 'rotationAngle': rotationAngle,
      if (horzFlip != null) 'horzFlip': horzFlip,
      if (vertFlip != null) 'vertFlip': vertFlip,
      if (hasCaption != null) 'hasCaption': hasCaption,
      if (captionDirection != null) 'captionDirection': captionDirection,
      if (captionVerticalAlign != null)
        'captionVertAlign': captionVerticalAlign,
      if (captionWidth != null) 'captionWidth': captionWidth,
      if (captionSpacing != null) 'captionSpacing': captionSpacing,
      if (captionIncludeMargin != null)
        'captionIncludeMargin': captionIncludeMargin,
    },
  };
}

class RhwpMoveLineEndpointCommand extends RhwpCommand {
  const RhwpMoveLineEndpointCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int startX;
  final int startY;
  final int endX;
  final int endY;

  @override
  Map<String, Object?> toJson() => {
    'type': 'moveLineEndpoint',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
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
    this.superscript,
    this.subscript,
    this.emboss,
    this.engrave,
    this.fontFamily,
    this.fontSize,
    this.textColor,
    this.shadeColor,
  });

  final int section;
  final int paragraph;
  final int startOffset;
  final int endOffset;
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
      if (superscript != null) 'superscript': superscript,
      if (subscript != null) 'subscript': subscript,
      if (emboss != null) 'emboss': emboss,
      if (engrave != null) 'engrave': engrave,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
      if (shadeColor != null) 'shadeColor': shadeColor,
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
    this.superscript,
    this.subscript,
    this.emboss,
    this.engrave,
    this.fontFamily,
    this.fontSize,
    this.textColor,
    this.shadeColor,
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
  final bool? superscript;
  final bool? subscript;
  final bool? emboss;
  final bool? engrave;
  final String? fontFamily;
  final int? fontSize;
  final String? textColor;
  final String? shadeColor;

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
      if (superscript != null) 'superscript': superscript,
      if (subscript != null) 'subscript': subscript,
      if (emboss != null) 'emboss': emboss,
      if (engrave != null) 'engrave': engrave,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (textColor != null) 'textColor': textColor,
      if (shadeColor != null) 'shadeColor': shadeColor,
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
    this.verticalAlign,
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
  final int? verticalAlign;

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
      verticalAlign: verticalAlign,
    ),
  };
}

class RhwpGetStyleListCommand extends RhwpCommand {
  const RhwpGetStyleListCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'getStyleList'};
}

class RhwpGetCharPropertiesAtCommand extends RhwpCommand {
  const RhwpGetCharPropertiesAtCommand({
    required this.section,
    required this.paragraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCharPropertiesAt',
    'section': section,
    'paragraph': paragraph,
    'offset': offset,
  };
}

class RhwpGetCellCharPropertiesAtCommand extends RhwpCommand {
  const RhwpGetCellCharPropertiesAtCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.offset,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int offset;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCellCharPropertiesAt',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'offset': offset,
  };
}

class RhwpGetParaPropertiesAtCommand extends RhwpCommand {
  const RhwpGetParaPropertiesAtCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getParaPropertiesAt',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpGetCellParaPropertiesAtCommand extends RhwpCommand {
  const RhwpGetCellParaPropertiesAtCommand({
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

  @override
  Map<String, Object?> toJson() => {
    'type': 'getCellParaPropertiesAt',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
  };
}

class RhwpApplyStyleCommand extends RhwpCommand {
  const RhwpApplyStyleCommand({
    required this.section,
    required this.paragraph,
    required this.styleId,
  });

  final int section;
  final int paragraph;
  final int styleId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyStyle',
    'section': section,
    'paragraph': paragraph,
    'styleId': styleId,
  };
}

class RhwpApplyCellStyleCommand extends RhwpCommand {
  const RhwpApplyCellStyleCommand({
    required this.section,
    required this.paragraph,
    required this.controlIndex,
    required this.cellIndex,
    required this.cellParagraph,
    required this.styleId,
  });

  final int section;
  final int paragraph;
  final int controlIndex;
  final int cellIndex;
  final int cellParagraph;
  final int styleId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'applyCellStyle',
    'section': section,
    'paragraph': paragraph,
    'controlIndex': controlIndex,
    'cellIndex': cellIndex,
    'cellParagraph': cellParagraph,
    'styleId': styleId,
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
  int? verticalAlign,
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
  if (verticalAlign != null) properties['verticalAlign'] = verticalAlign;
  return properties;
}

class RhwpSetFileNameCommand extends RhwpCommand {
  const RhwpSetFileNameCommand(this.name);

  final String name;

  @override
  Map<String, Object?> toJson() => {'type': 'setFileName', 'name': name};
}

class RhwpConvertToEditableCommand extends RhwpCommand {
  const RhwpConvertToEditableCommand();

  @override
  Map<String, Object?> toJson() => {'type': 'convertToEditable'};
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

class RhwpGetHeaderFooterCommand extends RhwpCommand {
  const RhwpGetHeaderFooterCommand({
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
    'type': 'getHeaderFooter',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
  };
}

class RhwpGetHeaderFooterListCommand extends RhwpCommand {
  const RhwpGetHeaderFooterListCommand({
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
    'type': 'getHeaderFooterList',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
  };
}

class RhwpDeleteHeaderFooterCommand extends RhwpCommand {
  const RhwpDeleteHeaderFooterCommand({
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
    'type': 'deleteHeaderFooter',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
  };
}

class RhwpInsertTextInHeaderFooterCommand extends RhwpCommand {
  const RhwpInsertTextInHeaderFooterCommand({
    required this.section,
    required this.isHeader,
    this.applyTo = 0,
    required this.paragraph,
    required this.offset,
    required this.text,
  });

  final int section;
  final bool isHeader;

  /// 0 applies to both pages, 1 to even pages, and 2 to odd pages.
  final int applyTo;
  final int paragraph;
  final int offset;
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insertTextInHeaderFooter',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
    'paragraph': paragraph,
    'offset': offset,
    'text': text,
  };
}

class RhwpDeleteTextInHeaderFooterCommand extends RhwpCommand {
  const RhwpDeleteTextInHeaderFooterCommand({
    required this.section,
    required this.isHeader,
    this.applyTo = 0,
    required this.paragraph,
    required this.offset,
    required this.count,
  });

  final int section;
  final bool isHeader;

  /// 0 applies to both pages, 1 to even pages, and 2 to odd pages.
  final int applyTo;
  final int paragraph;
  final int offset;
  final int count;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deleteTextInHeaderFooter',
    'section': section,
    'isHeader': isHeader,
    'applyTo': applyTo,
    'paragraph': paragraph,
    'offset': offset,
    'count': count,
  };
}

class RhwpGetPageSetupCommand extends RhwpCommand {
  const RhwpGetPageSetupCommand({required this.section});

  final int section;

  @override
  Map<String, Object?> toJson() => {'type': 'getPageSetup', 'section': section};
}

class RhwpSetPageSetupCommand extends RhwpCommand {
  const RhwpSetPageSetupCommand({
    required this.section,
    this.width,
    this.height,
    this.marginLeft,
    this.marginRight,
    this.marginTop,
    this.marginBottom,
    this.marginHeader,
    this.marginFooter,
    this.marginGutter,
    this.landscape,
    this.binding,
  });

  final int section;
  final int? width;
  final int? height;
  final int? marginLeft;
  final int? marginRight;
  final int? marginTop;
  final int? marginBottom;
  final int? marginHeader;
  final int? marginFooter;
  final int? marginGutter;
  final bool? landscape;
  final int? binding;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setPageSetup',
    'section': section,
    'properties': _pageSetupProperties(
      width: width,
      height: height,
      marginLeft: marginLeft,
      marginRight: marginRight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      marginHeader: marginHeader,
      marginFooter: marginFooter,
      marginGutter: marginGutter,
      landscape: landscape,
      binding: binding,
    ),
  };
}

class RhwpGetPageBorderFillCommand extends RhwpCommand {
  const RhwpGetPageBorderFillCommand({required this.section});

  final int section;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getPageBorderFill',
    'section': section,
  };
}

class RhwpSetPageBorderFillCommand extends RhwpCommand {
  const RhwpSetPageBorderFillCommand({
    required this.section,
    required this.properties,
  });

  final int section;
  final Map<String, Object?> properties;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setPageBorderFill',
    'section': section,
    'properties': properties,
  };
}

class RhwpGetPageHideCommand extends RhwpCommand {
  const RhwpGetPageHideCommand({
    required this.section,
    required this.paragraph,
  });

  final int section;
  final int paragraph;

  @override
  Map<String, Object?> toJson() => {
    'type': 'getPageHide',
    'section': section,
    'paragraph': paragraph,
  };
}

class RhwpSetPageHideCommand extends RhwpCommand {
  const RhwpSetPageHideCommand({
    required this.section,
    required this.paragraph,
    this.hideHeader = false,
    this.hideFooter = false,
    this.hideMasterPage = false,
    this.hideBorder = false,
    this.hideFill = false,
    this.hidePageNumber = false,
  });

  final int section;
  final int paragraph;
  final bool hideHeader;
  final bool hideFooter;
  final bool hideMasterPage;
  final bool hideBorder;
  final bool hideFill;
  final bool hidePageNumber;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setPageHide',
    'section': section,
    'paragraph': paragraph,
    'hideHeader': hideHeader,
    'hideFooter': hideFooter,
    'hideMasterPage': hideMasterPage,
    'hideBorder': hideBorder,
    'hideFill': hideFill,
    'hidePageNum': hidePageNumber,
  };
}

Map<String, Object?> _pageSetupProperties({
  int? width,
  int? height,
  int? marginLeft,
  int? marginRight,
  int? marginTop,
  int? marginBottom,
  int? marginHeader,
  int? marginFooter,
  int? marginGutter,
  bool? landscape,
  int? binding,
}) {
  final properties = <String, Object?>{};
  if (width != null) properties['width'] = width;
  if (height != null) properties['height'] = height;
  if (marginLeft != null) properties['marginLeft'] = marginLeft;
  if (marginRight != null) properties['marginRight'] = marginRight;
  if (marginTop != null) properties['marginTop'] = marginTop;
  if (marginBottom != null) properties['marginBottom'] = marginBottom;
  if (marginHeader != null) properties['marginHeader'] = marginHeader;
  if (marginFooter != null) properties['marginFooter'] = marginFooter;
  if (marginGutter != null) properties['marginGutter'] = marginGutter;
  if (landscape != null) properties['landscape'] = landscape;
  if (binding != null) properties['binding'] = binding;
  return properties;
}

Map<String, Object?> _pageBorderFillProperties({
  int? attr,
  int? spacingLeft,
  int? spacingRight,
  int? spacingTop,
  int? spacingBottom,
  int? borderFillId,
  RhwpBorderLine? borderLeft,
  RhwpBorderLine? borderRight,
  RhwpBorderLine? borderTop,
  RhwpBorderLine? borderBottom,
  String? fillType,
  String? fillColor,
  String? patternColor,
  int? patternType,
  bool clearFill = false,
}) {
  final properties = <String, Object?>{};
  if (attr != null) properties['attr'] = attr;
  if (spacingLeft != null) properties['spacingLeft'] = spacingLeft;
  if (spacingRight != null) properties['spacingRight'] = spacingRight;
  if (spacingTop != null) properties['spacingTop'] = spacingTop;
  if (spacingBottom != null) properties['spacingBottom'] = spacingBottom;
  if (borderFillId != null) properties['borderFillId'] = borderFillId;
  if (borderLeft != null) properties['borderLeft'] = borderLeft.toJson();
  if (borderRight != null) properties['borderRight'] = borderRight.toJson();
  if (borderTop != null) properties['borderTop'] = borderTop.toJson();
  if (borderBottom != null) properties['borderBottom'] = borderBottom.toJson();
  if (clearFill) {
    properties['fillType'] = 'none';
  } else if (fillType != null) {
    properties['fillType'] = fillType;
  } else if (fillColor != null) {
    properties['fillType'] = 'solid';
  }
  if (fillColor != null) properties['fillColor'] = fillColor;
  if (patternColor != null) properties['patternColor'] = patternColor;
  if (patternType != null) properties['patternType'] = patternType;
  return properties;
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
    RhwpExportIntent intent = RhwpExportIntent.export,
  }) async {
    _ensureOpen();
    final metadata = await this.metadata();
    final bytes = await export(format, page: page);
    return RhwpExportedDocument.fromBytes(
      format: format,
      bytes: bytes,
      sourceFileName: sourceFileName ?? metadata.fileName,
      page: page,
      intent: intent,
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

  Future<String> textInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required int count,
  }) {
    return apply(
      RhwpCommand.getTextInTableCell(
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

  Future<String> deleteRangeInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int startCellParagraph,
    required int startOffset,
    required int endCellParagraph,
    required int endOffset,
  }) {
    return apply(
      RhwpCommand.deleteRangeInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        startCellParagraph: startCellParagraph,
        startOffset: startOffset,
        endCellParagraph: endCellParagraph,
        endOffset: endOffset,
      ),
    );
  }

  Future<String> splitParagraphInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.splitParagraphInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
      ),
    );
  }

  Future<String> mergeParagraphInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) {
    return apply(
      RhwpCommand.mergeParagraphInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
      ),
    );
  }

  Future<int> cellParagraphCount({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
  }) async {
    final result = await apply(
      RhwpCommand.getCellParagraphCount(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
      ),
    );
    return _readIntResult(result, 'count');
  }

  Future<int> cellParagraphLength({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) async {
    final result = await apply(
      RhwpCommand.getCellParagraphLength(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
      ),
    );
    return _readIntResult(result, 'length');
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
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
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
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
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

  Future<String> insertFootnote({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.insertFootnote(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<RhwpFootnoteHit> footnoteAtCursor({
    required int section,
    required int paragraph,
    required int offset,
    required String direction,
  }) async {
    final result = await apply(
      RhwpCommand.getFootnoteAtCursor(
        section: section,
        paragraph: paragraph,
        offset: offset,
        direction: direction,
      ),
    );
    return RhwpFootnoteHit.fromJsonString(result);
  }

  Future<RhwpFootnoteInfo> footnoteInfo({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) async {
    final result = await apply(
      RhwpCommand.getFootnoteInfo(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
    return RhwpFootnoteInfo.fromJsonString(result);
  }

  Future<String> deleteFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) {
    return apply(
      RhwpCommand.deleteFootnote(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
  }

  Future<String> insertTextInFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int footnoteParagraph,
    required int offset,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertTextInFootnote(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        footnoteParagraph: footnoteParagraph,
        offset: offset,
        text: text,
      ),
    );
  }

  Future<String> deleteTextInFootnote({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int footnoteParagraph,
    required int offset,
    required int count,
  }) {
    return apply(
      RhwpCommand.deleteTextInFootnote(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        footnoteParagraph: footnoteParagraph,
        offset: offset,
        count: count,
      ),
    );
  }

  Future<String> insertEquation({
    required int section,
    required int paragraph,
    required int offset,
    required String script,
    int fontSize = 1000,
    int color = 0,
  }) {
    return apply(
      RhwpCommand.insertEquation(
        section: section,
        paragraph: paragraph,
        offset: offset,
        script: script,
        fontSize: fontSize,
        color: color,
      ),
    );
  }

  Future<String> insertHyperlink({
    required int section,
    required int paragraph,
    required int offset,
    required String url,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertHyperlink(
        section: section,
        paragraph: paragraph,
        offset: offset,
        url: url,
        text: text,
      ),
    );
  }

  Future<String> updateHyperlink({
    required int fieldId,
    required String url,
    required String text,
  }) {
    return apply(
      RhwpCommand.updateHyperlink(fieldId: fieldId, url: url, text: text),
    );
  }

  Future<String> insertHiddenComment({
    required int section,
    required int paragraph,
    required int offset,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertHiddenComment(
        section: section,
        paragraph: paragraph,
        offset: offset,
        text: text,
      ),
    );
  }

  Future<String> insertPicture({
    required int section,
    required int paragraph,
    required int offset,
    required Uint8List imageData,
    required int width,
    required int height,
    required int naturalWidthPx,
    required int naturalHeightPx,
    required String extension,
    String description = '',
  }) {
    return apply(
      RhwpCommand.insertPicture(
        section: section,
        paragraph: paragraph,
        offset: offset,
        imageData: imageData,
        width: width,
        height: height,
        naturalWidthPx: naturalWidthPx,
        naturalHeightPx: naturalHeightPx,
        extension: extension,
        description: description,
      ),
    );
  }

  Future<String> insertShape({
    required int section,
    required int paragraph,
    required int offset,
    int width = 9000,
    int height = 6750,
    int horzOffset = 0,
    int vertOffset = 0,
    String shapeType = 'rectangle',
    bool treatAsChar = false,
    String textWrap = 'InFrontOfText',
    bool lineFlipX = false,
    bool lineFlipY = false,
  }) {
    return apply(
      RhwpCommand.insertShape(
        section: section,
        paragraph: paragraph,
        offset: offset,
        width: width,
        height: height,
        horzOffset: horzOffset,
        vertOffset: vertOffset,
        shapeType: shapeType,
        treatAsChar: treatAsChar,
        textWrap: textWrap,
        lineFlipX: lineFlipX,
        lineFlipY: lineFlipY,
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

  Future<String> insertParagraph({
    required int section,
    required int paragraph,
  }) {
    return apply(
      RhwpCommand.insertParagraph(section: section, paragraph: paragraph),
    );
  }

  Future<String> deleteParagraph({
    required int section,
    required int paragraph,
  }) {
    return apply(
      RhwpCommand.deleteParagraph(section: section, paragraph: paragraph),
    );
  }

  Future<String> mergeParagraph({
    required int section,
    required int paragraph,
  }) {
    return apply(
      RhwpCommand.mergeParagraph(section: section, paragraph: paragraph),
    );
  }

  Future<int> sectionCount() async {
    final result = await apply(RhwpCommand.getSectionCount());
    return _readIntResult(result, 'count');
  }

  Future<int> paragraphCount({required int section}) async {
    final result = await apply(RhwpCommand.getParagraphCount(section: section));
    return _readIntResult(result, 'count');
  }

  Future<int> paragraphLength({
    required int section,
    required int paragraph,
  }) async {
    final result = await apply(
      RhwpCommand.getParagraphLength(section: section, paragraph: paragraph),
    );
    return _readIntResult(result, 'length');
  }

  Future<String> insertPageBreak({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.insertPageBreak(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<String> insertColumnBreak({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.insertColumnBreak(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<RhwpColumnDef> columnDef({required int section}) async {
    final result = await apply(RhwpCommand.getColumnDef(section: section));
    return RhwpColumnDef.fromJsonString(result);
  }

  Future<String> setColumnDef({
    required int section,
    required int columnCount,
    RhwpColumnType columnType = RhwpColumnType.normal,
    bool sameWidth = true,
    int spacing = 283,
  }) {
    return apply(
      RhwpCommand.setColumnDef(
        section: section,
        columnCount: columnCount,
        columnType: columnType,
        sameWidth: sameWidth,
        spacing: spacing,
      ),
    );
  }

  Future<RhwpSectionDef> sectionDef({required int section}) async {
    final result = await apply(RhwpCommand.getSectionDef(section: section));
    return RhwpSectionDef.fromJsonString(result);
  }

  Future<String> setSectionDef({
    required int section,
    required int pageNumber,
    required int pageNumberType,
    required int pictureNumber,
    required int tableNumber,
    required int equationNumber,
    required int columnSpacing,
    required int defaultTabSpacing,
    required bool hideHeader,
    required bool hideFooter,
    required bool hideMasterPage,
    required bool hideBorder,
    required bool hideFill,
    required bool hideEmptyLine,
  }) {
    return apply(
      RhwpCommand.setSectionDef(
        section: section,
        properties: {
          'pageNum': pageNumber,
          'pageNumType': pageNumberType,
          'pictureNum': pictureNumber,
          'tableNum': tableNumber,
          'equationNum': equationNumber,
          'columnSpacing': columnSpacing,
          'defaultTabSpacing': defaultTabSpacing,
          'hideHeader': hideHeader,
          'hideFooter': hideFooter,
          'hideMasterPage': hideMasterPage,
          'hideBorder': hideBorder,
          'hideFill': hideFill,
          'hideEmptyLine': hideEmptyLine,
        },
      ),
    );
  }

  Future<String> insertNewNumber({
    required int section,
    required int paragraph,
    required int offset,
    required int startNumber,
  }) {
    return apply(
      RhwpCommand.insertNewNumber(
        section: section,
        paragraph: paragraph,
        offset: offset,
        startNumber: startNumber,
      ),
    );
  }

  Future<List<RhwpBookmark>> bookmarks() async {
    final result = await apply(RhwpCommand.getBookmarks());
    final decoded = jsonDecode(result);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(RhwpBookmark.fromJson)
        .toList(growable: false);
  }

  Future<int> pageOfPosition({
    required int section,
    required int paragraph,
  }) async {
    final result = await apply(
      RhwpCommand.getPageOfPosition(section: section, paragraph: paragraph),
    );
    final decoded = jsonDecode(result);
    if (decoded is Map) {
      return _intFromJson(decoded['page']) ?? 0;
    }
    return 0;
  }

  Future<String> addBookmark({
    required int section,
    required int paragraph,
    required int offset,
    required String name,
  }) {
    return apply(
      RhwpCommand.addBookmark(
        section: section,
        paragraph: paragraph,
        offset: offset,
        name: name,
      ),
    );
  }

  Future<String> deleteBookmark({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) {
    return apply(
      RhwpCommand.deleteBookmark(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
  }

  Future<String> renameBookmark({
    required int section,
    required int paragraph,
    required int controlIndex,
    required String name,
  }) {
    return apply(
      RhwpCommand.renameBookmark(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        name: name,
      ),
    );
  }

  Future<List<RhwpFieldInfo>> fields() async {
    final result = await apply(RhwpCommand.getFieldList());
    final decoded = jsonDecode(result);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(RhwpFieldInfo.fromJson)
        .toList(growable: false);
  }

  Future<String> fieldValue(int fieldId) async {
    final result = await apply(RhwpCommand.getFieldValue(fieldId));
    final decoded = _tryDecodeObject(result);
    return decoded?['value']?.toString() ?? '';
  }

  Future<String> fieldValueByName(String name) async {
    final result = await apply(RhwpCommand.getFieldValueByName(name));
    final decoded = _tryDecodeObject(result);
    return decoded?['value']?.toString() ?? '';
  }

  Future<String> setFieldValue({required int fieldId, required String value}) {
    return apply(RhwpCommand.setFieldValue(fieldId: fieldId, value: value));
  }

  Future<String> setFieldValueByName({
    required String name,
    required String value,
  }) {
    return apply(RhwpCommand.setFieldValueByName(name: name, value: value));
  }

  Future<RhwpFieldRangeInfo> fieldInfoAt({
    required int section,
    required int paragraph,
    required int offset,
  }) async {
    final result = await apply(
      RhwpCommand.getFieldInfoAt(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
    return RhwpFieldRangeInfo.fromJson(_tryDecodeObject(result) ?? const {});
  }

  Future<RhwpFieldRangeInfo> fieldInfoAtInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox = false,
  }) async {
    final result = await apply(
      RhwpCommand.getFieldInfoAtInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        isTextBox: isTextBox,
      ),
    );
    return RhwpFieldRangeInfo.fromJson(_tryDecodeObject(result) ?? const {});
  }

  Future<bool> setActiveField({
    required int section,
    required int paragraph,
    required int offset,
  }) async {
    final result = await apply(
      RhwpCommand.setActiveField(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
    return _boolFromJson(_tryDecodeObject(result)?['changed']) ?? false;
  }

  Future<bool> setActiveFieldInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox = false,
  }) async {
    final result = await apply(
      RhwpCommand.setActiveFieldInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        isTextBox: isTextBox,
      ),
    );
    return _boolFromJson(_tryDecodeObject(result)?['changed']) ?? false;
  }

  Future<void> clearActiveField() async {
    await apply(RhwpCommand.clearActiveField());
  }

  Future<String> removeFieldAt({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.removeFieldAt(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<String> removeFieldAtInTableCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    bool isTextBox = false,
  }) {
    return apply(
      RhwpCommand.removeFieldAtInTableCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        isTextBox: isTextBox,
      ),
    );
  }

  Future<RhwpClickHereProperties> clickHereProperties(int fieldId) async {
    final result = await apply(RhwpCommand.getClickHereProperties(fieldId));
    return RhwpClickHereProperties.fromJson(
      _tryDecodeObject(result) ?? const {},
    );
  }

  Future<String> updateClickHereProperties({
    required int fieldId,
    required String guide,
    required String memo,
    required String name,
    required bool editable,
  }) {
    return apply(
      RhwpCommand.updateClickHereProperties(
        fieldId: fieldId,
        guide: guide,
        memo: memo,
        name: name,
        editable: editable,
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

  Future<String> createTableEx({
    required int section,
    required int paragraph,
    required int offset,
    required int rows,
    required int columns,
    bool treatAsChar = false,
    List<int> columnWidths = const [],
  }) {
    return apply(
      RhwpCommand.createTableEx(
        section: section,
        paragraph: paragraph,
        offset: offset,
        rows: rows,
        columns: columns,
        treatAsChar: treatAsChar,
        columnWidths: columnWidths,
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

  Future<String> splitTableCellInto({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
    required int rows,
    required int columns,
    bool equalRowHeight = true,
    bool mergeFirst = false,
  }) {
    return apply(
      RhwpCommand.splitTableCellInto(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        row: row,
        column: column,
        rows: rows,
        columns: columns,
        equalRowHeight: equalRowHeight,
        mergeFirst: mergeFirst,
      ),
    );
  }

  Future<String> splitTableCellsInRange({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
    required int rows,
    required int columns,
    required bool equalRowHeight,
  }) {
    return apply(
      RhwpCommand.splitTableCellsInRange(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        startRow: startRow,
        startColumn: startColumn,
        endRow: endRow,
        endColumn: endColumn,
        rows: rows,
        columns: columns,
        equalRowHeight: equalRowHeight,
      ),
    );
  }

  Future<RhwpTableProperties> tableProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) async {
    final json = await apply(
      RhwpCommand.getTableProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
    return RhwpTableProperties.fromJsonString(json);
  }

  Future<String> setTableProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    int? cellSpacing,
    int? paddingLeft,
    int? paddingRight,
    int? paddingTop,
    int? paddingBottom,
    int? pageBreak,
    bool? repeatHeader,
    bool? hasCaption,
    int? captionDirection,
    int? captionVerticalAlign,
    int? captionWidth,
    int? captionSpacing,
  }) {
    return apply(
      RhwpCommand.setTableProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellSpacing: cellSpacing,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        pageBreak: pageBreak,
        repeatHeader: repeatHeader,
        hasCaption: hasCaption,
        captionDirection: captionDirection,
        captionVerticalAlign: captionVerticalAlign,
        captionWidth: captionWidth,
        captionSpacing: captionSpacing,
      ),
    );
  }

  Future<RhwpCellProperties> cellProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
  }) async {
    final json = await apply(
      RhwpCommand.getCellProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
      ),
    );
    return RhwpCellProperties.fromJsonString(json);
  }

  Future<String> setCellProperties({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    int? width,
    int? height,
    int? paddingLeft,
    int? paddingRight,
    int? paddingTop,
    int? paddingBottom,
    int? verticalAlign,
    int? textDirection,
    bool? isHeader,
    bool? cellProtect,
  }) {
    return apply(
      RhwpCommand.setCellProperties(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        width: width,
        height: height,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        verticalAlign: verticalAlign,
        textDirection: textDirection,
        isHeader: isHeader,
        cellProtect: cellProtect,
      ),
    );
  }

  Future<String> resizeTableCells({
    required int section,
    required int paragraph,
    required int controlIndex,
    required List<RhwpTableCellResize> updates,
  }) {
    return apply(
      RhwpCommand.resizeTableCells(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        updates: updates,
      ),
    );
  }

  Future<String> evaluateTableFormula({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int row,
    required int column,
    required String formula,
    bool writeResult = true,
  }) {
    return apply(
      RhwpCommand.evaluateTableFormula(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        row: row,
        column: column,
        formula: formula,
        writeResult: writeResult,
      ),
    );
  }

  Future<String> deleteTableControl({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) {
    return apply(
      RhwpCommand.deleteTableControl(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
  }

  Future<String> moveTableOffset({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int deltaH,
    required int deltaV,
  }) {
    return apply(
      RhwpCommand.moveTableOffset(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        deltaH: deltaH,
        deltaV: deltaV,
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

  Future<String> copyObjectControl({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) {
    return apply(
      RhwpCommand.copyObjectControl(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
  }

  Future<bool> clipboardHasObjectControl() async {
    final result = await apply(RhwpCommand.clipboardHasObjectControl());
    final decoded = jsonDecode(result);
    if (decoded is Map<String, Object?>) {
      return decoded['hasControl'] == true;
    }
    return false;
  }

  Future<String> pasteObjectControl({
    required int section,
    required int paragraph,
    required int offset,
  }) {
    return apply(
      RhwpCommand.pasteObjectControl(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
  }

  Future<String> exportSelectionHtml({
    required int section,
    required int startParagraph,
    required int startOffset,
    required int endParagraph,
    required int endOffset,
  }) {
    return apply(
      RhwpCommand.exportSelectionHtml(
        section: section,
        startParagraph: startParagraph,
        startOffset: startOffset,
        endParagraph: endParagraph,
        endOffset: endOffset,
      ),
    );
  }

  Future<String> exportSelectionInCellHtml({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int startCellParagraph,
    required int startOffset,
    required int endCellParagraph,
    required int endOffset,
  }) {
    return apply(
      RhwpCommand.exportSelectionInCellHtml(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        startCellParagraph: startCellParagraph,
        startOffset: startOffset,
        endCellParagraph: endCellParagraph,
        endOffset: endOffset,
      ),
    );
  }

  Future<String> exportControlHtml({
    required int section,
    required int paragraph,
    required int controlIndex,
  }) {
    return apply(
      RhwpCommand.exportControlHtml(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
      ),
    );
  }

  Future<String> pasteHtml({
    required int section,
    required int paragraph,
    required int offset,
    required String html,
  }) {
    return apply(
      RhwpCommand.pasteHtml(
        section: section,
        paragraph: paragraph,
        offset: offset,
        html: html,
      ),
    );
  }

  Future<String> pasteHtmlInCell({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
    required String html,
  }) {
    return apply(
      RhwpCommand.pasteHtmlInCell(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
        html: html,
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
    int? rotationAngle,
    bool? horzFlip,
    bool? vertFlip,
    bool? hasCaption,
    String? captionDirection,
    String? captionVerticalAlign,
    int? captionWidth,
    int? captionSpacing,
    bool? captionIncludeMargin,
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
        rotationAngle: rotationAngle,
        horzFlip: horzFlip,
        vertFlip: vertFlip,
        hasCaption: hasCaption,
        captionDirection: captionDirection,
        captionVerticalAlign: captionVerticalAlign,
        captionWidth: captionWidth,
        captionSpacing: captionSpacing,
        captionIncludeMargin: captionIncludeMargin,
      ),
    );
  }

  Future<String> moveLineEndpoint({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int startX,
    required int startY,
    required int endX,
    required int endY,
  }) {
    return apply(
      RhwpCommand.moveLineEndpoint(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
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
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
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
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
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
    bool? superscript,
    bool? subscript,
    bool? emboss,
    bool? engrave,
    String? fontFamily,
    int? fontSize,
    String? textColor,
    String? shadeColor,
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
        superscript: superscript,
        subscript: subscript,
        emboss: emboss,
        engrave: engrave,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        shadeColor: shadeColor,
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
    int? verticalAlign,
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
        verticalAlign: verticalAlign,
      ),
    );
  }

  Future<List<RhwpStyleInfo>> styleList() async {
    final source = await apply(RhwpCommand.getStyleList());
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is Map)
          RhwpStyleInfo.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
    ];
  }

  Future<RhwpCharProperties> charPropertiesAt({
    required int section,
    required int paragraph,
    required int offset,
  }) async {
    final source = await apply(
      RhwpCommand.getCharPropertiesAt(
        section: section,
        paragraph: paragraph,
        offset: offset,
      ),
    );
    return RhwpCharProperties.fromJsonString(source);
  }

  Future<RhwpCharProperties> cellCharPropertiesAt({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int offset,
  }) async {
    final source = await apply(
      RhwpCommand.getCellCharPropertiesAt(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        offset: offset,
      ),
    );
    return RhwpCharProperties.fromJsonString(source);
  }

  Future<RhwpParaProperties> paraPropertiesAt({
    required int section,
    required int paragraph,
  }) async {
    final source = await apply(
      RhwpCommand.getParaPropertiesAt(section: section, paragraph: paragraph),
    );
    return RhwpParaProperties.fromJsonString(source);
  }

  Future<RhwpParaProperties> cellParaPropertiesAt({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
  }) async {
    final source = await apply(
      RhwpCommand.getCellParaPropertiesAt(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
      ),
    );
    return RhwpParaProperties.fromJsonString(source);
  }

  Future<String> applyStyle({
    required int section,
    required int paragraph,
    required int styleId,
  }) {
    return apply(
      RhwpCommand.applyStyle(
        section: section,
        paragraph: paragraph,
        styleId: styleId,
      ),
    );
  }

  Future<String> applyCellStyle({
    required int section,
    required int paragraph,
    required int controlIndex,
    required int cellIndex,
    required int cellParagraph,
    required int styleId,
  }) {
    return apply(
      RhwpCommand.applyCellStyle(
        section: section,
        paragraph: paragraph,
        controlIndex: controlIndex,
        cellIndex: cellIndex,
        cellParagraph: cellParagraph,
        styleId: styleId,
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

  Future<RhwpHeaderFooterInfo> headerFooter({
    required int section,
    required bool isHeader,
    int applyTo = 0,
  }) async {
    final result = await apply(
      RhwpCommand.getHeaderFooter(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
      ),
    );
    return RhwpHeaderFooterInfo.fromJsonString(result);
  }

  Future<RhwpHeaderFooterList> headerFooterList({
    int section = 0,
    bool isHeader = true,
    int applyTo = 0,
  }) async {
    final result = await apply(
      RhwpCommand.getHeaderFooterList(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
      ),
    );
    return RhwpHeaderFooterList.fromJsonString(result);
  }

  Future<String> deleteHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo = 0,
  }) {
    return apply(
      RhwpCommand.deleteHeaderFooter(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
      ),
    );
  }

  Future<String> insertTextInHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo = 0,
    required int paragraph,
    required int offset,
    required String text,
  }) {
    return apply(
      RhwpCommand.insertTextInHeaderFooter(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
        paragraph: paragraph,
        offset: offset,
        text: text,
      ),
    );
  }

  Future<String> deleteTextInHeaderFooter({
    required int section,
    required bool isHeader,
    int applyTo = 0,
    required int paragraph,
    required int offset,
    required int count,
  }) {
    return apply(
      RhwpCommand.deleteTextInHeaderFooter(
        section: section,
        isHeader: isHeader,
        applyTo: applyTo,
        paragraph: paragraph,
        offset: offset,
        count: count,
      ),
    );
  }

  Future<RhwpPageSetup> pageSetup({int section = 0}) async {
    final result = await apply(RhwpCommand.getPageSetup(section: section));
    return RhwpPageSetup.fromJsonString(result);
  }

  Future<String> setPageSetup({
    required int section,
    int? width,
    int? height,
    int? marginLeft,
    int? marginRight,
    int? marginTop,
    int? marginBottom,
    int? marginHeader,
    int? marginFooter,
    int? marginGutter,
    bool? landscape,
    int? binding,
  }) {
    return apply(
      RhwpCommand.setPageSetup(
        section: section,
        width: width,
        height: height,
        marginLeft: marginLeft,
        marginRight: marginRight,
        marginTop: marginTop,
        marginBottom: marginBottom,
        marginHeader: marginHeader,
        marginFooter: marginFooter,
        marginGutter: marginGutter,
        landscape: landscape,
        binding: binding,
      ),
    );
  }

  Future<RhwpPageBorderFill> pageBorderFill({required int section}) async {
    final result = await apply(RhwpCommand.getPageBorderFill(section: section));
    return RhwpPageBorderFill.fromJsonString(result);
  }

  Future<String> setPageBorderFill({
    required int section,
    int? attr,
    int? spacingLeft,
    int? spacingRight,
    int? spacingTop,
    int? spacingBottom,
    int? borderFillId,
    RhwpBorderLine? borderLeft,
    RhwpBorderLine? borderRight,
    RhwpBorderLine? borderTop,
    RhwpBorderLine? borderBottom,
    String? fillType,
    String? fillColor,
    String? patternColor,
    int? patternType,
    bool clearFill = false,
  }) {
    return apply(
      RhwpCommand.setPageBorderFill(
        section: section,
        properties: _pageBorderFillProperties(
          attr: attr,
          spacingLeft: spacingLeft,
          spacingRight: spacingRight,
          spacingTop: spacingTop,
          spacingBottom: spacingBottom,
          borderFillId: borderFillId,
          borderLeft: borderLeft,
          borderRight: borderRight,
          borderTop: borderTop,
          borderBottom: borderBottom,
          fillType: fillType,
          fillColor: fillColor,
          patternColor: patternColor,
          patternType: patternType,
          clearFill: clearFill,
        ),
      ),
    );
  }

  Future<RhwpPageHide> pageHide({
    required int section,
    required int paragraph,
  }) async {
    final result = await apply(
      RhwpCommand.getPageHide(section: section, paragraph: paragraph),
    );
    return RhwpPageHide.fromJsonString(result);
  }

  Future<String> setPageHide({
    required int section,
    required int paragraph,
    bool hideHeader = false,
    bool hideFooter = false,
    bool hideMasterPage = false,
    bool hideBorder = false,
    bool hideFill = false,
    bool hidePageNumber = false,
  }) {
    return apply(
      RhwpCommand.setPageHide(
        section: section,
        paragraph: paragraph,
        hideHeader: hideHeader,
        hideFooter: hideFooter,
        hideMasterPage: hideMasterPage,
        hideBorder: hideBorder,
        hideFill: hideFill,
        hidePageNumber: hidePageNumber,
      ),
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

  Future<String> convertToEditable() {
    return apply(RhwpCommand.convertToEditable());
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

  static int _readIntResult(String source, String key) {
    final decoded = _tryDecodeObject(source);
    final value = decoded?[key];
    if (value is num) {
      return value.toInt();
    }
    throw RhwpException('Command result did not include integer "$key".');
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
