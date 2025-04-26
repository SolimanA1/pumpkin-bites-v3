import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/audio_player_service.dart';

class CommentDetailScreen extends StatefulWidget {
  final BiteModel bite;
  final AudioPlayerService? audioService;
  
  const CommentDetailScreen({
    Key? key,
    required this.bite,
    this.audioService,
  }) : super(key: key);

  @override
  State<CommentDetailScreen> createState() => _CommentDetailScreenState();
}

class _CommentDetailScreenState extends State<CommentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ContentService _contentService = ContentService();
  
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  
  String? _replyingToCommentId;
  String? _replyingToUserName;
  
  @override
  void initState() {
    super.initState();
    _loadComments();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }
  
  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final comments = await _contentService.getCommentsForBite(widget.bite.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comments: $e')),
        );
      }
    }
  }
  
  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() {
      _isPosting = true;
    });
    
    try {
      await _contentService.addComment(
        widget.bite.id,
        _commentController.text.trim(),
      );
      
      // Clear the comment field
      _commentController.clear();
      
      // Reload comments
      await _loadComments();
    } catch (e) {
      print('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }
  
  Future<void> _postReply(String parentCommentId, String replyToName) async {
    if (_replyController.text.trim().isEmpty) return;
    
    setState(() {
      _isPosting = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to reply');
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final displayName = userData?['displayName'] as String? ?? 'User';
      final photoURL = userData?['photoURL'] as String? ?? '';
      
      // Add the reply as a nested comment
      await _firestore.collection('comments').add({
        'biteId': widget.bite.id,
        'text': '${_replyingToUserName != null ? "@$_replyingToUserName " : ""}${_replyController.text.trim()}',
        'userId': user.uid,
        'displayName': displayName,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'parentCommentId': parentCommentId,
        'isReply': true,
        'replyToName': replyToName,
      });
      
      // Clear the reply field and reset replying state
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });
      
      // Reload comments
      await _loadComments();
    } catch (e) {
      print('Error posting reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting reply: $e')),
        );
      }
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }
  
  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
    });
  }
  
  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _replyController.clear();
    });
  }
  
  Future<void> _likeComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Check if user already liked this comment
      final likeDoc = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(user.uid)
          .get();
      
      if (likeDoc.exists) {
        // User already liked the comment, remove the like
        await _firestore
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(user.uid)
            .delete();
        
        // Decrement like count
        await _firestore.collection('comments').doc(commentId).update({
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // User has not liked the comment yet, add the like
        await _firestore
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .doc(user.uid)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Increment like count
        await _firestore.collection('comments').doc(commentId).update({
          'likeCount': FieldValue.increment(1),
        });
      }
      
      // Reload comments to update like count
      await _loadComments();
    } catch (e) {
      print('Error liking comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking comment: $e')),
        );
      }
    }
  }
  
  Widget _buildCommentsList() {
    // Group comments by parent/reply
    final Map<String, List<CommentModel>> repliesMap = {};
    final List<CommentModel> parentComments = [];
    
    for (final comment in _comments) {
      final isReply = comment.text.startsWith('@') || 
                     _comments.any((c) => comment.text.contains('@${c.displayName}'));
      
      if (isReply) {
        // Simplistic approach to associate replies with parents
        // A more robust approach would use an actual parentId field
        final parentComment = _comments.firstWhere(
          (c) => comment.text.contains('@${c.displayName}'),
          orElse: () => comment,
        );
        
        if (!repliesMap.containsKey(parentComment.id)) {
          repliesMap[parentComment.id] = [];
        }
        
        repliesMap[parentComment.id]!.add(comment);
      } else {
        parentComments.add(comment);
      }
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: parentComments.length,
      itemBuilder: (context, index) {
        final comment = parentComments[index];
        final replies = repliesMap[comment.id] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parent comment
            _buildCommentCard(comment),
            
            // Replies (if any)
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  children: replies.map((reply) => _buildCommentCard(reply, isReply: true)).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildCommentCard(CommentModel comment, {bool isReply = false}) {
    return Card(
      margin: EdgeInsets.only(
        bottom: 8,
        left: isReply ? 16 : 0,
        right: 0,
      ),
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
                  radius: isReply ? 12 : 16,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: comment.photoURL.isNotEmpty
                      ? NetworkImage(comment.photoURL)
                      : null,
                  child: comment.photoURL.isEmpty
                      ? Text(
                          comment.displayName.isNotEmpty
                              ? comment.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isReply ? 10 : 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                
                // User name
                Text(
                  comment.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isReply ? 12 : 14,
                  ),
                ),
                const Spacer(),
                
                // Time
                Text(
                  comment.formattedTime,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isReply ? 10 : 12,
                  ),
                ),
              ],
            ),
            
            // Reply indicator if this is a reply
            if (isReply && comment.text.contains('@'))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Replying to ${comment.text.split(' ').first.substring(1)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                  ),
                ),
              ),
              
            const SizedBox(height: 8),
            
            // Comment text
            Text(
              isReply && comment.text.contains('@')
                  ? comment.text.substring(comment.text.indexOf(' ') + 1)
                  : comment.text,
              style: TextStyle(fontSize: isReply ? 12 : 14),
            ),
            
            const SizedBox(height: 8),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Like button
                TextButton.icon(
                  onPressed: () => _likeComment(comment.id),
                  icon: const Icon(Icons.thumb_up, size: 16),
                  label: Text(
                    comment.likeCount > 0 ? comment.likeCount.toString() : 'Like',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                
                // Reply button
                TextButton.icon(
                  onPressed: () => _startReply(comment.id, comment.displayName),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply', style: TextStyle(fontSize: 12)),
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
  
  @override
  Widget build(BuildContext context) {
    final bool showFloatingPlayer = widget.audioService != null && 
                                   widget.audioService!.isPlaying;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion: ${widget.bite.title}'),
      ),
      body: Column(
        children: [
          // Bite Info Header
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        widget.bite.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.bite.category,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_comments.length} comments',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.message,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No comments yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildCommentsList(),
          ),
          
          // Comment Input Area
          if (_replyingToCommentId == null)
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                    onPressed: _isPosting ? null : _postComment,
                    icon: _isPosting
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
          
          // Reply Input Area (shows only when replying)
          if (_replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[100],
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to ${_replyingToUserName ?? 'comment'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _cancelReply,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: const InputDecoration(
                            hintText: 'Write a reply...',
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
                        onPressed: _isPosting
                            ? null
                            : () => _postReply(
                                  _replyingToCommentId!,
                                  _replyingToUserName!,
                                ),
                        icon: _isPosting
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
                ],
              ),
            ),
          
          // Floating Player Bar (if audio is playing)
          if (showFloatingPlayer && widget.audioService != null)
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
                          widget.bite.title,
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
}