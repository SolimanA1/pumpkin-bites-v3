import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bite_model.dart';
import '../services/audio_player_service.dart';
import '../services/content_service.dart';
import '../services/share_service.dart';

class PlayerScreen extends StatefulWidget {
  final BiteModel bite;
  
  const PlayerScreen({Key? key, required this.bite}) : super(key: key);
  
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final ContentService _contentService = ContentService();
  final ShareService _shareService = ShareService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _hasAttemptedPlay = false;
  
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  bool _isBuffering = false;
  
  // Timer for force-exiting loading state and position updates
  Timer? _loadingTimeoutTimer;
  Timer? _positionUpdateTimer;
  
  // Reaction system
  bool _isSavingReaction = false;
  String _selectedReaction = '';
  final List<String> _reactionOptions = ['🤔', '🔥', '💡', '📝'];
  
  // Favorite system
  bool _isFavorite = false;
  bool _isSavingFavorite = false;
  
  // Share system
  bool _isSharing = false;
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadUserReaction();
    _checkIfFavorite();
    
    // Set a timeout to exit loading state even if something goes wrong
    _loadingTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        print("Loading timeout exceeded, forcing exit from loading state");
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    // Start a timer to update position manually if needed
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _updatePositionManually();
    });
  }
  
  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
  
  // Manually update position if stream isn't working
  void _updatePositionManually() {
    if (!mounted || _isLoading || _isError) return;
    
    // Get current position directly
    final currentPosition = _audioService.position;
    final currentDuration = _audioService.duration;
    final isPlaying = _audioService.isPlaying;
    
    // Only update if different from current state
    if (currentPosition != _position || isPlaying != _isPlaying || currentDuration != _duration) {
      setState(() {
        _position = currentPosition;
        _isPlaying = isPlaying;
        
        if (currentDuration != null && currentDuration.inMilliseconds > 0) {
          _duration = currentDuration;
          _progress = _position.inMilliseconds / _duration!.inMilliseconds;
          _progress = _progress.clamp(0.0, 1.0);
        } else if (widget.bite.duration > 0) {
          // Fallback to bite duration if player duration isn't available
          final totalDuration = Duration(seconds: widget.bite.duration);
          _duration = totalDuration;
          _progress = _position.inMilliseconds / totalDuration.inMilliseconds;
          _progress = _progress.clamp(0.0, 1.0);
        }
      });
    }
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
  
  Future<void> _shareBite() async {
    if (_isSharing) return;
    
    try {
      setState(() {
        _isSharing = true;
      });
      
      // Use enhanced sharing with audio service and position information
      await _shareService.shareBite(
        context, 
        widget.bite, 
        audioService: _audioService,
        currentPosition: _position,
        totalDuration: _duration ?? Duration(seconds: widget.bite.duration),
      );
    } catch (e) {
      print('Error sharing bite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing content: $e')),
      );
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }
  
  Future<void> _initPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
        _hasAttemptedPlay = false;
      });
      
      print("Initializing player for bite: ${widget.bite.id}");
      print("Audio URL: ${widget.bite.audioUrl}");
      print("Duration in bite model: ${widget.bite.duration} seconds");
      
      // Check if this bite is already playing
      final currentBite = _audioService.currentBite;
      final isAlreadyPlaying = currentBite != null && 
                               currentBite.id == widget.bite.id && 
                               _audioService.isPlaying;
      
      if (isAlreadyPlaying) {
        print("Bite is already playing, not restarting");
        
        // Just set up the UI streams without restarting playback
        setState(() {
          _hasAttemptedPlay = true;
          _isLoading = false;
        });
        
        // Mark as listened (if not already)
        _contentService.markBiteAsListened(widget.bite.id);
        
        // Set up position updates for UI
        _setupStreams();
        
        return;
      }
      
      print("Starting new playback");
      
      // Play the bite (this will restart if it's a different bite or not playing)
      await _audioService.playBite(widget.bite);
      
      // Mark as listened
      _contentService.markBiteAsListened(widget.bite.id);
      
      // Set _hasAttemptedPlay to true since playback has been initiated
      setState(() {
        _hasAttemptedPlay = true;
      });
      
      // Set up streams
      _setupStreams();
      
      // Important: Set loading to false here as a fallback
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isLoading) {
          print("Forcing loading state exit after delay");
          setState(() {
            _isLoading = false;
          });
        }
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
  
  void _setupStreams() {
    // Set up position updates
    _audioService.positionStream.listen((position) {
      if (!mounted) return;
      
      // If we're receiving position updates, audio is playing, so exit loading state
      if (_isLoading && position.inMilliseconds > 0) {
        setState(() {
          _isLoading = false;
        });
      }
      
      final duration = _audioService.duration ?? Duration(seconds: widget.bite.duration);
      if (duration.inMilliseconds > 0) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        setState(() {
          _position = position;
          _progress = progress.clamp(0.0, 1.0);
        });
      }
    }, onError: (error) {
      print("Error from position stream: $error");
    });
    
    // Set up duration updates
    _audioService.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      print("Duration update from stream: $duration");
      setState(() {
        _duration = duration;
        
        // If we got a duration, we can exit loading state
        if (_isLoading && _hasAttemptedPlay) {
          _isLoading = false;
        }
      });
    }, onError: (error) {
      print("Error from duration stream: $error");
    });
    
    // Set up player state updates
    _audioService.playerStateStream.listen((state) {
      if (!mounted) return;
      print("Player state update: $state");
      
      // If we're receiving state updates and have attempted playback, exit loading state
      if (_isLoading && _hasAttemptedPlay) {
        setState(() {
          _isLoading = false;
        });
      }
      
      setState(() {
        _isPlaying = state.playing;
        _isBuffering = state.processingState == ProcessingState.buffering;
      });
    }, onError: (error) {
      print("Error from player state stream: $error");
    });
  }
  
  void _togglePlayPause() {
    print("Toggle play/pause, current state: ${_isPlaying ? 'playing' : 'paused'}");
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.resume();
    }
    
    // Force UI update immediately
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }
  
  void _skipBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _audioService.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }
  
  void _skipForward() {
    final duration = _duration ?? Duration(seconds: widget.bite.duration);
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
            icon: _isSharing 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareBite,
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
                  
                  // Update UI immediately
                  setState(() {
                    _progress = value;
                    _position = position;
                  });
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
                  Text(_formatDuration(_duration ?? Duration(seconds: widget.bite.duration))),
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
            
            const SizedBox(height: 16),
            
            // Share content button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareBite,
                icon: const Icon(Icons.share),
                label: const Text('Share this bite with friends'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}