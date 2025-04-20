import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/bite_model.dart';

enum ProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

class PlayerState {
  final bool playing;
  final ProcessingState processingState;
  
  PlayerState({
    required this.playing,
    required this.processingState,
  });
}

class AudioPlayerService {
  // Singleton pattern
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  BiteModel? _currentBite;
  
  // Initialize the audio player
  Future<void> init() async {
    try {
      print("Initializing audio player");
      // We'll try to initialize the background service, but if it fails,
      // we'll still allow the app to function
      try {
        await JustAudioBackground.init(
          androidNotificationChannelId: 'com.pumpkinbites.audio',
          androidNotificationChannelName: 'Pumpkin Bites Audio',
          androidNotificationOngoing: true,
        );
        print("Background audio service initialized successfully");
      } catch (backgroundError) {
        print('Background audio initialization error: $backgroundError');
        print('Continuing without background playback...');
      }
      
      // Make sure player is stopped and reset
      await _player.stop();
      print("Audio player initialized successfully");
    } catch (e) {
      print('Audio player initialization error: $e');
    }
  }
  
  // Load a bite's audio with better error handling
  Future<void> loadBite(BiteModel bite) async {
    try {
      print("========== AUDIO DEBUG ==========");
      print("Loading audio for bite: ${bite.id}");
      print("Original audio URL: '${bite.audioUrl}'");
      
      _currentBite = bite;
      
      // Thorough URL cleaning
      String? cleanUrl = bite.audioUrl;
      
      // Check for null or empty URL
      if (cleanUrl == null || cleanUrl.isEmpty) {
        print("ERROR: Audio URL is null or empty!");
        throw Exception('Audio URL is null or empty');
      }
      
      // Trim the URL
      cleanUrl = cleanUrl.trim();
      print("Cleaned URL: '$cleanUrl'");
      
      // Validate the URL format
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        print("ERROR: URL does not start with http:// or https://");
        throw Exception('Invalid URL format');
      }
      
      print("Setting audio source...");
      
      // Set the audio source with better error handling
      try {
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(cleanUrl),
            tag: MediaItem(
              id: bite.id,
              title: bite.title,
              artist: 'Pumpkin Bites',
              artUri: Uri.parse(bite.thumbnailUrl.trim()),
            ),
          ),
        );
        print("Audio source set successfully");
      } catch (audioSourceError) {
        print("ERROR setting audio source: $audioSourceError");
        
        // Try with a fallback URL if the original fails
        print("Attempting with fallback audio URL...");
        const fallbackUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
        
        try {
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(fallbackUrl),
              tag: MediaItem(
                id: bite.id,
                title: bite.title + " (Fallback)",
                artist: 'Pumpkin Bites',
                artUri: Uri.parse(bite.thumbnailUrl.trim()),
              ),
            ),
          );
          print("Fallback audio source set successfully");
        } catch (fallbackError) {
          print("ERROR setting fallback audio source: $fallbackError");
          throw Exception('Could not load audio, even with fallback URL');
        }
      }
      
      print("Audio loaded successfully");
      print("========== END AUDIO DEBUG ==========");
    } catch (e) {
      print('ERROR in loadBite method: $e');
      throw e;
    }
  }
  
  // Play the currently loaded audio
  Future<void> play() async {
    try {
      print("Playing audio");
      await _player.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }
  
  // Pause the currently playing audio
  Future<void> pause() async {
    try {
      print("Pausing audio");
      await _player.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }
  
  // Seek to a specific position
  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('Error seeking audio: $e');
    }
  }
  
  // Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      print('Error setting speed: $e');
    }
  }
  
  // Get current position stream
  Stream<Duration> get positionStream => _player.positionStream;
  
  // Get buffer position stream
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  
  // Get duration stream
  Stream<Duration?> get durationStream => _player.durationStream;
  
  // Get player state stream
  Stream<PlayerState> get playerStateStream {
    return Rx.combineLatest2<bool, ProcessingStateStreamValue, PlayerState>(
      _player.playingStream,
      _processingStateStream,
      (playing, processingState) => PlayerState(
        playing: playing,
        processingState: processingState.state,
      ),
    );
  }
  
  // Private stream to convert Just Audio processing state to our enum
  Stream<ProcessingStateStreamValue> get _processingStateStream {
    return _player.processingStateStream.map((state) {
      switch (state) {
        case ProcessingState.idle:
          return ProcessingStateStreamValue(ProcessingState.idle);
        case ProcessingState.loading:
          return ProcessingStateStreamValue(ProcessingState.loading);
        case ProcessingState.buffering:
          return ProcessingStateStreamValue(ProcessingState.buffering);
        case ProcessingState.ready:
          return ProcessingStateStreamValue(ProcessingState.ready);
        case ProcessingState.completed:
          return ProcessingStateStreamValue(ProcessingState.completed);
        default:
          return ProcessingStateStreamValue(ProcessingState.error);
      }
    });
  }
  
  // Dispose the player
  Future<void> dispose() async {
    await _player.dispose();
  }
}

// Helper class to wrap our ProcessingState enum
class ProcessingStateStreamValue {
  final ProcessingState state;
  
  ProcessingStateStreamValue(this.state);
}