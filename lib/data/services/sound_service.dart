import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flow/data/services/settings_service.dart';

class SoundService {
  SoundService({this.settingsService}) {
    _init();
  }

  final SettingsService? settingsService;
  static const int _poolSize = 2;
  static const int _minIntervalMs = 48;
  final List<AudioPlayer> _players = [];
  AudioPlayer? _connectionPlayer;
  AudioPlayer? _levelCompletePlayer;
  int _currentIndex = 0;
  int _lastPlayTime = 0;
  int _lastConnectionTime = 0;
  int _lastLevelCompleteTime = 0;
  bool _initialized = false;

  Future<void> _init() async {
    try {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource('audio/sound.mp3'));
        await player.setVolume(0.38);
        _players.add(player);
      }

      final connectionPlayer = AudioPlayer();
      await connectionPlayer.setPlayerMode(PlayerMode.lowLatency);
      await connectionPlayer.setReleaseMode(ReleaseMode.stop);
      await connectionPlayer.setSource(AssetSource('audio/complete_connection.mp3'));
      await connectionPlayer.setVolume(0.65);
      _connectionPlayer = connectionPlayer;

      final levelCompletePlayer = AudioPlayer();
      await levelCompletePlayer.setPlayerMode(PlayerMode.lowLatency);
      await levelCompletePlayer.setReleaseMode(ReleaseMode.stop);
      await levelCompletePlayer.setSource(AssetSource('audio/level_complete.mp3'));
      await levelCompletePlayer.setVolume(0.75);
      _levelCompletePlayer = levelCompletePlayer;

      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  bool get _isEnabled {
    if (settingsService == null) return true;
    return settingsService!.getSettings().isSoundEnabled;
  }

  void _playSound({double volume = 0.38, bool force = false}) {
    if (!_isEnabled || !_initialized || _players.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && (now - _lastPlayTime < _minIntervalMs)) return;
    _lastPlayTime = now;

    final player = _players[_currentIndex];
    _currentIndex = (_currentIndex + 1) % _players.length;

    unawaited(() async {
      try {
        await player.setVolume(volume);
        await player.stop();
        await player.resume();
      } catch (_) {}
    }());
  }

  void playDragStep(int stepIndex) {
    _playSound(volume: 0.38);
  }

  void playDragRetract(int stepIndex) {
    _playSound(volume: 0.24);
  }

  void playConnectionComplete() {
    if (!_isEnabled || !_initialized || _connectionPlayer == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastConnectionTime < 150) return;
    _lastConnectionTime = now;

    unawaited(() async {
      try {
        await _connectionPlayer!.stop();
        await _connectionPlayer!.resume();
      } catch (_) {}
    }());
  }

  void playFlowComplete() {
    playConnectionComplete();
  }

  void playLevelComplete() {
    if (!_isEnabled || !_initialized || _levelCompletePlayer == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLevelCompleteTime < 300) return;
    _lastLevelCompleteTime = now;

    unawaited(() async {
      try {
        await Future.delayed(const Duration(milliseconds: 180));
        await _levelCompletePlayer!.stop();
        await _levelCompletePlayer!.resume();
      } catch (_) {}
    }());
  }

  void dispose() {
    for (final player in _players) {
      unawaited(player.dispose());
    }
    _players.clear();
    unawaited(_connectionPlayer?.dispose());
    _connectionPlayer = null;
    unawaited(_levelCompletePlayer?.dispose());
    _levelCompletePlayer = null;
    _initialized = false;
  }
}
