import 'package:just_audio/just_audio.dart';
import '../models/bite_model.dart';

class AudioPlayerService {
  // Create a singleton
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  // The audio player instance
  final AudioPlayer _player = AudioPlayer();
  
  // Current bite being played
  BiteModel? _currentBite;
  
  // Initialize player
  Future<void> init() async {
    print("Initializing audio player service");
    // Nothing to do here for now - just a placeholder
  }
  
  // Load and play a bite
  Future<void> playBite(BiteModel bite) async {
    try {
      print("Playing bite: ${bite.id}, audio URL: ${bite.audioUrl}");
      _currentBite = bite;
      
      // Use fallback URL if needed
      String audioUrl = bite.audioUrl.trim();
      if (audioUrl.isEmpty || (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://'))) {
        audioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
        print("Using fallback URL: $audioUrl");
      }
      
      // Set the audio source
      await _player.setUrl(audioUrl);
      
      // Ensure we start at the beginning
      await _player.seek(Duration.zero);
      
      // Then play
      await _player.play();
      print("Successfully started playback from beginning");
    } catch (e) {
      print("Error playing bite: $e");
      throw e;
    }
  }
  
  // Pause playback
  Future<void> pause() async {
    await _player.pause();
  }
  
  // Resume playback
  Future<void> resume() async {
    await _player.play();
  }
  
  // Seek to position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }
  
  // Get current position
  Duration get position => _player.position;
  
  // Get current duration
  Duration? get duration => _player.duration;
  
  // Get position stream
  Stream<Duration> get positionStream => _player.positionStream;
  
  // Get duration stream
  Stream<Duration?> get durationStream => _player.durationStream;
  
  // Is playing?
  bool get isPlaying => _player.playing;
  
  // Get playback state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  // Dispose
  Future<void> dispose() async {
    await _player.dispose();
  }
}