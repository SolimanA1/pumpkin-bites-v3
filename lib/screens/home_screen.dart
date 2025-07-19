import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContentService _contentService = ContentService();
  BiteModel? _todaysBite;
  List<BiteModel> _catchUpBites = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  
  // Sequential release system variables
  bool _isTodaysBiteUnlocked = false;
  DateTime? _nextUnlockTime;
  Duration _timeUntilUnlock = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _startContentRefreshTimer();
    _startCountdownTimer();
  }

  void _startContentRefreshTimer() {
    // Refresh content every 30 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _refreshContent();
    });
  }
  
  void _startCountdownTimer() {
    // Update countdown every second for unlock timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextUnlockTime != null) {
        final now = DateTime.now();
        final difference = _nextUnlockTime!.difference(now);
        
        if (difference.isNegative) {
          // Time to unlock! Refresh content
          setState(() {
            _isTodaysBiteUnlocked = true;
            _timeUntilUnlock = Duration.zero;
          });
          _refreshContent();
        } else {
          setState(() {
            _timeUntilUnlock = difference;
          });
        }
      }
    });
  }

  Future<void> _refreshContent() async {
    if (_isRefreshing) return;

    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final todaysBite = await _contentService.getTodaysBite();
      final catchUpBites = await _contentService.getCatchUpBites();

      // Simulate sequential release logic
      final now = DateTime.now();
      final unlockHour = 9; // 9 AM unlock time
      final todayUnlockTime = DateTime(now.year, now.month, now.day, unlockHour);
      
      bool isUnlocked = now.isAfter(todayUnlockTime);
      DateTime? nextUnlock;
      
      if (!isUnlocked) {
        nextUnlock = todayUnlockTime;
      }

      setState(() {
        _todaysBite = todaysBite;
        _catchUpBites = catchUpBites;
        _isTodaysBiteUnlocked = isUnlocked;
        _nextUnlockTime = nextUnlock;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final todaysBite = await _contentService.getTodaysBite();
      final catchUpBites = await _contentService.getCatchUpBites();

      // Initialize sequential release logic
      final now = DateTime.now();
      final unlockHour = 9; // 9 AM unlock time
      final todayUnlockTime = DateTime(now.year, now.month, now.day, unlockHour);
      
      bool isUnlocked = now.isAfter(todayUnlockTime);
      DateTime? nextUnlock;
      
      if (!isUnlocked) {
        nextUnlock = todayUnlockTime;
      }

      setState(() {
        _todaysBite = todaysBite;
        _catchUpBites = catchUpBites;
        _isTodaysBiteUnlocked = isUnlocked;
        _nextUnlockTime = nextUnlock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load content';
        _isLoading = false;
      });
    }
  }

  void _navigateToPlayer(BiteModel bite) {
    // Always navigate to player without any premium checks
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  void _navigateToLibrary() {
    Navigator.of(context).pushNamed('/library');
  }


  Widget _buildTodaysBiteSection() {
    if (_todaysBite == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Today\'s Bite',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No content available for today. Check back later!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Main content
          InkWell(
            onTap: _isTodaysBiteUnlocked ? () => _navigateToPlayer(_todaysBite!) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with unlock status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTodaysBiteUnlocked 
                          ? [const Color(0xFFF56500), const Color(0xFFFFB366)]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DAY',
                          style: TextStyle(
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _todaysBite!.dayNumber.toString(),
                          style: TextStyle(
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _isTodaysBiteUnlocked ? 'TODAY\'S BITE' : 'COMING SOON',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (!_isTodaysBiteUnlocked && _timeUntilUnlock.inSeconds > 0)
                            Text(
                              'Unlocks in ${_formatDuration(_timeUntilUnlock)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Thumbnail with lock overlay
                AspectRatio(
                  aspectRatio: 16 / 10, // Slightly taller as requested
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _todaysBite!.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              _todaysBite!.thumbnailUrl,
                              fit: BoxFit.cover,
                              color: _isTodaysBiteUnlocked ? null : Colors.grey,
                              colorBlendMode: _isTodaysBiteUnlocked ? null : BlendMode.saturation,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                      
                      // Lock overlay
                      if (!_isTodaysBiteUnlocked)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                if (_timeUntilUnlock.inSeconds > 0)
                                  Text(
                                    'Unlocks in\n${_formatDuration(_timeUntilUnlock)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      
                      // "NEW" badge for unlocked content
                      if (_isTodaysBiteUnlocked)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF56500),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todaysBite!.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _isTodaysBiteUnlocked ? Colors.black : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isTodaysBiteUnlocked 
                            ? _todaysBite!.description
                            : 'This bite will be available soon. Get ready for some fresh wisdom!',
                        style: TextStyle(
                          color: _isTodaysBiteUnlocked ? Colors.grey : Colors.grey.shade500,
                          fontSize: 16,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _todaysBite!.formattedDuration,
                            style: TextStyle(
                              color: _isTodaysBiteUnlocked 
                                  ? const Color(0xFFF56500) 
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _isTodaysBiteUnlocked ? () => _navigateToPlayer(_todaysBite!) : null,
                            icon: Icon(_isTodaysBiteUnlocked ? Icons.play_circle_filled : Icons.lock),
                            label: Text(_isTodaysBiteUnlocked ? 'PLAY NOW' : 'LOCKED'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTodaysBiteUnlocked 
                                  ? const Color(0xFFF56500) 
                                  : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFreshBitesWaitingSection() {
    if (_catchUpBites.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no catch-up bites
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🍂 Fresh Bites Waiting',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Catch up on ${_catchUpBites.length} missed ${_catchUpBites.length == 1 ? 'bite' : 'bites'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _navigateToLibrary,
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
        ),
        
        // Vertical list of catch-up bites (much better UX!)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _catchUpBites.length.clamp(0, 3), // Show max 3
          itemBuilder: (context, index) {
            final bite = _catchUpBites[index];
            return _buildCatchUpCard(bite);
          },
        ),
      ],
    );
  }

  Widget _buildCatchUpCard(BiteModel bite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToPlayer(bite),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: bite.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          bite.thumbnailUrl,
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
                      bite.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF56500).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DAY ${bite.dayNumber}',
                            style: const TextStyle(
                              color: Color(0xFFF56500),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bite.formattedDuration,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Play button
              IconButton(
                onPressed: () => _navigateToPlayer(bite),
                icon: const Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFFF56500),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${twoDigits(minutes)}m';
    } else if (minutes > 0) {
      return '${minutes}m ${twoDigits(seconds)}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pumpkin Bites'),
        actions: [
          // Notification icon (can be implemented later)
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContent,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshContent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      _buildTodaysBiteSection(),
                      _buildFreshBitesWaitingSection(),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}