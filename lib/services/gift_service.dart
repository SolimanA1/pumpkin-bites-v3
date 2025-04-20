import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/bite_model.dart';
import 'content_service.dart';

class GiftService {
  // Singleton pattern
  static final GiftService _instance = GiftService._internal();
  factory GiftService() => _instance;
  GiftService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ContentService _contentService = ContentService();
  
  final String _giftsCollection = 'gifts';
  final String _usersCollection = 'users';

  // Get count of unread gifts for current user
  Future<int> getUnreadGiftsCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;
      
      final userDoc = await _firestore.collection(_usersCollection).doc(user.uid).get();
      if (!userDoc.exists) return 0;
      
      return userDoc.data()?['unreadGifts'] ?? 0;
    } catch (e) {
      print('Error getting unread gifts count: $e');
      return 0;
    }
  }
  
  // Get gifts sent by current user
  Future<List<Map<String, dynamic>>> getSentGifts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final querySnapshot = await _firestore
          .collection(_giftsCollection)
          .where('senderUid', isEqualTo: user.uid)
          .orderBy('sentAt', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
    } catch (e) {
      print('Error getting sent gifts: $e');
      return [];
    }
  }
  
  // Get gifts received by current user
  Future<List<Map<String, dynamic>>> getReceivedGifts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final querySnapshot = await _firestore
          .collection(_giftsCollection)
          .where('recipientUid', isEqualTo: user.uid)
          .orderBy('sentAt', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
    } catch (e) {
      print('Error getting received gifts: $e');
      return [];
    }
  }
  
  // Find a user by email
  Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      final doc = querySnapshot.docs.first;
      return {
        ...doc.data(),
        'uid': doc.id,
      };
    } catch (e) {
      print('Error finding user by email: $e');
      return null;
    }
  }

  // Send an episode gift to another user
  Future<void> sendEpisodeGift({
    required String senderUid,
    required String recipientEmail,
    required String biteId,
    String? message,
  }) async {
    try {
      print("Starting to send episode gift...");
      print("Sender UID: $senderUid");
      print("Recipient email: $recipientEmail");
      print("Bite ID: $biteId");
      
      // Get the bite details
      final bite = await _contentService.getBiteById(biteId);
      if (bite == null) {
        throw Exception('Episode not found');
      }
      
      print("Found bite with title: ${bite.title}");
      
      // Check if recipient user exists
      final recipientUser = await _findUserByEmail(recipientEmail);
      final bool recipientExists = recipientUser != null;
      final String? recipientUid = recipientUser?['uid'];
      
      print("Recipient exists: $recipientExists");
      if (recipientExists) {
        print("Recipient UID: $recipientUid");
      }
      
      // Get sender details
      final senderData = await _firestore.collection(_usersCollection).doc(senderUid).get();
      final senderName = senderData.data()?['displayName'] ?? 'A friend';
      final senderEmail = senderData.data()?['email'] ?? 'Unknown';
      
      print("Sender name: $senderName");
      
      // Create gift document
      final giftRef = _firestore.collection(_giftsCollection).doc();
      print("Created gift with ID: ${giftRef.id}");
      
      final giftData = {
        'id': giftRef.id,
        'type': 'episode',
        'biteId': biteId,
        'biteTitle': bite.title,
        'senderUid': senderUid,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'recipientEmail': recipientEmail,
        'recipientUid': recipientUid,
        'message': message ?? '',
        'sentAt': FieldValue.serverTimestamp(),
        'receivedAt': null,
        'status': recipientExists ? 'pending' : 'awaiting_registration',
        'isOpened': false,
      };
      
      print("Setting gift document with data: $giftData");
      await giftRef.set(giftData);
      print("Gift document set successfully");
      
      // If recipient exists, add to their gifted episodes
      if (recipientExists && recipientUid != null) {
        print("Adding gift to recipient's gifted episodes...");
        await _firestore.collection(_usersCollection).doc(recipientUid).update({
          'giftedEpisodes': FieldValue.arrayUnion([{
            'giftId': giftRef.id,
            'biteId': biteId,
            'senderUid': senderUid,
            'senderName': senderName,
            'receivedAt': FieldValue.serverTimestamp(),
          }]),
          'unreadGifts': FieldValue.increment(1),
        });
        print("Updated recipient's document successfully");
      }
      
      // Update sender's sent gifts counter
      print("Updating sender's sent gifts counter...");
      await _firestore.collection(_usersCollection).doc(senderUid).update({
        'sentGifts': FieldValue.increment(1),
      });
      print("Updated sender's document successfully");
      
      print("Gift sent successfully!");
    } catch (e) {
      print('Error sending episode gift: $e');
      throw e;
    }
  }
  
  // Send a membership gift to another user
  Future<void> sendMembershipGift({
    required String senderUid,
    required String recipientEmail,
    required int days,
    String? message,
  }) async {
    try {
      // Check if recipient user exists
      final recipientUser = await _findUserByEmail(recipientEmail);
      final bool recipientExists = recipientUser != null;
      final String? recipientUid = recipientUser?['uid'];
      
      // Get sender details
      final senderData = await _firestore.collection(_usersCollection).doc(senderUid).get();
      final senderName = senderData.data()?['displayName'] ?? 'A friend';
      final senderEmail = senderData.data()?['email'] ?? 'Unknown';
      
      // Create gift document
      final giftRef = _firestore.collection(_giftsCollection).doc();
      
      // Calculate expiry date
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: days));
      
      final giftData = {
        'id': giftRef.id,
        'type': 'membership',
        'days': days,
        'senderUid': senderUid,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'recipientEmail': recipientEmail,
        'recipientUid': recipientUid,
        'message': message ?? '',
        'sentAt': FieldValue.serverTimestamp(),
        'receivedAt': null,
        'expiresAt': Timestamp.fromDate(expiryDate),
        'status': recipientExists ? 'pending' : 'awaiting_registration',
        'isOpened': false,
      };
      
      await giftRef.set(giftData);
      
      // If recipient exists, add to their membership gifts
      if (recipientExists && recipientUid != null) {
        await _firestore.collection(_usersCollection).doc(recipientUid).update({
          'membershipGifts': FieldValue.arrayUnion([{
            'giftId': giftRef.id,
            'days': days,
            'senderUid': senderUid,
            'senderName': senderName,
            'receivedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expiryDate),
          }]),
          'unreadGifts': FieldValue.increment(1),
        });
      }
      
      // Update sender's sent gifts counter
      await _firestore.collection(_usersCollection).doc(senderUid).update({
        'sentGifts': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error sending membership gift: $e');
      throw e;
    }
  }
  
  // Check for pending gifts for a new user
  Future<void> checkPendingGiftsForNewUser(String userId, String email) async {
    try {
      print("Checking for pending gifts for new user: $email");
      // Find gifts sent to this email that are awaiting registration
      final querySnapshot = await _firestore
          .collection(_giftsCollection)
          .where('recipientEmail', isEqualTo: email)
          .where('status', isEqualTo: 'awaiting_registration')
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print("No pending gifts found for new user");
        return;
      }
      
      print("Found ${querySnapshot.docs.length} pending gifts");
      
      // Process each pending gift
      for (final doc in querySnapshot.docs) {
        final giftData = doc.data();
        final giftId = doc.id;
        final giftType = giftData['type'];
        
        print("Processing gift: $giftId of type: $giftType");
        
        // Update the gift document
        await _firestore.collection(_giftsCollection).doc(giftId).update({
          'recipientUid': userId,
          'receivedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        
        // Add to appropriate user collection based on gift type
        if (giftType == 'episode') {
          final biteId = giftData['biteId'];
          final senderUid = giftData['senderUid'];
          final senderName = giftData['senderName'];
          
          print("Adding episode gift to user's giftedEpisodes");
          
          await _firestore.collection(_usersCollection).doc(userId).update({
            'giftedEpisodes': FieldValue.arrayUnion([{
              'giftId': giftId,
              'biteId': biteId,
              'senderUid': senderUid,
              'senderName': senderName,
              'receivedAt': FieldValue.serverTimestamp(),
            }]),
            'unreadGifts': FieldValue.increment(1),
          });
        } else if (giftType == 'membership') {
          final days = giftData['days'];
          final senderUid = giftData['senderUid'];
          final senderName = giftData['senderName'];
          final expiresAt = giftData['expiresAt'];
          
          print("Adding membership gift to user's membershipGifts");
          
          await _firestore.collection(_usersCollection).doc(userId).update({
            'membershipGifts': FieldValue.arrayUnion([{
              'giftId': giftId,
              'days': days,
              'senderUid': senderUid,
              'senderName': senderName,
              'receivedAt': FieldValue.serverTimestamp(),
              'expiresAt': expiresAt,
            }]),
            'unreadGifts': FieldValue.increment(1),
          });
        }
      }
      
      print("All pending gifts processed successfully");
    } catch (e) {
      print('Error checking pending gifts: $e');
      // Don't throw error here - we don't want to interrupt registration
    }
  }
  
  // NEW METHOD: Check for pending gifts for existing user
  Future<void> checkPendingGiftsForExistingUser(String userId, String email) async {
    try {
      print("Checking for pending gifts for existing user: $email");
      
      // Find gifts sent to this email that are awaiting acceptance
      final querySnapshot = await _firestore
          .collection(_giftsCollection)
          .where('recipientEmail', isEqualTo: email)
          .where('status', isEqualTo: 'awaiting_registration')
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print("No pending gifts found for existing user");
        return;
      }
      
      print("Found ${querySnapshot.docs.length} pending gifts");
      
      // Process each pending gift
      for (final doc in querySnapshot.docs) {
        final giftData = doc.data();
        final giftId = doc.id;
        final giftType = giftData['type'];
        
        print("Processing gift: $giftId of type: $giftType");
        
        // Update the gift document
        await _firestore.collection(_giftsCollection).doc(giftId).update({
          'recipientUid': userId,
          'receivedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        
        // Add to appropriate user collection based on gift type
        if (giftType == 'episode') {
          final biteId = giftData['biteId'];
          final senderUid = giftData['senderUid'];
          final senderName = giftData['senderName'];
          final message = giftData['message'];
          
          print("Adding episode gift to user's giftedEpisodes");
          
          await _firestore.collection(_usersCollection).doc(userId).update({
            'giftedEpisodes': FieldValue.arrayUnion([{
              'giftId': giftId,
              'biteId': biteId,
              'senderUid': senderUid,
              'senderName': senderName,
              'message': message,
              'receivedAt': FieldValue.serverTimestamp(),
            }]),
            'unreadGifts': FieldValue.increment(1),
          });
        } else if (giftType == 'membership') {
          final days = giftData['days'];
          final senderUid = giftData['senderUid'];
          final senderName = giftData['senderName'];
          final expiresAt = giftData['expiresAt'];
          
          print("Adding membership gift to user's membershipGifts");
          
          await _firestore.collection(_usersCollection).doc(userId).update({
            'membershipGifts': FieldValue.arrayUnion([{
              'giftId': giftId,
              'days': days,
              'senderUid': senderUid,
              'senderName': senderName,
              'receivedAt': FieldValue.serverTimestamp(),
              'expiresAt': expiresAt,
            }]),
            'unreadGifts': FieldValue.increment(1),
          });
        }
      }
      
      print("All pending gifts processed successfully");
    } catch (e) {
      print('Error checking pending gifts for existing user: $e');
    }
  }
  
  // Mark a gift as read
  Future<void> markGiftAsRead(String giftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the gift document
      await _firestore.collection(_giftsCollection).doc(giftId).update({
        'isOpened': true,
      });
      
      // Decrement the unread gifts counter
      await _firestore.collection(_usersCollection).doc(user.uid).update({
        'unreadGifts': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error marking gift as read: $e');
    }
  }
  
  // Accept a gift
  Future<void> acceptGift(String giftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the gift status
      await _firestore.collection(_giftsCollection).doc(giftId).update({
        'status': 'accepted',
      });
    } catch (e) {
      print('Error accepting gift: $e');
    }
  }
}