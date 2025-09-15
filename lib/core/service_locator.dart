import 'package:get_it/get_it.dart';
import '../services/user_progression_service.dart';
import '../services/content_service.dart';
import '../services/subscription_service.dart';
import '../services/snippet_service.dart';
import '../services/audio_service.dart';
import '../repositories/content_repository.dart';
import '../repositories/content_repository_impl.dart';
import '../controllers/home_controller.dart';
import '../controllers/library_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/profile_controller.dart';
import '../utils/app_logger.dart';

/// Service Locator for Dependency Injection - COMPLETE VERSION
final GetIt getIt = GetIt.instance;

/// Initialize all services, repositories, and controllers
Future<void> setupServiceLocator() async {
  AppLogger.info('Setting up service locator...');

  try {
    // === CORE SERVICES (Your existing working services) ===
    getIt.registerSingleton<UserProgressionService>(UserProgressionService());
    getIt.registerSingleton<ContentService>(ContentService());
    getIt.registerSingleton<SubscriptionService>(SubscriptionService());
    getIt.registerSingleton<SnippetService>(SnippetService());
    getIt.registerSingleton<AudioService>(AudioService());
    
    // === REPOSITORIES (New clean interfaces) ===
    getIt.registerSingleton<ContentRepository>(ContentRepositoryImpl());
    
    // === CONTROLLERS (Factory - new instance each time) ===
    getIt.registerFactory<HomeController>(() => HomeController());
    getIt.registerFactory<LibraryController>(() => LibraryController());
    getIt.registerFactory<PlayerController>(() => PlayerController());
    getIt.registerFactory<ProfileController>(() => ProfileController());
    
    AppLogger.info('All services, repositories, and controllers registered successfully');
  } catch (error, stackTrace) {
    AppLogger.error('Failed to setup service locator', error, stackTrace);
    rethrow;
  }
}

/// Reset all registrations (useful for testing)
Future<void> resetServiceLocator() async {
  AppLogger.debug('Resetting service locator...');
  await getIt.reset();
}

/// Check if service locator is properly initialized
bool get isServiceLocatorInitialized {
  try {
    getIt<ContentService>();
    getIt<ContentRepository>();
    return true;
  } catch (_) {
    return false;
  }
}