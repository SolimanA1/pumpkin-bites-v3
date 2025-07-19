import 'package:flutter/material.dart';
import 'models/bite_model.dart';
import 'services/audio_player_service.dart';

class FloatingPlayerBar extends StatefulWidget {
  final BiteModel bite;
  final VoidCallback onTap;
  final AudioPlayerService audioService;

  const FloatingPlayerBar({
    Key? key,
    required this.bite,
    required this.onTap,
    required this.audioService,
  }) : super(key: key);

  @override
  State<FloatingPlayerBar> createState() => _FloatingPlayerBarState();
}

class _FloatingPlayerBarState extends State<FloatingPlayerBar> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.audioService.isPlaying;
    _position = widget.audioService.position;
    _duration = widget.audioService.duration ?? Duration(seconds: widget.bite.duration);
    
    
    // Subscribe to position updates
    widget.audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    
    // Subscribe to player state changes
    widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  void _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await widget.audioService.pause();
      } else {
        await widget.audioService.resume();
      }
    } catch (e) {
      // Handle error silently or show user-friendly message
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: kBottomNavigationBarHeight + bottomPadding + 8, // iOS safe area support
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8.0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8.0),
            child: SizedBox(
              height: 64.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: widget.bite.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                widget.bite.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, e, s) => Container(
                                  color: Colors.orange.shade100,
                                  child: Icon(Icons.music_note, color: Colors.orange.shade400),
                                ),
                              )
                            : Container(
                                color: Colors.orange.shade100,
                                child: Icon(Icons.music_note, color: Colors.orange.shade400),
                              ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Title and progress
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
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Rewind button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final newPosition = _position - const Duration(seconds: 10);
                          widget.audioService.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.replay_10,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 4),
                    
                    // Play/Pause button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _togglePlayPause,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 32,
                            color: const Color(0xFFF56500), // Pumpkin orange
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}