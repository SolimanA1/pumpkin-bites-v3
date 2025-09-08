import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/share_service.dart';
import '../services/content_service.dart';

class ShareHistoryScreen extends StatefulWidget {
  const ShareHistoryScreen({Key? key}) : super(key: key);

  @override
  _ShareHistoryScreenState createState() => _ShareHistoryScreenState();
}

class _ShareHistoryScreenState extends State<ShareHistoryScreen> {
  final ShareService _shareService = ShareService();
  final ContentService _contentService = ContentService();
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
  
  String _formatSnippetDetails(Map<String, dynamic> share) {
    final snippetStart = share['snippetStart'];
    final snippetDuration = share['snippetDuration'];
    
    if (snippetStart != null && snippetDuration != null) {
      final startMinutes = (snippetStart / 60).floor();
      final startSeconds = (snippetStart % 60).floor();
      final startFormatted = "${startMinutes.toString().padLeft(2, '0')}:${startSeconds.toString().padLeft(2, '0')}";
      
      return "$snippetDuration second snippet starting at $startFormatted";
    }
    
    return "Full content";
  }
  
  void _navigateToBite(String biteId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Get the bite details
      final bite = await _contentService.getBiteById(biteId);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (bite != null) {
        // Navigate to player screen
        Navigator.of(context).pushNamed('/player', arguments: bite);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content not found')),
        );
      }
    } catch (e) {
      // Close loading dialog in case of error
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildShareItem(Map<String, dynamic> share) {
    final hasPersonalMessage = share['message'] != null && share['message'].toString().isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and timestamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Color(0xFF8B0000)),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share['biteTitle'] ?? 'Unknown Bite',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shared ${_formatTimestamp(share['timestamp'])}',
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
            
            // Snippet details if available
            if (share['snippetStart'] != null && share['snippetDuration'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.content_cut, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatSnippetDetails(share),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Personal message if available
            if (hasPersonalMessage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B0000).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your message:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      share['message'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Play button
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToBite(share['biteId']),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                ),
              ),
            ),
          ],
        ),
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