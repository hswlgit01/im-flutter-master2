import 'package:flutter_test/flutter_test.dart';
import 'package:openim_common/openim_common.dart';

void main() {
  test('parses TRTC credential response', () {
    final certificate = SignalingCertificate.fromJson({
      'provider': 'trtc',
      'sdkAppId': 12345678,
      'userSig': 'test-user-sig',
      'userID': 'im-user-1',
      'roomID': 'room-1',
      'expiresAt': 1700000000,
      'token': 'test-user-sig',
    });

    expect(certificate.provider, 'trtc');
    expect(certificate.sdkAppID, 12345678);
    expect(certificate.userSig, 'test-user-sig');
    expect(certificate.userID, 'im-user-1');
    expect(certificate.roomID, 'room-1');
    expect(certificate.expiresAt, 1700000000);
  });

  test('keeps compatibility with the legacy LiveKit response', () {
    final certificate = SignalingCertificate.fromJson({
      'ServerUrl': 'wss://rtc.example.com',
      'Token': 'legacy-token',
    });

    expect(certificate.provider, 'livekit');
    expect(certificate.liveURL, 'wss://rtc.example.com');
    expect(certificate.token, 'legacy-token');
  });
}
