import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;
  AudioService._();

  bool _muted = false;
  bool get muted => _muted;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('audio_muted') ?? false;
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_muted', _muted);
  }

  void _play(String asset, {double volume = 1.0}) {
    if (_muted) return;
    final player = AudioPlayer();
    player.setReleaseMode(ReleaseMode.stop);
    player.setVolume(volume);
    player.play(AssetSource(asset));
    player.onPlayerComplete.listen((_) => player.dispose());
  }

  void playTap() => _play('audio/tap.wav', volume: 0.5);
  void playCorrect() => _play('audio/correct.wav', volume: 0.7);
  void playWrong() => _play('audio/wrong.wav', volume: 0.7);
  void playSpellCast() => _play('audio/spell_cast.mp3', volume: 0.8);
  void playImpact() => _play('audio/impact.wav', volume: 0.8);
  void playVictory() => _play('audio/victory.mp3');
  void playDefeat() => _play('audio/defeat.mp3');
  void playCoin() => _play('audio/coin.mp3', volume: 0.7);
  void playStreak() => _play('audio/streak.mp3', volume: 0.6);
  void playSelect() => _play('audio/select.mp3', volume: 0.6);
}
