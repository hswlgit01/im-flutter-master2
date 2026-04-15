import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/url_converter.dart';
import '../../managers/audio_session_manager.dart';

class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;

  final AudioPlayer _player = AudioPlayer();
  final AudioSessionManager _audioSessionManager = AudioSessionManager();
  String? _currentId;

  AudioPlayerManager._internal();

  Future<void> _configureAudioSession() async {
    try {
      // 使用统一的音频会话管理器配置媒体播放会话
      await _audioSessionManager.configureSession(AudioSessionType.playback);
    } catch (e) {
      print('Failed to configure audio session: $e');
    }
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  String? get currentId => _currentId;

  /// 预下载
  Future<void> preDownload(Message message) async {
    final localPath = await AudioCacheManager().getLocalPath(message);
    if (localPath != null) {
      print("Audio pre-downloaded: $localPath");
    } else {
      print("Failed to pre-download audio for message: ${message.clientMsgID}");
    }
  }

  Future<void> play(Message message) async {
    // 配置媒体播放音频会话
    await _configureAudioSession();
    
    final state = _player.playerState;
    if (currentId == message.clientMsgID &&
        state.playing &&
        state.processingState == ProcessingState.ready) {
      await _player.pause(); // 同一个音频就暂停
    } else {
      await _player.stop();
      _currentId = message.clientMsgID;
      final localPath = await AudioCacheManager().getLocalPath(message);
      if (localPath != null) {
        print("localPath: $localPath");
        await _player.setFilePath(localPath);
      } else {
        await _player.setUrl(message.soundElem?.sourceUrl ?? ""); // 网络备用
      }
      _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentId = null;
    // 停止播放后激活状态会自动管理，不需要手动重置会话
  }

  void dispose() {
    _player.dispose();
  }
}

class AudioCacheManager {
  static final AudioCacheManager _instance = AudioCacheManager._internal();
  factory AudioCacheManager() => _instance;
  AudioCacheManager._internal();

  Future<bool> isFileExists(String path) async {
    final file = File(path);
    return await file.exists();
  }

  Future<String?> getLocalPath(Message message) async {
    final soundPath = message.soundElem?.soundPath;
    if (soundPath != null) {
      if (await isFileExists(soundPath)) {
        return soundPath;
      }
    }
    final sourceUrl = message.soundElem?.sourceUrl ?? "";
    final dir = await getTemporaryDirectory();
    final fileName = Uri.parse(sourceUrl).pathSegments.last;
    final id = message.clientMsgID ?? "";
    final filePath = "${dir.path}/message/$id/$fileName";
    if (await isFileExists(filePath)) {
      return filePath;
    }
    try {
      await Dio().download(UrlConverter.convertMediaUrl(sourceUrl), filePath);
      return filePath;
    } catch (e) {
      print("Download audio failed: $e");
      return null;
    }
  }
}
