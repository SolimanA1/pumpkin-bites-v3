import 'package:flutter/material.dart';
import 'package:pumpkin_bites_new/services/subscription_service.dart';
import 'package:pumpkin_bites_new/screens/subscription_screen.dart';

class SubscriptionGate extends StatelessWidget {
  final Widget child;
  final String? customMessage;
  
  const SubscriptionGate({
    Key? key,
    required this.child,
    this.customMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();
    
    return StreamBuilder<bool>(
      stream: subscriptionService.subscriptionStatusStream,
      initialData: subscriptionService.hasContentAccess,
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        
        if (hasAccess || subscriptionService.hasContentAccess) {
          return child;
        } else {
          return _buildSubscriptionWall(context);
        }
      },
    );
  }

  Widget _buildSubscriptionWall(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: Color(0xFFF56500),
          ),
          const SizedBox(height: 24),
          
          Text(
            customMessage ?? 'The Good Stuff Awaits',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          const Text(
            'Your free taste is over! Ready to keep the wisdom flowing? We promise it\'s worth it.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _navigateToSubscription(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF56500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Let\'s Do This – \$2.99/month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => _navigateToSubscription(context),
            child: const Text(
              'Tell Me More',
              style: TextStyle(
                color: Color(0xFFF56500),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(isFromTrialExpiration: true),
      ),
    );
  }
}

class TrialStatusWidget extends StatelessWidget {
  const TrialStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();
    
    return StreamBuilder<int>(
      stream: subscriptionService.trialDaysRemainingStream,
      initialData: subscriptionService.trialDaysRemaining,
      builder: (context, snapshot) {
        final daysRemaining = snapshot.data ?? 0;
        
        if (!subscriptionService.isInTrialPeriod || subscriptionService.isSubscriptionActive) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF56500), Color(0xFFFF8A50)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF56500).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  daysRemaining > 0 
                    ? 'Free wisdom for $daysRemaining more ${daysRemaining == 1 ? 'day' : 'days'}'
                    : 'Last chance for free wisdom!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigateToSubscription(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Keep Going',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSubscription(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
      ),
    );
  }
}