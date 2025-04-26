import 'dart:async';
import 'package:flutter/material.dart';
import 'models/bite_model.dart';
import 'services/audio_player_service.dart';

class FloatingPlayerBar extends StatefulWidget {
  final BiteModel bite;
  final VoidCallback onTap;

  const FloatingPlayerBar({
    Key? key,
    required this.bite,
    required this.onTap,
  }) : super(key: key);

  @override
  State<FloatingPlayerBar> createState() => _FloatingPlayerBarState();
}

class _FloatingPlayerBarState extends State<FloatingPlayerBar> {
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updatePlaybackInfo();
    
    // Set up a timer to update the UI periodically
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updatePlaybackInfo();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _updatePlaybackInfo() {
    if (!mounted) return;
    
    setState(() {
      _isPlaying = _audioService.isPlaying;
      _position = _audioService.position;
      _duration = _audioService.duration ?? Duration(seconds: widget.bite.duration);
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.resume();
    }
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _rewind10Seconds() {
    final newPosition = _position - const Duration(seconds: 10);
    _audioService.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: widget.bite.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          widget.bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 20,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.music_note,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Title and position
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.bite.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Rewind button
              IconButton(
                icon: const Icon(Icons.replay_10, size: 24),
                onPressed: _rewind10Seconds,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              
              // Play/pause button
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: _togglePlayPause,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}