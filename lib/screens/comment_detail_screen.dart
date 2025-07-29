import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/community_service.dart';
import 'comment_thread_screen.dart';

class CommentDetailScreen extends StatefulWidget {
  final BiteModel bite;

  const CommentDetailScreen({
    Key? key, 
    required this.bite,
  }) : super(key: key);

  @override
  State<CommentDetailScreen> createState() => _CommentDetailScreenState();
}

class _CommentDetailScreenState extends State<CommentDetailScreen> {
  final ContentService _contentService = ContentService();
  final CommunityService _communityService = CommunityService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<CommentModel> _parentComments = [];
  Map<String, int> _replyCounts = {};
  bool _isLoading = true;
  bool _isPostingComment = false;
  String _errorMessage = '';
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    
    // Listen to text changes to update send button state
    _commentController.addListener(() {
      final hasText = _commentController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Get all comments for this bite
      final allComments = await _contentService.getCommentsForBite(widget.bite.id);
      
      // Separate parent comments (don't start with @) from replies
      final parentComments = <CommentModel>[];
      final replyMap = <String, List<CommentModel>>{};
      
      for (final comment in allComments) {
        if (comment.text.startsWith('@')) {
          // This is a reply - extract the parent username
          final spaceIndex = comment.text.indexOf(' ');
          if (spaceIndex > 1) {
            final parentUsername = comment.text.substring(1, spaceIndex);
            
            // Find the parent comment by username
            final parentComment = allComments.firstWhere(
              (c) => c.displayName == parentUsername && !c.text.startsWith('@'),
              orElse: () => comment, // fallback
            );
            
            if (parentComment.id != comment.id) {
              // Group replies by parent comment ID
              replyMap.putIfAbsent(parentComment.id, () => []).add(comment);
            } else {
              // If no parent found, treat as parent comment
              parentComments.add(comment);
            }
          } else {
            // Malformed reply, treat as parent comment
            parentComments.add(comment);
          }
        } else {
          // This is a parent comment
          parentComments.add(comment);
        }
      }
      
      // Calculate reply counts
      final replyCounts = <String, int>{};
      for (final parentComment in parentComments) {
        replyCounts[parentComment.id] = replyMap[parentComment.id]?.length ?? 0;
      }
      
      // Sort parent comments by date (newest first)
      parentComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _parentComments = parentComments;
        _replyCounts = replyCounts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      
      setState(() {
        _errorMessage = 'Failed to load comments: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _isPostingComment = true;
    });
    
    try {
      final success = await _contentService.addComment(widget.bite.id, text);
      
      if (success) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
        
        // Reload comments
        await _loadComments();
        
        // Scroll to top to show new comment
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isPostingComment = false;
      });
    }
  }

  Future<void> _likeComment(CommentModel comment) async {
    try {
      await _communityService.likeComment(comment.id);
      
      // Reload comments to update like count
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error liking comment: $e')),
      );
    }
  }

  void _playBite() {
    Navigator.pushNamed(context, '/player', arguments: widget.bite);
  }

  void _openCommentThread(CommentModel parentComment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentThreadScreen(
          bite: widget.bite,
          parentComment: parentComment,
        ),
      ),
    ).then((_) {
      // Reload comments when returning from thread view
      _loadComments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _playBite,
            tooltip: 'Play this bite',
          ),
        ],
      ),
      body: Column(
        children: [
          // Bite info header
          _buildBiteHeader(),
          
          // Comments section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorView()
                    : _buildCommentsSection(),
          ),
          
          // Comment input at bottom
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildBiteHeader() {
    final totalComments = _parentComments.length + _replyCounts.values.fold(0, (sum, count) => sum + count);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: widget.bite.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      widget.bite.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Bite info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bite.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.bite.formattedDuration} • ${widget.bite.category}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${widget.bite.authorName}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$totalComments ${totalComments == 1 ? 'comment' : 'comments'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Play button
          ElevatedButton.icon(
            onPressed: _playBite,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (_parentComments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your thoughts!',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _parentComments.length,
        itemBuilder: (context, index) {
          return _buildParentCommentItem(_parentComments[index]);
        },
      ),
    );
  }

  Widget _buildParentCommentItem(CommentModel comment) {
    final replyCount = _replyCounts[comment.id] ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.orange.shade200,
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
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name and time
                    Row(
                      children: [
                        Text(
                          comment.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.formattedTime,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Comment text
                    Text(
                      comment.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    
                    // Action buttons
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () => _likeComment(comment),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.thumb_up_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                if (comment.likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${comment.likeCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Reply button - always show for parent comments
                        InkWell(
                          onTap: () => _openCommentThread(comment),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
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
          
          // Reply count and view thread button (if there are replies)
          if (replyCount > 0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 44), // Align with comment text
              child: InkWell(
                onTap: () => _openCommentThread(comment),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.orange.shade200,
              backgroundImage: user?.photoURL?.isNotEmpty == true
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL?.isEmpty != false
                  ? Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // Comment input field
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 2, // Reduced from 3 to 2
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _hasText && !_isPostingComment
                    ? Colors.orange 
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isPostingComment || !_hasText
                    ? null 
                    : _postComment,
                icon: _isPostingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: _hasText ? Colors.white : Colors.grey.shade500,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
            onPressed: _loadComments,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}