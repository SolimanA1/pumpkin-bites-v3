import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProgressionService {
  static final UserProgressionService _instance = UserProgressionService._internal();
  factory UserProgressionService() => _instance;
  UserProgressionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache to improve performance
  Map<String, dynamic>? _cachedProgression;
  String? _cachedUserId;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  Future<Map<String, dynamic>?> getUserProgression() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Use cached data if still valid
    final now = DateTime.now();
    if (_cachedProgression != null && 
        _cachedUserId == user.uid &&
        _lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!).abs() < _cacheValidityDuration) {
      return _cachedProgression;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final progression = userData['sequentialRelease'] as Map<String, dynamic>?;

      // Cache the result
      _cachedProgression = progression;
      _cachedUserId = user.uid;
      _lastCacheUpdate = now;

      return progression;
    } catch (e) {
      print('Error getting user progression: $e');
      return null;
    }
  }

  Future<int> getCurrentDay() async {
    final user = _auth.currentUser;
    if (user == null) return 1;

    try {
      final progression = await getUserProgression();
      if (progression == null) {
        // New user - migrate them
        await migrateExistingUser();
        return 1;
      }

      final startDate = (progression['startDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceStart = now.difference(startDate).inDays + 1;
      
      return daysSinceStart.clamp(1, 365); // Cap at 365 days
    } catch (e) {
      print('Error getting current day: $e');
      return 1;
    }
  }

  Future<void> migrateExistingUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      
      // Check if already migrated
      if (userData['sequentialRelease'] != null) return;
      
      final createdAt = userData['createdAt'] as Timestamp?;
      if (createdAt == null) return;
      
      // Calculate current day based on existing registration date
      final createdAtDate = createdAt.toDate();
      final now = DateTime.now();
      final daysSinceRegistration = now.difference(createdAtDate).inDays + 1;
      
      // Determine trial status
      final trialEndDate = createdAtDate.add(Duration(days: 7));
      final isTrialActive = now.isBefore(trialEndDate);
      
      // Create enhanced sequential release data
      final sequentialData = {
        'version': '1.0',
        'currentDay': daysSinceRegistration.clamp(1, 50), // Reasonable upper bound
        'signupTimestamp': createdAtDate.toIso8601String(),
        'firstBiteUnlockedAt': createdAtDate.toIso8601String(),
        'lastUnlockTimestamp': now.toIso8601String(),
        'unlockHour': userData['unlockHour'] ?? 9,
        'unlockMinute': userData['unlockMinute'] ?? 0,
        'progressionStatus': isTrialActive ? 'active' : 'trial_ended',
        'trialEndDate': trialEndDate.toIso8601String(),
        'subscriptionActivatedAt': null,
        'startDate': createdAt, // Use original registration date
        'migratedAt': FieldValue.serverTimestamp(),
      };

      await userDocRef.update({
        'sequentialRelease': sequentialData,
      });

      // Clear cache to force refresh
      _clearCache();
      
      print('✅ Migrated existing user ${user.uid} to sequential release');
      
    } catch (e) {
      print('Error migrating user: $e');
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'status': 'no_user', 'healthy': false};
      }

      // Test database connection
      await _firestore.collection('users').doc(user.uid).get();
      
      // Test progression access
      final progression = await getUserProgression();
      
      return {
        'status': 'healthy',
        'healthy': true,
        'hasProgression': progression != null,
        'currentDay': await getCurrentDay(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'healthy': false,
        'error': e.toString(),
      };
    }
  }

  void _clearCache() {
    _cachedProgression = null;
    _cachedUserId = null;
    _lastCacheUpdate = null;
  }

  // Check if next bite should unlock based on user's schedule
  Future<void> checkAndUnlockNextBite() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data == null) return;

      final sequentialData = data['sequentialRelease'] as Map<String, dynamic>?;
      if (sequentialData == null) return;

      final progressionStatus = sequentialData['progressionStatus'] as String;
      if (progressionStatus != 'active') return;

      final currentDay = sequentialData['currentDay'] as int;
      final lastUnlockStr = sequentialData['lastUnlockTimestamp'] as String;
      final lastUnlock = DateTime.parse(lastUnlockStr);
      final unlockHour = sequentialData['unlockHour'] as int;
      final unlockMinute = sequentialData['unlockMinute'] as int;

      final now = DateTime.now();

      // Calculate next unlock time
      final nextUnlockDate = DateTime(
        lastUnlock.year,
        lastUnlock.month,
        lastUnlock.day + 1,
      );
      final nextUnlockTime = DateTime(
        nextUnlockDate.year,
        nextUnlockDate.month,
        nextUnlockDate.day,
        unlockHour,
        unlockMinute,
      );

      // Check if it's time to unlock next bite
      if (now.isBefore(nextUnlockTime)) return;

      // Check trial/subscription limits
      final trialEndStr = sequentialData['trialEndDate'] as String;
      final trialEndDate = DateTime.parse(trialEndStr);

      // If trial ended and not subscribed, pause progression
      if (currentDay >= 7 && now.isAfter(trialEndDate)) {
        final isSubscribed = await _isUserSubscribed();
        if (!isSubscribed) {
          await _firestore.collection('users').doc(user.uid).update({
            'sequentialRelease.progressionStatus': 'trial_ended',
          });
          _clearCache();
          return;
        }
      }

      // Unlock next day
      await _firestore.collection('users').doc(user.uid).update({
        'sequentialRelease.currentDay': currentDay + 1,
        'sequentialRelease.lastUnlockTimestamp': now.toIso8601String(),
      });

      _clearCache();
      print('Unlocked day ${currentDay + 1} for user ${user.uid}');
    } catch (e) {
      print('Error checking/unlocking next bite: $e');
    }
  }

  // Helper method to check subscription status
  Future<bool> _isUserSubscribed() async {
    // This will be enhanced when we integrate with SubscriptionService
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data == null) return false;
      
      final isPremium = data['isPremium'] as bool? ?? false;
      return isPremium;
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }

  // Handle subscription activation
  Future<void> activateSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'sequentialRelease.progressionStatus': 'active',
        'sequentialRelease.subscriptionActivatedAt': DateTime.now().toIso8601String(),
      });

      _clearCache();
      print('Subscription activated - progression resumed for user ${user.uid}');

      // Check if next bite should unlock immediately
      await checkAndUnlockNextBite();
    } catch (e) {
      print('Error activating subscription: $e');
    }
  }

  // Handle trial expiration
  Future<void> handleTrialExpiration() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'sequentialRelease.progressionStatus': 'trial_ended',
      });

      _clearCache();
      print('Trial expired - progression paused for user ${user.uid}');
    } catch (e) {
      print('Error handling trial expiration: $e');
    }
  }

  // Get current progression status
  Future<String> getProgressionStatus() async {
    try {
      final progression = await getUserProgression();
      if (progression == null) return 'inactive';
      
      return progression['progressionStatus'] as String? ?? 'inactive';
    } catch (e) {
      print('Error getting progression status: $e');
      return 'inactive';
    }
  }

  // Initialize progression for new users
  Future<void> initializeUserProgression(String userId) async {
    try {
      // Check if user already has sequential release data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      if (data?['sequentialRelease'] != null) {
        print('User already has sequential release data - skipping initialization');
        return;
      }
      
      final now = DateTime.now();
      final trialEndDate = now.add(Duration(days: 7));
      
      // Add sequential release tracking to existing user document
      final sequentialData = {
        'version': '1.0',
        'currentDay': 1,
        'signupTimestamp': now.toIso8601String(),
        'firstBiteUnlockedAt': now.toIso8601String(), // INSTANT UNLOCK on signup
        'lastUnlockTimestamp': now.toIso8601String(),
        'unlockHour': data?['unlockHour'] ?? 9, // Preserve existing preference
        'unlockMinute': data?['unlockMinute'] ?? 0,
        'progressionStatus': 'active', // active, paused, trial_ended
        'trialEndDate': trialEndDate.toIso8601String(),
        'subscriptionActivatedAt': null,
        'startDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update({
        'sequentialRelease': sequentialData,
      });

      _clearCache();
      print('Sequential release progression initialized for user $userId');
    } catch (e) {
      print('Error initializing user progression: $e');
    }
  }
}