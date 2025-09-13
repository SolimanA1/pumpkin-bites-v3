import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import 'user_progression_service.dart';

class ContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Lazy initialization to avoid circular dependencies
  UserProgressionService? _progressionService;
  UserProgressionService get _userProgression {
    _progressionService ??= UserProgressionService();
    return _progressionService!;
  }
  
  // Performance optimization: Cache user document to avoid duplicate Firebase calls
  DocumentSnapshot<Map<String, dynamic>>? _cachedUserDoc;
  String? _cachedUserId;
  DateTime? _userDocCacheTime;
  static const Duration _userDocCacheValidityDuration = Duration(minutes: 5);

  // Performance optimization: Get user document with caching
  Future<DocumentSnapshot<Map<String, dynamic>>?> _getCachedUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final now = DateTime.now();
    
    // Check if we have a valid cached user document
    if (_cachedUserDoc != null && 
        _cachedUserId == user.uid &&
        _userDocCacheTime != null &&
        now.difference(_userDocCacheTime!).abs() < _userDocCacheValidityDuration) {
      return _cachedUserDoc;
    }
    
    // Fetch fresh user document
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    // Cache the result
    _cachedUserDoc = userDoc;
    _cachedUserId = user.uid;
    _userDocCacheTime = now;
    
    return userDoc;
  }

  // Enhanced method to get user's current bite based on progression
  Future<BiteModel?> getTodaysBite() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;
      
      final data = userDoc.data()!;
      
      // Check for sequential release data (new system)
      final sequentialData = data['sequentialRelease'] as Map<String, dynamic>?;
      
      int currentDay;
      if (sequentialData != null) {
        // Use new progression system
        currentDay = sequentialData['currentDay'] as int;
        
        // Check if progression is active
        final progressionStatus = sequentialData['progressionStatus'] as String;
        if (progressionStatus == 'paused') {
          return null; // No content available when paused
        }
        
        // Check if next bite should be unlocked
        await _userProgression.checkAndUnlockNextBite();
        
        // Refresh data after potential unlock
        final updatedDoc = await _firestore.collection('users').doc(user.uid).get();
        final updatedData = updatedDoc.data()!;
        final updatedSequentialData = updatedData['sequentialRelease'] as Map<String, dynamic>;
        currentDay = updatedSequentialData['currentDay'] as int;
      } else {
        // Fallback to old system for unmigrated users
        final userRegistrationDate = (data['createdAt'] as Timestamp).toDate();
        final now = DateTime.now();
        currentDay = now.difference(userRegistrationDate).inDays + 1;
      }
      
      // Get bite for current day
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isEqualTo: currentDay)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Fallback to highest available day
        final fallbackQuery = await _firestore
            .collection('bites')
            .where('dayNumber', isLessThanOrEqualTo: currentDay)
            .orderBy('dayNumber', descending: true)
            .limit(1)
            .get();
            
        if (fallbackQuery.docs.isEmpty) return null;
        return BiteModel.fromFirestore(fallbackQuery.docs.first);
      }
      
      return BiteModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('Error getting today\'s bite: $e');
      return null;
    }
  }

  // Get user's NEXT sequential bite (for locked preview after trial expires) - CRITICAL
  Future<BiteModel?> getUsersNextBite() async {
    try {
      print("Getting user's NEXT sequential bite...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user");
        return null;
      }
      
      // Get user's registration date to calculate their day number
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return null;
      }
      
      final userData = UserModel.fromFirestore(userDoc);
      final userRegistrationDate = userData.createdAt;
      
      // Calculate the user's current day (Day 1, Day 2, etc.)
      final now = DateTime.now();
      final daysSinceRegistration = now.difference(userRegistrationDate).inDays + 1;
      
      print("User is on Day: $daysSinceRegistration - getting NEXT bite");
      
      // Get the bite for this specific day number (their current/next bite)
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isEqualTo: daysSinceRegistration)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("No bite found for day $daysSinceRegistration, trying highest available");
        
        // If no exact day match, get the highest available day number
        final fallbackQuery = await _firestore
            .collection('bites')
            .orderBy('dayNumber', descending: true)
            .limit(1)
            .get();
            
        if (fallbackQuery.docs.isEmpty) {
          print("No bites available at all");
          return null;
        }
        
        final doc = fallbackQuery.docs.first;
        print("Found highest available bite for day ${doc.data()['dayNumber']}: ${doc.id}");
        return BiteModel.fromFirestore(doc);
      }
      
      final doc = querySnapshot.docs.first;
      print("Found exact NEXT bite for day $daysSinceRegistration: ${doc.id}");
      return BiteModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting user\'s next bite: $e');
      return null;
    }
  }

  // Get bite by ID with better error handling
  Future<BiteModel?> getBiteById(String biteId) async {
    try {
      print("Getting bite by ID: $biteId");
      
      final docSnapshot = await _firestore.collection('bites').doc(biteId).get();
      
      if (!docSnapshot.exists) {
        print("Bite not found: $biteId");
        return null;
      }
      
      print("Found bite: ${docSnapshot.id}");
      return BiteModel.fromFirestore(docSnapshot);
    } catch (e) {
      print('Error getting bite by ID: $e');
      return null;
    }
  }

  // Enhanced catch-up bites with progression awareness
  Future<List<BiteModel>> getCatchUpBites({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];
      
      final data = userDoc.data()!;
      final openedBites = data['openedBites'] as List<dynamic>? ?? [];
      final openedBiteIds = openedBites.map((id) => id.toString()).toSet();
      
      // Get current day (with fallback)
      int currentDay;
      final sequentialData = data['sequentialRelease'] as Map<String, dynamic>?;
      
      if (sequentialData != null) {
        currentDay = sequentialData['currentDay'] as int;
      } else {
        // Fallback for unmigrated users
        final userRegistrationDate = (data['createdAt'] as Timestamp).toDate();
        final now = DateTime.now();
        currentDay = now.difference(userRegistrationDate).inDays + 1;
      }
      
      // Get bites for days 1 through (current day - 1)
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isLessThan: currentDay)
          .orderBy('dayNumber', descending: true)
          .get();
      
      final List<BiteModel> catchUpBites = [];
      for (final doc in querySnapshot.docs) {
        final bite = BiteModel.fromFirestore(doc);
        
        // Only include unopened bites
        if (!openedBiteIds.contains(bite.id)) {
          catchUpBites.add(bite);
          if (catchUpBites.length >= limit) break;
        }
      }
      
      return catchUpBites;
    } catch (e) {
      print('Error getting catch-up bites: $e');
      return [];
    }
  }

  // Get available bites for the dinner table discussion
  Future<List<BiteModel>> getAvailableBites({int limit = 10}) async {
    try {
      print("Getting available bites...");
      
      final user = _auth.currentUser;
      final isPremiumUser = user != null ? await _isUserPremium(user.uid) : false;
      
      // Query parameters - get all bites
      final querySnapshot = await _firestore
          .collection('bites')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print("No available bites found");
        return [];
      }
      
      final bites = querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .where((bite) => !bite.isPremiumOnly || isPremiumUser) // Filter premium content
          .toList();
      
      // Load comment counts for each bite
      await _loadCommentCounts(bites);
      
      print("Found ${bites.length} available bites");
      return bites;
    } catch (e) {
      print('Error getting available bites: $e');
      return [];
    }
  }

  // Get bites available to user based on sequential release (CRITICAL FIX for Library)
  Future<List<BiteModel>> getUserSequentialBites() async {
    try {
      print("Getting user's sequential bites for Library...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user");
        return [];
      }
      
      // Get user's registration date to calculate their current day
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = UserModel.fromFirestore(userDoc);
      final userRegistrationDate = userData.createdAt;
      final now = DateTime.now();
      final userCurrentDay = now.difference(userRegistrationDate).inDays + 1;
      
      print("User is on day $userCurrentDay - getting bites for days 1 through $userCurrentDay");
      
      // Get bites for days 1 through current day (all unlocked content)
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isLessThanOrEqualTo: userCurrentDay)
          .orderBy('dayNumber', descending: true) // Most recent first (like Instagram)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print("No sequential bites found for user");
        return [];
      }
      
      final List<BiteModel> userBites = [];
      for (final doc in querySnapshot.docs) {
        final bite = BiteModel.fromFirestore(doc);
        final commentCount = await _getCommentCount(bite.id);
        userBites.add(bite.copyWith(commentCount: commentCount));
        print('Sequential bite: Day ${bite.dayNumber} - ${bite.title} (${commentCount} comments)');
      }
      
      print("Found ${userBites.length} sequential bites for user");
      return userBites;
    } catch (e) {
      print('Error getting user sequential bites: $e');
      return [];
    }
  }

  // Get user's sequential bites that have comments (CRITICAL FIX for Dinner Table)
  Future<List<BiteModel>> getUserSequentialBitesWithComments() async {
    try {
      print("Getting user's sequential bites with comments for Dinner Table...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user");
        return [];
      }
      
      // Get user's registration date to calculate their current day
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = UserModel.fromFirestore(userDoc);
      final userRegistrationDate = userData.createdAt;
      final now = DateTime.now();
      final userCurrentDay = now.difference(userRegistrationDate).inDays + 1;
      
      print("User is on day $userCurrentDay - getting bites with comments for days 1 through $userCurrentDay");
      
      // Get bites for days 1 through current day (all unlocked content)
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isLessThanOrEqualTo: userCurrentDay)
          .orderBy('dayNumber', descending: true)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print("No sequential bites found for user");
        return [];
      }
      
      final List<BiteModel> bitesWithComments = [];
      for (final doc in querySnapshot.docs) {
        final bite = BiteModel.fromFirestore(doc);
        final commentCount = await _getCommentCount(bite.id);
        
        // Only include bites that have comments (for dinner table discussion)
        if (commentCount > 0) {
          bitesWithComments.add(bite.copyWith(commentCount: commentCount));
          print('Dinner Table bite: Day ${bite.dayNumber} - ${bite.title} (${commentCount} comments)');
        }
      }
      
      // Sort by comment count (most discussed first)
      bitesWithComments.sort((a, b) => b.commentCount.compareTo(a.commentCount));
      
      print("Found ${bitesWithComments.length} sequential bites with comments for dinner table");
      return bitesWithComments;
    } catch (e) {
      print('Error getting user sequential bites with comments: $e');
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

  // Get unlocked bites for a user - improved to handle errors better
  Future<List<BiteModel>> getUnlockedBites() async {
    try {
      print("Getting unlocked bites...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return [];
      }
      
      // First, try to get all bites if there aren't many
      var allBitesQuery = await _firestore.collection('bites').get();
      
      if (allBitesQuery.docs.isEmpty) {
        print("No bites found at all");
        return [];
      }
      
      // Get user data to check unlocked content
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print("User document doesn't exist");
        
        // If user doc doesn't exist, return some bites anyway so the app isn't empty
        final bites = allBitesQuery.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .take(5) // Limit to 5 bites
            .toList();
        
        print("Returning ${bites.length} bites (user doc missing)");
        return bites;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final unlockedContent = (userData['unlockedContent'] as List<dynamic>?) ?? [];
      
      // If no specific unlocked content or the list is empty, return recent bites
      if (unlockedContent.isEmpty) {
        print("No unlocked content specified, returning recent bites");
        final recentBites = allBitesQuery.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .take(5)
            .toList();
        
        print("Returning ${recentBites.length} recent bites");
        return recentBites;
      }
      
      // Convert to list of strings
      final unlockedIds = unlockedContent.map((item) => item.toString()).toList();
      
      // Get all bites and filter by unlocked IDs
      final allBites = allBitesQuery.docs.map((doc) => BiteModel.fromFirestore(doc)).toList();
      final unlocked = allBites.where((bite) => unlockedIds.contains(bite.id)).toList();
      
      // If no unlocked bites found, return some recent ones
      if (unlocked.isEmpty) {
        print("No unlocked bites found matching IDs, returning recent bites");
        final recentBites = allBites.take(5).toList();
        print("Returning ${recentBites.length} recent bites");
        return recentBites;
      }
      
      // Filter out premium-only content if user is not premium
      final isPremium = userData['isPremium'] as bool? ?? false;
      final result = isPremium ? unlocked : unlocked.where((bite) => !bite.isPremiumOnly).toList();
      
      // Sort by date, newest first
      result.sort((a, b) => b.date.compareTo(a.date));
      
      print("Returning ${result.length} unlocked bites");
      return result;
    } catch (e) {
      print('Error getting unlocked bites: $e');
      
      // Try to get some bites anyway so the app isn't empty
      try {
        final fallbackBites = await _firestore
            .collection('bites')
            .limit(5)
            .get();
            
        final bites = fallbackBites.docs
            .map((doc) => BiteModel.fromFirestore(doc))
            .toList();
            
        print("Returning ${bites.length} fallback bites after error");
        return bites;
      } catch (fallbackError) {
        print('Error getting fallback bites: $fallbackError');
        return [];
      }
    }
  }

  // Get all bites - for admin or gifting
  Future<List<BiteModel>> getAllBites() async {
    try {
      print("Getting all bites...");
      
      final querySnapshot = await _firestore
          .collection('bites')
          .orderBy('date', descending: true)
          .get();
      
      final bites = querySnapshot.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
          
      print("Found ${bites.length} bites");
      return bites;
    } catch (e) {
      print('Error getting all bites: $e');
      return [];
    }
  }

  // Get listened bites for a user - improved error handling
  Future<List<BiteModel>> getListenedBites() async {
    try {
      print("Getting listened bites...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return [];
      }
      
      // Get all bites first
      final allBitesQuery = await _firestore
          .collection('bites')
          .orderBy('date', descending: true)
          .get();
          
      if (allBitesQuery.docs.isEmpty) {
        print("No bites found");
        return [];
      }
      
      final allBites = allBitesQuery.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
      
      // Get user data to check listened bites
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print("User document doesn't exist");
        return [];
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final listenedBites = (userData['listenedBites'] as List<dynamic>?) ?? [];
      
      // Convert to list of strings
      final listenedIds = listenedBites.map((item) => item.toString()).toList();
      
      if (listenedIds.isEmpty) {
        print("No listened bites found");
        return [];
      }
      
      // Filter all bites by listened IDs
      final listened = allBites.where((bite) => listenedIds.contains(bite.id)).toList();
      
      // Filter out premium-only content if user is not premium
      final isPremium = userData['isPremium'] as bool? ?? false;
      final result = isPremium ? listened : listened.where((bite) => !bite.isPremiumOnly).toList();
      
      // Sort by date, newest first
      result.sort((a, b) => b.date.compareTo(a.date));
      
      print("Found ${result.length} listened bites");
      return result;
    } catch (e) {
      print('Error getting listened bites: $e');
      return [];
    }
  }

  // Get gifted episodes for a user - improved error handling
  Future<List<BiteModel>> getGiftedEpisodes() async {
    try {
      print("Getting gifted episodes...");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return [];
      }
      
      // Get the user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print("User document doesn't exist");
        return [];
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final giftedEpisodes = userData['giftedEpisodes'] as List<dynamic>? ?? [];
      
      if (giftedEpisodes.isEmpty) {
        print("No gifted episodes found");
        return [];
      }
      
      print("Found ${giftedEpisodes.length} gifted episodes in user data");
      
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
        print("No valid bite IDs found in gifted episodes");
        return [];
      }
      
      print("Extracted ${biteIds.length} bite IDs from gifted episodes");
      
      // Get all bites and filter by IDs
      final allBitesQuery = await _firestore
          .collection('bites')
          .get();
          
      final allBites = allBitesQuery.docs
          .map((doc) => BiteModel.fromFirestore(doc))
          .toList();
      
      final result = <BiteModel>[];
      
      // Match bites with gift info
      for (final bite in allBites) {
        if (biteIds.contains(bite.id)) {
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
      
      print("Returning ${result.length} gifted bites");
      return result;
    } catch (e) {
      print('Error getting gifted episodes: $e');
      return [];
    }
  }

  // Mark a bite as listened
  Future<bool> markBiteAsListened(String biteId) async {
    try {
      print("Marking bite as listened: $biteId");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return false;
      }
      
      await _firestore.collection('users').doc(user.uid).update({
        'listenedBites': FieldValue.arrayUnion([biteId]),
      });
      
      print("Successfully marked bite as listened");
      return true;
    } catch (e) {
      print('Error marking bite as listened: $e');
      return false;
    }
  }

  // Mark bite as opened (CRITICAL FIX for Fresh Bites Waiting)
  Future<void> markBiteAsOpened(String biteId) async {
    try {
      print("Marking bite $biteId as opened");
      
      final user = _auth.currentUser;
      if (user == null) return;
      
      final timestamp = FieldValue.serverTimestamp();
      
      // Add to opened bites list (for filtering Fresh Bites)
      await _firestore.collection('users').doc(user.uid).update({
        'openedBites': FieldValue.arrayUnion([biteId]),
        'lastActivityDate': timestamp,
      });
      
      print("Successfully marked bite $biteId as opened");
    } catch (e) {
      print('Error marking bite as opened: $e');
    }
  }

  // Get comments for a bite
  Future<List<CommentModel>> getCommentsForBite(String biteId) async {
    try {
      print("Getting comments for bite: $biteId");
      
      final querySnapshot = await _firestore
          .collection('comments')
          .where('biteId', isEqualTo: biteId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final comments = querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
          
      print("Found ${comments.length} comments for bite");
      return comments;
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Add a comment to a bite
  Future<bool> addComment(String biteId, String text) async {
    try {
      print("Adding comment to bite: $biteId");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
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
        'likeCount': 0,
      });
      
      print("Comment added successfully");
      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  // Get user's reactions to bites
  Future<Map<String, String>> getUserReactions() async {
    try {
      print("Getting user reactions");
      
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in");
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
      
      print("Found ${reactions.length} user reactions");
      return reactions;
    } catch (e) {
      print('Error getting user reactions: $e');
      return {};
    }
  }

  // Get current day's bite using UserProgressionService (enhanced)
  Future<BiteModel?> getCurrentDayBite() async {
    try {
      print('Getting current day bite using sequential release...');
      
      // Trigger check for next bite unlock
      await _userProgression.checkAndUnlockNextBite();
      
      final currentDay = await _userProgression.getCurrentDay();
      print('User current day: $currentDay');
      
      // Get the bite for this specific day number
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isEqualTo: currentDay)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No bite found for day $currentDay, getting fallback');
        // If no exact day match, get the highest available day number that's <= user's day
        final fallbackQuery = await _firestore
            .collection('bites')
            .where('dayNumber', isLessThanOrEqualTo: currentDay)
            .orderBy('dayNumber', descending: true)
            .limit(1)
            .get();
            
        if (fallbackQuery.docs.isEmpty) {
          return null;
        }
        
        final doc = fallbackQuery.docs.first;
        final bite = BiteModel.fromFirestore(doc);
        print('Found fallback bite: ${bite.title}');
        return bite;
      }
      
      final doc = querySnapshot.docs.first;
      final bite = BiteModel.fromFirestore(doc);
      print('Found current day bite: ${bite.title}');
      return bite;
    } catch (e) {
      print('Error getting current day bite: $e');
      return null;
    }
  }

  // Get all available bites for user based on their progression (enhanced)
  Future<List<BiteModel>> getUserAvailableBites() async {
    try {
      print('Getting user available bites with progression awareness...');
      
      // Check for progression updates first
      await _userProgression.checkAndUnlockNextBite();
      
      final currentDay = await _userProgression.getCurrentDay();
      print('User current day for available bites: $currentDay');
      
      // Get bites for days 1 through current day (all unlocked content)
      final querySnapshot = await _firestore
          .collection('bites')
          .where('dayNumber', isLessThanOrEqualTo: currentDay)
          .orderBy('dayNumber', descending: true) // Most recent first
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return [];
      }
      
      final List<BiteModel> userBites = [];
      for (final doc in querySnapshot.docs) {
        final bite = BiteModel.fromFirestore(doc);
        userBites.add(bite);
      }
      
      print('Found ${userBites.length} available bites for user');
      return userBites;
    } catch (e) {
      print('Error getting user available bites: $e');
      return [];
    }
  }
}