import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pumpkin_bites_new/screens/auth/login_screen.dart';
import 'package:pumpkin_bites_new/screens/auth/register_screen.dart';
import 'package:pumpkin_bites_new/screens/home_screen.dart';
import 'package:pumpkin_bites_new/screens/library_screen.dart';
import 'package:pumpkin_bites_new/screens/unified_dinner_table_screen.dart';
import 'package:pumpkin_bites_new/screens/profile_screen.dart';
import 'package:pumpkin_bites_new/screens/player_screen.dart';
import 'package:pumpkin_bites_new/screens/diagnostic_screen.dart';
import 'package:pumpkin_bites_new/screens/share_history_screen.dart';
import 'package:pumpkin_bites_new/screens/comment_detail_screen.dart';
import 'package:pumpkin_bites_new/services/auth_service.dart';
import 'package:pumpkin_bites_new/services/audio_player_service.dart';
import 'package:pumpkin_bites_new/services/share_service.dart';
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
  
  // Initialize audio player
  await _audioService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // FIXED: Changed logic - show floating bar when there's a loaded bite, not just when playing
  bool _hasActiveBite = false;  // Changed from _isAudioPlaying
  BiteModel? _currentBite;

  @override
  void initState() {
    super.initState();
    _setupAudioListener();
  }
  
  void _setupAudioListener() {
    // FIXED: Listen to player state changes but show floating bar for ANY loaded content
    _audioService.playerStateStream.listen((state) {
      if (mounted) {
        final currentBite = _audioService.currentBite;
        
        print("=== MAIN APP AUDIO LISTENER ===");
        print("Player state: ${state.playing}");
        print("Processing state: ${state.processingState}");
        print("Current bite: ${currentBite?.title}");
        print("Should show floating bar: ${currentBite != null}");
        
        setState(() {
          // Show floating bar if there's ANY loaded bite (playing OR paused)
          _hasActiveBite = currentBite != null;
          _currentBite = currentBite;
        });
        
        print("Updated _hasActiveBite: $_hasActiveBite");
        print("=== END MAIN APP AUDIO LISTENER ===");
      }
    });
  }

  void _navigateToPlayer() {
    // Only navigate if there's a current bite
    if (_currentBite != null) {
      // Navigate to player screen without restarting playback
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
        // Primary color scheme - Pumpkin Orange
        primarySwatch: Colors.orange,
        primaryColor: const Color(0xFFF56500),          // Etsy Orange
        scaffoldBackgroundColor: const Color(0xFFFFF8F3), // Soft Cream
        
        // Visual density for modern look
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // AppBar theme with Pumpkin styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8F3),           // Soft Cream
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFF56500)), // Orange icons
          titleTextStyle: TextStyle(
            color: Color(0xFF2D2D2D),                   // Dark text
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF56500),   // Orange background
            foregroundColor: Colors.white,              // White text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        
        // Text button theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFF56500),   // Orange text
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
              color: Color(0xFFF56500),                 // Orange focus border
              width: 2,
            ),
          ),
        ),
        
        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFF56500),           // Orange background
          foregroundColor: Colors.white,                // White icon
        ),
        
        // Progress indicator theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFF56500),                     // Orange progress
        ),
        
        // Tab bar theme
        tabBarTheme: const TabBarTheme(
          labelColor: Color(0xFFF56500),                // Orange selected
          unselectedLabelColor: Color(0xFF8D6E63),      // Brown unselected
          indicatorColor: Color(0xFFF56500),            // Orange indicator
        ),
      ),
      home: _buildHomeWithFloatingPlayer(),
      routes: {
        '/home': (context) => _wrapWithFloatingPlayer(const HomeScreen()),
        '/library': (context) => _wrapWithFloatingPlayer(const LibraryScreen()),
        '/dinner_table': (context) => _wrapWithFloatingPlayer(const UnifiedDinnerTableScreen()),
        '/profile': (context) => _wrapWithFloatingPlayer(const ProfileScreen()),
        '/diagnostics': (context) => _wrapWithFloatingPlayer(const DiagnosticScreen()),
        '/share_history': (context) => _wrapWithFloatingPlayer(const ShareHistoryScreen()),
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
          // Import the CommentDetailScreen at the top of main.dart
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
        
        // FIXED: Show floating player if there's ANY active bite (playing OR paused)
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
        
        // FIXED: Show floating player if there's ANY active bite (playing OR paused)
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
          return const MainScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const UnifiedDinnerTableScreen(),
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
        selectedItemColor: const Color(0xFFF56500),       // Orange when selected
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