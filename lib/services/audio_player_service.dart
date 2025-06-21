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
  
  // Get current bite being played
  BiteModel? get currentBite => _currentBite;

  // Initialize player
  Future<void> init() async {
    print("Initializing audio player service");
    // Initialize with better error handling
    _player.playbackEventStream.listen(
      (event) => {
        // Log playback events for debugging
        print("Playback event: $event")
      },
      onError: (Object e, StackTrace st) {
        print('Audio player error: $e');
      },
    );
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
      
      // Stop previous playback if any
      await _player.stop();
      
      // Set the audio source with better error handling
      try {
        await _player.setUrl(audioUrl);
        print("Audio source set successfully");
      } catch (e) {
        print("Error setting audio source: $e");
        // Try fallback URL if setting url fails
        await _player.setUrl("https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3");
      }
      
      // Wait for the duration to be available
      final duration = await _waitForDuration();
      print("Audio duration: $duration");
      
      // If the model has a duration, but the player couldn't detect it,
      // manually set a default duration from the model
      if (duration == null || duration.inMilliseconds <= 0) {
        print("Using bite model duration: ${bite.duration} seconds");
        // Use the duration from the bite model (in seconds)
        if (bite.duration > 0) {
          // Force a default duration based on the bite model
          _player.setClip(
            start: Duration.zero,
            end: Duration(seconds: bite.duration),
          );
        } else {
          // If model duration is also invalid, use a default of 3 minutes
          print("Using default 3-minute duration");
          _player.setClip(
            start: Duration.zero,
            end: const Duration(minutes: 3),
          );
        }
      }
      
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
  
  // Helper method to wait for duration to be available
  Future<Duration?> _waitForDuration() async {
    // Wait up to 5 seconds for duration to be available
    for (int i = 0; i < 50; i++) {
      final duration = _player.duration;
      if (duration != null && duration.inMilliseconds > 0) {
        return duration;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    print("Timed out waiting for duration");
    return null;
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
  Duration? get duration {
    final durFromPlayer = _player.duration;
    
    // If player duration is valid, use it
    if (durFromPlayer != null && durFromPlayer.inMilliseconds > 0) {
      return durFromPlayer;
    }
    
    // Otherwise, fall back to the bite model duration
    if (_currentBite != null && _currentBite!.duration > 0) {
      return Duration(seconds: _currentBite!.duration);
    }
    
    // As a last resort, default to 3 minutes
    return const Duration(minutes: 3);
  }
  
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