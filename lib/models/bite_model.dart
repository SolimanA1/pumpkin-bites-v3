import 'package:cloud_firestore/cloud_firestore.dart';

class BiteModel {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final String thumbnailUrl;
  final String category;
  final String authorName;
  final DateTime date;
  final int duration; // in seconds
  final bool isPremium;
  final bool isPremiumOnly;
  
  // Additional properties needed by other parts of the app
  final int dayNumber;
  final int commentCount;
  
  // Gift-related fields
  String giftedBy;
  String giftMessage;
  
  BiteModel({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.thumbnailUrl,
    required this.category,
    required this.authorName,
    required this.date,
    required this.duration,
    required this.isPremium,
    this.isPremiumOnly = false,
    this.dayNumber = 0,
    this.commentCount = 0,
    this.giftedBy = '',
    this.giftMessage = '',
  });
  
  // Create a BiteModel from a Firestore document
  factory BiteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document does not exist');
    }
    
    // Parse the date field - could be a Timestamp, String, or null
    DateTime parsedDate = DateTime.now();
    final dateField = data['date'];
    
    if (dateField is Timestamp) {
      parsedDate = dateField.toDate();
    } else if (dateField is String) {
      try {
        parsedDate = DateTime.parse(dateField);
      } catch (e) {
        // If parsing fails, use current date
        print('Failed to parse date: $dateField, using current date');
      }
    }
    
    // Calculate day number based on the date
    final firstDay = DateTime(2023, 1, 1); // A reference date
    final dayNumber = parsedDate.difference(firstDay).inDays;
    
    return BiteModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Bite',
      description: data['description'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      authorName: data['authorName'] ?? 'Unknown Author',
      date: parsedDate,
      duration: data['duration'] ?? 0,
      isPremium: data['isPremium'] ?? false,
      isPremiumOnly: data['isPremiumOnly'] ?? false,
      dayNumber: data['dayNumber'] ?? dayNumber,
      commentCount: data['commentCount'] ?? 0,
      giftedBy: data['giftedBy'] ?? '',
      giftMessage: data['giftMessage'] ?? '',
    );
  }
  
  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'thumbnailUrl': thumbnailUrl,
      'category': category,
      'authorName': authorName,
      'date': date,
      'duration': duration,
      'isPremium': isPremium,
      'isPremiumOnly': isPremiumOnly,
      'dayNumber': dayNumber,
      'commentCount': commentCount,
      'giftedBy': giftedBy,
      'giftMessage': giftMessage,
    };
  }
  
  // Create a copy with modified fields
  BiteModel copyWith({
    String? id,
    String? title,
    String? description,
    String? audioUrl,
    String? thumbnailUrl,
    String? category,
    String? authorName,
    DateTime? date,
    int? duration,
    bool? isPremium,
    bool? isPremiumOnly,
    int? dayNumber,
    int? commentCount,
    String? giftedBy,
    String? giftMessage,
  }) {
    return BiteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      authorName: authorName ?? this.authorName,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      isPremium: isPremium ?? this.isPremium,
      isPremiumOnly: isPremiumOnly ?? this.isPremiumOnly,
      dayNumber: dayNumber ?? this.dayNumber,
      commentCount: commentCount ?? this.commentCount,
      giftedBy: giftedBy ?? this.giftedBy,
      giftMessage: giftMessage ?? this.giftMessage,
    );
  }
  
  // Format duration from seconds to mm:ss
  String get formattedDuration {
    final minutes = (duration / 60).floor();
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Check if the bite was gifted
  bool get isGifted => giftedBy.isNotEmpty;
  
  // Update comment count
  BiteModel withCommentCount(int count) {
    return this.copyWith(commentCount: count);
  }
  
  // Create a gifted bite
  BiteModel asGiftedBite({required String senderName, String message = ''}) {
    return this.copyWith(
      giftedBy: senderName,
      giftMessage: message.isNotEmpty ? message : 'Enjoy this content!',
    );
  }
}