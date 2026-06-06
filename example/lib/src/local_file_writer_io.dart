import 'dart:io';
import 'dart:typed_data';

bool get supportsLocalFileWrite => true;

Future<void> writeLocalFile(String path, Uint8List bytes) {
  return File(path).writeAsBytes(bytes);
}
