import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Like a comment - added to fix the missing method
  Future<bool> likeComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      // Check if user already liked this comment
      final likeDoc = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(user.uid)
          .get();
      
      if (likeDoc.exists) {
        // User already liked the comment, remove the like
        await _firestore
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(user.uid)
            .delete();
        
        // Decrement like count
        await _firestore.collection('comments').doc(commentId).update({
          'likeCount': FieldValue.increment(-1),
        });
        
        return false; // Returning false to indicate the comment is now unliked
      } else {
        // User has not liked the comment yet, add the like
        await _firestore
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(user.uid)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Increment like count
        await _firestore.collection('comments').doc(commentId).update({
          'likeCount': FieldValue.increment(1),
        });
        
        return true; // Returning true to indicate the comment is now liked
      }
    } catch (e) {
      print('Error liking comment: $e');
      return false;
    }
  }

  // Get trending topics
  Future<List<BiteModel>> getTrendingTopics({int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection('bites')
          .orderBy('commentCount', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting trending topics: $e');
      return [];
    }
  }

  // Get recent comments
  Future<List<CommentModel>> getRecentComments({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting recent comments: $e');
      return [];
    }
  }

  // Check if user liked a comment
  Future<bool> hasUserLikedComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final likeDoc = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(user.uid)
          .get();
      
      return likeDoc.exists;
    } catch (e) {
      print('Error checking if user liked comment: $e');
      return false;
    }
  }

  // Get user's favorite bites
  Future<List<BiteModel>> getFavoriteBites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final favoriteBites = userData['favoriteBites'] as List<dynamic>? ?? [];
      
      // Convert to list of strings
      final favoriteIds = favoriteBites.map((item) => item.toString()).toList();
      
      if (favoriteIds.isEmpty) {
        return [];
      }
      
      // Firestore doesn't support direct array queries with more than 10 items,
      // so we might need to do multiple queries or filter in-memory
      final result = <BiteModel>[];
      
      if (favoriteIds.length <= 10) {
        // We can use a single Firestore query
        final querySnapshot = await _firestore
            .collection('bites')
            .where(FieldPath.documentId, whereIn: favoriteIds)
            .get();
            
        result.addAll(querySnapshot.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .toList());
      } else {
        // Need to use multiple queries
        for (int i = 0; i < favoriteIds.length; i += 10) {
          final endIndex = (i + 10 < favoriteIds.length) ? i + 10 : favoriteIds.length;
          final batchIds = favoriteIds.sublist(i, endIndex);
          
          final querySnapshot = await _firestore
              .collection('bites')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
              
          result.addAll(querySnapshot.docs
              .map((doc) => BiteModel.fromFirestore(doc))
              .toList());
        }
      }
      
      // Load comment counts for each bite
      for (int i = 0; i < result.length; i++) {
        final bite = result[i];
        final commentCount = await _getCommentCount(bite.id);
        result[i] = bite.withCommentCount(commentCount);
      }
      
      return result;
    } catch (e) {
      print('Error getting favorite bites: $e');
      return [];
    }
  }

  // Toggle favorite status of a bite
  Future<bool> toggleFavoriteBite(String biteId, bool isFavorite) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      if (isFavorite) {
        // Add to favorites
        await _firestore.collection('users').doc(user.uid).update({
          'favoriteBites': FieldValue.arrayUnion([biteId]),
        });
        
        return true;
      } else {
        // Remove from favorites
        await _firestore.collection('users').doc(user.uid).update({
          'favoriteBites': FieldValue.arrayRemove([biteId]),
        });
        
        return false;
      }
    } catch (e) {
      print('Error toggling favorite bite: $e');
      return isFavorite; // Return the original state on error
    }
  }

  // Helper method to get comment count for a bite
  Future<int> _getCommentCount(String biteId) async {
    try {
      final querySnapshot = await _firestore
          .collection('comments')
          .where('biteId', isEqualTo: biteId)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting comment count: $e');
      return 0;
    }
  }
}