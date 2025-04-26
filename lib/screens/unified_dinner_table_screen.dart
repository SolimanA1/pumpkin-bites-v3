import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/audio_player_service.dart';
import 'comment_detail_screen.dart';

class UnifiedDinnerTableScreen extends StatefulWidget {
  final String? initialBiteId;
  final AudioPlayerService? audioService;
  
  const UnifiedDinnerTableScreen({
    Key? key,
    this.initialBiteId,
    this.audioService,
  }) : super(key: key);

  @override
  State<UnifiedDinnerTableScreen> createState() => _UnifiedDinnerTableScreenState();
}

class _UnifiedDinnerTableScreenState extends State<UnifiedDinnerTableScreen> {
  final ContentService _contentService = ContentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<BiteModel> _bites = [];
  Map<String, int> _commentCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  // Current bite being played (if any)
  BiteModel? _currentPlayingBite;
  
  @override
  void initState() {
    super.initState();
    _loadContent();
    
    // If we have an audio service, check if something is playing
    if (widget.audioService != null && widget.audioService!.isPlaying) {
      // Try to determine which bite is playing
      _getCurrentPlayingBite();
    }
  }
  
  void _getCurrentPlayingBite() async {
    try {
      // This assumes bite info is stored in audio service or could be retrieved
      // For now, let's just use the initialBiteId if available
      if (widget.initialBiteId != null) {
        final bite = await _contentService.getBiteById(widget.initialBiteId!);
        if (bite != null) {
          setState(() {
            _currentPlayingBite = bite;
          });
        }
      }
    } catch (e) {
      print('Error determining current playing bite: $e');
    }
  }
  
  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Load available bites for discussion
      final bites = await _contentService.getAvailableBites();
      
      // Load comment counts for each bite
      final commentCounts = <String, int>{};
      for (final bite in bites) {
        try {
          final comments = await _contentService.getCommentsForBite(bite.id);
          commentCounts[bite.id] = comments.length;
        } catch (e) {
          print('Error getting comment count for bite ${bite.id}: $e');
          commentCounts[bite.id] = 0;
        }
      }
      
      // If there's an initialBiteId, make sure that bite is first in the list
      if (widget.initialBiteId != null) {
        bites.sort((a, b) => 
          a.id == widget.initialBiteId ? -1 : 
          b.id == widget.initialBiteId ? 1 : 0);
      }
      
      setState(() {
        _bites = bites;
        _commentCounts = commentCounts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dinner table content: $e');
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }
  
  void _openBiteComments(BiteModel bite) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommentDetailScreen(
          bite: bite,
          audioService: widget.audioService,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final bool showFloatingPlayer = widget.audioService != null && 
                                   widget.audioService!.isPlaying &&
                                   _currentPlayingBite != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinner Table'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _bites.isEmpty
                        ? _buildEmptyView()
                        : _buildBitesList(),
          ),
          
          // Floating player bar if audio is playing
          if (showFloatingPlayer && _currentPlayingBite != null)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      widget.audioService!.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (widget.audioService!.isPlaying) {
                        widget.audioService!.pause();
                      } else {
                        widget.audioService!.resume();
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  
                  // Bite title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPlayingBite!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Simple progress indicator
                        LinearProgressIndicator(
                          value: null, // Indeterminate
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Go back to player
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Error Loading Content',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadContent,
              child: const Text('Try Again'),
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
            Icons.forum_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No discussions available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for content to discuss',
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
  
  Widget _buildBitesList() {
    return RefreshIndicator(
      onRefresh: _loadContent,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _bites.length,
        itemBuilder: (context, index) {
          final bite = _bites[index];
          final commentCount = _commentCounts[bite.id] ?? 0;
          final isInitialBite = bite.id == widget.initialBiteId;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isInitialBite
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                  : BorderSide.none,
            ),
            elevation: isInitialBite ? 4 : 1,
            child: InkWell(
              onTap: () => _openBiteComments(bite),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bite.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bite.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Info row with category, duration, comment count
                        Row(
                          children: [
                            // Category pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                bite.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Duration
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  bite.formattedDuration,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            
                            // Comment count
                            Row(
                              children: [
                                Icon(
                                  Icons.comment,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // View comments button
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          child: ElevatedButton.icon(
                            onPressed: () => _openBiteComments(bite),
                            icon: const Icon(Icons.forum, size: 18),
                            label: Text(
                              commentCount > 0
                                  ? 'View comments'
                                  : 'Start the conversation',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}