import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bite_model.dart';
import '../repositories/content_repository.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';
import '../core/service_locator.dart';

/// Controller for LibraryScreen state management
/// Extracts all business logic from the LibraryScreen widget
class LibraryController extends ChangeNotifier with LoggerMixin {
  // Dependencies
  ContentRepository get _contentRepository => getIt<ContentRepository>();
  SubscriptionService get _subscriptionService => getIt<SubscriptionService>();
  
  // State variables
  LibraryScreenState _state = LibraryScreenState.loading;
  List<BiteModel> _allBites = [];
  List<BiteModel> _favoriteBites = [];
  List<BiteModel> _filteredBites = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _errorMessage = '';
  
  // Categories
  final List<String> _categories = [
    'All',
    'Psychology',
    'Relationships', 
    'Life Skills',
    'Business',
    'Philosophy'
  ];
  
  // Subscriptions
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  
  // Getters
  LibraryScreenState get state => _state;
  List<BiteModel> get allBites => _allBites;
  List<BiteModel> get favoriteBites => _favoriteBites;
  List<BiteModel> get filteredBites => _filteredBites;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get errorMessage => _errorMessage;
  List<String> get categories => _categories;
  
  bool get isLoading => _state == LibraryScreenState.loading;
  bool get hasError => _state == LibraryScreenState.error;
  bool get isEmpty => _state == LibraryScreenState.loaded && _filteredBites.isEmpty;

  /// Initialize the controller
  LibraryController() {
    logDebug('LibraryController created');
    _initialize();
  }

  Future<void> _initialize() async {
    logDebug('Initializing LibraryController...');
    
    try {
      await loadContent();
      _setupSubscriptionListener();
      
      logInfo('LibraryController initialized successfully');
    } catch (error, stackTrace) {
      logError('Failed to initialize LibraryController', error, stackTrace);
      _setState(LibraryScreenState.error);
      _errorMessage = 'Failed to initialize library';
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

  /// Load all content for the library
  Future<void> loadContent() async {
    logDebug('Loading library content...');
    _setState(LibraryScreenState.loading);
    notifyListeners();
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Load user's sequential bites (respects progression)
      _allBites = await _contentRepository.getUserSequentialBites();
      
      // Load favorites
      await _loadFavorites();
      
      // Apply current filters
      _applyFilters();
      
      _setState(LibraryScreenState.loaded);
      _errorMessage = '';
      
      stopwatch.stop();
      logInfo('Library content loaded successfully', {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'total_bites': _allBites.length,
        'favorites_count': _favoriteBites.length,
        'filtered_count': _filteredBites.length,
      });
      
    } catch (error, stackTrace) {
      logError('Failed to load library content', error, stackTrace);
      _setState(LibraryScreenState.error);
      _errorMessage = _getErrorMessage(error);
    } finally {
      notifyListeners();
    }
  }

  /// Refresh content
  Future<void> refreshContent() async {
    logUserAction('Refresh library content');
    await loadContent();
  }

  /// Search bites
  void searchBites(String query) {
    logUserAction('Search bites', {'query': query});
    
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  /// Filter by category
  void filterByCategory(String category) {
    logUserAction('Filter by category', {'category': category});
    
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String biteId) async {
    logUserAction('Toggle favorite', {'bite_id': biteId});
    
    try {
      final isFavorite = _favoriteBites.any((bite) => bite.id == biteId);
      
      if (isFavorite) {
        await _removeFavorite(biteId);
      } else {
        await _addFavorite(biteId);
      }
      
      // Refresh favorites and apply filters
      await _loadFavorites();
      _applyFilters();
      notifyListeners();
      
    } catch (error, stackTrace) {
      logError('Failed to toggle favorite', error, stackTrace, {
        'bite_id': biteId,
      });
    }
  }

  /// Handle bite selection
  Future<void> onBiteSelected(BiteModel bite) async {
    logUserAction('Bite selected', {
      'bite_id': bite.id,
      'bite_title': bite.title,
    });
    
    try {
      // Check access and mark as opened
      final hasAccess = await _contentRepository.hasUserAccessToBite(bite.id);
      
      if (hasAccess) {
        await _contentRepository.markBiteAsOpened(bite.id);
        await _contentRepository.trackBitePlay(bite.id);
        
        logInfo('Bite selected and tracked', {'bite_id': bite.id});
      } else {
        logWarning('User does not have access to bite', {'bite_id': bite.id});
      }
    } catch (error, stackTrace) {
      logError('Failed to handle bite selection', error, stackTrace, {
        'bite_id': bite.id,
      });
    }
  }

  /// Load favorites from storage
  Future<void> _loadFavorites() async {
    try {
      // Use your existing favorites logic
      _favoriteBites = _allBites.where((bite) => bite.isFavorite ?? false).toList();
      
      logDebug('Favorites loaded', {'count': _favoriteBites.length});
    } catch (error, stackTrace) {
      logError('Failed to load favorites', error, stackTrace);
      _favoriteBites = [];
    }
  }

  /// Add bite to favorites
  Future<void> _addFavorite(String biteId) async {
    try {
      // Add your existing favorite logic here
      logInfo('Bite added to favorites', {'bite_id': biteId});
    } catch (error, stackTrace) {
      logError('Failed to add favorite', error, stackTrace, {'bite_id': biteId});
      rethrow;
    }
  }

  /// Remove bite from favorites
  Future<void> _removeFavorite(String biteId) async {
    try {
      // Add your existing unfavorite logic here
      logInfo('Bite removed from favorites', {'bite_id': biteId});
    } catch (error, stackTrace) {
      logError('Failed to remove favorite', error, stackTrace, {'bite_id': biteId});
      rethrow;
    }
  }

  /// Apply current search and category filters
  void _applyFilters() {
    List<BiteModel> filtered = List.from(_allBites);
    
    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((bite) => bite.category == _selectedCategory).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((bite) {
        return bite.title.toLowerCase().contains(query) ||
               bite.description.toLowerCase().contains(query);
      }).toList();
    }
    
    _filteredBites = filtered;
    
    logDebug('Filters applied', {
      'category': _selectedCategory,
      'search_query': _searchQuery,
      'total_results': _filteredBites.length,
    });
  }

  /// Set state and log transitions
  void _setState(LibraryScreenState newState) {
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
    } else {
      return 'Something went wrong loading your library.';
    }
  }

  @override
  void dispose() {
    logDebug('Disposing LibraryController');
    
    _subscriptionStatusSubscription?.cancel();
    
    super.dispose();
  }
}

/// Enum for LibraryScreen states
enum LibraryScreenState {
  loading,
  loaded,
  error,
}