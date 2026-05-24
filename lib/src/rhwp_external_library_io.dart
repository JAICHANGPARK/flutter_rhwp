import 'dart:io' show Platform;

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

ExternalLibrary? defaultRhwpExternalLibrary() {
  if (Platform.isIOS || Platform.isMacOS) {
    return ExternalLibrary.process(
      iKnowHowToUseIt: true,
      debugInfo: ' for flutter_rhwp Apple static library',
    );
  }
  return null;
}
