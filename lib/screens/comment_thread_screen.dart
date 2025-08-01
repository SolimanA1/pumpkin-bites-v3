import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../models/comment_model.dart';
import '../services/content_service.dart';
import '../services/community_service.dart';

class CommentThreadScreen extends StatefulWidget {
  final BiteModel bite;
  final CommentModel parentComment;

  const CommentThreadScreen({
    Key? key, 
    required this.bite,
    required this.parentComment,
  }) : super(key: key);

  @override
  State<CommentThreadScreen> createState() => _CommentThreadScreenState();
}

class _CommentThreadScreenState extends State<CommentThreadScreen> {
  final ContentService _contentService = ContentService();
  final CommunityService _communityService = CommunityService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<CommentModel> _replies = [];
  bool _isLoading = true;
  bool _isPostingReply = false;
  String _errorMessage = '';
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
    
    // Listen to text changes for send button
    _replyController.addListener(() {
      final hasText = _replyController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Get all comments for this bite
      final allComments = await _contentService.getCommentsForBite(widget.bite.id);
      
      // Filter replies to this parent comment (comments that start with @parentAuthor or contain nested replies)
      final replies = allComments.where((comment) {
        return comment.id != widget.parentComment.id && 
               (comment.text.startsWith('@${widget.parentComment.displayName}') ||
                comment.text.contains('→ @${widget.parentComment.displayName}'));
      }).toList();
      
      // Sort replies chronologically (oldest first, like YouTube)
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading replies: $e');
      setState(() {
        _errorMessage = 'Failed to load replies: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _postReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _isPostingReply = true;
    });
    
    try {
      String replyText;
      
      // Check if this is a nested reply (contains "→")
      if (text.contains('→')) {
        // It's already formatted as a nested reply
        replyText = text;
      } else {
        // It's a direct reply to the parent comment
        replyText = '@${widget.parentComment.displayName} $text';
      }
      
      final success = await _contentService.addComment(widget.bite.id, replyText);
      
      if (success) {
        _replyController.clear();
        FocusScope.of(context).unfocus();
        
        // Reload replies to show the new one
        await _loadReplies();
        
        // Scroll to bottom to show new reply
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post reply')),
        );
      }
    } catch (e) {
      print('Error posting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isPostingReply = false;
      });
    }
  }

  void _replyToReply(CommentModel reply) {
    // Extract the original username from the reply
    String originalUsername = widget.parentComment.displayName;
    String replyToUsername = reply.displayName;
    
    // Set placeholder text showing who they're replying to
    _replyController.text = '@$replyToUsername (→ @$originalUsername) ';
    
    // Move cursor to end and focus
    _replyController.selection = TextSelection.fromPosition(
      TextPosition(offset: _replyController.text.length),
    );
    
    // Focus the text field
    FocusScope.of(context).requestFocus();
  }

  Future<void> _likeComment(CommentModel comment) async {
    try {
      await _communityService.likeComment(comment.id);
      // Reload to update like count
      if (comment.id == widget.parentComment.id) {
        // If it's the parent comment, we need to notify the parent screen
        // For now, just reload the replies
        await _loadReplies();
      } else {
        await _loadReplies();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error liking comment: $e')),
      );
    }
  }

  void _playBite() {
    Navigator.pushNamed(context, '/player', arguments: widget.bite);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replies'),
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
          // Parent comment header (always visible)
          _buildParentCommentHeader(),
          
          // Replies section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorView()
                    : _buildRepliesSection(),
          ),
          
          // Reply input
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildParentCommentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.shade200,
            backgroundImage: widget.parentComment.photoURL.isNotEmpty
                ? NetworkImage(widget.parentComment.photoURL)
                : null,
            child: widget.parentComment.photoURL.isEmpty
                ? Text(
                    widget.parentComment.displayName.isNotEmpty
                        ? widget.parentComment.displayName[0].toUpperCase()
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
                      widget.parentComment.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.parentComment.formattedTime,
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
                  widget.parentComment.text,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                
                // Like button
                InkWell(
                  onTap: () => _likeComment(widget.parentComment),
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
                        if (widget.parentComment.likeCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${widget.parentComment.likeCount}',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesSection() {
    if (_replies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No replies yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to reply!',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReplies,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _replies.length,
        itemBuilder: (context, index) {
          return _buildReplyItem(_replies[index]);
        },
      ),
    );
  }

  Widget _buildReplyItem(CommentModel reply) {
    // Parse display text based on reply format
    String displayText = reply.text;
    if (reply.text.startsWith('@')) {
      if (reply.text.contains('→')) {
        // Handle nested reply format: "@user1 (→ @user2) actual text"
        final arrowIndex = reply.text.indexOf('→');
        final closingParen = reply.text.indexOf(')', arrowIndex);
        if (closingParen > arrowIndex) {
          displayText = reply.text.substring(closingParen + 1).trim();
          
          // Extract usernames for display
          final firstAt = reply.text.indexOf('@');
          final firstUser = reply.text.substring(firstAt + 1, reply.text.indexOf(' '));
          
          displayText = 'Replying to @$firstUser: $displayText';
        }
      } else {
        // Handle simple reply format: "@user actual text"
        final spaceIndex = reply.text.indexOf(' ');
        if (spaceIndex > 1) {
          displayText = reply.text.substring(spaceIndex + 1);
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(left: 16), // Indent replies
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar (smaller for replies)
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.orange.shade200,
            backgroundImage: reply.photoURL.isNotEmpty
                ? NetworkImage(reply.photoURL)
                : null,
            child: reply.photoURL.isEmpty
                ? Text(
                    reply.displayName.isNotEmpty
                        ? reply.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name and time
                Row(
                  children: [
                    Text(
                      reply.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reply.formattedTime,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Reply text
                Text(
                  displayText,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                
                // Like and Reply buttons
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () => _likeComment(reply),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            if (reply.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${reply.likeCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Reply button
                    InkWell(
                      onTap: () => _replyToReply(reply),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildReplyInput() {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Replying to" indicator (smaller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12), // Smaller radius
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply,
                    size: 12, // Smaller icon
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Replying to @${widget.parentComment.displayName}',
                    style: TextStyle(
                      fontSize: 11, // Smaller font
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8), // Reduced spacing
            
            // Input row
            Row(
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
                
                // Reply input field
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Add a reply...',
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
                    color: _hasText && !_isPostingReply
                        ? Colors.orange 
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isPostingReply || !_hasText
                        ? null 
                        : _postReply,
                    icon: _isPostingReply
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
            onPressed: _loadReplies,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}