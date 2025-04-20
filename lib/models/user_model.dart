import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  final DateTime createdAt;
  final List<dynamic> giftedEpisodes;
  final List<dynamic> membershipGifts;
  final int unreadGifts;
  final int sentGifts;
  final List<String> listenedBites;
  final List<String> favorites;
  final Map<String, dynamic> reactions;
  final bool isPremium;
  final List<String> unlockedContent;

  // Getter for backward compatibility
  String get id => uid;
  
  // Getter for name consistency (photoURL vs photoUrl)
  String? get photoUrl => photoURL;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.createdAt,
    this.giftedEpisodes = const [],
    this.membershipGifts = const [],
    this.unreadGifts = 0,
    this.sentGifts = 0,
    this.listenedBites = const [],
    this.favorites = const [],
    this.reactions = const {},
    this.isPremium = false,
    this.unlockedContent = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception("User data is null");
    }

    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      giftedEpisodes: List<dynamic>.from(data['giftedEpisodes'] ?? []),
      membershipGifts: List<dynamic>.from(data['membershipGifts'] ?? []),
      unreadGifts: data['unreadGifts'] ?? 0,
      sentGifts: data['sentGifts'] ?? 0,
      listenedBites: List<String>.from(data['listenedBites'] ?? []),
      favorites: List<String>.from(data['favorites'] ?? []),
      reactions: data['reactions'] as Map<String, dynamic>? ?? {},
      isPremium: data['isPremium'] ?? false,
      unlockedContent: List<String>.from(data['unlockedContent'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'giftedEpisodes': giftedEpisodes,
      'membershipGifts': membershipGifts,
      'unreadGifts': unreadGifts,
      'sentGifts': sentGifts,
      'listenedBites': listenedBites,
      'favorites': favorites,
      'reactions': reactions,
      'isPremium': isPremium,
      'unlockedContent': unlockedContent,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoURL,
    DateTime? createdAt,
    List<dynamic>? giftedEpisodes,
    List<dynamic>? membershipGifts,
    int? unreadGifts,
    int? sentGifts,
    List<String>? listenedBites,
    List<String>? favorites,
    Map<String, dynamic>? reactions,
    bool? isPremium,
    List<String>? unlockedContent,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      giftedEpisodes: giftedEpisodes ?? this.giftedEpisodes,
      membershipGifts: membershipGifts ?? this.membershipGifts,
      unreadGifts: unreadGifts ?? this.unreadGifts,
      sentGifts: sentGifts ?? this.sentGifts,
      listenedBites: listenedBites ?? this.listenedBites,
      favorites: favorites ?? this.favorites,
      reactions: reactions ?? this.reactions,
      isPremium: isPremium ?? this.isPremium,
      unlockedContent: unlockedContent ?? this.unlockedContent,
    );
  }
}