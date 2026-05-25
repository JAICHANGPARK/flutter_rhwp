import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'rhwp_document.dart';
import 'rhwp_exception.dart';

class RhwpFullEditorController extends ChangeNotifier {
  bool get isAttached => false;

  Future<Uint8List> export(RhwpExportFormat format) async {
    throw const RhwpUnsupportedPlatformException(
      'The upstream rhwp full editor is not available on this platform.',
    );
  }

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

class RhwpFullEditor extends StatelessWidget {
  const RhwpFullEditor({
    super.key,
    this.moduleUrl = 'https://esm.sh/@rhwp/editor',
    this.initialBytes,
    this.fileName,
    this.controller,
  });

  final String moduleUrl;
  final Uint8List? initialBytes;
  final String? fileName;
  final RhwpFullEditorController? controller;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xfff8fafc),
      child: Center(
        child: Text('The upstream rhwp full editor is not available here.'),
      ),
    );
  }
}
