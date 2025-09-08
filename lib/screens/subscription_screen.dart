import 'package:flutter/material.dart';
import 'package:pumpkin_bites_new/services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isFromTrialExpiration;
  
  const SubscriptionScreen({
    Key? key,
    this.isFromTrialExpiration = false,
  }) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isFromTrialExpiration 
          ? null 
          : IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
              onPressed: () => Navigator.pop(context),
            ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Header
            const Icon(
              Icons.auto_stories,
              size: 80,
              color: Color(0xFF8B0000),
            ),
            const SizedBox(height: 20),
            
            Text(
              widget.isFromTrialExpiration 
                ? 'Ready for More Wisdom?' 
                : 'Unlock Your Daily Dose',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            Text(
              widget.isFromTrialExpiration
                ? 'Your free taste is over, but the feast is just beginning. Keep the wisdom flowing!'
                : 'Bite-sized wisdom delivered daily. No fluff, just the good stuff.',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Features list
            _buildFeaturesList(),
            const SizedBox(height: 40),
            
            // Pricing card
            _buildPricingCard(),
            const SizedBox(height: 30),
            
            // Subscribe button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Keep the Wisdom Coming – \$2.99/month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Restore purchases button
            TextButton(
              onPressed: _isLoading ? null : _handleRestorePurchases,
              child: const Text(
                'Restore Purchases',
                style: TextStyle(
                  color: Color(0xFF8B0000),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Terms and privacy
            Text(
              'Renews monthly unless you change your mind. Manage everything in your App Store settings.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'All the wisdom, all the time',
      'Fresh insights served daily',
      'Listen anywhere, even offline',
      'Zero interruptions, pure content',
      'Share the good stuff with loved ones',
      'Crystal-clear audio that actually sounds nice',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: features
            .map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF8B0000),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B0000),
            Color(0xFFB71C1C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Daily Wisdom Delivered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '\$2.99',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'per month',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.isFromTrialExpiration)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Free week to try it out',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _subscriptionService.purchaseSubscription();
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated successfully!'),
              backgroundColor: Color(0xFF8B0000),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hmm, something didn\'t work quite right. Mind giving it another try?'),
              backgroundColor: Color(0xFF8B0000),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! We hit a little snag. Let\'s try that again in a moment.'),
            backgroundColor: Color(0xFF8B0000),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _subscriptionService.restorePurchases();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully!'),
            backgroundColor: Color(0xFF8B0000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t find your previous purchase right now. Try again in a bit!'),
            backgroundColor: Color(0xFF8B0000),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}