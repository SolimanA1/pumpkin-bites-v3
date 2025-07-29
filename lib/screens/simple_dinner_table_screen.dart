import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';
import 'comment_detail_screen.dart';

class SimpleReelDinnerTableScreen extends StatefulWidget {
  const SimpleReelDinnerTableScreen({Key? key}) : super(key: key);

  @override
  _SimpleReelDinnerTableScreenState createState() => _SimpleReelDinnerTableScreenState();
}

class _SimpleReelDinnerTableScreenState extends State<SimpleReelDinnerTableScreen> {
  final ContentService _contentService = ContentService();
  List<BiteModel> _bitesWithComments = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBitesWithComments();
  }

  Future<void> _loadBitesWithComments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('DEBUG: DinnerTable - Loading sequential bites with comments...');

      // Get user's sequential bites that have comments (CRITICAL FIX)
      final bitesWithComments = await _contentService.getUserSequentialBitesWithComments();
      
      setState(() {
        _bitesWithComments = bitesWithComments;
        _isLoading = false;
      });
      
      print('DEBUG: DinnerTable - Loaded ${bitesWithComments.length} bites with comments');
      
    } catch (e) {
      print('DEBUG: DinnerTable - Error loading: $e');
      setState(() {
        _errorMessage = 'Failed to load discussions: $e';
        _isLoading = false;
      });
    }
  }


  void _navigateToCommentDetail(BiteModel bite) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentDetailScreen(bite: bite),
      ),
    );
    // Refresh the discussion when returning from comment detail
    _loadBitesWithComments();
  }

  void _playBite(BiteModel bite) {
    // Mark bite as opened when user navigates to player (CRITICAL FIX for Fresh Bites)
    _contentService.markBiteAsOpened(bite.id);
    
    Navigator.pushNamed(context, '/player', arguments: bite);
  }

  Widget _buildBiteCard(BiteModel bite) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: () => _navigateToCommentDetail(bite),
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail with play button and comment count
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                    child: bite.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            bite.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                  ),
                  // Category and comment count overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bite.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.comment, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${bite.commentCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Play button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withOpacity(0.6),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _playBite(bite),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content section
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
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration: ${bite.formattedDuration}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Container(),
                    ],
                  ),
                ],
              ),
            ),
            
            // "Join discussion" button bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12.0),
                  bottomRight: Radius.circular(12.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to join the discussion',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dinner Table',
          style: GoogleFonts.crimsonText(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: const Color(0xFFF56500),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: const Color(0xFFF56500).withOpacity(0.08),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFFF56500),
            ))
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _bitesWithComments.isEmpty
                  ? _buildEmptyView()
                  : RefreshIndicator(
                      onRefresh: _loadBitesWithComments,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: _bitesWithComments.length,
                        itemBuilder: (context, index) {
                          return _buildBiteCard(_bitesWithComments[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
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
              onPressed: _loadBitesWithComments,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No discussions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Missing a bite? Time to stir the pot! Tap \'Discuss\' to share what\'s on your mind.',
            style: TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBitesWithComments,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}