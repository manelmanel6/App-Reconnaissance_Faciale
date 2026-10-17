import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playSuccessSound() async {
    await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  Future<void> playFailureSound() async {
    await _audioPlayer.play(AssetSource('sounds/failure.mp3'));
  }

  void dispose() {
    _audioPlayer.dispose();
  }
} 