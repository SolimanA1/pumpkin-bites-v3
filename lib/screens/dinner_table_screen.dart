import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/community_service.dart';

class DinnerTableScreen extends StatefulWidget {
  const DinnerTableScreen({Key? key}) : super(key: key);

  @override
  _DinnerTableScreenState createState() => _DinnerTableScreenState();
}

class _DinnerTableScreenState extends State<DinnerTableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContentService _contentService = ContentService();
  final CommunityService _communityService = CommunityService();
  final TextEditingController _commentController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<BiteModel> _availableBites = [];
  Map<String, List<CommentModel>> _commentsMap = {};
  bool _isLoading = true;
  bool _isPostingComment = false;
  String _errorMessage = '';
  String? _selectedBiteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load available bites - fixed to use named parameter
      final bites = await _contentService.getAvailableBites();
      
      if (bites.isEmpty) {
        setState(() {
          _availableBites = [];
          _isLoading = false;
        });
        return;
      }

      // Initialize selected bite to the first one
      final selectedBiteId = bites.isNotEmpty ? bites[0].id : null;
      
      // Load comments for all bites
      final commentsMap = <String, List<CommentModel>>{};
      for (final bite in bites) {
        final comments = await _contentService.getCommentsForBite(bite.id);
        commentsMap[bite.id] = comments;
      }

      setState(() {
        _availableBites = bites;
        _commentsMap = commentsMap;
        _selectedBiteId = selectedBiteId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    if (_selectedBiteId == null || _commentController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isPostingComment = true;
    });

    try {
      final success = await _contentService.addComment(
        _selectedBiteId!,
        _commentController.text.trim(),
      );

      if (success) {
        // Clear the input field
        _commentController.clear();
        
        // Reload comments for the selected bite
        final comments = await _contentService.getCommentsForBite(_selectedBiteId!);
        
        setState(() {
          _commentsMap[_selectedBiteId!] = comments;
          _isPostingComment = false;
        });
      } else {
        setState(() {
          _isPostingComment = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } catch (e) {
      setState(() {
        _isPostingComment = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _selectBite(String biteId) {
    setState(() {
      _selectedBiteId = biteId;
    });
  }

  Future<void> _likeComment(CommentModel comment) async {
    try {
      await _communityService.likeComment(comment.id);
      
      // Reload comments to update like count
      if (_selectedBiteId != null) {
        final comments = await _contentService.getCommentsForBite(_selectedBiteId!);
        
        setState(() {
          _commentsMap[_selectedBiteId!] = comments;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error liking comment: $e')),
      );
    }
  }

  void _playBite(BiteModel bite) {
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  Widget _buildBiteItem(BiteModel bite) {
    final isSelected = _selectedBiteId == bite.id;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _selectBite(bite.id),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: bite.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 24,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
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
                      bite.category,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.message,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${bite.commentCount} comments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => _playBite(bite),
                          child: const Text('Play'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
      ),
    );
  }

  Widget _buildCommentSection() {
    if (_selectedBiteId == null) {
      return const Center(
        child: Text('Select a bite to view comments'),
      );
    }

    final comments = _commentsMap[_selectedBiteId] ?? [];
    final selectedBite = _availableBites.firstWhere(
      (bite) => bite.id == _selectedBiteId,
      orElse: () => throw Exception('Selected bite not found'),
    );

    return Column(
      children: [
        // Selected bite info
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: selectedBite.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          selectedBite.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 24,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedBite.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${selectedBite.duration} seconds • ${selectedBite.category}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.message,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedBite.commentCount} comments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => _playBite(selectedBite),
                          child: const Text('Play'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
        
        // Comment input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isPostingComment ? null : _postComment,
                icon: _isPostingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
        
        // Comments list
        Expanded(
          child: comments.isEmpty
              ? const Center(
                  child: Text(
                    'No comments yet. Be the first to comment!',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(comments[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: comment.photoURL.isNotEmpty
                      ? NetworkImage(comment.photoURL)
                      : null,
                  child: comment.photoURL.isEmpty
                      ? Text(
                          comment.displayName.isNotEmpty
                              ? comment.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                
                // User name
                Text(
                  comment.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                
                // Time
                Text(
                  comment.formattedTime,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Comment text
            Text(
              comment.text,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            
            // Like button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _likeComment(comment),
                  icon: const Icon(Icons.thumb_up, size: 16),
                  label: const Text('Like'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitesList() {
    if (_availableBites.isEmpty) {
      return const Center(
        child: Text(
          'No bites available for discussion',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _availableBites.length,
      itemBuilder: (context, index) {
        return _buildBiteItem(_availableBites[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinner Table'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Comments'),
            Tab(text: 'Topics'),
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
                    _buildCommentSection(),
                    _buildBitesList(),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}