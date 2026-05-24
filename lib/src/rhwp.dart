import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import 'rhwp_document.dart';
import 'rust/api/rhwp.dart' as rust;
import 'rust/frb_generated.dart';

class Rhwp {
  Rhwp._();

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized({ExternalLibrary? externalLibrary}) {
    return _initFuture ??= RustLib.init(externalLibrary: externalLibrary);
  }

  static Future<String> version() async {
    await ensureInitialized();
    return rust.rhwpVersion();
  }

  static Future<RhwpDocument> open(Uint8List bytes, {String? fileName}) async {
    await ensureInitialized();
    final session = await rust.openBytes(bytes: bytes, fileName: fileName);
    return RhwpDocument.fromSession(session);
  }

  static Future<RhwpDocument> createEmpty({String? fileName}) async {
    await ensureInitialized();
    final session = await rust.createEmpty(fileName: fileName);
    return RhwpDocument.fromSession(session);
  }

  static void disposeBridge() {
    RustLib.dispose();
    _initFuture = null;
  }
}
