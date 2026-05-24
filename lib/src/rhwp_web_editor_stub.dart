import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'rhwp_document.dart';
import 'rhwp_exception.dart';

class RhwpWebEditorController extends ChangeNotifier {
  bool get isAttached => false;

  Future<Uint8List> export(RhwpExportFormat format) async {
    throw const RhwpUnsupportedPlatformException(
      'The upstream rhwp Web editor is only available on Web.',
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
