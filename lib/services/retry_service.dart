import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

enum RetryStrategy {
  exponential,
  linear,
  immediate,
}

class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final RetryStrategy strategy;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool Function(dynamic error)? retryIf;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.strategy = RetryStrategy.exponential,
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.retryIf,
  });

  static const RetryConfig network = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 2),
    strategy: RetryStrategy.exponential,
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 10),
  );

  static const RetryConfig server = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 5),
    strategy: RetryStrategy.linear,
    maxDelay: Duration(seconds: 15),
  );

  static const RetryConfig quick = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(milliseconds: 500),
    strategy: RetryStrategy.exponential,
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 3),
  );
}

class RetryResult<T> {
  final T? data;
  final dynamic error;
  final int attemptCount;
  final Duration totalDuration;
  final bool isSuccess;

  const RetryResult({
    this.data,
    this.error,
    required this.attemptCount,
    required this.totalDuration,
    required this.isSuccess,
  });

  bool get isFailure => !isSuccess;
}

class RetryService {
  static Duration _calculateDelay(RetryConfig config, int attemptNumber) {
    switch (config.strategy) {
      case RetryStrategy.exponential:
        final delay = config.initialDelay * pow(config.backoffMultiplier, attemptNumber - 1);
        return Duration(
          milliseconds: min(
            delay.inMilliseconds.toInt(),
            config.maxDelay.inMilliseconds,
          ),
        );
      
      case RetryStrategy.linear:
        final delay = config.initialDelay * attemptNumber;
        return Duration(
          milliseconds: min(
            delay.inMilliseconds,
            config.maxDelay.inMilliseconds,
          ),
        );
      
      case RetryStrategy.immediate:
        return Duration.zero;
    }
  }

  static bool _shouldRetry(dynamic error, RetryConfig config) {
    if (config.retryIf != null) {
      return config.retryIf!(error);
    }

    // Default retry conditions
    final errorString = error.toString().toLowerCase();
    
    // Retry on network-related errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('host lookup failed') ||
        errorString.contains('no internet')) {
      return true;
    }

    // Retry on server errors (5xx)
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Don't retry on client errors (4xx) except 408 (timeout)
    if (errorString.contains('400') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('404')) {
      return false;
    }

    if (errorString.contains('408')) {
      return true; // Request timeout
    }

    return false; // Don't retry by default for unknown errors
  }

  static Future<RetryResult<T>> execute<T>(
    Future<T> Function() operation,
    RetryConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();
    dynamic lastError;
    int attemptCount = 0;

    for (int attempt = 1; attempt <= config.maxRetries + 1; attempt++) {
      attemptCount = attempt;
      
      try {
        if (kDebugMode && attempt > 1) {
          print('Retry attempt $attempt/${config.maxRetries + 1}');
        }
        
        final result = await operation();
        stopwatch.stop();
        
        return RetryResult<T>(
          data: result,
          attemptCount: attemptCount,
          totalDuration: stopwatch.elapsed,
          isSuccess: true,
        );
      } catch (error) {
        lastError = error;
        
        if (kDebugMode) {
          print('Attempt $attempt failed: $error');
        }

        // If this was the last attempt, don't retry
        if (attempt > config.maxRetries) {
          break;
        }

        // Check if we should retry this error
        if (!_shouldRetry(error, config)) {
          if (kDebugMode) {
            print('Error not retryable, stopping attempts');
          }
          break;
        }

        // Calculate delay before next attempt
        final delay = _calculateDelay(config, attempt);
        if (delay > Duration.zero) {
          if (kDebugMode) {
            print('Waiting ${delay.inMilliseconds}ms before retry');
          }
          await Future.delayed(delay);
        }
      }
    }

    stopwatch.stop();
    
    return RetryResult<T>(
      error: lastError,
      attemptCount: attemptCount,
      totalDuration: stopwatch.elapsed,
      isSuccess: false,
    );
  }

  static Future<RetryResult<T>> executeWithProgress<T>(
    Future<T> Function() operation,
    RetryConfig config,
    void Function(int attempt, int maxAttempts, Duration nextDelay)? onRetry,
  ) async {
    final stopwatch = Stopwatch()..start();
    dynamic lastError;
    int attemptCount = 0;

    for (int attempt = 1; attempt <= config.maxRetries + 1; attempt++) {
      attemptCount = attempt;
      
      try {
        final result = await operation();
        stopwatch.stop();
        
        return RetryResult<T>(
          data: result,
          attemptCount: attemptCount,
          totalDuration: stopwatch.elapsed,
          isSuccess: true,
        );
      } catch (error) {
        lastError = error;

        // If this was the last attempt, don't retry
        if (attempt > config.maxRetries) {
          break;
        }

        // Check if we should retry this error
        if (!_shouldRetry(error, config)) {
          break;
        }

        // Calculate delay before next attempt
        final delay = _calculateDelay(config, attempt);
        
        // Notify about retry
        if (onRetry != null) {
          onRetry(attempt, config.maxRetries + 1, delay);
        }

        // Wait before retrying
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }

    stopwatch.stop();
    
    return RetryResult<T>(
      error: lastError,
      attemptCount: attemptCount,
      totalDuration: stopwatch.elapsed,
      isSuccess: false,
    );
  }
}