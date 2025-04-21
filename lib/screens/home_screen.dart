import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isPremium = true; // Always set to true to allow access to all content

  @override
  void initState() {
    super.initState();
    _loadContent();
    _startContentRefreshTimer();
  }

  void _startContentRefreshTimer() {
    // Refresh content every 30 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _refreshContent();
    });
  }

  Future<void> _refreshContent() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final todaysBite = await _contentService.getTodaysBite();
      final catchUpBites = await _contentService.getCatchUpBites();

      setState(() {
        _todaysBite = todaysBite;
        _catchUpBites = catchUpBites;
        _isRefreshing = false;
      });
    } catch (e) {
      print('Error refreshing content: $e');
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

      setState(() {
        _todaysBite = todaysBite;
        _catchUpBites = catchUpBites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load content: $e';
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

  void _navigateToDinnerTable() {
    Navigator.of(context).pushNamed('/dinner_table');
  }

  void _navigateToProfile() {
    Navigator.of(context).pushNamed('/profile');
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
      child: InkWell(
        onTap: () => _navigateToPlayer(_todaysBite!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor,
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
                        color: Theme.of(context).primaryColor,
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
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'TODAY\'S BITE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _todaysBite!.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      _todaysBite!.thumbnailUrl,
                      fit: BoxFit.cover,
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
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todaysBite!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _todaysBite!.description,
                    style: const TextStyle(
                      color: Colors.grey,
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
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _todaysBite!.formattedDuration,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToPlayer(_todaysBite!),
                        icon: const Icon(Icons.play_circle_filled),
                        label: const Text('PLAY NOW'),
                        style: ElevatedButton.styleFrom(
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
    );
  }

  Widget _buildCatchUpSection() {
    if (_catchUpBites.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Catch Up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'No catch-up content available. Check back later!',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Catch Up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _navigateToLibrary,
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _catchUpBites.length,
            itemBuilder: (context, index) {
              final bite = _catchUpBites[index];
              return _buildCatchUpCard(bite);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCatchUpCard(BiteModel bite) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _navigateToPlayer(bite),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day badge
              Stack(
                children: [
                  // Thumbnail
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: bite.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            bite.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 24,
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
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  
                  // Day badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DAY ${bite.dayNumber.toString()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  // Duration badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        bite.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
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
                    Text(
                      bite.category,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                    children: [
                      _buildTodaysBiteSection(),
                      _buildCatchUpSection(),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}