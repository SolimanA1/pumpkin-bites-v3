import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  TimeOfDay _selectedUnlockTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isSettingTime = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      print('🎉 DEBUG: Completing onboarding...');
      
      setState(() {
        _isSettingTime = true;
      });

      // Save unlock time to user preferences
      final user = FirebaseAuth.instance.currentUser;
      print('🎉 DEBUG: Current user: ${user?.uid}');
      
      if (user != null) {
        print('🎉 DEBUG: Updating user document with onboarding completion...');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'unlockHour': _selectedUnlockTime.hour,
          'unlockMinute': _selectedUnlockTime.minute,
          'hasCompletedOnboarding': true,
        });
        print('🎉 DEBUG: User document updated successfully - hasCompletedOnboarding set to true for user ${user.uid}');
        
        // Verify it was saved by reading back
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final verified = userDoc.data()?['hasCompletedOnboarding'] ?? false;
        print('🎉 DEBUG: Verified hasCompletedOnboarding in Firestore: $verified');
      } else {
        print('🚨 DEBUG: No authenticated user found during onboarding completion!');
        return; // Cannot complete onboarding without user
      }

      // REMOVED: No longer using SharedPreferences for onboarding flag
      // All onboarding state is now user-specific in Firestore

      // Trigger app state refresh by navigating back to root
      print('🎉 DEBUG: Navigating to root to refresh app state...');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingTime = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3), // Soft cream background
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? const Color(0xFFF56500)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildFeaturesPage(),
                  _buildUnlockTimePage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Color(0xFFF56500),
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // Skip button (only on first two pages)
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // Next/Finish button
                  ElevatedButton(
                    onPressed: _isSettingTime ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF56500),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isSettingTime
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentPage == 2 ? 'Get Started!' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon/logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF56500),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF56500).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.restaurant,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          // App name
          const Text(
            'Pumpkin Bites',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF56500),
            ),
          ),

          const SizedBox(height: 16),

          // Tagline
          const Text(
            'Wisdom without the stuffiness',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE55100),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            'Big ideas from great books, served up in bite-sized pieces that won\'t make your eyes glaze over.\n\nDaily 3-minute wisdom drops that actually fit into real life. Smart stuff, zero stuffiness.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Trial info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF56500), Color(0xFFFF8A50)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try it free for a whole week',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Then \$2.99/month • Change your mind anytime',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Features preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(Icons.schedule, '3-min\nDaily'),
              _buildFeatureIcon(Icons.people, 'Fun\nDiscussions'),
              _buildFeatureIcon(Icons.lightbulb, 'Big Ideas\nSimple'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesPage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          const Text(
            'Here\'s How We Roll',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF56500),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Feature 1: Daily Brain Food
          _buildFeatureCard(
            icon: Icons.lock_clock,
            title: 'Daily Brain Food',
            description: 'One perfectly-sized insight delivered fresh each day when you want it',
            color: const Color(0xFFF56500),
          ),

          const SizedBox(height: 24),

          // Feature 2: Deliberately Silly
          _buildFeatureCard(
            icon: Icons.emoji_emotions,
            title: 'Actually Interesting',
            description: 'Big ideas explained through stories that won\'t put you to sleep',
            color: const Color(0xFFFFB366),
          ),

          const SizedBox(height: 24),

          // Feature 3: Join Discussions
          _buildFeatureCard(
            icon: Icons.chat_bubble,
            title: 'Chat About It',
            description: 'Share thoughts, react with emojis, and connect with other curious humans',
            color: const Color(0xFFE55100),
          ),

          const SizedBox(height: 40),

          // Bottom message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF56500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF56500).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFF56500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No homework vibes. Just listen and let ideas simmer.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockTimePage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          const Text(
            'When should your daily\nbite unlock?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF56500),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Text(
            'Choose a time that fits your routine.\nYou can always change this later.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Time picker
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 48,
                  color: Color(0xFFF56500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Daily Unlock Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedUnlockTime,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: const Color(0xFFF56500),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    
                    if (picked != null) {
                      setState(() {
                        _selectedUnlockTime = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF56500),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedUnlockTime.format(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Time suggestions
          const Text(
            'Popular choices:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildTimeChip('6:00 AM', 'Morning coffee', const TimeOfDay(hour: 6, minute: 0)),
              _buildTimeChip('7:30 AM', 'Commute time', const TimeOfDay(hour: 7, minute: 30)),
              _buildTimeChip('9:00 AM', 'Start of day', const TimeOfDay(hour: 9, minute: 0)),
              _buildTimeChip('12:00 PM', 'Lunch break', const TimeOfDay(hour: 12, minute: 0)),
              _buildTimeChip('6:00 PM', 'Evening wind-down', const TimeOfDay(hour: 18, minute: 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF56500).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            size: 30,
            color: const Color(0xFFF56500),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String time, String label, TimeOfDay timeOfDay) {
    final isSelected = _selectedUnlockTime.hour == timeOfDay.hour && 
                      _selectedUnlockTime.minute == timeOfDay.minute;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedUnlockTime = timeOfDay;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF56500) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFF56500) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}