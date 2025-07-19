import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bite_model.dart';
import '../services/audio_player_service.dart';
import '../services/share_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShareDialog extends StatefulWidget {
  final BiteModel bite;
  final AudioPlayerService audioService;
  final Duration currentPosition;
  final Duration? totalDuration;

  const ShareDialog({
    Key? key,
    required this.bite,
    required this.audioService,
    required this.currentPosition,
    required this.totalDuration,
  }) : super(key: key);

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ShareService _shareService = ShareService();
  
  // Default snippet duration is 30 seconds
  double _snippetDuration = 30.0;
  // Starting position for the snippet (in seconds)
  double _startPosition = 0.0;
  
  // Maximum allowed snippet duration (60 seconds)
  final double _maxSnippetDuration = 60.0;
  
  bool _isSharing = false;
  bool _isPreviewing = false;
  bool _isInstagramAvailable = false;
  Timer? _previewTimer;
  
  @override
  void initState() {
    super.initState();
    _initializePositionAndDuration();
    _checkInstagramAvailability();
  }
  
  Future<void> _checkInstagramAvailability() async {
    final isAvailable = await _shareService.isInstagramAvailable();
    if (mounted) {
      setState(() {
        _isInstagramAvailable = isAvailable;
      });
    }
  }
  
  void _initializePositionAndDuration() {
    // Get the total duration in seconds, default to 5 minutes if not available
    // This ensures we're ready for production clips
    final double totalDurationSeconds = widget.totalDuration?.inSeconds.toDouble() ?? 300.0;
    
    // Initialize start position to current playback position
    _startPosition = widget.currentPosition.inSeconds.toDouble();
    
    // Make sure start position is within bounds
    if (_startPosition < 0) {
      _startPosition = 0.0;
    } else if (_startPosition > totalDurationSeconds - 30) {
      // Don't start a snippet in the last 30 seconds of content
      _startPosition = totalDurationSeconds > 30 ? totalDurationSeconds - 30 : 0.0;
    }
    
    // Keep the default snippet duration at 30 seconds for production-length clips
    // But make sure it doesn't extend beyond the end of the audio
    if (_startPosition + _snippetDuration > totalDurationSeconds) {
      if (totalDurationSeconds >= 30) {
        // If total duration is at least 30 seconds, keep snippet at 30 seconds
        // and adjust the start position
        _startPosition = totalDurationSeconds - 30;
      } else {
        // For very short clips, use the entire clip
        _snippetDuration = totalDurationSeconds;
        _startPosition = 0;
      }
    }
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _previewTimer?.cancel();
    super.dispose();
  }
  
  String _formatDuration(double seconds) {
    final Duration duration = Duration(seconds: seconds.round());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  double get _maxStartPosition {
    final totalDurationSeconds = widget.totalDuration?.inSeconds.toDouble() ?? 300.0;
    
    // Cannot start a snippet so late that it exceeds the audio duration
    final maxPos = totalDurationSeconds - _snippetDuration;
    return maxPos < 0 ? 0 : maxPos;
  }
  
  double get _snippetEndPosition {
    final totalDurationSeconds = widget.totalDuration?.inSeconds.toDouble() ?? 300.0;
    final endPos = _startPosition + _snippetDuration;
    return endPos > totalDurationSeconds ? totalDurationSeconds : endPos;
  }
  
  // Track the share in analytics
  Future<void> _trackShare(String biteId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the user's share count
      await _firestore.collection('users').doc(user.uid).update({
        'shares': FieldValue.increment(1),
      });
      
      // Add to share history with the snippet information
      await _firestore.collection('users').doc(user.uid).collection('shares').add({
        'biteId': biteId,
        'biteTitle': widget.bite.title,
        'timestamp': FieldValue.serverTimestamp(),
        'snippetStart': _startPosition,
        'snippetDuration': _snippetDuration,
        'message': _commentController.text.trim(),
      });
      
      // Update the bite's share count
      await _firestore.collection('bites').doc(biteId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking share: $e');
    }
  }
  
  Future<void> _shareSnippet() async {
    if (_isSharing) return;
    
    setState(() {
      _isSharing = true;
    });
    
    try {
      // Generate a deep link for the bite with snippet information
      final deepLink = await _generateDeepLink(
        widget.bite.id, 
        _startPosition.round(),
        _snippetDuration.round()
      );
      
      // Create a message to share
      final message = _createShareMessage(widget.bite, deepLink);
      
      // Use the Share.share from share_plus package
      await Share.share(message, subject: 'Check out this bite from Pumpkin Bites!');
      
      // Track the share in analytics
      await _trackShare(widget.bite.id);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      print('Error sharing bite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share content: $e')),
        );
        Navigator.of(context).pop(false); // Return failure
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }
  
  Future<void> _shareToInstagramStories() async {
    if (_isSharing) return;
    
    setState(() {
      _isSharing = true;
    });
    
    try {
      await _shareService.shareToInstagramStories(
        context,
        widget.bite,
        personalComment: _commentController.text.trim(),
        snippetDuration: _snippetDuration.round(),
      );
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      print('Error sharing to Instagram Stories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share to Instagram Stories: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }
  
  // Generate a deep link to the specific bite with snippet information
  Future<String> _generateDeepLink(String biteId, int startSeconds, int durationSeconds) async {
    // For now, we'll use a simple URL format
    // In a production app, you would use Firebase Dynamic Links or a similar service
    return 'https://pumpkinbites.app/bite/$biteId?start=$startSeconds&duration=$durationSeconds';
  }
  
  // Create a share message based on the bite content
  String _createShareMessage(BiteModel bite, String deepLink) {
    final personalComment = _commentController.text.trim();
    final personalNote = personalComment.isNotEmpty 
        ? "Here's what I think: $personalComment\n\n" 
        : "";
        
    return '''
I just listened to "${bite.title}" on Pumpkin Bites and thought you might enjoy it too!

$personalNote${bite.description}

Check out this ${_snippetDuration.round()}-second snippet: $deepLink
''';
  }
  
  // Preview the selected snippet with automatic stop
  void _previewSnippet() {
    // Cancel any existing preview timer
    _previewTimer?.cancel();
    
    // Calculate the end time of the snippet
    final startPosition = Duration(seconds: _startPosition.round());
    final endPosition = Duration(seconds: (_startPosition + _snippetDuration).round());
    
    // Start playing from the beginning of the snippet
    widget.audioService.seekTo(startPosition);
    widget.audioService.resume();
    
    setState(() {
      _isPreviewing = true;
    });
    
    // Calculate how long to play
    final playDuration = Duration(seconds: _snippetDuration.round());
    
    // Set a timer to stop playback after snippet duration
    _previewTimer = Timer(playDuration, () {
      if (mounted) {
        widget.audioService.pause();
        setState(() {
          _isPreviewing = false;
        });
      }
    });
    
    // Show a snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing ${_snippetDuration.round()} second preview...'),
        duration: playDuration,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final totalDurationSeconds = widget.totalDuration?.inSeconds.toDouble() ?? 300.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.share, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Share a Snippet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            
            // Bite information
            Text(
              widget.bite.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a snippet (${_formatDuration(_snippetDuration)} seconds)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            // Snippet duration slider
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Snippet length:'),
                Text('${_snippetDuration.round()} seconds'),
              ],
            ),
            Slider(
              value: _snippetDuration,
              min: 5.0, // Minimum 5 seconds
              max: _maxSnippetDuration, // Maximum 60 seconds
              divisions: 11, // 5-second increments
              label: "${_snippetDuration.round()} sec",
              onChanged: (value) {
                setState(() {
                  _snippetDuration = value;
                  // Adjust start position if needed
                  if (_startPosition > _maxStartPosition) {
                    _startPosition = _maxStartPosition;
                  }
                });
              },
            ),
            
            // Starting position slider
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Starting from:'),
                Text(_formatDuration(_startPosition)),
              ],
            ),
            Slider(
              value: _startPosition,
              min: 0,
              max: _maxStartPosition,
              divisions: totalDurationSeconds > 60 ? (totalDurationSeconds ~/ 5).clamp(1, 60) : 1,
              label: _formatDuration(_startPosition),
              onChanged: (value) {
                setState(() {
                  _startPosition = value;
                });
              },
            ),
            
            // Current selection display
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('From: ${_formatDuration(_startPosition)}'),
                  Text('To: ${_formatDuration(_snippetEndPosition)}'),
                ],
              ),
            ),
            
            // Preview button
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: Icon(_isPreviewing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                label: Text(_isPreviewing ? 'Stop Preview' : 'Preview Snippet'),
                onPressed: _isPreviewing 
                    ? () {
                        _previewTimer?.cancel();
                        widget.audioService.pause();
                        setState(() {
                          _isPreviewing = false;
                        });
                      }
                    : _previewSnippet,
              ),
            ),
            
            // Personal comment
            const SizedBox(height: 16),
            const Text(
              'Add a personal comment (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80, // Fixed height for iOS compatibility
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'What did you think about this bite?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
                maxLength: 280, // Twitter-like character limit
                expands: false,
              ),
            ),
            
            // Share buttons
            const SizedBox(height: 16),
            Column(
              children: [
                // Instagram Stories button (if available)
                if (_isInstagramAvailable) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _shareToInstagramStories,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text(
                        'SHARE TO INSTAGRAM STORIES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE4405F), // Instagram pink
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Regular share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSharing ? null : _shareSnippet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSharing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SHARE SNIPPET',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}