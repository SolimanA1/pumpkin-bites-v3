import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/share_service.dart';

class ShareHistoryScreen extends StatefulWidget {
  const ShareHistoryScreen({Key? key}) : super(key: key);

  @override
  _ShareHistoryScreenState createState() => _ShareHistoryScreenState();
}

class _ShareHistoryScreenState extends State<ShareHistoryScreen> {
  final ShareService _shareService = ShareService();
  List<Map<String, dynamic>> _shares = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadShareHistory();
  }

  Future<void> _loadShareHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final shares = await _shareService.getShareHistory();
      
      setState(() {
        _shares = shares;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading share history: $e');
      setState(() {
        _errorMessage = 'Failed to load share history: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }
  
  void _navigateToBite(String biteId) {
    // This would navigate to the player screen with the specific bite
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigating to bite: $biteId')),
    );
  }

  Widget _buildShareItem(Map<String, dynamic> share) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(share['biteTitle'] ?? 'Unknown Bite'),
        subtitle: Text('Shared ${_formatTimestamp(share['timestamp'])}'),
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.share, color: Colors.white),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => _navigateToBite(share['biteId']),
        ),
        onTap: () => _navigateToBite(share['biteId']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share History'),
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
                        const Icon(
                          Icons.error_outline,
                          size: 64,
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
                          onPressed: _loadShareHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _shares.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.share,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'You haven\'t shared any bites yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Share content with your friends by tapping the share button on any bite',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadShareHistory,
                      child: ListView.builder(
                        itemCount: _shares.length,
                        itemBuilder: (context, index) {
                          return _buildShareItem(_shares[index]);
                        },
                      ),
                    ),
    );
  }
}