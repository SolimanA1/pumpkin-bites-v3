import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pumpkin_bites_new/screens/auth/login_screen.dart';
import 'package:pumpkin_bites_new/screens/home_screen.dart';
import 'package:pumpkin_bites_new/screens/library_screen.dart';
import 'package:pumpkin_bites_new/screens/simple_dinner_table_screen.dart';
import 'package:pumpkin_bites_new/screens/profile_screen.dart';
import 'package:pumpkin_bites_new/screens/player_screen.dart';
import 'package:pumpkin_bites_new/screens/diagnostic_screen.dart';
import 'package:pumpkin_bites_new/screens/share_history_screen.dart';
import 'package:pumpkin_bites_new/screens/comment_detail_screen.dart';
import 'package:pumpkin_bites_new/screens/onboarding_screen.dart';
import 'package:pumpkin_bites_new/screens/subscription_screen.dart';
import 'package:pumpkin_bites_new/services/auth_service.dart';
import 'package:pumpkin_bites_new/services/audio_player_service.dart';
import 'package:pumpkin_bites_new/services/share_service.dart';
import 'package:pumpkin_bites_new/services/subscription_service.dart';
import 'package:pumpkin_bites_new/models/bite_model.dart';
import 'package:pumpkin_bites_new/floating_player_bar.dart';
import 'firebase_options.dart';

