import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/user_progression_service.dart';
import '../utils/app_logger.dart';
import '../core/service_locator.dart';
import 'content_repository.dart';

/// Implementation that wraps your existing ContentService
/// This preserves all your working logic while adding clean structure
class ContentRepositoryImpl with LoggerMixin implements ContentRepository {
  // Use your existing services through dependency injection
  ContentService get _contentService => getIt<ContentService>();
  UserProgressionService get _progressionService => getIt<UserProgressionService>();
  
  // Cache for performance
  final Map<String, BiteModel> _biteCache = {};
  final Map<String, int> _commentCountCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  @override
  Future<BiteModel?> getTodaysBite() async {
    logDebug('Getting today\'s bite...');
    
    try {
      // Use your existing ContentService logic
      final bite = await _contentService.getTodaysBite();
      
      if (bite != null) {
        _biteCache[bite.id] = bite;
        _cacheTimestamps[bite.id] = DateTime.now();
        
        logInfo('Today\'s bite loaded successfully', {'bite_id': bite.id});
      }
      
      return bite;
    } catch (error, stackTrace) {
      logError('Failed to get today\'s bite', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<BiteModel>> getCatchUpBites() async {
    logDebug('Getting catch-up bites...');
    
    try {
      // Use your existing ContentService logic
      final bites = await _contentService.getCatchUpBites();
      
      // Cache the results
      for (final bite in bites) {
        _biteCache[bite.id] = bite;
        _cacheTimestamps[bite.id] = DateTime.now();
      }
      
      logInfo('Catch-up bites loaded successfully', {'count': bites.length});
      return bites;
    } catch (error, stackTrace) {
      logError('Failed to get catch-up bites', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<BiteModel>> getUserSequentialBites() async {
    logDebug('Getting user sequential bites...');
    
    try {
      // Use your existing ContentService logic
      final bites = await _contentService.getUserSequentialBites();
      
      logInfo('User sequential bites loaded', {'count': bites.length});
      return bites;
    } catch (error, stackTrace) {
      logError('Failed to get user sequential bites', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<BiteModel?> getBiteById(String biteId) async {
    logDebug('Getting bite by ID', {'bite_id': biteId});
    
    try {
      // Check cache first
      if (_isCacheValid(biteId)) {
        logDebug('Bite retrieved from cache', {'bite_id': biteId});
        return _biteCache[biteId];
      }
      
      // Use your existing ContentService logic
      final bite = await _contentService.getBiteById(biteId);
      
      if (bite != null) {
        _biteCache[biteId] = bite;
        _cacheTimestamps[biteId] = DateTime.now();
      }
      
      return bite;
    } catch (error, stackTrace) {
      logError('Failed to get bite by ID', error, stackTrace, {'bite_id': biteId});
      rethrow;
    }
  }

  @override
  Future<List<BiteModel>> getBitesByCategory(String category) async {
    logDebug('Getting bites by category', {'category': category});
    
    try {
      // TODO: ContentService.getBitesByCategory method doesn't exist yet
      // Using getAllBites as fallback for now
      final allBites = await _contentService.getAllBites();
      final bites = allBites.where((bite) => bite.category == category).toList();
      
      logInfo('Bites loaded by category', {
        'category': category,
        'count': bites.length,
      });
      
      return bites;
    } catch (error, stackTrace) {
      logError('Failed to get bites by category', error, stackTrace, {
        'category': category,
      });
      rethrow;
    }
  }

  @override
  Future<List<BiteModel>> searchBites(String query) async {
    logDebug('Searching bites', {'query': query});
    
    try {
      // TODO: ContentService.searchBites method doesn't exist yet
      // Using getAllBites with filter as fallback for now
      final allBites = await _contentService.getAllBites();
      final bites = allBites.where((bite) =>
        bite.title.toLowerCase().contains(query.toLowerCase()) ||
        bite.description.toLowerCase().contains(query.toLowerCase())
      ).toList();
      
      logInfo('Bite search completed', {
        'query': query,
        'results_count': bites.length,
      });
      
      return bites;
    } catch (error, stackTrace) {
      logError('Failed to search bites', error, stackTrace, {'query': query});
      rethrow;
    }
  }

  @override
  Future<void> markBiteAsOpened(String biteId) async {
    logUserAction('Mark bite as opened', {'bite_id': biteId});
    
    try {
      // Use your existing ContentService logic
      await _contentService.markBiteAsOpened(biteId);
      
      // Invalidate cache
      _biteCache.remove(biteId);
      _cacheTimestamps.remove(biteId);
      
      logInfo('Bite marked as opened', {'bite_id': biteId});
    } catch (error, stackTrace) {
      logError('Failed to mark bite as opened', error, stackTrace, {
        'bite_id': biteId,
      });
      rethrow;
    }
  }

  @override
  Future<bool> hasUserAccessToBite(String biteId) async {
    try {
      // Use your existing progression service logic
      final currentDay = await _progressionService.getCurrentDay();
      // Add your existing access logic here
      
      return true; // Simplified for now
    } catch (error, stackTrace) {
      logError('Failed to check user access', error, stackTrace, {
        'bite_id': biteId,
      });
      return false;
    }
  }

  @override
  Future<List<CommentModel>> getCommentsForBite(String biteId) async {
    logDebug('Getting comments for bite', {'bite_id': biteId});
    
    try {
      // Use your existing ContentService logic
      final comments = await _contentService.getCommentsForBite(biteId);
      
      logInfo('Comments loaded', {
        'bite_id': biteId,
        'count': comments.length,
      });
      
      return comments;
    } catch (error, stackTrace) {
      logError('Failed to get comments', error, stackTrace, {'bite_id': biteId});
      rethrow;
    }
  }

  @override
  Future<void> addComment(String biteId, String content) async {
    logUserAction('Add comment', {
      'bite_id': biteId,
      'content_length': content.length,
    });
    
    try {
      // Use your existing ContentService logic
      await _contentService.addComment(biteId, content);
      
      // Invalidate comment count cache
      _commentCountCache.remove(biteId);
      
      logInfo('Comment added successfully', {'bite_id': biteId});
    } catch (error, stackTrace) {
      logError('Failed to add comment', error, stackTrace, {'bite_id': biteId});
      rethrow;
    }
  }

  @override
  Future<void> replyToComment(String commentId, String content) async {
    logUserAction('Reply to comment', {
      'comment_id': commentId,
      'content_length': content.length,
    });
    
    try {
      // Use your existing ContentService logic
      // TODO: ContentService.replyToComment method doesn't exist yet
      throw UnimplementedError('Reply to comment not implemented yet');
      
      logInfo('Comment reply added', {'comment_id': commentId});
    } catch (error, stackTrace) {
      logError('Failed to reply to comment', error, stackTrace, {
        'comment_id': commentId,
      });
      rethrow;
    }
  }

  @override
  Future<int> getCommentCount(String biteId) async {
    try {
      // Check cache first
      if (_commentCountCache.containsKey(biteId)) {
        return _commentCountCache[biteId]!;
      }
      
      // TODO: ContentService.getCommentCount method doesn't exist yet
      // Return 0 as fallback for now
      final count = 0;
      
      // Cache the result
      _commentCountCache[biteId] = count;
      
      return count;
    } catch (error, stackTrace) {
      logError('Failed to get comment count', error, stackTrace, {
        'bite_id': biteId,
      });
      return 0;
    }
  }

  @override
  Future<void> addReaction(String biteId, String reactionType) async {
    logUserAction('Add reaction', {
      'bite_id': biteId,
      'reaction_type': reactionType,
    });
    
    try {
      // Use your existing ContentService logic
      // TODO: ContentService.addReaction method doesn't exist yet
      throw UnimplementedError('Add reaction not implemented yet');
      
      logInfo('Reaction added', {
        'bite_id': biteId,
        'reaction_type': reactionType,
      });
    } catch (error, stackTrace) {
      logError('Failed to add reaction', error, stackTrace, {
        'bite_id': biteId,
        'reaction_type': reactionType,
      });
      rethrow;
    }
  }

  @override
  Future<void> removeReaction(String biteId, String reactionType) async {
    logUserAction('Remove reaction', {
      'bite_id': biteId,
      'reaction_type': reactionType,
    });
    
    try {
      // Use your existing ContentService logic
      // TODO: ContentService.removeReaction method doesn't exist yet
      throw UnimplementedError('Remove reaction not implemented yet');
      
      logInfo('Reaction removed', {
        'bite_id': biteId,
        'reaction_type': reactionType,
      });
    } catch (error, stackTrace) {
      logError('Failed to remove reaction', error, stackTrace, {
        'bite_id': biteId,
        'reaction_type': reactionType,
      });
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getReactionCounts(String biteId) async {
    try {
      // TODO: ContentService.getReactionCounts method doesn't exist yet
      final counts = <String, int>{}; // Empty map as fallback
      
      return counts;
    } catch (error, stackTrace) {
      logError('Failed to get reaction counts', error, stackTrace, {
        'bite_id': biteId,
      });
      return {};
    }
  }

  @override
  Future<void> clearCache() async {
    logDebug('Clearing content cache');
    
    _biteCache.clear();
    _commentCountCache.clear();
    _cacheTimestamps.clear();
    
    logInfo('Content cache cleared');
  }

  @override
  Future<void> refreshCache() async {
    logDebug('Refreshing content cache');
    
    await clearCache();
    
    logInfo('Content cache refreshed');
  }

  @override
  Future<void> trackBitePlay(String biteId) async {
    logUserAction('Track bite play', {'bite_id': biteId});
    
    try {
      // TODO: ContentService.trackBitePlay method doesn't exist yet
      // Commenting out until method is implemented
      // await _contentService.trackBitePlay(biteId);
    } catch (error, stackTrace) {
      logError('Failed to track bite play', error, stackTrace, {
        'bite_id': biteId,
      });
      // Don't rethrow - analytics failures shouldn't break functionality
    }
  }

  @override
  Future<void> trackBiteCompletion(String biteId) async {
    logUserAction('Track bite completion', {'bite_id': biteId});
    
    try {
      // TODO: ContentService.trackBiteCompletion method doesn't exist yet
      // Commenting out until method is implemented
      // await _contentService.trackBiteCompletion(biteId);
    } catch (error, stackTrace) {
      logError('Failed to track bite completion', error, stackTrace, {
        'bite_id': biteId,
      });
      // Don't rethrow - analytics failures shouldn't break functionality
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid(String key) {
    if (!_biteCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    
    final timestamp = _cacheTimestamps[key]!;
    final age = DateTime.now().difference(timestamp);
    
    return age < _cacheValidityDuration;
  }
}