import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ContentService _contentService = ContentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<BiteModel> _allBites = [];
  List<BiteModel> _favoriteBites = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _favoriteIds = [];
  Map<String, int> _commentCountCache = {};
  
  // Performance optimization: cache timestamp to avoid unnecessary refreshes
  DateTime? _lastFavoritesRefresh;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChange);
    WidgetsBinding.instance.addObserver(this);
    _loadContent();
    _loadFavorites();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Removed automatic favorites refresh on app resume to improve performance
    // Favorites will be refreshed only when explicitly needed
  }

  void _onTabChange() {
    // Performance optimization: only refresh favorites if needed
    if (_tabController.index == 1) {
      // Only refresh if it's been more than 30 seconds since last refresh
      // or if favorites are empty but should have content
      final now = DateTime.now();
      final shouldRefresh = _lastFavoritesRefresh == null ||
          now.difference(_lastFavoritesRefresh!).inSeconds > 30 ||
          (_favoriteBites.isEmpty && _favoriteIds.isNotEmpty);
      
      if (shouldRefresh) {
        _refreshFavorites();
      }
    }
  }

  Future<void> _refreshFavorites() async {
    print('DEBUG: Library - Refreshing favorites...');
    _lastFavoritesRefresh = DateTime.now();
    await _loadFavorites();
    await _loadFavoriteBites();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('DEBUG: Library - Loading sequential content for user...');
      
      // Get bites available to user based on their progression (CRITICAL FIX)
      final allBitesWithComments = await _contentService.getUserSequentialBites();
      
      if (allBitesWithComments.isEmpty) {
        setState(() {
          _allBites = [];
          _favoriteBites = [];
          _isLoading = false;
          _errorMessage = 'No content available. Use Diagnostics to create test content.';
        });
        return;
      }
      
      setState(() {
        _allBites = allBitesWithComments;
        _isLoading = false;
      });
      
      // Load favorites after all content is loaded
      await _loadFavoriteBites();
      
    } catch (e) {
      print('DEBUG: Library - Error loading content: $e');
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<int> _getCommentCount(String biteId) async {
    // Check cache first for performance
    if (_commentCountCache.containsKey(biteId)) {
      return _commentCountCache[biteId]!;
    }
    
    try {
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('biteId', isEqualTo: biteId)
          .get();
      final count = commentsSnapshot.docs.length;
      
      // Cache the result
      _commentCountCache[biteId] = count;
      return count;
    } catch (e) {
      print('DEBUG: Library - Error getting comment count for bite $biteId: $e');
      return 0;
    }
  }

  // Method to refresh comment counts for specific bite (called when returning from comments)
  Future<void> _refreshBiteCommentCount(String biteId) async {
    try {
      final newCommentCount = await _getCommentCount(biteId);
      print('DEBUG: Library - Refreshing comment count for bite $biteId: $newCommentCount');
      
      // Update all bites list
      final updatedAllBites = _allBites.map((bite) {
        if (bite.id == biteId) {
          return bite.copyWith(commentCount: newCommentCount);
        }
        return bite;
      }).toList();
      
      // Update favorite bites list if needed
      final updatedFavoriteBites = _favoriteBites.map((bite) {
        if (bite.id == biteId) {
          return bite.copyWith(commentCount: newCommentCount);
        }
        return bite;
      }).toList();
      
      setState(() {
        _allBites = updatedAllBites;
        _favoriteBites = updatedFavoriteBites;
      });
    } catch (e) {
      print('DEBUG: Library - Error refreshing comment count for bite $biteId: $e');
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
      // Removed debug print for performance
    }
  }
  
  Future<void> _loadFavoriteBites() async {
    try {
      if (_favoriteIds.isEmpty) {
        print('DEBUG: Library - No favorite IDs, clearing favorites list');
        setState(() {
          _favoriteBites = [];
        });
        return;
      }
      
      // Filter all bites to get only favorites
      final favoriteBites = _allBites.where((bite) => _favoriteIds.contains(bite.id)).toList();
      print('DEBUG: Library - Found ${favoriteBites.length} favorite bites with comment counts');
      
      for (var bite in favoriteBites) {
        print('DEBUG: Library - Favorite bite ${bite.id} (${bite.title}) has ${bite.commentCount} comments');
      }
      
      // FIXED: Sort favorites by dayNumber, newest/highest first (like Instagram/social media)
      favoriteBites.sort((a, b) => b.dayNumber.compareTo(a.dayNumber));
      
      setState(() {
        _favoriteBites = favoriteBites;
      });
      
    } catch (e) {
      print('DEBUG: Library - Error loading favorite bites: $e');
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
      
      // Reload favorite bites to update the favorites tab (only if on favorites tab)
      if (_tabController.index == 1) {
        await _loadFavoriteBites();
      }
      _lastFavoritesRefresh = DateTime.now(); // Update cache timestamp
      
    } catch (e) {
      // Removed debug print for performance
    }
  }

  void _playBite(BiteModel bite) {
    // Mark bite as opened when user navigates to player (CRITICAL FIX for Fresh Bites)
    _contentService.markBiteAsOpened(bite.id);
    
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
                      ? CachedNetworkImage(
                          imageUrl: bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF8B0000),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
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
                      color: const Color(0xFF8B0000),
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
                      if (bite.commentCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${bite.commentCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
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

  Widget _buildBitesList(List<BiteModel> bites, String emptyMessage, String emptyIcon, {bool isFavoritesTab = false}) {
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
              onPressed: isFavoritesTab ? _refreshFavorites : _loadContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: isFavoritesTab ? _refreshFavorites : _loadContent,
      color: const Color(0xFF8B0000),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: bites.length,
        itemBuilder: (context, index) {
          return _buildBiteCard(bites[index]);
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Library',
          style: GoogleFonts.crimsonText(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: const Color(0xFF8B0000),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: const Color(0xFF8B0000).withOpacity(0.08),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8B0000),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF8B0000),
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
                color: Color(0xFF8B0000),
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
                            backgroundColor: const Color(0xFF8B0000),
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
                      isFavoritesTab: true,
                    ),
                  ],
                ),
    );
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _commentCountCache.clear();
    super.dispose();
  }
}