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
  List<BiteModel> _favoriteBites = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _favoriteIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      
      // Get all bites to ensure we have content
      final allBitesQuery = await _firestore.collection('bites').get();
      
      if (allBitesQuery.docs.isEmpty) {
        setState(() {
          _allBites = [];
          _favoriteBites = [];
          _isLoading = false;
          _errorMessage = 'No content available. Use Diagnostics to create test content.';
        });
        return;
      }
      
      // Parse all bites
      final allBites = allBitesQuery.docs.map((doc) => BiteModel.fromFirestore(doc)).toList();
      print('Found ${allBites.length} total bites');
      
      // FIXED: Sort by dayNumber, newest/highest first (like Instagram/social media)
      // Higher day numbers (Day 5, Day 4, Day 3...) appear at the top
      allBites.sort((a, b) => b.dayNumber.compareTo(a.dayNumber));
      
      setState(() {
        _allBites = allBites;
        _isLoading = false;
      });
      
      // Load favorites after all content is loaded
      await _loadFavoriteBites();
      
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
        _favoriteIds = favorites.map((item) => item.toString()).toList();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }
  
  Future<void> _loadFavoriteBites() async {
    try {
      if (_favoriteIds.isEmpty) {
        setState(() {
          _favoriteBites = [];
        });
        return;
      }
      
      // Filter all bites to get only favorites
      final favoriteBites = _allBites.where((bite) => _favoriteIds.contains(bite.id)).toList();
      
      // FIXED: Sort favorites by dayNumber, newest/highest first (like Instagram/social media)
      favoriteBites.sort((a, b) => b.dayNumber.compareTo(a.dayNumber));
      
      setState(() {
        _favoriteBites = favoriteBites;
      });
      
      print('Loaded ${_favoriteBites.length} favorite bites');
    } catch (e) {
      print('Error loading favorite bites: $e');
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
          _favoriteIds.add(biteId);
        });
      } else {
        // Remove from favorites
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'favorites': FieldValue.arrayRemove([biteId]),
        });
        setState(() {
          _favoriteIds.remove(biteId);
        });
      }
      
      // Reload favorite bites to update the favorites tab
      await _loadFavoriteBites();
      
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  void _playBite(BiteModel bite) {
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  Widget _buildBiteCard(BiteModel bite) {
    final isFavorite = _favoriteIds.contains(bite.id);
    
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
                
                // Day badge - ENHANCED: Shows newest first
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF56500),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DAY ${bite.dayNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                // Favorite button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withOpacity(0.5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _toggleFavorite(bite.id, !isFavorite),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFavorite ? Colors.red : Colors.white,
                        ),
                      ),
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
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.category,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bite.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      // ENHANCED: Show relative date for social media feel
                      Text(
                        _getRelativeDate(bite.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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

  // ADDED: Get relative date like social media (e.g., "2 days ago", "1 week ago")
  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  Widget _buildBitesList(List<BiteModel> bites, String emptyMessage, String emptyIcon) {
    if (bites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon == 'folder' ? Icons.folder_open : Icons.favorite_border,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF56500),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: const Color(0xFFF56500),
      child: ListView.builder(
        itemCount: bites.length,
        itemBuilder: (context, index) {
          return _buildBiteCard(bites[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF56500),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFFF56500),
          tabs: const [
            Tab(
              icon: Icon(Icons.library_books),
              text: 'All Content',
            ),
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Favorites',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF56500),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF56500),
                          ),
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
                      'No content found.\nUse Diagnostics to create test content or check your connection.',
                      'folder',
                    ),
                    _buildBitesList(
                      _favoriteBites,
                      'No favorites yet!\nTap the ❤️ icon on any bite to add it to your favorites.',
                      'favorite',
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