import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bite_model.dart';
import '../repositories/content_repository.dart';
import '../services/user_progression_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';
import '../core/service_locator.dart';

/// Controller for HomeScreen state management
/// Extracts all business logic from the widget
class HomeController extends ChangeNotifier with LoggerMixin {
  // Dependencies through service locator
  ContentRepository get _contentRepository => getIt<ContentRepository>();
  UserProgressionService get _progressionService => getIt<UserProgressionService>();
  SubscriptionService get _subscriptionService => getIt<SubscriptionService>();
  
  // State variables
  HomeScreenState _state = HomeScreenState.loading;
  BiteModel? _todaysBite;
  List<BiteModel> _catchUpBites = [];
  String _errorMessage = '';
  String _loadingMessage = 'Loading content...';
  
  // Sequential release state
  bool _isTodaysBiteUnlocked = false;
  DateTime? _nextUnlockTime;
  Duration _timeUntilUnlock = Duration.zero;
  
  // Timers
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  
  // Performance optimization
  DateTime? _lastContentRefresh;
  static const Duration _refreshInterval = Duration(minutes: 30);
  
  // Getters
  HomeScreenState get state => _state;
  BiteModel? get todaysBite => _todaysBite;
  List<BiteModel> get catchUpBites => _catchUpBites;
  String get errorMessage => _errorMessage;
  String get loadingMessage => _loadingMessage;
  bool get isTodaysBiteUnlocked => _isTodaysBiteUnlocked;
  DateTime? get nextUnlockTime => _nextUnlockTime;
  Duration get timeUntilUnlock => _timeUntilUnlock;
  
  bool get isLoading => _state == HomeScreenState.loading;
  bool get hasError => _state == HomeScreenState.error;
  bool get isRefreshing => _state == HomeScreenState.refreshing;

  /// Initialize the controller
  HomeController() {
    logDebug('HomeController created');
    _initialize();
  }

  Future<void> _initialize() async {
    logDebug('Initializing HomeController...');
    
    try {
      await loadContent();
      _startTimers();
      _setupSubscriptionListener();
      
      logInfo('HomeController initialized successfully');
    } catch (error, stackTrace) {
      logError('Failed to initialize HomeController', error, stackTrace);
      _setState(HomeScreenState.error);
      _errorMessage = 'Failed to initialize home screen';
      notifyListeners();
    }
  }

  /// Setup subscription status listener
  void _setupSubscriptionListener() {
    _subscriptionStatusSubscription = _subscriptionService
        .subscriptionStatusStream
        .listen(
          (hasAccess) {
            logDebug('Subscription status changed', {'has_access': hasAccess});
            refreshContent();
          },
          onError: (error, stackTrace) {
            logError('Subscription status listener error', error, stackTrace);
          },
        );
  }

