import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web registrar for the FRB/WASM implementation.
class FlutterRhwpWeb {
  /// Constructs a [FlutterRhwpWeb].
  FlutterRhwpWeb();

  /// Keeps Flutter's generated web registrant satisfied.
  ///
  /// Runtime calls go through `RustLib.init`, which loads the FRB WASM bundle.
  static void registerWith(Registrar registrar) {
    // No method-channel registration is needed for flutter_rust_bridge.
  }
}
