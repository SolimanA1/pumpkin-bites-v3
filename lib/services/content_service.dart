import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';

class ContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get today's bite
  Future<BiteModel?> getTodaysBite() async {
    try {
      // Get today's date in the format stored in Firestore
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final querySnapshot = await _firestore
          .collection('bites')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // If no bite for today, get the most recent one
        final recentQuerySnapshot = await _firestore
            .collection('bites')
            .orderBy('date', descending: true)
            .limit(1)
            .get();
            
        if (recentQuerySnapshot.docs.isEmpty) {
          return null;
        }
        
        final doc = recentQuerySnapshot.docs.first;
        return BiteModel.fromFirestore(doc);
      }

      final doc = querySnapshot.docs.first;
      return BiteModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting today\'s bite: $e');
      return null;
    }
  }

  // Get bite by ID
  Future<BiteModel?> getBiteById(String biteId) async {
    try {
      final docSnapshot = await _firestore.collection('bites').doc(biteId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      return BiteModel.fromFirestore(docSnapshot);
    } catch (e) {
      print('Error getting bite by ID: $e');
      return null;
    }
  }

  // Get catch-up bites (recent bites excluding today's)
  Future<List<BiteModel>> getCatchUpBites({int limit = 7}) async {
    try {
      // Get today's date in the format stored in Firestore
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final querySnapshot = await _firestore
          .collection('bites')
          .where('date', isNotEqualTo: today)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting catch-up bites: $e');
      return [];
    }
  }

  // Get available bites for the dinner table discussion
  Future<List<BiteModel>> getAvailableBites({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      final isPremiumUser = user != null ? await _isUserPremium(user.uid) : false;
      
      // Query parameters
      final query = _firestore.collection('bites')
          .orderBy('date', descending: true)
          .limit(limit);
      
      final querySnapshot = await query.get();
      
      final bites = querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .where((bite) => !bite.isPremiumOnly || isPremiumUser) // Filter premium content
          .toList();
      
      // Load comment counts for each bite
      await _loadCommentCounts(bites);
      
      return bites;
    } catch (e) {
      print('Error getting available bites: $e');
      return [];
    }
  }
  
  // Helper method to check if user is premium
  Future<bool> _isUserPremium(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data();
      if (userData == null) return false;
      
      final isPremium = userData['isPremium'] as bool? ?? false;
      final membershipEndDate = userData['membershipEndDate'] as Timestamp?;
      
      // If no end date, it's a lifetime membership
      if (isPremium && membershipEndDate == null) return true;
      
      // Check if membership is still active
      if (isPremium && membershipEndDate != null) {
        return DateTime.now().isBefore(membershipEndDate.toDate());
      }
      
      return false;
    } catch (e) {
      print('Error checking premium status: $e');
      return false;
    }
  }
  
  // Helper method to load comment counts
  Future<void> _loadCommentCounts(List<BiteModel> bites) async {
    try {
      for (int i = 0; i < bites.length; i++) {
        final bite = bites[i];
        final count = await _getCommentCount(bite.id);
        // Update the bite's comment count
        bites[i] = bite.withCommentCount(count);
      }
    } catch (e) {
      print('Error loading comment counts: $e');
    }
  }
  
  // Helper method to get comment count for a bite - FIXED
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

  // Get unlocked bites for a user
  Future<List<BiteModel>> getUnlockedBites() async {
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
      final unlockedContent = (userData['unlockedContent'] as List<dynamic>?) ?? [];
      
      // Convert to list of strings
      final unlockedIds = unlockedContent.map((item) => item.toString()).toList();
      
      if (unlockedIds.isEmpty) {
        return [];
      }
      
      // Firestore doesn't support direct array queries with more than 10 items,
      // so we might need to do multiple queries or filter in-memory
      final result = <BiteModel>[];
      
      if (unlockedIds.length <= 10) {
        // We can use a single Firestore query
        final querySnapshot = await _firestore
            .collection('bites')
            .where(FieldPath.documentId, whereIn: unlockedIds)
            .get();
            
        result.addAll(querySnapshot.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .toList());
      } else {
        // Need to use multiple queries
        for (int i = 0; i < unlockedIds.length; i += 10) {
          final endIndex = (i + 10 < unlockedIds.length) ? i + 10 : unlockedIds.length;
          final batchIds = unlockedIds.sublist(i, endIndex);
          
          final querySnapshot = await _firestore
              .collection('bites')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
              
          result.addAll(querySnapshot.docs
              .map((doc) => BiteModel.fromFirestore(doc))
              .toList());
        }
      }
      
      // Filter out premium-only content if user is not premium
      final isPremium = userData['isPremium'] as bool? ?? false;
      if (!isPremium) {
        result.removeWhere((bite) => bite.isPremiumOnly);
      }
      
      // Sort by date, newest first
      result.sort((a, b) => b.date.compareTo(a.date));
      
      return result;
    } catch (e) {
      print('Error getting unlocked bites: $e');
      return [];
    }
  }

  // Get all bites - for admin or gifting
  Future<List<BiteModel>> getAllBites() async {
    try {
      final querySnapshot = await _firestore
          .collection('bites')
          .orderBy('date', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all bites: $e');
      return [];
    }
  }

  // Get listened bites for a user
  Future<List<BiteModel>> getListenedBites() async {
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
      final listenedBites = (userData['listenedBites'] as List<dynamic>?) ?? [];
      
      // Convert to list of strings
      final listenedIds = listenedBites.map((item) => item.toString()).toList();
      
      if (listenedIds.isEmpty) {
        return [];
      }
      
      // Firestore doesn't support direct array queries with more than 10 items,
      // so we might need to do multiple queries
      final result = <BiteModel>[];
      
      if (listenedIds.length <= 10) {
        // We can use a single Firestore query
        final querySnapshot = await _firestore
            .collection('bites')
            .where(FieldPath.documentId, whereIn: listenedIds)
            .get();
            
        result.addAll(querySnapshot.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .toList());
      } else {
        // Need to use multiple queries
        for (int i = 0; i < listenedIds.length; i += 10) {
          final endIndex = (i + 10 < listenedIds.length) ? i + 10 : listenedIds.length;
          final batchIds = listenedIds.sublist(i, endIndex);
          
          final querySnapshot = await _firestore
              .collection('bites')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
              
          result.addAll(querySnapshot.docs
              .map((doc) => BiteModel.fromFirestore(doc))
              .toList());
        }
      }
      
      // Filter out premium-only content if user is not premium
      final isPremium = userData['isPremium'] as bool? ?? false;
      if (!isPremium) {
        result.removeWhere((bite) => bite.isPremiumOnly);
      }
      
      // Sort by date, newest first
      result.sort((a, b) => b.date.compareTo(a.date));
      
      return result;
    } catch (e) {
      print('Error getting listened bites: $e');
      return [];
    }
  }

  // Get gifted episodes for a user
  Future<List<BiteModel>> getGiftedEpisodes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }
      
      // Get the user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final giftedEpisodes = userData['giftedEpisodes'] as List<dynamic>? ?? [];
      
      if (giftedEpisodes.isEmpty) {
        return [];
      }
      
      // Extract bite IDs
      final List<String> biteIds = [];
      final Map<String, Map<String, dynamic>> giftInfo = {};
      
      for (final gift in giftedEpisodes) {
        if (gift is Map<String, dynamic> && gift.containsKey('biteId')) {
          final biteId = gift['biteId'] as String?;
          if (biteId != null && biteId.isNotEmpty) {
            biteIds.add(biteId);
            
            // Store gift info for later use
            giftInfo[biteId] = {
              'senderName': gift['senderName'] as String? ?? 'Someone',
              'message': gift['message'] as String? ?? 'Enjoy this content!',
            };
          }
        }
      }
      
      if (biteIds.isEmpty) {
        return [];
      }
      
      // Load the bites
      final result = <BiteModel>[];
      
      if (biteIds.length <= 10) {
        // We can use a single Firestore query
        final querySnapshot = await _firestore
            .collection('bites')
            .where(FieldPath.documentId, whereIn: biteIds)
            .get();
            
        for (final doc in querySnapshot.docs) {
          final bite = BiteModel.fromFirestore(doc);
          final giftData = giftInfo[bite.id];
          
          if (giftData != null) {
            // Add gift info
            result.add(bite.asGiftedBite(
              senderName: giftData['senderName'] as String,
              message: giftData['message'] as String,
            ));
          } else {
            result.add(bite);
          }
        }
      } else {
        // Need to use multiple queries
        for (int i = 0; i < biteIds.length; i += 10) {
          final endIndex = (i + 10 < biteIds.length) ? i + 10 : biteIds.length;
          final batchIds = biteIds.sublist(i, endIndex);
          
          final querySnapshot = await _firestore
              .collection('bites')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
              
          for (final doc in querySnapshot.docs) {
            final bite = BiteModel.fromFirestore(doc);
            final giftData = giftInfo[bite.id];
            
            if (giftData != null) {
              // Add gift info
              result.add(bite.asGiftedBite(
                senderName: giftData['senderName'] as String,
                message: giftData['message'] as String,
              ));
            } else {
              result.add(bite);
            }
          }
        }
      }
      
      return result;
    } catch (e) {
      print('Error getting gifted episodes: $e');
      return [];
    }
  }

  // Mark a bite as listened
  Future<bool> markBiteAsListened(String biteId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      await _firestore.collection('users').doc(user.uid).update({
        'listenedBites': FieldValue.arrayUnion([biteId]),
      });
      
      return true;
    } catch (e) {
      print('Error marking bite as listened: $e');
      return false;
    }
  }

  // Get comments for a bite
  Future<List<CommentModel>> getCommentsForBite(String biteId) async {
    try {
      final querySnapshot = await _firestore
          .collection('comments')
          .where('biteId', isEqualTo: biteId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Add a comment to a bite
  Future<bool> addComment(String biteId, String text) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final displayName = userData?['displayName'] as String? ?? 'User';
      final photoURL = userData?['photoURL'] as String? ?? '';
      
      await _firestore.collection('comments').add({
        'biteId': biteId,
        'text': text,
        'userId': user.uid,
        'displayName': displayName,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  // Get user's reactions to bites
  Future<Map<String, String>> getUserReactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {};
      }
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reactions')
          .get();
      
      final reactions = <String, String>{};
      
      for (final doc in querySnapshot.docs) {
        final biteId = doc.id;
        final data = doc.data();
        final reaction = data['reaction'] as String? ?? '';
        
        if (reaction.isNotEmpty) {
          reactions[biteId] = reaction;
        }
      }
      
      return reactions;
    } catch (e) {
      print('Error getting user reactions: $e');
      return {};
    }
  }
}