import 'dart:async';

import 'package:openim_common/openim_common.dart';

typedef RTCCredentialLoader = Future<SignalingCertificate> Function(
  String roomID,
  String userID,
);

typedef SignalDelivery = Future<void> Function();
typedef SignalDeliveryError = void Function(
  String channel,
  Object error,
  StackTrace stackTrace,
);

/// Suppresses the durable duplicate of a signal that was already delivered by
/// the online-only path.
class RecentRoomSignalDeduplicator {
  RecentRoomSignalDeduplicator({
    this.window = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;
  final Map<String, DateTime> _seenAt = {};

  bool shouldProcess(String roomID) {
    final now = _clock();
    _seenAt.removeWhere((_, seenAt) => now.difference(seenAt) > window);
    final previous = _seenAt[roomID];
    if (previous != null && now.difference(previous) <= window) return false;
    _seenAt[roomID] = now;
    return true;
  }

  void clear() => _seenAt.clear();
}

/// Starts the RTC credential request as soon as an incoming invitation is
/// received, then lets the pickup path reuse the result.
///
/// Prefetch failures are deliberately converted to `null` so a failed request
/// cannot become an unhandled asynchronous error while the phone is ringing.
/// Pickup performs one fresh request when the cached request failed or is
/// still stuck after [prefetchGrace].
class IncomingRTCCredentialPrefetcher {
  IncomingRTCCredentialPrefetcher(
    this._loader, {
    this.prefetchGrace = const Duration(milliseconds: 500),
    this.onPrefetchError,
  });

  final RTCCredentialLoader _loader;
  final Duration prefetchGrace;
  final void Function(Object error, StackTrace stackTrace)? onPrefetchError;

  final Map<String, Future<SignalingCertificate?>> _pending = {};

  String _key(String roomID, String userID) => '$roomID\u0000$userID';

  Future<SignalingCertificate?> prefetch(String roomID, String userID) {
    final key = _key(roomID, userID);
    return _pending.putIfAbsent(
      key,
      () async {
        try {
          return await _loader(roomID, userID);
        } catch (error, stackTrace) {
          onPrefetchError?.call(error, stackTrace);
          return null;
        }
      },
    );
  }

  Future<SignalingCertificate> takeOrLoad(
    String roomID,
    String userID,
  ) async {
    final pending = _pending.remove(_key(roomID, userID));
    if (pending != null) {
      final prefetched = await pending.timeout(
        prefetchGrace,
        onTimeout: () => null,
      );
      if (prefetched != null) return prefetched;
    }
    return _loader(roomID, userID);
  }

  void discard(String roomID, String userID) {
    _pending.remove(_key(roomID, userID));
  }

  void clear() => _pending.clear();
}

/// Sends a latency-sensitive signal through an online-only fast path while a
/// durable copy is queued independently as a fallback.
///
/// Neither path is allowed to block media setup indefinitely. The fast path
/// gets a short grace period; the reliable path runs in the background and
/// reports failures through [onDeliveryError].
class FastReliableSignalDispatcher {
  const FastReliableSignalDispatcher({
    this.fastPathGrace = const Duration(milliseconds: 800),
    this.reliableDelay = const Duration(milliseconds: 250),
    this.onDeliveryError,
    this.onFastPathTimeout,
  });

  final Duration fastPathGrace;
  final Duration reliableDelay;
  final SignalDeliveryError? onDeliveryError;
  final void Function()? onFastPathTimeout;

  Future<void> dispatch({
    required SignalDelivery sendFast,
    required SignalDelivery sendReliable,
  }) async {
    final fast = _guarded('online', sendFast);
    unawaited(Future<void>.delayed(
      reliableDelay,
      () => _guarded('reliable', sendReliable),
    ));

    try {
      await fast.timeout(fastPathGrace);
    } on TimeoutException {
      onFastPathTimeout?.call();
    }
  }

  Future<void> _guarded(String channel, SignalDelivery delivery) async {
    try {
      await delivery();
    } catch (error, stackTrace) {
      onDeliveryError?.call(channel, error, stackTrace);
    }
  }
}
