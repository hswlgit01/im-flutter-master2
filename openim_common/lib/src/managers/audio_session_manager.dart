import 'package:audio_session/audio_session.dart';

enum AudioSessionType {
  /// 默认环境音频（系统音效、通知等）
  ambient,
  /// 媒体播放（语音消息、音乐等）
  playback,
  /// 录音
  record,
}

/// 全局音频会话管理器
/// 统一管理应用中所有音频会话的配置，避免冲突
class AudioSessionManager {
  static final AudioSessionManager _instance = AudioSessionManager._internal();
  factory AudioSessionManager() => _instance;
  AudioSessionManager._internal();

  AudioSession? _session;
  AudioSessionType? _currentSessionType;
  int _activeCount = 0; // 活跃音频播放器计数

  /// 获取音频会话实例
  Future<AudioSession> get session async {
    _session ??= await AudioSession.instance;
    return _session!;
  }

  /// 当前会话类型
  AudioSessionType? get currentSessionType => _currentSessionType;

  /// 配置音频会话
  Future<void> configureSession(AudioSessionType type) async {
    // 如果已经是相同类型的会话，不需要重复配置
    if (_currentSessionType == type) {
      return;
    }

    try {
      final audioSession = await session;
      AudioSessionConfiguration configuration;

      switch (type) {
        case AudioSessionType.ambient:
          configuration = const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.ambient,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
            androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.notification,
            ),
          );
          break;
        
        case AudioSessionType.playback:
          configuration = const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
            ),
          );
          break;
        
        case AudioSessionType.record:
          configuration = const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.record,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.speech,
              usage: AndroidAudioUsage.voiceCommunication,
            ),
          );
          break;
      }

      await audioSession.configure(configuration);
      _currentSessionType = type;
      print('Audio session configured to: $type');
    } catch (e) {
      print('Failed to configure audio session: $e');
    }
  }

  /// 激活音频会话
  Future<void> setActive(bool active) async {
    try {
      final audioSession = await session;
      
      if (active) {
        _activeCount++;
        await audioSession.setActive(true);
      } else {
        _activeCount--;
        if (_activeCount <= 0) {
          _activeCount = 0;
          await audioSession.setActive(false);
        }
      }
    } catch (e) {
      print('Failed to set audio session active: $e');
    }
  }

  /// 重置到默认状态
  Future<void> reset() async {
    try {
      _activeCount = 0;
      _currentSessionType = null;
      final audioSession = await session;
      await audioSession.setActive(false);
      
      // 重置为默认的环境音频配置
      await configureSession(AudioSessionType.ambient);
    } catch (e) {
      print('Failed to reset audio session: $e');
    }
  }

  /// 获取适合消息提示音的音频会话
  Future<AudioSession> getNotificationAudioSession() async {
    await configureSession(AudioSessionType.ambient);
    return session;
  }

  /// 获取适合媒体播放的音频会话
  Future<AudioSession> getMediaAudioSession() async {
    await configureSession(AudioSessionType.playback);
    return session;
  }

  /// 获取适合录音的音频会话
  Future<AudioSession> getRecordAudioSession() async {
    await configureSession(AudioSessionType.record);
    return session;
  }
}
