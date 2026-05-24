import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_rhwp_platform_interface.dart';

/// An implementation of [FlutterRhwpPlatform] that uses method channels.
class MethodChannelFlutterRhwp extends FlutterRhwpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_rhwp');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
