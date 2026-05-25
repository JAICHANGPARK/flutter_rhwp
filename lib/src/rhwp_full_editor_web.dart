import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'rhwp_web_editor.dart';

/// Controller for the upstream `@rhwp/editor` full editor.
class RhwpFullEditorController extends RhwpWebEditorController {}

/// Full HWP editor backed by upstream `@rhwp/editor`.
class RhwpFullEditor extends StatelessWidget {
  const RhwpFullEditor({
    super.key,
    this.moduleUrl = RhwpWebEditor.defaultModuleUrl,
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
    return RhwpWebEditor(
      moduleUrl: moduleUrl,
      initialBytes: initialBytes,
      fileName: fileName,
      controller: controller,
    );
  }
}