  /// Load all content for the home screen
  Future<void> loadContent() async {
    logDebug('Loading home screen content...');
    _setState(HomeScreenState.loading);
    _loadingMessage = 'Loading content...';
    notifyListeners();
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check progression status first
      await _progressionService.checkTrialExpiration();
      
      // Load content in parallel
      final futures = await Future.wait([
        _contentRepository.getTodaysBite(),
        _contentRepository.getCatchUpBites(),
        _loadUnlockStatus(),
      ]);
      
      _todaysBite = futures[0] as BiteModel?;
      _catchUpBites = futures[1] as List<BiteModel>;
      // futures[2] is void (unlock status loading)
      
      _lastContentRefresh = DateTime.now();
      _setState(HomeScreenState.loaded);
      _errorMessage = '';
      
      stopwatch.stop();
      logInfo('Home content loaded successfully', {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'todays_bite_loaded': _todaysBite != null,
        'catchup_count': _catchUpBites.length,
      });
      
    } catch (error, stackTrace) {
      logError('Failed to load home screen content', error, stackTrace);
      _setState(HomeScreenState.error);
      _errorMessage = _getErrorMessage(error);
    } finally {
      notifyListeners();
    }
  }

  /// Refresh content with loading state
  Future<void> refreshContent() async {
    if (_state == HomeScreenState.refreshing) return;
    
    logUserAction('Refresh home screen content');
    _setState(HomeScreenState.refreshing);
    notifyListeners();
    
    try {
      await loadContent();
      logInfo('Home screen content refreshed successfully');
    } catch (error, stackTrace) {
      logError('Failed to refresh home screen content', error, stackTrace);
    }
  }

  /// Handle bite tap navigation
  Future<void> onBiteTapped(BiteModel bite) async {
    logUserAction('Bite tapped', {
      'bite_id': bite.id,
      'bite_title': bite.title,
    });
    
    try {
      // Check if user has access
      final hasAccess = await _contentRepository.hasUserAccessToBite(bite.id);
      
      if (hasAccess) {
        // Mark as opened and track play
        await _contentRepository.markBiteAsOpened(bite.id);
        await _contentRepository.trackBitePlay(bite.id);
        
        logInfo('User has access to bite, ready to play', {'bite_id': bite.id});
      } else {
        logWarning('User does not have access to bite', {'bite_id': bite.id});
      }
    } catch (error, stackTrace) {
      logError('Failed to handle bite tap', error, stackTrace, {
        'bite_id': bite.id,
      });
    }
  }

  /// Handle unlock event (called by countdown timer)
  void onUnlockEvent() {
    logInfo('Unlock event triggered');
    _isTodaysBiteUnlocked = true;
    _timeUntilUnlock = Duration.zero;
    notifyListeners();
    refreshContent();
  }

  /// Load unlock status and timing information
  Future<void> _loadUnlockStatus() async {
    try {
      final currentDay = await _progressionService.getCurrentDay();
      final shouldUnlock = await _progressionService.shouldUnlockNextBite();
      
      _isTodaysBiteUnlocked = shouldUnlock;
      
      // Calculate next unlock time (simplified)
      if (!shouldUnlock) {
        final now = DateTime.now();
        _nextUnlockTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
        _timeUntilUnlock = _nextUnlockTime!.difference(now);
      }
      
      logDebug('Unlock status loaded', {
        'current_day': currentDay,
        'is_unlocked': _isTodaysBiteUnlocked,
        'next_unlock': _nextUnlockTime?.toIso8601String(),
      });
      
    } catch (error, stackTrace) {
      logError('Failed to load unlock status', error, stackTrace);
      _isTodaysBiteUnlocked = false;
      _nextUnlockTime = null;
      _timeUntilUnlock = Duration.zero;
    }
  }

  /// Start refresh and countdown timers
  void _startTimers() {
    // Content refresh timer
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      logDebug('Auto-refreshing content');
      refreshContent();
    });
    
    // Countdown timer
    _startCountdownTimer();
  }

  /// Start countdown timer for unlock
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    
    if (_timeUntilUnlock.inSeconds > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timeUntilUnlock.inSeconds <= 1) {
          timer.cancel();
          onUnlockEvent();
        } else {
          _timeUntilUnlock = Duration(seconds: _timeUntilUnlock.inSeconds - 1);
          notifyListeners();
        }
      });
    }
  }

  /// Set state and log transitions
  void _setState(HomeScreenState newState) {
    if (_state != newState) {
      logDebug('State transition', {
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
      return 'Please check your internet connection and try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('access')) {
      return 'You don\'t have permission to access this content.';
    } else if (errorStr.contains('trial') || errorStr.contains('subscription')) {
      return 'Please check your subscription status.';
    } else {
      return 'Something went wrong. Please try again later.';
    }
  }

  @override
  void dispose() {
    logDebug('Disposing HomeController');
    
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _subscriptionStatusSubscription?.cancel();
    
    super.dispose();
  }
}

/// Enum for HomeScreen states
enum HomeScreenState {
  loading,
  loaded,
  refreshing,
  error,
}