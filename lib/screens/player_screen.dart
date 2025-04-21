import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bite_model.dart';
import '../services/audio_player_service.dart';
import '../services/content_service.dart';

class PlayerScreen extends StatefulWidget {
  final BiteModel bite;
  
  const PlayerScreen({Key? key, required this.bite}) : super(key: key);
  
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final ContentService _contentService = ContentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  bool _isBuffering = false;
  
  // Reaction system
  bool _isSavingReaction = false;
  String _selectedReaction = '';
  final List<String> _reactionOptions = ['🤔', '🔥', '💡', '📝'];
  
  // Favorite system
  bool _isFavorite = false;
  bool _isSavingFavorite = false;
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadUserReaction();
    _checkIfFavorite();
  }
  
  Future<void> _loadUserReaction() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final reactionDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reactions')
          .doc(widget.bite.id)
          .get();
      
      if (reactionDoc.exists && reactionDoc.data() != null) {
        final reaction = reactionDoc.data()?['reaction'] ?? '';
        if (mounted) {
          setState(() {
            _selectedReaction = reaction;
          });
        }
      }
    } catch (e) {
      print('Error loading user reaction: $e');
    }
  }
  
  Future<void> _checkIfFavorite() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data();
      if (userData == null) return;
      
      final List<dynamic> favorites = userData['favorites'] ?? [];
      final isFavorite = favorites.contains(widget.bite.id);
      
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }
  
  Future<void> _saveReaction(String reaction) async {
    if (_isSavingReaction) return;
    
    try {
      setState(() {
        _isSavingReaction = true;
      });
      
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to react')),
        );
        return;
      }
      
      // Save reaction to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reactions')
          .doc(widget.bite.id)
          .set({
        'reaction': reaction,
        'timestamp': FieldValue.serverTimestamp(),
        'biteTitle': widget.bite.title,
      });
      
      setState(() {
        _selectedReaction = reaction;
        _isSavingReaction = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction saved: $reaction')),
      );
    } catch (e) {
      print('Error saving reaction: $e');
      setState(() {
        _isSavingReaction = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving reaction: $e')),
      );
    }
  }
  
  Future<void> _toggleFavorite() async {
    if (_isSavingFavorite) return;
    
    try {
      setState(() {
        _isSavingFavorite = true;
      });
      
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to favorite content')),
        );
        return;
      }
      
      if (_isFavorite) {
        // Remove from favorites
        await _firestore.collection('users').doc(user.uid).update({
          'favorites': FieldValue.arrayRemove([widget.bite.id]),
        });
        
        setState(() {
          _isFavorite = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      } else {
        // Add to favorites
        await _firestore.collection('users').doc(user.uid).update({
          'favorites': FieldValue.arrayUnion([widget.bite.id]),
        });
        
        setState(() {
          _isFavorite = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites')),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    } finally {
      setState(() {
        _isSavingFavorite = false;
      });
    }
  }
  
  Future<void> _initPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
      });
      
      print("Initializing player for bite: ${widget.bite.id}");
      
      // Play the bite
      await _audioService.playBite(widget.bite);
      
      // Mark as listened
      _contentService.markBiteAsListened(widget.bite.id);
      
      // Set up position updates
      _audioService.positionStream.listen((position) {
        if (!mounted) return;
        
        final duration = _audioService.duration ?? Duration.zero;
        if (duration.inMilliseconds > 0) {
          final progress = position.inMilliseconds / duration.inMilliseconds;
          setState(() {
            _position = position;
            _progress = progress.clamp(0.0, 1.0);
          });
        }
      });
      
      // Set up duration updates
      _audioService.durationStream.listen((duration) {
        if (!mounted || duration == null) return;
        setState(() {
          _duration = duration;
        });
      });
      
      // Set up player state updates
      _audioService.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.buffering;
        });
      });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error initializing player: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = "Couldn't play audio: $e";
        });
      }
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.resume();
    }
  }
  
  void _skipBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _audioService.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }
  
  void _skipForward() {
    final duration = _duration ?? Duration.zero;
    final newPosition = _position + const Duration(seconds: 30);
    _audioService.seekTo(newPosition > duration ? duration : newPosition);
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bite.title),
        actions: [
          // Favorite button
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _isSavingFavorite ? null : _toggleFavorite,
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _isError 
              ? _buildErrorView()
              : _buildPlayerView(),
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
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Play Audio',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initPlayer,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            Text(
              widget.bite.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.bite.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            
            // Image if available
            if (widget.bite.thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.bite.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Player controls
            Slider(
              value: _progress,
              onChanged: (value) {
                if (_duration != null) {
                  final position = Duration(
                    milliseconds: (value * _duration!.inMilliseconds).round(),
                  );
                  _audioService.seekTo(position);
                }
              },
            ),
            
            // Time display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position)),
                  Text(_formatDuration(_duration ?? Duration.zero)),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Play controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _skipBackward,
                  icon: const Icon(Icons.replay_10),
                  iconSize: 36,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _isBuffering ? null : _togglePlayPause,
                  icon: Icon(
                    _isBuffering
                        ? Icons.hourglass_empty
                        : _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                  ),
                  iconSize: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _skipForward,
                  icon: const Icon(Icons.forward_30),
                  iconSize: 36,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Reaction buttons
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'How did you feel about this content?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            _isSavingReaction
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _reactionOptions.map((emoji) {
                      final isSelected = _selectedReaction == emoji;
                      return InkWell(
                        onTap: () => _saveReaction(emoji),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Theme.of(context).primaryColor.withOpacity(0.2)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    // We don't dispose the AudioPlayerService since it's a singleton
    super.dispose();
  }
}