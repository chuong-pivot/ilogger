import 'package:flutter_test/flutter_test.dart';
import 'package:ilogger/ilogger.dart';
import 'package:ilogger/ilogger_platform_interface.dart';
import 'package:ilogger/ilogger_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIloggerPlatform
    with MockPlatformInterfaceMixin
    implements IloggerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final IloggerPlatform initialPlatform = IloggerPlatform.instance;

  test('$MethodChannelIlogger is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIlogger>());
  });

  test('getPlatformVersion', () async {
    Ilogger iloggerPlugin = Ilogger();
    MockIloggerPlatform fakePlatform = MockIloggerPlatform();
    IloggerPlatform.instance = fakePlatform;

    expect(await iloggerPlugin.getPlatformVersion(), '42');
  });
}
