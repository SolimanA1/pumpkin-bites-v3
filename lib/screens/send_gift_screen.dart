import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';
import '../services/gift_service.dart';

class SendGiftScreen extends StatefulWidget {
  const SendGiftScreen({Key? key}) : super(key: key);

  @override
  State<SendGiftScreen> createState() => _SendGiftScreenState();
}

class _SendGiftScreenState extends State<SendGiftScreen> with SingleTickerProviderStateMixin {
  final GiftService _giftService = GiftService();
  final ContentService _contentService = ContentService();
  
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSending = false;
  String _errorMessage = '';
  
  // Episode gift
  List<BiteModel> _availableEpisodes = [];
  BiteModel? _selectedEpisode;
  
  // Membership gift
  int _membershipDuration = 30; // Default 30 days
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEpisodes();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Load all episodes
      final episodes = await _contentService.getAllBites();
      
      if (mounted) {
        setState(() {
          _availableEpisodes = episodes;
          if (episodes.isNotEmpty) {
            _selectedEpisode = episodes[0];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading episodes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load episodes: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _sendGift() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter recipient email')),
      );
      return;
    }
    
    final recipientEmail = _emailController.text.trim();
    final message = _messageController.text.trim();
    
    // Check if it's a valid email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(recipientEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to send a gift');
      }
      
      bool success = false;
      
      // Send gift based on selected tab
      if (_tabController.index == 0) {
        // Episode gift
        if (_selectedEpisode == null) {
          throw Exception('Please select an episode to gift');
        }
        
        await _giftService.sendEpisodeGift(
          senderUid: user.uid,
          recipientEmail: recipientEmail,
          biteId: _selectedEpisode!.id,
          message: message,
        );
        success = true;
      } else {
        // Membership gift
        await _giftService.sendMembershipGift(
          senderUid: user.uid,
          recipientEmail: recipientEmail,
          days: _membershipDuration,
          message: message,
        );
        success = true;
      }
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift sent successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error sending gift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send gift: ${e.toString()}')),
        );
        setState(() {
          _isSending = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Send a Gift',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildGiftForm(),
    );
  }
  
  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Content',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadEpisodes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGiftForm() {
    return Column(
      children: [
        // Gift type tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.headphones),
                text: 'Episode',
              ),
              Tab(
                icon: Icon(Icons.star),
                text: 'Membership',
              ),
            ],
          ),
        ),
        
        // Gift form
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEpisodeGiftForm(),
              _buildMembershipGiftForm(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEpisodeGiftForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Send an Episode as a Gift',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Episode selection
          const Text(
            'Select an Episode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BiteModel>(
                isExpanded: true,
                value: _selectedEpisode,
                items: _availableEpisodes.map((bite) {
                  return DropdownMenuItem<BiteModel>(
                    value: bite,
                    child: Text(
                      bite.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedEpisode = value;
                    });
                  }
                },
              ),
            ),
          ),
          
          // Recipient email
          const SizedBox(height: 24),
          const Text(
            'Recipient Email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Enter recipient email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          
          // Message
          const SizedBox(height: 24),
          const Text(
            'Personal Message (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Add a personal message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
          ),
          
          // Send button
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendGift,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SEND GIFT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMembershipGiftForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Send a Membership as a Gift',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Membership duration
          const Text(
            'Select Membership Duration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDurationOption(30, '1 Month'),
              _buildDurationOption(90, '3 Months'),
              _buildDurationOption(180, '6 Months'),
              _buildDurationOption(365, '1 Year'),
            ],
          ),
          
          // Recipient email
          const SizedBox(height: 24),
          const Text(
            'Recipient Email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Enter recipient email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          
          // Message
          const SizedBox(height: 24),
          const Text(
            'Personal Message (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Add a personal message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
          ),
          
          // Send button
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendGift,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SEND GIFT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDurationOption(int days, String label) {
    final bool isSelected = _membershipDuration == days;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _membershipDuration = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}