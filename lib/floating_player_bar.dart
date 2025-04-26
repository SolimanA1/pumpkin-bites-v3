import 'package:flutter/material.dart';
import 'models/bite_model.dart';
import 'services/audio_player_service.dart';

class FloatingPlayerBar extends StatefulWidget {
  final BiteModel bite;
  final Function onTap;
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
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateState();
    
    // Listen for changes in playback state
    widget.audioService.playerStateStream.listen((_) {
      if (mounted) {
        _updateState();
      }
    });
    
    // Listen for position changes
    widget.audioService.positionStream.listen((_) {
      if (mounted) {
        _updateState();
      }
    });
  }

  void _updateState() {
    final duration = widget.audioService.duration ??
        Duration(seconds: widget.bite.duration);
    final position = widget.audioService.position;
    
    setState(() {
      _isPlaying = widget.audioService.isPlaying;
      if (duration.inMilliseconds > 0) {
        _progress = position.inMilliseconds / duration.inMilliseconds;
        _progress = _progress.clamp(0.0, 1.0);
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.audioService.pause();
    } else {
      widget.audioService.resume();
    }
    
    // Immediately update UI state
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap(),
      child: Container(
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
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
              padding: EdgeInsets.zero,
              onPressed: _togglePlayPause,
            ),
            const SizedBox(width: 8),
            
            // Bite title and progress bar
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
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Close button
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                widget.audioService.stop();
              },
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}