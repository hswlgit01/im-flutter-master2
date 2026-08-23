import 'package:openim_common/openim_common.dart';

import '../../openim_live.dart';

class LiveUtils {
  /// Regex of url.
  static const String regexUrl = '[a-zA-Z]+://[^\\s]*';

  /// Return whether input matches regex of url.
  static bool isURL(String input) {
    return matches(regexUrl, input);
  }

  static bool matches(String regex, String input) {
    if (input.isEmpty) return false;
    return RegExp(regex).hasMatch(input);
  }

  static String seconds2HMS(int seconds) {
    int h = 0;
    int m = 0;
    int s = 0;
    int temp = seconds % 3600;
    if (seconds > 3600) {
      h = seconds ~/ 3600;
      if (temp != 0) {
        if (temp > 60) {
          m = temp ~/ 60;
          if (temp % 60 != 0) {
            s = temp % 60;
          }
        } else {
          s = temp;
        }
      }
    } else {
      m = seconds ~/ 60;
      if (seconds % 60 != 0) {
        s = seconds % 60;
      }
    }
    if (h == 0) {
      return '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';
    }
    return "${h < 10 ? '0$h' : h}:${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}";
  }

  /// 我主动发起通话，一开始roomID为null，拨号成功返回roomID
  /// 我被邀请通话，一开始就存在roomID
  static bool isSameRoom(CallEvent event, String? roomID) {
    var signalingInfo = event.data;
    var invitation = signalingInfo.invitation;
    if (invitation == null) {
      Logger.print('${event.state}--当前房间：$roomID--信令 invitation 为空，放行以关界面');
      return true;
    }
    // dawn 2026-07-09 本端 roomID 尚未绑定（拨号中）时不要过滤掉 cancel/hangup，
    // 否则关界面/停铃信号被 sameRoomSignalStream 丢掉，对端一直卡在通话页。
    if (roomID == null || roomID.isEmpty) {
      Logger.print('${event.state}--当前房间为空，放行信令 room=${invitation.roomID}');
      return true;
    }
    Logger.print('${event.state}--当前房间：$roomID--信令来自：${invitation.roomID}');
    return roomID == invitation.roomID;
  }
}
