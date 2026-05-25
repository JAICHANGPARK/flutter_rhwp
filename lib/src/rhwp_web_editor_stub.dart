import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'rhwp_document.dart';
import 'rhwp_exception.dart';

/// Controls an embedded upstream `@rhwp/editor` instance.
///
/// This controller is only functional on Web. On other platforms its methods
/// throw [RhwpUnsupportedPlatformException].
class RhwpWebEditorController extends ChangeNotifier {
  /// Whether this controller is attached to a mounted [RhwpWebEditor].
  bool get isAttached => false;

  /// Exports the current upstream editor state as raw bytes.
  ///
  /// Throws [RhwpUnsupportedPlatformException] outside Web, or when the upstream
  /// editor build does not expose an exporter for [format].
  Future<Uint8List> export(RhwpExportFormat format) async {
    throw const RhwpUnsupportedPlatformException(
      'The upstream rhwp Web editor is only available on Web.',
    );
  }

  /// Exports the current upstream editor state with save metadata.
  ///
  /// [sourceFileName] and [page] are used only to derive the returned
  /// [RhwpExportedDocument.fileName].
  Future<RhwpExportedDocument> exportDocument(
    RhwpExportFormat format, {
    String? sourceFileName,
    int? page,
  }) async {
    final bytes = await export(format);
    return RhwpExportedDocument.fromBytes(
      format: format,
      bytes: bytes,
      sourceFileName: sourceFileName,
      page: page,
    );
  }

  Future<Uint8List> exportHwp() => export(RhwpExportFormat.hwp);

  Future<Uint8List> exportHwpx() => export(RhwpExportFormat.hwpx);

  Future<Uint8List> exportPdf() => export(RhwpExportFormat.pdf);

  Future<Uint8List> exportDocx() => export(RhwpExportFormat.docx);

  Future<Uint8List> exportText() => export(RhwpExportFormat.text);

  Future<Uint8List> exportMarkdown() => export(RhwpExportFormat.markdown);

  Future<Uint8List> exportPageSvg() => export(RhwpExportFormat.svg);
}

class RhwpWebEditor extends StatelessWidget {
  const RhwpWebEditor({
    super.key,
    this.moduleUrl = defaultModuleUrl,
    this.initialBytes,
    this.fileName,
    this.controller,
  });

  static const defaultModuleUrl = 'https://esm.sh/@rhwp/editor';

  final String moduleUrl;
  final Uint8List? initialBytes;
  final String? fileName;
  final RhwpWebEditorController? controller;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xfff8fafc),
      child: Center(
        child: Text('The upstream rhwp Web editor is only available on Web.'),
      ),
    );
  }
}
