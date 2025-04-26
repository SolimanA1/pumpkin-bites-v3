import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';

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
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isPostingComment = false;
  String _errorMessage = '';
  
  // Reply functionality
  String? _replyToCommentId;
  String _replyToUsername = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final comments = await _contentService.getCommentsForBite(widget.bite.id);
      
      setState(() {
        _comments = comments;
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
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to comment')),
        );
        return;
      }

      // Create comment data with parentCommentId field for replies
      final Map<String, dynamic> commentData = {
        'biteId': widget.bite.id,
        'userId': user.uid,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
      };
      
      // Add parentCommentId if this is a reply
      if (_replyToCommentId != null) {
        commentData['parentCommentId'] = _replyToCommentId;
        commentData['replyTo'] = _replyToUsername;
      }

      // Add the comment to Firestore
      await _firestore.collection('comments').add(commentData);
      
      // Clear input and reset reply state
      setState(() {
        _commentController.clear();
        _replyToCommentId = null;
        _replyToUsername = '';
        _isPostingComment = false;
      });

      // Refresh comments to include the new one
      _loadComments();
      
      // Update comment count in the bite document
      await _firestore.collection('bites').doc(widget.bite.id).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error posting comment: $e');
      setState(() {
        _isPostingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    }
  }

  void _setReplyTo(CommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToUsername = comment.displayName;
      // Focus the text field
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments for ${widget.bite.title}'),
      ),
      body: Column(
        children: [
          // Bite info header
          _buildBiteHeader(),
          
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorView()
                    : _comments.isEmpty
                        ? _buildEmptyView()
                        : _buildCommentsList(),
          ),
          
          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildBiteHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: widget.bite.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      widget.bite.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 24),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.music_note, size: 24),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Bite details
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bite.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadComments,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.message,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No comments yet. Be the first to comment!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final isReply = comment.text.contains('@') && comment.text.contains(':');
        
        if (isReply) {
          // This is a visual approach to showing replies
          // It identifies comments that are replies by looking for "@username:" pattern
          return Padding(
            padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
            child: _buildCommentCard(comment, true),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildCommentCard(comment, false),
          );
        }
      },
    );
  }

  Widget _buildCommentCard(CommentModel comment, bool isReply) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isReply
            ? BorderSide(color: Colors.grey.shade300)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
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
                
                // Username and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        comment.formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Like count
                if (comment.likeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.thumb_up, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Comment text
            Text(comment.text),
            
            const SizedBox(height: 8),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Like button
                TextButton.icon(
                  onPressed: () {
                    // Implement like functionality
                  },
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
                
                const SizedBox(width: 8),
                
                // Reply button
                TextButton.icon(
                  onPressed: () => _setReplyTo(comment),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
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

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show reply indicator if replying
          if (_replyToCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to $_replyToUsername',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          
          // Comment input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyToCommentId == null
                        ? 'Add a comment...'
                        : 'Reply to $_replyToUsername...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                    : Icon(
                        Icons.send,
                        color: Theme.of(context).primaryColor,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}