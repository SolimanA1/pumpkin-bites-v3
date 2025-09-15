import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/pumpkin_bites_app.dart';
import 'core/service_locator.dart';
import 'utils/app_logger.dart';
import 'firebase_options.dart';

/// Clean, focused main entry point
/// All complexity moved to dedicated modules
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging first
  AppLogger.initialize();
  AppLogger.info('🎃 Starting Pumpkin Bites v3...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully');
    
    // Setup dependency injection
    await setupServiceLocator();
    AppLogger.info('Service locator setup completed');
    
    // Launch the app
    runApp(const PumpkinBitesApp());
    AppLogger.info('🚀 Pumpkin Bites launched successfully!');
    
  } catch (error, stackTrace) {
    AppLogger.error('Failed to start app', error, stackTrace);
    runApp(_buildErrorApp(error));
  }
}

/// Error app when startup fails
Widget _buildErrorApp(Object error) {
  return MaterialApp(
    title: 'Pumpkin Bites - Error',
    home: Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎃', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please restart the app and try again.',
                style: TextStyle(fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}