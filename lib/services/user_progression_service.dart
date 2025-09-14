import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProgressionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Initialize user progression on signup
  Future<void> initializeUserProgression([String? userId]) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final targetUserId = userId ?? user.uid;
    
    final now = DateTime.now();
    final trialEndDate = now.add(Duration(days: 7));
    
    // Check if already initialized
    final userDoc = await _firestore.collection('users').doc(targetUserId).get();
    final data = userDoc.data();
    
    if (data?['sequentialRelease'] != null) {
      print('User progression already initialized');
      return;
    }
    
    // Initialize progression
    await _firestore.collection('users').doc(targetUserId).update({
      'sequentialRelease': {
        'currentDay': 1,
        'signupTimestamp': now.toIso8601String(),
        'firstBiteUnlockedAt': now.toIso8601String(),
        'lastUnlockTimestamp': now.toIso8601String(),
        'unlockHour': data?['unlockHour'] ?? 9,
        'unlockMinute': data?['unlockMinute'] ?? 0,
        'progressionStatus': 'active',
        'trialEndDate': trialEndDate.toIso8601String(),
        'subscriptionActivatedAt': null,
      }
    });
    
    print('User progression initialized for $targetUserId');
  }
  
  // Get user's current day number
  Future<int> getCurrentDay() async {
    final user = _auth.currentUser;
    if (user == null) return 1;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    
    final sequentialData = data?['sequentialRelease'] as Map<String, dynamic>?;
    if (sequentialData != null) {
      return sequentialData['currentDay'] as int? ?? 1;
    }
    
    // Fallback to old calculation
    final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();
    if (createdAt != null) {
      final daysSinceSignup = DateTime.now().difference(createdAt).inDays + 1;
      return daysSinceSignup.clamp(1, 50);
    }
    
    return 1;
  }
  
  // Check if next bite should unlock
  Future<bool> shouldUnlockNextBite() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data == null) return false;
    
    final sequentialData = data['sequentialRelease'] as Map<String, dynamic>?;
    if (sequentialData == null) return false;
    
    final progressionStatus = sequentialData['progressionStatus'] as String?;
    if (progressionStatus != 'active') return false;
    
    final lastUnlockStr = sequentialData['lastUnlockTimestamp'] as String?;
    if (lastUnlockStr == null) return false;
    
    final lastUnlock = DateTime.parse(lastUnlockStr);
    final unlockHour = sequentialData['unlockHour'] as int? ?? 9;
    final unlockMinute = sequentialData['unlockMinute'] as int? ?? 0;
    
    final now = DateTime.now();
    final nextUnlockTime = DateTime(
      lastUnlock.year,
      lastUnlock.month,
      lastUnlock.day + 1,
      unlockHour,
      unlockMinute,
    );
    
    return now.isAfter(nextUnlockTime);
  }
  
  // Unlock next bite
  Future<void> unlockNextBite() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final currentDay = await getCurrentDay();
    final newDay = currentDay + 1;
    
    await _firestore.collection('users').doc(user.uid).update({
      'sequentialRelease.currentDay': newDay,
      'sequentialRelease.lastUnlockTimestamp': DateTime.now().toIso8601String(),
    });
    
    print('Unlocked day $newDay for user ${user.uid}');
  }
  
  // Migrate existing user to sequential release system
  Future<void> migrateExistingUser(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data();
    
    if (data?['sequentialRelease'] != null) {
      print('User $userId already migrated');
      return;
    }
    
    final now = DateTime.now();
    final createdAt = (data?['createdAt'] as Timestamp?)?.toDate() ?? now;
    final trialEndDate = createdAt.add(Duration(days: 7));
    
    // Calculate current day based on original signup
    final daysSinceSignup = now.difference(createdAt).inDays + 1;
    final currentDay = daysSinceSignup.clamp(1, 50);
    
    await _firestore.collection('users').doc(userId).update({
      'sequentialRelease': {
        'currentDay': currentDay,
        'signupTimestamp': createdAt.toIso8601String(),
        'firstBiteUnlockedAt': createdAt.toIso8601String(),
        'lastUnlockTimestamp': now.toIso8601String(),
        'unlockHour': data?['unlockHour'] ?? 9,
        'unlockMinute': data?['unlockMinute'] ?? 0,
        'progressionStatus': 'active',
        'trialEndDate': trialEndDate.toIso8601String(),
        'subscriptionActivatedAt': null,
      }
    });
    
    print('Migrated user $userId to sequential release system');
  }
  
  // Handle trial expiration by pausing progression
  Future<void> handleTrialExpiration() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore.collection('users').doc(user.uid).update({
      'sequentialRelease.progressionStatus': 'trial_ended',
    });
    
    print('Trial expired for user ${user.uid} - progression paused');
  }
  
  // Activate subscription and resume progression
  Future<void> activateSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final now = DateTime.now();
    
    await _firestore.collection('users').doc(user.uid).update({
      'sequentialRelease.progressionStatus': 'active',
      'sequentialRelease.subscriptionActivatedAt': now.toIso8601String(),
    });
    
    print('Subscription activated for user ${user.uid} - progression resumed');
  }
}