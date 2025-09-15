import '../models/bite_model.dart';
import '../models/comment_model.dart';

/// Clean interface for all content operations
/// This replaces your monolithic ContentService
abstract class ContentRepository {
  // === BITE OPERATIONS ===
  Future<BiteModel?> getTodaysBite();
  Future<List<BiteModel>> getCatchUpBites();
  Future<List<BiteModel>> getUserSequentialBites();
  Future<BiteModel?> getBiteById(String biteId);
  Future<List<BiteModel>> getBitesByCategory(String category);
  Future<List<BiteModel>> searchBites(String query);
  Future<void> markBiteAsOpened(String biteId);
  Future<bool> hasUserAccessToBite(String biteId);
  
  // === COMMENT OPERATIONS ===
  Future<List<CommentModel>> getCommentsForBite(String biteId);
  Future<void> addComment(String biteId, String content);
  Future<void> replyToComment(String commentId, String content);
  Future<int> getCommentCount(String biteId);
  
  // === REACTION OPERATIONS ===
  Future<void> addReaction(String biteId, String reactionType);
  Future<void> removeReaction(String biteId, String reactionType);
  Future<Map<String, int>> getReactionCounts(String biteId);
  
  // === CACHE OPERATIONS ===
  Future<void> clearCache();
  Future<void> refreshCache();
  
  // === ANALYTICS ===
  Future<void> trackBitePlay(String biteId);
  Future<void> trackBiteCompletion(String biteId);
}