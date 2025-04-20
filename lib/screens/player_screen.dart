import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bite_model.dart';

class PlayerScreen extends StatefulWidget {
  final BiteModel bite;
  
  const PlayerScreen({Key? key, required this.bite}) : super(key: key);
  
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _progress = 0.0;
  String _positionText = '0:00';
  String _durationText = '0:00';
  bool _isPlaying = false;
  Timer? _initTimeout;
  bool _isBuffering = false;
  bool _isComplete = false;
  String _reaction = '';
  final List<String> _reactionOptions = ['👍', '❤️', '😊', '🤔', '😢'];

  @override
  void initState() {
    super.initState();
    print("PlayerScreen initialized with bite: ${widget.bite.id}");
    print("Audio URL: ${widget.bite.audioUrl}");
    
    // Set a timeout for audio initialization
    _initTimeout = Timer(const Duration(seconds: 10), () {
      if (_isLoading) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Audio loading timeout - please check your connection';
        });
      }
    });
    
    _initAudio();
    _loadUserReaction();
  }
  
  Future<void> _loadUserReaction() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final reactionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reactions')
          .doc(widget.bite.id)
          .get();
      
      if (reactionDoc.exists && reactionDoc.data() != null) {
        setState(() {
          _reaction = reactionDoc.data()?['reaction'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user reaction: $e');
    }
  }
  
  Future<void> _initAudio() async {
    try {
      print("Initializing audio player");
      
      // Prepare multiple fallback URLs
      final audioUrls = [
        widget.bite.audioUrl.trim(),
        'https://samplelib.com/lib/preview/mp3/sample-3s.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ];
      
      bool loaded = false;
      String lastError = '';
      
      // Try each URL until one works
      for (final url in audioUrls) {
        try {
          print("Trying to load audio from URL: '$url'");
          
          if (url.isEmpty) {
            print("Empty URL, skipping");
            continue;
          }
          
          // Set the audio source
          await _player.setUrl(url);
          
          // If we get here, it worked!
          print("Audio loaded successfully from: $url");
          loaded = true;
          break;
        } catch (e) {
          lastError = e.toString();
          print("Failed to load from $url: $e");
          // Continue to the next URL
        }
      }
      
      if (!loaded) {
        throw Exception("Could not load audio from any URL. Last error: $lastError");
      }
      
      // Set up position and state listeners
      _player.positionStream.listen((position) {
        if (!mounted) return;
        
        final duration = _player.duration ?? Duration.zero;
        
        setState(() {
          _progress = duration.inMilliseconds > 0 
              ? position.inMilliseconds / duration.inMilliseconds 
              : 0.0;
          _positionText = _formatDuration(position);
          _durationText = _formatDuration(duration);
        });
      });
      
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.buffering;
          _isComplete = state.processingState == ProcessingState.completed;
          
          if (_isComplete) {
            _markBiteAsListened();
          }
        });
      });
      
      // Start playing automatically
      await _player.play();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR initializing audio: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Could not load audio: ${e.toString().substring(0, min(100, e.toString().length))}';
      });
    } finally {
      // Cancel timeout
      _initTimeout?.cancel();
    }
  }
  
  int min(int a, int b) => a < b ? a : b;
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  Future<void> _markBiteAsListened() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      // Add to listened bites
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'listenedBites': FieldValue.arrayUnion([widget.bite.id]),
      });
      
      print('Marked bite as listened: ${widget.bite.id}');
    } catch (e) {
      print('Error marking bite as listened: $e');
    }
  }
  
  Future<void> _saveReaction(String reaction) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      // Save reaction
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reactions')
          .doc(widget.bite.id)
          .set({
        'reaction': reaction,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _reaction = reaction;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction saved: $reaction')),
      );
    } catch (e) {
      print('Error saving reaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save reaction: $e')),
      );
    }
  }
  
  @override
  void dispose() {
    _player.dispose();
    _initTimeout?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bite.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _hasError 
          ? _buildErrorView() 
          : _isLoading 
              ? _buildLoadingView() 
              : _buildPlayerView(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 72,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Playing Content',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _initAudio();
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading ${widget.bite.title}...',
            textAlign: TextAlign.center,
          ),
        ],
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
            // Thumbnail
            if (widget.bite.thumbnailUrl.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(widget.bite.thumbnailUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              widget.bite.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              widget.bite.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            
            // Player Controls
            _buildPlayerControls(),
            const SizedBox(height: 32),
            
            // Reactions
            _buildReactionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Column(
      children: [
        // Progress bar
        Slider(
          value: _progress,
          onChanged: (value) {
            if (_player.duration != null) {
              final position = Duration(
                milliseconds: (value * _player.duration!.inMilliseconds).round(),
              );
              _player.seek(position);
            }
          },
        ),
        
        // Position and duration text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_positionText),
            Text(_durationText),
          ],
        ),
        const SizedBox(height: 16),
        
        // Play/pause and other controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                if (_player.position.inSeconds >= 10) {
                  _player.seek(_player.position - const Duration(seconds: 10));
                } else {
                  _player.seek(Duration.zero);
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 64,
              icon: Icon(
                _isBuffering 
                    ? Icons.hourglass_top
                    : _isPlaying 
                        ? Icons.pause_circle_filled 
                        : Icons.play_circle_filled,
              ),
              onPressed: _isBuffering 
                  ? null 
                  : () {
                      if (_isPlaying) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.forward_30),
              onPressed: () {
                if (_player.duration != null) {
                  final newPosition = _player.position + const Duration(seconds: 30);
                  if (newPosition < _player.duration!) {
                    _player.seek(newPosition);
                  } else {
                    _player.seek(_player.duration!);
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildReactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How did you feel about this content?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Reaction options
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _reactionOptions.map((emoji) {
            return GestureDetector(
              onTap: () => _saveReaction(emoji),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _reaction == emoji 
                      ? Theme.of(context).primaryColor.withOpacity(0.2) 
                      : Colors.transparent,
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}