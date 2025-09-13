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
      print('✅ Migrated existing user ${user.uid} to sequential release');
      
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final createdAt = userData['createdAt'] as Timestamp?;
      
      if (createdAt == null) return;

      // Check if already migrated
      if (userData['sequentialRelease'] != null) return;

      // Create sequential release data
      final sequentialData = {
        'version': '1.0',
        'startDate': createdAt, // Use original registration date
        'migratedAt': FieldValue.serverTimestamp(),
        'unlockTime': {'hour': 9, 'minute': 0}, // Default 9 AM
      };

      await userDocRef.update({
        'sequentialRelease': sequentialData,
      });

      // Clear cache to force refresh
      _clearCache();
      
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

  // Initialize progression for new users
  Future<void> initializeUserProgression(String userId) async {
    try {
      final sequentialData = {
        'version': '1.0',
        'startDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unlockTime': {'hour': 9, 'minute': 0}, // Default 9 AM
      };

      await _firestore.collection('users').doc(userId).update({
        'sequentialRelease': sequentialData,
      });

      _clearCache();
    } catch (e) {
      print('Error initializing user progression: $e');
    }
  }
}