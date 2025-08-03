import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
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
    
    // Initialize just_audio_background for media controls
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.pumpkinbites.channel.audio',
      androidNotificationChannelName: 'Pumpkin Bites Audio',
      androidNotificationChannelDescription: 'Audio playback for Pumpkin Bites',
    );
    
    // Initialize audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
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
      
      // Create MediaItem for lock screen and notification controls
      final mediaItem = MediaItem(
        id: bite.id,
        title: bite.title,
        artist: 'Pumpkin Bites',
        duration: Duration(seconds: bite.duration),
        artUri: bite.thumbnailUrl.isNotEmpty ? Uri.parse(bite.thumbnailUrl) : null,
        album: bite.category,
        extras: {
          'authorName': bite.authorName,
          'description': bite.description,
        },
      );
      
      // Set the audio source with media item for background controls
      String finalAudioUrl = audioUrl;
      MediaItem finalMediaItem = mediaItem;
      
      try {
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: mediaItem,
          ),
        );
        print("Audio source set successfully with media controls");
      } catch (e) {
        print("Error setting audio source: $e");
        // Try fallback URL if setting url fails
        finalAudioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
        finalMediaItem = mediaItem.copyWith(
          id: '${bite.id}_fallback',
          title: '${bite.title} (Fallback)',
        );
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(finalAudioUrl),
            tag: finalMediaItem,
          ),
        );
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
          // Create clipped audio source with MediaItem tag preserved
          final clippedSource = ClippingAudioSource(
            start: Duration.zero,
            end: Duration(seconds: bite.duration),
            child: AudioSource.uri(
              Uri.parse(finalAudioUrl),
              tag: finalMediaItem,
            ),
          );
          await _player.setAudioSource(clippedSource);
        } else {
          // If model duration is also invalid, use a default of 3 minutes
          print("Using default 3-minute duration");
          final clippedSource = ClippingAudioSource(
            start: Duration.zero,
            end: const Duration(minutes: 3),
            child: AudioSource.uri(
              Uri.parse(finalAudioUrl),
              tag: finalMediaItem,
            ),
          );
          await _player.setAudioSource(clippedSource);
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
  
  // FIXED: Pause playback (keeps audio loaded, just pauses)
  Future<void> pause() async {
    try {
      print("AudioService: Pausing playback");
      await _player.pause();
      print("AudioService: Successfully paused");
    } catch (e) {
      print("AudioService: Error pausing: $e");
    }
  }
  
  // FIXED: Resume playback (continues from current position)
  Future<void> resume() async {
    try {
      print("AudioService: Resuming playback");
      await _player.play();
      print("AudioService: Successfully resumed");
    } catch (e) {
      print("AudioService: Error resuming: $e");
    }
  }
  
  // ADDED: Toggle play/pause for convenience
  Future<void> togglePlayPause() async {
    try {
      if (isPlaying) {
        await pause();
      } else {
        await resume();
      }
    } catch (e) {
      print("AudioService: Error toggling play/pause: $e");
    }
  }
  
  // Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      print("AudioService: Seeking to $position");
      await _player.seek(position);
    } catch (e) {
      print("AudioService: Error seeking: $e");
    }
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
  
  // FIXED: Is playing check (more reliable)
  bool get isPlaying {
    try {
      return _player.playing;
    } catch (e) {
      print("AudioService: Error checking playing state: $e");
      return false;
    }
  }
  
  // Get playback state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  // ADDED: Stop playback completely (for when you actually want to stop)
  Future<void> stop() async {
    try {
      print("AudioService: Stopping playback completely");
      await _player.stop();
      _currentBite = null;
      print("AudioService: Successfully stopped");
    } catch (e) {
      print("AudioService: Error stopping: $e");
    }
  }
  
  // Dispose
  Future<void> dispose() async {
    await _player.dispose();
  }
}