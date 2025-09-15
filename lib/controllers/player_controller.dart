import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bite_model.dart';
import '../repositories/content_repository.dart';
import '../services/audio_service.dart';
import '../utils/app_logger.dart';
import '../core/service_locator.dart';

/// Controller for player screens and floating player
/// Manages audio playback state and progress
class PlayerController extends ChangeNotifier with LoggerMixin {
  // Dependencies
  ContentRepository get _contentRepository => getIt<ContentRepository>();
  AudioService get _audioService => getIt<AudioService>();
  
  // State variables
  PlayerState _state = PlayerState.stopped;
  BiteModel? _currentBite;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;
  String _errorMessage = '';
  
  // Subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  
  // Getters
  PlayerState get state => _state;
  BiteModel? get currentBite => _currentBite;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackSpeed => _playbackSpeed;
  bool get isBuffering => _isBuffering;
  String get errorMessage => _errorMessage;
  
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  bool get isStopped => _state == PlayerState.stopped;
  bool get hasError => _state == PlayerState.error;
  
  double get progress {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }
  
  String get positionText => _formatDuration(_position);
  String get durationText => _formatDuration(_duration);
  String get remainingText => _formatDuration(_duration - _position);

  /// Initialize the controller
  PlayerController() {
    logDebug('PlayerController created');
    _setupAudioListeners();
  }

  /// Setup audio service listeners
  void _setupAudioListeners() {
    // Position updates
    _positionSubscription = _audioService.positionStream.listen(
      (position) {
        _position = position;
        notifyListeners();
      },
      onError: (error, stackTrace) {
        logError('Position stream error', error, stackTrace);
      },
    );
    
    // Duration updates
    _durationSubscription = _audioService.durationStream.listen(
      (duration) {
        if (duration != null) {
          _duration = duration;
          notifyListeners();
        }
      },
      onError: (error, stackTrace) {
        logError('Duration stream error', error, stackTrace);
      },
    );
    
    // Playing state updates
    _playingSubscription = _audioService.playingStream.listen(
      (isPlaying) {
        if (isPlaying && _state != PlayerState.playing) {
          _setState(PlayerState.playing);
        } else if (!isPlaying && _state == PlayerState.playing) {
          _setState(PlayerState.paused);
        }
      },
      onError: (error, stackTrace) {
        logError('Playing stream error', error, stackTrace);
      },
    );
  }

  /// Load and play a bite
  Future<void> playBite(BiteModel bite) async {
    logUserAction('Play bite', {
      'bite_id': bite.id,
      'bite_title': bite.title,
    });
    
    try {
      _setState(PlayerState.loading);
      _isBuffering = true;
      _currentBite = bite;
      notifyListeners();
      
      // Check access
      final hasAccess = await _contentRepository.hasUserAccessToBite(bite.id);
      if (!hasAccess) {
        throw Exception('You don\'t have access to this content');
      }
      
      // Load audio
      await _audioService.setAudioSource(bite.audioUrl);
      
      // Mark as opened and track play
      await _contentRepository.markBiteAsOpened(bite.id);
      await _contentRepository.trackBitePlay(bite.id);
      
      // Start playing
      await _audioService.play();
      
      _isBuffering = false;
      _setState(PlayerState.playing);
      
      logInfo('Bite loaded and playing', {'bite_id': bite.id});
      
    } catch (error, stackTrace) {
      logError('Failed to play bite', error, stackTrace, {
        'bite_id': bite.id,
      });
      
      _setState(PlayerState.error);
      _errorMessage = _getErrorMessage(error);
      _isBuffering = false;
    } finally {
      notifyListeners();
    }
  }

  /// Play/pause toggle
  Future<void> togglePlayPause() async {
    logUserAction('Toggle play/pause', {'current_state': _state.toString()});
    
    try {
      if (_state == PlayerState.playing) {
        await _audioService.pause();
        _setState(PlayerState.paused);
      } else if (_state == PlayerState.paused) {
        await _audioService.play();
        _setState(PlayerState.playing);
      }
    } catch (error, stackTrace) {
      logError('Failed to toggle play/pause', error, stackTrace);
      _setState(PlayerState.error);
      _errorMessage = 'Failed to control playback';
      notifyListeners();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    logUserAction('Stop playback');
    
    try {
      await _audioService.stop();
      _setState(PlayerState.stopped);
      _position = Duration.zero;
      
      // Track completion if near end
      if (_currentBite != null && progress > 0.8) {
        await _contentRepository.trackBiteCompletion(_currentBite!.id);
        logInfo('Bite completion tracked', {'bite_id': _currentBite!.id});
      }
      
    } catch (error, stackTrace) {
      logError('Failed to stop playback', error, stackTrace);
    } finally {
      notifyListeners();
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    logUserAction('Seek to position', {
      'position_seconds': position.inSeconds,
      'progress': position.inMilliseconds / _duration.inMilliseconds,
    });
    
    try {
      await _audioService.seek(position);
      _position = position;
      notifyListeners();
    } catch (error, stackTrace) {
      logError('Failed to seek', error, stackTrace, {
        'position_seconds': position.inSeconds,
      });
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    logUserAction('Set playback speed', {'speed': speed});
    
    try {
      await _audioService.setSpeed(speed);
      _playbackSpeed = speed;
      notifyListeners();
    } catch (error, stackTrace) {
      logError('Failed to set playback speed', error, stackTrace, {
        'speed': speed,
      });
    }
  }

  /// Skip forward
  Future<void> skipForward([Duration duration = const Duration(seconds: 10)]) async {
    final newPosition = _position + duration;
    await seekTo(newPosition > _duration ? _duration : newPosition);
  }

  /// Skip backward
  Future<void> skipBackward([Duration duration = const Duration(seconds: 10)]) async {
    final newPosition = _position - duration;
    await seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  /// Set state and log transitions
  void _setState(PlayerState newState) {
    if (_state != newState) {
      logDebug('Player state transition', {
        'from': _state.toString(),
        'to': newState.toString(),
      });
      _state = newState;
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Check your internet connection and try again.';
    } else if (errorStr.contains('access') || errorStr.contains('permission')) {
      return 'You don\'t have access to this content.';
    } else if (errorStr.contains('format') || errorStr.contains('codec')) {
      return 'This audio format is not supported.';
    } else {
      return 'Failed to play audio. Please try again.';
    }
  }

  @override
  void dispose() {
    logDebug('Disposing PlayerController');
    
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    
    super.dispose();
  }
}

/// Enum for player states
enum PlayerState {
  stopped,
  loading,
  playing,
  paused,
  error,
}