import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/src/call_setup_optimizer.dart';

SignalingCertificate certificate(String roomID) => SignalingCertificate(
      provider: 'trtc',
      roomID: roomID,
      sdkAppID: 20000001,
      userID: 'user',
      userSig: 'sig',
    );

void main() {
  test('RecentRoomSignalDeduplicator suppresses the durable duplicate', () {
    var now = DateTime(2026, 8, 25, 12);
    final deduplicator = RecentRoomSignalDeduplicator(
      window: const Duration(minutes: 2),
      clock: () => now,
    );

    expect(deduplicator.shouldProcess('room-1'), isTrue);
    expect(deduplicator.shouldProcess('room-1'), isFalse);
    expect(deduplicator.shouldProcess('room-2'), isTrue);

    now = now.add(const Duration(minutes: 3));
    expect(deduplicator.shouldProcess('room-1'), isTrue);
  });

  group('IncomingRTCCredentialPrefetcher', () {
    test('reuses a successful invitation-time request on pickup', () async {
      var loads = 0;
      final ready = Completer<SignalingCertificate>();
      final prefetcher = IncomingRTCCredentialPrefetcher((roomID, userID) {
        loads++;
        return ready.future;
      });

      final pending = prefetcher.prefetch('room-1', 'user');
      final expected = certificate('room-1');
      ready.complete(expected);

      expect(await pending, same(expected));
      expect(await prefetcher.takeOrLoad('room-1', 'user'), same(expected));
      expect(loads, 1);
    });

    test('retries on pickup after a prefetch failure', () async {
      var loads = 0;
      final expected = certificate('room-2');
      final errors = <Object>[];
      final prefetcher = IncomingRTCCredentialPrefetcher(
        (roomID, userID) async {
          loads++;
          if (loads == 1) throw StateError('temporary failure');
          return expected;
        },
        onPrefetchError: (error, _) => errors.add(error),
      );

      expect(await prefetcher.prefetch('room-2', 'user'), isNull);
      expect(await prefetcher.takeOrLoad('room-2', 'user'), same(expected));
      expect(loads, 2);
      expect(errors, hasLength(1));
    });

    test('does not wait indefinitely for a stuck prefetch', () async {
      var loads = 0;
      final stuck = Completer<SignalingCertificate>();
      final expected = certificate('room-3');
      final prefetcher = IncomingRTCCredentialPrefetcher(
        (roomID, userID) {
          loads++;
          return loads == 1 ? stuck.future : Future.value(expected);
        },
        prefetchGrace: const Duration(milliseconds: 10),
      );

      unawaited(prefetcher.prefetch('room-3', 'user'));
      expect(await prefetcher.takeOrLoad('room-3', 'user'), same(expected));
      expect(loads, 2);
      stuck.complete(certificate('room-3'));
    });
  });

  group('FastReliableSignalDispatcher', () {
    test('starts fast delivery and queues a durable copy', () async {
      final calls = <String>[];
      const dispatcher = FastReliableSignalDispatcher(
        fastPathGrace: Duration(milliseconds: 50),
        reliableDelay: Duration(milliseconds: 5),
      );

      await dispatcher.dispatch(
        sendFast: () async => calls.add('online'),
        sendReliable: () async => calls.add('reliable'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(calls, ['online', 'reliable']);
    });

    test('a stuck fast path cannot block media setup', () async {
      final stuck = Completer<void>();
      var reliableSent = false;
      var timedOut = false;
      final dispatcher = FastReliableSignalDispatcher(
        fastPathGrace: const Duration(milliseconds: 15),
        reliableDelay: Duration.zero,
        onFastPathTimeout: () => timedOut = true,
      );

      final stopwatch = Stopwatch()..start();
      await dispatcher.dispatch(
        sendFast: () => stuck.future,
        sendReliable: () async => reliableSent = true,
      );
      stopwatch.stop();

      expect(timedOut, isTrue);
      expect(reliableSent, isTrue);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
      stuck.complete();
    });

    test('delivery failures are reported without failing pickup', () async {
      final failedChannels = <String>[];
      final dispatcher = FastReliableSignalDispatcher(
        fastPathGrace: const Duration(milliseconds: 50),
        reliableDelay: Duration.zero,
        onDeliveryError: (channel, error, stackTrace) {
          failedChannels.add(channel);
        },
      );

      await dispatcher.dispatch(
        sendFast: () async => throw StateError('online failed'),
        sendReliable: () async => throw StateError('reliable failed'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(failedChannels, containsAll(['online', 'reliable']));
    });
  });
}
