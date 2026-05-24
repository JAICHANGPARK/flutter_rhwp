import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/flutter_rhwp_platform_interface.dart';
import 'package:flutter_rhwp/flutter_rhwp_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterRhwpPlatform
    with MockPlatformInterfaceMixin
    implements FlutterRhwpPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterRhwpPlatform initialPlatform = FlutterRhwpPlatform.instance;

  test('$MethodChannelFlutterRhwp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterRhwp>());
  });

  test('getPlatformVersion', () async {
    FlutterRhwp flutterRhwpPlugin = FlutterRhwp();
    MockFlutterRhwpPlatform fakePlatform = MockFlutterRhwpPlatform();
    FlutterRhwpPlatform.instance = fakePlatform;

    expect(await flutterRhwpPlugin.getPlatformVersion(), '42');
  });
}
