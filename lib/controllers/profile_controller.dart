import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/subscription_service.dart';
import '../services/user_progression_service.dart';
import '../utils/app_logger.dart';
import '../core/service_locator.dart';

/// Controller for ProfileScreen state management
class ProfileController extends ChangeNotifier with LoggerMixin {
  // Dependencies
  SubscriptionService get _subscriptionService => getIt<SubscriptionService>();
  UserProgressionService get _progressionService => getIt<UserProgressionService>();
  
  // State variables
  ProfileScreenState _state = ProfileScreenState.loading;
  User? _currentUser;
  bool _isSubscribed = false;
  DateTime? _trialEndDate;
  int _currentDay = 1;
  int _totalBitesListened = 0;
  int _totalComments = 0;
  String _errorMessage = '';
  
  // Subscriptions
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  
  // Getters
  ProfileScreenState get state => _state;
  User? get currentUser => _currentUser;
  bool get isSubscribed => _isSubscribed;
  DateTime? get trialEndDate => _trialEndDate;
  int get currentDay => _currentDay;
  int get totalBitesListened => _totalBitesListened;
  int get totalComments => _totalComments;
  String get errorMessage => _errorMessage;
  
  bool get isLoading => _state == ProfileScreenState.loading;
  bool get hasError => _state == ProfileScreenState.error;
  bool get isInTrial => _trialEndDate != null && DateTime.now().isBefore(_trialEndDate!);
  
  String get displayName => _currentUser?.displayName ?? 'Pumpkin Bites User';
  String get email => _currentUser?.email ?? '';
  String? get photoUrl => _currentUser?.photoURL;

  /// Initialize the controller
  ProfileController() {
    logDebug('ProfileController created');
    _initialize();
  }

  Future<void> _initialize() async {
    logDebug('Initializing ProfileController...');
    
    try {
      await loadProfile();
      _setupListeners();
      
      logInfo('ProfileController initialized successfully');
    } catch (error, stackTrace) {
      logError('Failed to initialize ProfileController', error, stackTrace);
      _setState(ProfileScreenState.error);
      _errorMessage = 'Failed to load profile';
      notifyListeners();
    }
  }

  /// Setup authentication and subscription listeners
  void _setupListeners() {
    // Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        logDebug('Auth state changed', {
          'user_id': user?.uid,
          'is_authenticated': user != null,
        });
        
        _currentUser = user;
        if (user != null) {
          loadProfile();
        }
      },
      onError: (error, stackTrace) {
        logError('Auth state listener error', error, stackTrace);
      },
    );
    
    // Subscription status changes
    _subscriptionStatusSubscription = _subscriptionService
        .subscriptionStatusStream
        .listen(
          (isSubscribed) {
            logDebug('Subscription status changed', {'is_subscribed': isSubscribed});
            _isSubscribed = isSubscribed;
            notifyListeners();
          },
          onError: (error, stackTrace) {
            logError('Subscription status listener error', error, stackTrace);
          },
        );
  }

  /// Load user profile data
  Future<void> loadProfile() async {
    logDebug('Loading user profile...');
    _setState(ProfileScreenState.loading);
    notifyListeners();
    
    final stopwatch = Stopwatch()..start();
    
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      
      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Load subscription info
      await _subscriptionService.initialize();
      _isSubscribed = _subscriptionService.isSubscriptionActive;
      _trialEndDate = _subscriptionService.trialEndDate;
      
      // Load progression info
      _currentDay = await _progressionService.getCurrentDay();
      
      // Load stats (simplified)
      await _loadUserStats();
      
      _setState(ProfileScreenState.loaded);
      _errorMessage = '';
      
      stopwatch.stop();
      logInfo('Profile loaded successfully', {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'current_day': _currentDay,
        'is_subscribed': _isSubscribed,
        'is_in_trial': isInTrial,
      });
      
    } catch (error, stackTrace) {
      logError('Failed to load profile', error, stackTrace);
      _setState(ProfileScreenState.error);
      _errorMessage = _getErrorMessage(error);
    } finally {
      notifyListeners();
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    logUserAction('Refresh profile');
    await loadProfile();
  }

  /// Sign out user
  Future<void> signOut() async {
    logUserAction('Sign out user');
    
    try {
      await FirebaseAuth.instance.signOut();
      
      // Reset state
      _currentUser = null;
      _isSubscribed = false;
      _trialEndDate = null;
      _currentDay = 1;
      _totalBitesListened = 0;
      _totalComments = 0;
      
      logInfo('User signed out successfully');
      notifyListeners();
      
    } catch (error, stackTrace) {
      logError('Failed to sign out', error, stackTrace);
      _errorMessage = 'Failed to sign out. Please try again.';
      notifyListeners();
    }
  }

  /// Update display name
  Future<void> updateDisplayName(String newName) async {
    logUserAction('Update display name', {'new_name': newName});
    
    try {
      if (_currentUser == null) throw Exception('User not authenticated');
      
      await _currentUser!.updateDisplayName(newName);
      await _currentUser!.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
      
      logInfo('Display name updated successfully', {'new_name': newName});
      notifyListeners();
      
    } catch (error, stackTrace) {
      logError('Failed to update display name', error, stackTrace);
      _errorMessage = 'Failed to update name. Please try again.';
      notifyListeners();
    }
  }

  /// Subscribe to premium
  Future<void> subscribeToPremium() async {
    logUserAction('Subscribe to premium');
    
    try {
      // Use your existing subscription logic
      await _subscriptionService.purchaseSubscription();
      
      _isSubscribed = true;
      
      logInfo('Successfully subscribed to premium');
      notifyListeners();
      
    } catch (error, stackTrace) {
      logError('Failed to subscribe', error, stackTrace);
      _errorMessage = 'Failed to subscribe. Please try again.';
      notifyListeners();
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    logUserAction('Restore purchases');
    
    try {
      // Use your existing restore logic
      await _subscriptionService.restorePurchases();
      
      // Refresh subscription status
      await _subscriptionService.initialize();
      _isSubscribed = _subscriptionService.isSubscriptionActive;
      
      logInfo('Purchases restored successfully');
      notifyListeners();
      
    } catch (error, stackTrace) {
      logError('Failed to restore purchases', error, stackTrace);
      _errorMessage = 'Failed to restore purchases. Please try again.';
      notifyListeners();
    }
  }

  /// Load user statistics
  Future<void> _loadUserStats() async {
    try {
      // Add your existing stats logic here
      _totalBitesListened = 25; // Placeholder
      _totalComments = 8; // Placeholder
      
      logDebug('User stats loaded', {
        'bites_listened': _totalBitesListened,
        'comments': _totalComments,
      });
    } catch (error, stackTrace) {
      logError('Failed to load user stats', error, stackTrace);
      // Don't fail profile loading for stats
      _totalBitesListened = 0;
      _totalComments = 0;
    }
  }

  /// Set state and log transitions
  void _setState(ProfileScreenState newState) {
    if (_state != newState) {
      logDebug('Profile state transition', {
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
    } else if (errorStr.contains('auth') || errorStr.contains('permission')) {
      return 'Authentication error. Please sign in again
} else if (errorStr.contains('subscription') || errorStr.contains('billing')) {
      return 'Subscription error. Please check your payment method.';
    } else {
      return 'Something went wrong. Please try again later.';
    }
  }

  @override
  void dispose() {
    logDebug('Disposing ProfileController');
    
    _authSubscription?.cancel();
    _subscriptionStatusSubscription?.cancel();
    
    super.dispose();
  }
}

/// Enum for ProfileScreen states
enum ProfileScreenState {
  loading,
  loaded,
  error,
}