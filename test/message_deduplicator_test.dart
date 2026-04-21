import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim/utils/message_deduplicator.dart';

void main() {
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
      ..conversationID = 'group_1'
      ..seq = 42;
    final second = Message()
      ..clientMsgID = 'local-b'
      ..conversationID = 'group_1'
      ..seq = 42;

    expect(await MessageDeduplicator.instance.shouldProcessMessage(first), isTrue);
    expect(await MessageDeduplicator.instance.shouldProcessMessage(second), isFalse);
  });
}
