import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create a static instance that can be accessed by other services
  static final AuthService _instance = AuthService._internal();
  
  // Private constructor for singleton pattern
  AuthService._internal();
  
  // Factory constructor to return the same instance
  factory AuthService() {
    return _instance;
  }
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current user
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }
  
  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }
  
  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email, 
    String password, 
    String displayName,
  ) async {
    try {
      
      // Create user account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      
      // Create user document in Firestore
      final now = DateTime.now();
      final userModel = UserModel(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        createdAt: now,
        isPremium: false,
        unlockedContent: [],
        giftedEpisodes: [],
        membershipGifts: [],
        unreadGifts: 0,
        sentGifts: 0,
      );
      
      
      // CRITICAL FIX: Set fresh trial start date for new user
      final userDocData = userModel.toMap();
      userDocData['trialStartDate'] = FieldValue.serverTimestamp(); // Fresh trial start
      userDocData['hasCompletedOnboarding'] = false; // Ensure onboarding is required
      
      
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userDocData);
      
      
      // Verify the document was created with trial data
      try {
        final verifyDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
        if (verifyDoc.exists) {
          final data = verifyDoc.data();
        } else {
          print('ERROR - User document was not created!');
        }
      } catch (e) {
        print('Error verifying user document: $e');
      }
      
      // COORDINATION FIX: Allow small delay for Firestore consistency
      // This ensures SubscriptionService can properly load the new user's trial data
      await Future.delayed(Duration(milliseconds: 500));
      
      // IMPORTANT: New users should NOT have hasCompletedOnboarding set in Firestore
      // This should only be set when they actually complete onboarding
      
      // Check for any pending gifts sent to this email
      // We'll handle this in the GiftService instead of here
      
      return credential;
    } catch (e) {
      print('Error registering: $e');
      throw e;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }
  
  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      }
      
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      
      // Update Auth profile
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
      }
      
      // Update Firestore document
      final updates = <String, dynamic>{};
      
      if (displayName != null) {
        updates['displayName'] = displayName;
      }
      
      if (photoUrl != null) {
        updates['photoUrl'] = photoUrl;
      }
      
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      throw e;
    }
  }
}