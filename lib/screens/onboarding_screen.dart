import 'package:flutter/material.dart';
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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isSettingTime = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setNotificationTime(TimeOfDay time) async {
    setState(() {
      _selectedTime = time;
    });
    print('Selected notification time: ${time.hour}:${time.minute}');
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isSettingTime = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🎉 DEBUG: Completing onboarding for user: ${user.uid}');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'hasCompletedOnboarding': true,
        });
        
        print('🎉 DEBUG: Updated hasCompletedOnboarding in Firestore');
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
      backgroundColor: const Color(0xFFFFF8F3),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? const Color(0xFF8B0000)
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
                  _buildSlide1(),
                  _buildSlide2(),
                  _buildSlide3(),
                ],
              ),
            ),

            // Navigation buttons
            Container(
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
                          color: Color(0xFF8B0000),
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // Skip button
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

                  // Next button
                  ElevatedButton(
                    onPressed: _isSettingTime ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
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

  Widget _buildSlide1() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.explore,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          const Text(
            'Where Curious Minds Wander',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B0000),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          const Text(
            '3-minute daily doses of \'huh, interesting\'',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE55100),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            'We\'re that friend who reads way too much and can\'t help but share the cool stuff we find. Ideas from books, research, poetry, history - drawn from anywhere curiosity leads.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSlide2() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 50,
              color: Color(0xFF8B0000),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          const Text(
            'One curious bite, daily',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B0000),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          const Text(
            'No overwhelm, no homework',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE55100),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            'Every day unlocks something new. Listen when you want, let ideas simmer. We might forget to floss, but we never miss sharing something cool.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSlide3() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.schedule,
              size: 50,
              color: Color(0xFF8B0000),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          const Text(
            'When should we drop by?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B0000),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          const Text(
            'Pick your daily curiosity time',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE55100),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            'Join the wanderers. Start your free week.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Time chips - simplified
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildTimeChip('9:00 AM', const TimeOfDay(hour: 9, minute: 0)),
              _buildTimeChip('12:00 PM', const TimeOfDay(hour: 12, minute: 0)),
              _buildTimeChip('6:00 PM', const TimeOfDay(hour: 18, minute: 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String timeText, TimeOfDay timeOfDay) {
    final isSelected = _selectedTime.hour == timeOfDay.hour && _selectedTime.minute == timeOfDay.minute;
    
    return InkWell(
      onTap: () => _setNotificationTime(timeOfDay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B0000) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B0000) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          timeText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF8B0000),
          ),
        ),
      ),
    );
  }
}