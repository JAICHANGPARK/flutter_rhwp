import 'dart:typed_data';

bool get supportsLocalFileWrite => false;

Future<void> writeLocalFile(String path, Uint8List bytes) async {
  throw UnsupportedError('Local file writes are not supported here.');
}
