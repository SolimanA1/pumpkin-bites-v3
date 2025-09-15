import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logging system for Pumpkin Bites
/// Replaces all print statements with structured logging
class AppLogger {
  static late final Logger _logger;
  static bool _isInitialized = false;
  
  /// Initialize the logger
  static void initialize() {
    if (_isInitialized) return;
    
    _logger = Logger(
      filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
      printer: kDebugMode ? PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ) : SimplePrinter(),
      output: ConsoleOutput(),
    );
    
    _isInitialized = true;
    info('🎃 AppLogger initialized successfully');
  }
  
  /// Log info level messages
  static void info(String message, [Map<String, dynamic>? context]) {
    _ensureInitialized();
    final logMessage = _formatMessage(message, context);
    _logger.i(logMessage);
  }
  
  /// Log debug level messages
  static void debug(String message, [Map<String, dynamic>? context]) {
    _ensureInitialized();
    final logMessage = _formatMessage(message, context);
    _logger.d(logMessage);
  }
  
  /// Log warning level messages
  static void warning(String message, [Map<String, dynamic>? context]) {
    _ensureInitialized();
    final logMessage = _formatMessage(message, context);
    _logger.w(logMessage);
  }
  
  /// Log error level messages
  static void error(String message, [Object? error, StackTrace? stackTrace, Map<String, dynamic>? context]) {
    _ensureInitialized();
    final logMessage = _formatMessage(message, context);
    _logger.e(logMessage, error: error, stackTrace: stackTrace);
  }
  
  /// Log user actions for analytics
  static void userAction(String action, [Map<String, dynamic>? context]) {
    _ensureInitialized();
    final actionContext = {
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
      ...?context,
    };
    info('User Action: $action', actionContext);
  }
  
  /// Ensure logger is initialized before use
  static void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }
  
  /// Format message with context data
  static String _formatMessage(String message, Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) {
      return message;
    }
    
    final contextString = context.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    
    return '$message | Context: {$contextString}';
  }
}

/// Mixin for classes that need logging
mixin LoggerMixin {
  void logInfo(String message, [Map<String, dynamic>? context]) {
    AppLogger.info('[${runtimeType}] $message', context);
  }
  
  void logDebug(String message, [Map<String, dynamic>? context]) {
    AppLogger.debug('[${runtimeType}] $message', context);
  }
  
  void logWarning(String message, [Map<String, dynamic>? context]) {
    AppLogger.warning('[${runtimeType}] $message', context);
  }
  
  void logError(String message, [Object? error, StackTrace? stackTrace, Map<String, dynamic>? context]) {
    AppLogger.error('[${runtimeType}] $message', error, stackTrace, context);
  }
  
  void logUserAction(String action, [Map<String, dynamic>? context]) {
    AppLogger.userAction('[${runtimeType}] $action', context);
  }
}