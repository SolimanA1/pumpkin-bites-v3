import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart';
import '../screens/subscription_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _user;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  
  // User stats
  int _totalListened = 0;
  int _totalFavorites = 0;
  int _totalShares = 0;
  int _streakDays = 0;
  
  // User preferences
  TimeOfDay _unlockTime = const TimeOfDay(hour: 9, minute: 0); // Default 9 AM
  bool _dailyReminders = true;
  bool _commentNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserStats();
    _loadUserPreferences();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final userData = await _authService.getUserData(currentUser.uid);
        
        setState(() {
          _user = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      
      // Get listened bites count
      final listenedBites = userData['listenedBites'] as List<dynamic>? ?? [];
      
      // Get favorites count
      final favorites = userData['favorites'] as List<dynamic>? ?? [];
      
      // Get shares count
      final shares = userData['shares'] as int? ?? 0;
      
      // Calculate streak (simplified - consecutive days)
      final streak = await _calculateStreak(user.uid);

      setState(() {
        _totalListened = listenedBites.length;
        _totalFavorites = favorites.length;
        _totalShares = shares;
        _streakDays = streak;
      });
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      
      // Load unlock time preference (stored as hour and minute)
      final unlockHour = userData['unlockHour'] as int? ?? 9;
      final unlockMinute = userData['unlockMinute'] as int? ?? 0;
      
      // Load notification preferences
      final dailyReminders = userData['dailyReminders'] as bool? ?? true;
      final commentNotifications = userData['commentNotifications'] as bool? ?? true;

      setState(() {
        _unlockTime = TimeOfDay(hour: unlockHour, minute: unlockMinute);
        _dailyReminders = dailyReminders;
        _commentNotifications = commentNotifications;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'unlockHour': _unlockTime.hour,
        'unlockMinute': _unlockTime.minute,
        'dailyReminders': _dailyReminders,
        'commentNotifications': _commentNotifications,
      });
    } catch (e) {
      print('Error saving user preferences: $e');
    }
  }

  Future<int> _calculateStreak(String userId) async {
    try {
      // Simple streak calculation - days with listened content
      final now = DateTime.now();
      int streak = 0;
      
      for (int i = 0; i < 30; i++) { // Check last 30 days
        final checkDate = now.subtract(Duration(days: i));
        final dateString = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        
        // Check if user listened to anything on this date
        final listenQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('dailyActivity')
            .doc(dateString)
            .get();
            
        if (listenQuery.exists) {
          streak++;
        } else {
          break; // Streak broken
        }
      }
      
      return streak;
    } catch (e) {
      print('Error calculating streak: $e');
      return 0;
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _user?.displayName ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Photo upload button
            OutlinedButton.icon(
              onPressed: _showPhotoUploadOptions,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Profile Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF56500),
                side: const BorderSide(color: Color(0xFFF56500)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _authService.updateUserProfile(
                  uid: _user!.uid,
                  displayName: nameController.text.trim(),
                );
                Navigator.pop(context);
                _loadUserData(); // Refresh data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: Color(0xFFF56500),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating profile: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPhotoUploadOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose how you want to update your profile photo:'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildPhotoOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF56500)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFFF56500),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFF56500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      Navigator.pop(context); // Close the dialog
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadProfilePhoto(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePhoto(File imageFile) async {
    if (_user == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      // Show uploading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFF56500),
              ),
              const SizedBox(height: 16),
              const Text('Uploading profile photo...'),
            ],
          ),
        ),
      );

      // Create a unique filename
      final String fileName = 'profile_photos/${_user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Create reference to Firebase Storage
      final Reference storageRef = _storage.ref().child(fileName);
      
      // Upload file
      final TaskSnapshot uploadTask = await storageRef.putFile(imageFile);
      
      // Get download URL
      final String downloadURL = await uploadTask.ref.getDownloadURL();
      
      // Update user profile in Firestore
      await _firestore.collection('users').doc(_user!.uid).update({
        'photoURL': downloadURL,
      });

      // Update Firebase Auth user profile
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(downloadURL);
      
      // Close uploading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Reload user data to reflect changes
      await _loadUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFFF56500),
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile photo: $e');
      
      // Close uploading dialog if it's open
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showUnlockTimeSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Unlock Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose when you want your daily bite to unlock:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF56500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF56500).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Unlock Time:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _unlockTime,
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
                          _unlockTime = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF56500),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _unlockTime.format(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Perfect for:\n• Morning coffee (6-8 AM)\n• Commute time (7-9 AM)\n• Lunch break (12-1 PM)\n• Evening wind-down (6-8 PM)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveUserPreferences();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Daily unlock time set to ${_unlockTime.format(context)}',
                  ),
                  backgroundColor: const Color(0xFFF56500),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF56500),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Bite Reminders
              SwitchListTile(
                title: const Text('Daily Bite Reminders'),
                subtitle: Text('Get notified at ${_unlockTime.format(context)} when new bites unlock'),
                value: _dailyReminders,
                onChanged: (value) {
                  setDialogState(() {
                    _dailyReminders = value;
                  });
                  setState(() {
                    _dailyReminders = value;
                  });
                },
                activeColor: const Color(0xFFF56500),
              ),
              // Unlock time setting
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close current dialog
                    _showUnlockTimeSettings(); // Open time picker dialog
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text('Change unlock time (${_unlockTime.format(context)})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF56500),
                    side: const BorderSide(color: Color(0xFFF56500)),
                  ),
                ),
              ),
              const Divider(),
              // Comment Replies
              SwitchListTile(
                title: const Text('Comment Replies'),
                subtitle: const Text('Get notified when someone replies to your comments'),
                value: _commentNotifications,
                onChanged: (value) {
                  setDialogState(() {
                    _commentNotifications = value;
                  });
                  setState(() {
                    _commentNotifications = value;
                  });
                },
                activeColor: const Color(0xFFF56500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveUserPreferences();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification preferences saved!'),
                    backgroundColor: Color(0xFFF56500),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF56500),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Pumpkin Bites'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wisdom without the stuffiness',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFF56500),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Book insights served silly-side up. We deliver the most thought-provoking ideas from great books in daily 3-minute audio snacks that actually fit into your life.',
            ),
            SizedBox(height: 16),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to use Pumpkin Bites:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Check daily for new bite releases'),
            Text('• Join discussions in the Dinner Table'),
            Text('• Share your favorite moments with friends'),
            Text('• Build your personal library of wisdom'),
            SizedBox(height: 16),
            Text(
              'Need more help?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Contact us at: support@pumpkinbites.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFFF56500),
            ))
          : _user == null
              ? _buildNotLoggedIn()
              : _buildProfile(),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          const Text(
            'You are not logged in',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Navigate to login
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF56500),
            ),
            child: const Text('LOG IN'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Profile Header
            Center(
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF56500).withOpacity(0.2),
                        backgroundImage: _user?.photoURL?.isNotEmpty == true
                            ? NetworkImage(_user!.photoURL!)
                            : null,
                        child: _user?.photoURL?.isEmpty != false
                            ? Text(
                                _getInitials(_user?.displayName ?? ''),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF56500),
                                ),
                              )
                            : null,
                      ),
                      
                      // Show loading overlay while uploading
                      if (_isUploadingPhoto)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: const Color(0xFFF56500),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _isUploadingPhoto ? null : _showEditProfileDialog,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                _isUploadingPhoto ? Icons.hourglass_empty : Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Stats Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF56500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF56500).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Wisdom Journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF56500),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.headphones,
                          value: _totalListened.toString(),
                          label: 'Bites Listened',
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.favorite,
                          value: _totalFavorites.toString(),
                          label: 'Favorites',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.share,
                          value: _totalShares.toString(),
                          label: 'Shared',
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.local_fire_department,
                          value: _streakDays.toString(),
                          label: 'Day Streak',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Divider(),

            // Menu items
            _buildMenuItem(
              icon: Icons.person,
              title: 'Edit Profile',
              onTap: _showEditProfileDialog,
            ),
            _buildMenuItem(
              icon: Icons.notifications,
              title: 'Notifications',
              onTap: _showNotificationSettings,
            ),
            _buildSubscriptionMenuItem(),
            _buildMenuItem(
              icon: Icons.share,
              title: 'Share History',
              onTap: () {
                Navigator.pushNamed(context, '/share_history');
              },
            ),
            _buildMenuItem(
              icon: Icons.help,
              title: 'Help & Support',
              onTap: _showHelpDialog,
            ),
            _buildMenuItem(
              icon: Icons.info,
              title: 'About',
              onTap: _showAboutDialog,
            ),
            const Divider(),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'Sign Out',
              onTap: () async {
                // Show confirmation dialog
                final shouldSignOut = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                
                if (shouldSignOut == true) {
                  await _signOut();
                }
              },
              textColor: Colors.red,
            ),
            
            const Divider(),
            // Diagnostics button (for debugging)
            _buildMenuItem(
              icon: Icons.bug_report,
              title: 'Diagnostics',
              onTap: () {
                Navigator.pushNamed(context, '/diagnostics');
              },
              textColor: Colors.purple,
            ),
            
            const SizedBox(height: 30),
            
            // App version
            Center(
              child: Text(
                'Pumpkin Bites v1.0.0\nWisdom without the stuffiness 🎃',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: const Color(0xFFF56500),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF56500),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    int badge = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: textColor ?? Colors.black87,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor ?? Colors.black87,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionMenuItem() {
    final subscriptionService = SubscriptionService();
    
    return StreamBuilder<bool>(
      stream: subscriptionService.subscriptionStatusStream,
      initialData: subscriptionService.isSubscriptionActive,
      builder: (context, snapshot) {
        final isSubscribed = snapshot.data ?? false;
        
        if (isSubscribed) {
          return _buildMenuItem(
            icon: Icons.star,
            title: 'Subscription Active',
            onTap: () => _showSubscriptionDetails(),
          );
        } else if (subscriptionService.isInTrialPeriod) {
          return StreamBuilder<int>(
            stream: subscriptionService.trialDaysRemainingStream,
            initialData: subscriptionService.trialDaysRemaining,
            builder: (context, trialSnapshot) {
              final daysRemaining = trialSnapshot.data ?? 0;
              return _buildMenuItem(
                icon: Icons.timer,
                title: 'Trial: $daysRemaining days left',
                onTap: () => _navigateToSubscription(),
                badge: daysRemaining,
              );
            },
          );
        } else {
          return _buildMenuItem(
            icon: Icons.upgrade,
            title: 'Subscribe for \$2.99/month',
            onTap: () => _navigateToSubscription(),
            textColor: const Color(0xFFF56500),
          );
        }
      },
    );
  }
  
  void _navigateToSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
      ),
    );
  }
  
  void _showSubscriptionDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Active'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✓ Unlimited access to all stories'),
            Text('✓ New stories added regularly'),
            Text('✓ Ad-free experience'),
            Text('✓ Offline listening'),
            SizedBox(height: 16),
            Text(
              'You can manage your subscription in your App Store account settings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    
    return '';
  }
}