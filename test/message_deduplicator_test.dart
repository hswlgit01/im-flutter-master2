import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter/services.dart';
import 'package:openim/utils/message_deduplicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const deviceInfoChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
  const openIMChannel = MethodChannel('flutter_openim_sdk');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (call) async {
    if (call.method == 'getDeviceInfo') {
      return <String, dynamic>{
        'computerName': 'test',
        'hostName': 'test',
        'arch': 'arm64',
        'model': 'test',
        'kernelVersion': 'test',
        'osRelease': 'test',
        'majorVersion': 14,
        'minorVersion': 0,
        'patchVersion': 0,
        'activeCPUs': 8,
        'memorySize': 1024,
        'cpuFrequency': 0,
        'systemGUID': 'test',
      };
    }
    return null;
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(openIMChannel, (call) async {
    if (call.method == 'logs') {
      return null;
    }
    return null;
  });

  setUp(() {
    MessageDeduplicator.instance.clear();
  });

  test('deduplicates messages by server id when client ids differ', () async {
    final first = Message()
      ..clientMsgID = 'local-a'
      ..serverMsgID = 'server-1';
    final second = Message()
      ..clientMsgID = 'local-b'
      ..serverMsgID = 'server-1';

    expect(await MessageDeduplicator.instance.shouldProcessMessage(first), isTrue);
    expect(await MessageDeduplicator.instance.shouldProcessMessage(second), isFalse);
  });

  test('deduplicates messages by conversation seq when server id is empty', () async {
    final first = Message()
      ..clientMsgID = 'local-a'
      ..groupID = 'group_1'
      ..seq = 42;
    final second = Message()
      ..clientMsgID = 'local-b'
      ..groupID = 'group_1'
      ..seq = 42;

    expect(await MessageDeduplicator.instance.shouldProcessMessage(first), isTrue);
    expect(await MessageDeduplicator.instance.shouldProcessMessage(second), isFalse);
  });
}
