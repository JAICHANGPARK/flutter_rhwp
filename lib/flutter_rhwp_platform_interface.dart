import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_rhwp_method_channel.dart';

abstract class FlutterRhwpPlatform extends PlatformInterface {
  /// Constructs a FlutterRhwpPlatform.
  FlutterRhwpPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRhwpPlatform _instance = MethodChannelFlutterRhwp();

  /// The default instance of [FlutterRhwpPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterRhwp].
  static FlutterRhwpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterRhwpPlatform] when
  /// they register themselves.
  static set instance(FlutterRhwpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
