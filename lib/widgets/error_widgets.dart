import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum ErrorType {
  network,
  server,
  timeout,
  unknown,
  noContent,
  authentication,
}

class ErrorInfo {
  final ErrorType type;
  final String title;
  final String message;
  final String actionText;
  final IconData icon;

  const ErrorInfo({
    required this.type,
    required this.title,
    required this.message,
    required this.actionText,
    required this.icon,
  });

  static ErrorInfo fromException(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socket') || 
        errorString.contains('network') || 
        errorString.contains('connection')) {
      return const ErrorInfo(
        type: ErrorType.network,
        title: 'Connection Problem',
        message: 'Please check your internet connection and try again.',
        actionText: 'Retry',
        icon: Icons.wifi_off,
      );
    } else if (errorString.contains('timeout')) {
      return const ErrorInfo(
        type: ErrorType.timeout,
        title: 'Request Timed Out',
        message: 'The request is taking longer than expected. Please try again.',
        actionText: 'Try Again',
        icon: Icons.access_time,
      );
    } else if (errorString.contains('server') || 
               errorString.contains('500') || 
               errorString.contains('502') || 
               errorString.contains('503')) {
      return const ErrorInfo(
        type: ErrorType.server,
        title: 'Server Issue',
        message: 'Our servers are experiencing issues. We\'re working to fix this.',
        actionText: 'Try Again',
        icon: Icons.cloud_off,
      );
    } else if (errorString.contains('auth') || 
               errorString.contains('permission') || 
               errorString.contains('unauthorized')) {
      return const ErrorInfo(
        type: ErrorType.authentication,
        title: 'Authentication Required',
        message: 'Please sign in again to continue.',
        actionText: 'Sign In',
        icon: Icons.lock_outline,
      );
    } else {
      return const ErrorInfo(
        type: ErrorType.unknown,
        title: 'Something Went Wrong',
        message: 'An unexpected error occurred. Please try again.',
        actionText: 'Retry',
        icon: Icons.error_outline,
      );
    }
  }
}

class PumpkinErrorWidget extends StatelessWidget {
  final ErrorInfo errorInfo;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionText;
  final bool isCompact;

  const PumpkinErrorWidget({
    Key? key,
    required this.errorInfo,
    this.onRetry,
    this.onSecondaryAction,
    this.secondaryActionText,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactError(context);
    }
    return _buildFullError(context);
  }

  Widget _buildCompactError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            errorInfo.icon,
            color: PumpkinColors.errorRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorInfo.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  errorInfo.message,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: PumpkinColors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(errorInfo.actionText),
            ),
        ],
      ),
    );
  }

  Widget _buildFullError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PumpkinColors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                errorInfo.icon,
                size: 64,
                color: PumpkinColors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              errorInfo.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorInfo.message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(errorInfo.actionText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PumpkinColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                if (onSecondaryAction != null && secondaryActionText != null) ...[
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PumpkinColors.orange,
                      side: const BorderSide(color: PumpkinColors.orange),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(secondaryActionText!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NoContentWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionText;
  final IconData icon;

  const NoContentWidget({
    Key? key,
    required this.title,
    required this.message,
    this.onAction,
    this.actionText,
    this.icon = Icons.inbox_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PumpkinColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkStatusBanner extends StatelessWidget {
  final bool isConnected;
  final VoidCallback? onRetry;

  const NetworkStatusBanner({
    Key? key,
    required this.isConnected,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isConnected) return const SizedBox.shrink();

    return Material(
      color: PumpkinColors.errorRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('RETRY'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}