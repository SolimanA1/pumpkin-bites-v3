import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String biteId;
  final String userId;
  final String displayName; // Property needed by dinner_table_screen
  final String photoURL; // Property needed by dinner_table_screen
  final String text;
  final DateTime createdAt;
  final int likeCount;

  CommentModel({
    required this.id,
    required this.biteId,
    required this.userId,
    required this.displayName,
    required this.photoURL,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
  });

  // Create a CommentModel from a Firestore document
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document does not exist');
    }

    // Parse the timestamp
    DateTime createdAt = DateTime.now();
    final timestamp = data['createdAt'];
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    }

    return CommentModel(
      id: doc.id,
      biteId: data['biteId'] ?? '',
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? 'Anonymous',
      photoURL: data['photoURL'] ?? '',
      text: data['text'] ?? '',
      createdAt: createdAt,
      likeCount: data['likeCount'] ?? 0,
    );
  }

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'biteId': biteId,
      'userId': userId,
      'displayName': displayName,
      'photoURL': photoURL,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
    };
  }

  // Format the creation time (e.g., "3 hours ago")
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}