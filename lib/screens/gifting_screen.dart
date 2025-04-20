import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../services/gift_service.dart';
import '../services/content_service.dart';

class GiftingScreen extends StatefulWidget {
  const GiftingScreen({Key? key}) : super(key: key);

  @override
  _GiftingScreenState createState() => _GiftingScreenState();
}

class _GiftingScreenState extends State<GiftingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GiftService _giftService = GiftService();
  final ContentService _contentService = ContentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _receivedGifts = [];
  List<Map<String, dynamic>> _sentGifts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get received gifts
      final receivedGifts = await _giftService.getReceivedGifts();
      
      // Get sent gifts
      final sentGifts = await _giftService.getSentGifts();

      // Debug info
      print('Received gifts: ${receivedGifts.length}');
      print('Sent gifts: ${sentGifts.length}');

      setState(() {
        _receivedGifts = receivedGifts;
        _sentGifts = sentGifts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading gifts: $e');
      setState(() {
        _error = 'Failed to load gifts: $e';
        _isLoading = false;
      });
    }
  }

  Future<BiteModel?> _getBiteDetails(String biteId) async {
    try {
      return await _contentService.getBiteById(biteId);
    } catch (e) {
      print('Error getting bite details: $e');
      return null;
    }
  }

  Widget _buildGiftItem(Map<String, dynamic> gift, bool isReceived) {
    final String giftType = gift['type'] ?? 'unknown';
    final String status = gift['status'] ?? 'unknown';
    final String senderName = gift['senderName'] ?? 'Someone';
    final Timestamp? timestamp = isReceived 
        ? (gift['receivedAt'] as Timestamp?) ?? (gift['sentAt'] as Timestamp?)
        : gift['sentAt'] as Timestamp?;
    final String dateText = timestamp != null 
        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
        : 'Date unknown';
    final String recipientName = gift['recipientName'] ?? 'Someone';
    final String biteId = gift['biteId'] ?? '';
    final String biteTitle = gift['biteTitle'] ?? 'Unknown content';
    
    // Extract message if available
    final String message = gift['message'] ?? 'Enjoy this content!';
    
    // Determine which name to display based on whether viewing sent or received
    final String displayName = isReceived ? 'From: $senderName' : 'To: $recipientName';
    
    // Determine icon and color based on gift type
    IconData typeIcon = Icons.card_giftcard;
    Color statusColor = Colors.grey;
    
    if (giftType == 'episode') {
      typeIcon = Icons.headphones;
    } else if (giftType == 'membership') {
      typeIcon = Icons.star;
    }
    
    // Determine color based on status
    if (status == 'pending') {
      statusColor = Colors.orange;
    } else if (status == 'accepted') {
      statusColor = Colors.green;
    } else if (status == 'awaiting_registration') {
      statusColor = Colors.blue;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    biteTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(displayName, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(dateText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'Message: $message',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftsList(List<Map<String, dynamic>> gifts, bool isReceived) {
    if (gifts.isEmpty) {
      return Center(
        child: Text(
          isReceived ? 'No gifts received yet' : 'No gifts sent yet',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGifts,
      child: ListView.builder(
        itemCount: gifts.length,
        itemBuilder: (context, index) {
          return _buildGiftItem(gifts[index], isReceived);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifts & Sharing'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadGifts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGiftsList(_receivedGifts, true),
                    _buildGiftsList(_sentGifts, false),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/send_gift');
        },
        icon: const Icon(Icons.card_giftcard),
        label: const Text('Send Gift'),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}