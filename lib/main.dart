import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pumpkin_bites_new/screens/auth/login_screen.dart';
import 'package:pumpkin_bites_new/screens/auth/register_screen.dart';
import 'package:pumpkin_bites_new/screens/home_screen.dart';
import 'package:pumpkin_bites_new/screens/library_screen.dart';
// Replacing DinnerTableScreen with UnifiedDinnerTableScreen
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

// Global variable to track currently playing bite
BiteModel? currentlyPlayingBite;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize services
  AuthService();  // Initialize the singleton
  ShareService(); // Initialize the sharing singleton
  
  // Initialize audio player
  final audioService = AudioPlayerService();
  await audioService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pumpkin Bites',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/library': (context) => const LibraryScreen(),
        '/dinner_table': (context) => const UnifiedDinnerTableScreen(), // Changed to UnifiedDinnerTableScreen
        '/profile': (context) => const ProfileScreen(),
        '/diagnostics': (context) => const DiagnosticScreen(),
        '/share_history': (context) => const ShareHistoryScreen(),
      },
      // Use onGenerateRoute for routes that need parameters
      onGenerateRoute: (settings) {
        if (settings.name == '/player') {
          final args = settings.arguments as BiteModel;
          // Store the currently playing bite for the floating player
          currentlyPlayingBite = args;
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
  final AudioPlayerService _audioService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const UnifiedDinnerTableScreen(), // Changed to UnifiedDinnerTableScreen
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

  void _navigateToPlayer() {
    if (currentlyPlayingBite != null) {
      Navigator.of(context).pushNamed('/player', arguments: currentlyPlayingBite);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if audio is playing to show the floating player
    final isPlaying = _audioService.isPlaying;
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating player bar (only show if audio is playing)
          if (isPlaying && currentlyPlayingBite != null)
            FloatingPlayerBar(
              bite: currentlyPlayingBite!,
              onTap: _navigateToPlayer,
            ),
          // Regular bottom navigation
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
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
        ],
      ),
    );
  }
}