// Global key to access the navigator state
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Audio service reference
final AudioPlayerService _audioService = AudioPlayerService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize services
  AuthService();  // Initialize the singleton
  ShareService(); // Initialize the sharing singleton
  await SubscriptionService().initialize(); // Initialize subscription service
  
  // Initialize audio player with platform-specific handling
  if (Platform.isAndroid) {
    // Android: Use direct initialization (AndroidManifest.xml is properly configured)
    await _audioService.init();
    print("✅ Android audio service initialized successfully");
  } else if (Platform.isIOS) {
    // iOS: Use graceful fallback until iOS configuration is fixed
    try {
      await _audioService.init();
      print("✅ iOS audio service initialized successfully");
    } catch (e) {
      print("⚠️ iOS audio service initialization failed: $e");
      print("📱 iOS will continue with limited audio functionality");
      // Continue app initialization - iOS audio needs proper configuration
    }
  } else {
    // Web/other platforms: Use graceful fallback
    try {
      await _audioService.init();
      print("✅ Audio service initialized successfully on ${Platform.operatingSystem}");
    } catch (e) {
      print("⚠️ Audio service initialization failed on ${Platform.operatingSystem}: $e");
      print("📱 App will continue with limited audio functionality");
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Restore the floating player logic to the top level
  bool _hasActiveBite = false;
  BiteModel? _currentBite;

  @override
  void initState() {
    super.initState();
    _setupAudioListener();
  }
  
  void _setupAudioListener() {
    _audioService.playerStateStream.listen((state) {
      if (mounted) {
        final currentBite = _audioService.currentBite;
        
        setState(() {
          _hasActiveBite = currentBite != null;
          _currentBite = currentBite;
        });
      }
    });
  }

  void _navigateToPlayer() {
    if (_currentBite != null) {
      navigatorKey.currentState?.pushNamed(
        '/player',
        arguments: _currentBite,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pumpkin Bites',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        // Primary color scheme - Wine Theme
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFF8B0000),          // Deep Wine Red
        scaffoldBackgroundColor: const Color(0xFFF7F6F4), // Linen Background
        
        // Visual density for modern look
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // AppBar theme with Pumpkin styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F6F4),           // Linen Background
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF8B0000)), // Wine icons
          titleTextStyle: TextStyle(
            color: Color(0xFF2F2F2F),                   // Charcoal text
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),   // Wine background
            foregroundColor: Colors.white,              // White text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        
        // Text button theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8B0000),   // Wine text
          ),
        ),
        
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF8B0000),                 // Wine focus border
              width: 2,
            ),
          ),
        ),
        
        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF8B0000),           // Wine background
          foregroundColor: Colors.white,                // White icon
        ),
        
        // Progress indicator theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF8B0000),                     // Wine progress
        ),
        
        // Tab bar theme
        tabBarTheme: const TabBarTheme(
          labelColor: Color(0xFF8B0000),                // Wine selected
          unselectedLabelColor: Color(0xFF8D6E63),      // Brown unselected
          indicatorColor: Color(0xFF8B0000),            // Wine indicator
        ),
      ),
      home: _buildHomeWithFloatingPlayer(),
      routes: {
        '/home': (context) => _wrapWithFloatingPlayer(const HomeScreen()),
        '/library': (context) => _wrapWithFloatingPlayer(const LibraryScreen()),
        '/dinner_table': (context) => _wrapWithFloatingPlayer(const SimpleReelDinnerTableScreen()),
        '/profile': (context) => _wrapWithFloatingPlayer(const ProfileScreen()),
        '/diagnostics': (context) => _wrapWithFloatingPlayer(const DiagnosticScreen()),
        '/share_history': (context) => _wrapWithFloatingPlayer(const ShareHistoryScreen()),
        '/onboarding': (context) => const OnboardingScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
      },
      // Use onGenerateRoute for routes that need parameters
      onGenerateRoute: (settings) {
        if (settings.name == '/player') {
          final args = settings.arguments as BiteModel;
          return MaterialPageRoute(
            builder: (context) => PlayerScreen(bite: args),
          );
        } else if (settings.name == '/comment_detail') {
          final args = settings.arguments as BiteModel;
          return MaterialPageRoute(
            builder: (context) => CommentDetailScreen(bite: args),
          );
        }
        return null;
      },
    );
  }
  
  Widget _buildHomeWithFloatingPlayer() {
    return Stack(
      children: [
        const AuthWrapper(),
        
        // Original working floating player logic
        if (_hasActiveBite && _currentBite != null)
          FloatingPlayerBar(
            bite: _currentBite!,
            onTap: _navigateToPlayer,
            audioService: _audioService,
          ),
      ],
    );
  }
  
  Widget _wrapWithFloatingPlayer(Widget child) {
    return Stack(
      children: [
        child,
        
        // Show floating player on individual routes too
        if (_hasActiveBite && _currentBite != null)
          FloatingPlayerBar(
            bite: _currentBite!,
            onTap: _navigateToPlayer,
            audioService: _audioService,
          ),
      ],
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const OnboardingWrapper();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8B0000),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingWrapper extends StatelessWidget {
  const OnboardingWrapper({Key? key}) : super(key: key);

  Future<Map<String, bool>> _checkStatus() async {
    try {
      print('🎯 DEBUG: OnboardingWrapper - Checking user-specific onboarding status...');
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🎯 DEBUG: OnboardingWrapper - No authenticated user, showing onboarding');
        return {'hasCompletedOnboarding': false};
      }
      
      // Check user-specific onboarding status from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      bool hasCompletedOnboarding = false;
      if (userDoc.exists && userDoc.data() != null) {
        hasCompletedOnboarding = userDoc.data()!['hasCompletedOnboarding'] ?? false;
      }
      
      print('🎯 DEBUG: OnboardingWrapper - User ${user.uid} hasCompletedOnboarding: $hasCompletedOnboarding');
      
      // Initialize subscription service to load user-specific trial state
      final subscriptionService = SubscriptionService();
      await subscriptionService.initialize();
      
      print('🎯 DEBUG: OnboardingWrapper - Trial end date: ${subscriptionService.trialEndDate}');
      print('🎯 DEBUG: OnboardingWrapper - Is subscription active: ${subscriptionService.isSubscriptionActive}');
      print('🎯 DEBUG: OnboardingWrapper - Is in trial period: ${subscriptionService.isInTrialPeriod}');
      print('🎯 DEBUG: OnboardingWrapper - Trial days remaining: ${subscriptionService.trialDaysRemaining}');
      
      return {
        'hasCompletedOnboarding': hasCompletedOnboarding,
      };
    } catch (e) {
      print('Error checking status: $e');
      return {'hasCompletedOnboarding': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _checkStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B0000),
              ),
            ),
          );
        }
        
        final status = snapshot.data ?? {'hasCompletedOnboarding': false};
        final hasCompletedOnboarding = status['hasCompletedOnboarding'] ?? false;
        
        print('DEBUG: OnboardingWrapper.build - hasCompletedOnboarding: $hasCompletedOnboarding');
        
        if (hasCompletedOnboarding) {
          print('DEBUG: OnboardingWrapper.build - Showing SubscriptionWrapper');
          return const SubscriptionWrapper();
        } else {
          print('DEBUG: OnboardingWrapper.build - Showing OnboardingScreen');
          return const OnboardingScreen();
        }
      },
    );
  }
}

class SubscriptionWrapper extends StatelessWidget {
  const SubscriptionWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();
    
    return StreamBuilder<bool>(
      stream: subscriptionService.subscriptionStatusStream,
      initialData: subscriptionService.hasContentAccess,
      builder: (context, snapshot) {
        return const MainScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
  }
  
  // Remove the floating player logic from MainScreen since it's back at top level
  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const SimpleReelDinnerTableScreen(),
    const ProfileScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF8B0000),       // Wine when selected
        unselectedItemColor: const Color(0xFF8D6E63),   // Warm Brown when unselected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Dinner Table',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}