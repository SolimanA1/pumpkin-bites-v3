import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContentService _contentService = ContentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<BiteModel> _allBites = [];
  List<BiteModel> _listenedBites = [];
  List<BiteModel> _giftedBites = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _favoriteBites = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContent();
    _loadFavorites();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('Loading library content...');
      
      // First, get all bites to ensure we have content
      final allBitesQuery = await _firestore.collection('bites').get();
      
      if (allBitesQuery.docs.isEmpty) {
        setState(() {
          _allBites = [];
          _listenedBites = [];
          _giftedBites = [];
          _isLoading = false;
          _errorMessage = 'No content available. Use Diagnostics to create test content.';
        });
        return;
      }
      
      // Parse all bites
      final allBites = allBitesQuery.docs.map((doc) => BiteModel.fromFirestore(doc)).toList();
      print('Found ${allBites.length} total bites');
      
      // Get user data
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _allBites = allBites;
          _listenedBites = [];
          _giftedBites = [];
          _isLoading = false;
        });
        return;
      }
      
      // Get user document to check listened and gifted bites
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() {
          _allBites = allBites;
          _listenedBites = [];
          _giftedBites = [];
          _isLoading = false;
        });
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        setState(() {
          _allBites = allBites;
          _listenedBites = [];
          _giftedBites = [];
          _isLoading = false;
        });
        return;
      }
      
      // Parse listened bites
      final listenedIds = List<String>.from(userData['listenedBites'] ?? []);
      print('Found ${listenedIds.length} listened bite IDs');
      
      final listened = allBites.where((bite) => listenedIds.contains(bite.id)).toList();
      
      // Parse gifted episodes
      final giftedEpisodesRaw = userData['giftedEpisodes'] as List<dynamic>? ?? [];
      print('Found ${giftedEpisodesRaw.length} gifted episodes');
      
      final giftedBiteIds = <String>[];
      final giftedBiteInfo = <String, Map<String, String>>{};
      
      for (final gift in giftedEpisodesRaw) {
        if (gift is Map<String, dynamic> && gift.containsKey('biteId')) {
          final biteId = gift['biteId'] as String?;
          if (biteId != null && biteId.isNotEmpty) {
            giftedBiteIds.add(biteId);
            giftedBiteInfo[biteId] = {
              'senderName': gift['senderName'] as String? ?? 'Someone',
              'message': gift['message'] as String? ?? 'Enjoy this content!',
            };
          }
        }
      }
      
      final giftedBites = <BiteModel>[];
      for (final bite in allBites) {
        if (giftedBiteIds.contains(bite.id)) {
          final info = giftedBiteInfo[bite.id];
          if (info != null) {
            giftedBites.add(bite.asGiftedBite(
              senderName: info['senderName'] ?? 'Someone',
              message: info['message'] ?? 'Enjoy this content!',
            ));
          }
        }
      }

      setState(() {
        _allBites = allBites;
        _listenedBites = listened;
        _giftedBites = giftedBites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading library content: $e');
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      if (userData == null) return;

      final favorites = userData['favorites'] as List<dynamic>? ?? [];
      setState(() {
        _favoriteBites = favorites.map((item) => item.toString()).toList();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String biteId, bool isFavorite) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      if (isFavorite) {
        // Add to favorites
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'favorites': FieldValue.arrayUnion([biteId]),
        });
        setState(() {
          _favoriteBites.add(biteId);
        });
      } else {
        // Remove from favorites
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'favorites': FieldValue.arrayRemove([biteId]),
        });
        setState(() {
          _favoriteBites.remove(biteId);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  void _playBite(BiteModel bite) {
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  Widget _buildBiteCard(BiteModel bite, bool showGiftBadge) {
    final isFavorite = _favoriteBites.contains(bite.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _playBite(bite),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with overlay
            Stack(
              children: [
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: bite.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
                
                // Duration overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bite.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                // Gift badge
                if (showGiftBadge && bite.isGifted)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Gift from ${bite.giftedBy}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Favorite button
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: () => _toggleFavorite(bite.id, !isFavorite),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bite.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bite.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.category,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bite.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${bite.date.day}/${bite.date.month}/${bite.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitesList(List<BiteModel> bites, String emptyMessage, bool showGiftBadge) {
    if (bites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadContent,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: bites.length,
      itemBuilder: (context, index) {
        return _buildBiteCard(bites[index], showGiftBadge);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Content'),
            Tab(text: 'History'),
            Tab(text: 'Gifted'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContent,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBitesList(
                      _allBites,
                      'No content found. Use Diagnostics to create test content.',
                      false,
                    ),
                    _buildBitesList(
                      _listenedBites,
                      'No listening history yet. Play some content to see it here!',
                      false,
                    ),
                    _buildBitesList(
                      _giftedBites,
                      'No gifted episodes yet. Friends can send you content that will appear here!',
                      true,
                    ),
                  ],
                ),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}