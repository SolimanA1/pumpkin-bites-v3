import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum NetworkStatus {
  connected,
  disconnected,
  unknown,
}

enum ConnectionType {
  wifi,
  mobile,
  none,
  unknown,
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final StreamController<NetworkStatus> _statusController = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  ConnectionType _connectionType = ConnectionType.unknown;
  Timer? _connectivityTimer;

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus get currentStatus => _currentStatus;
  ConnectionType get connectionType => _connectionType;

  bool get isConnected => _currentStatus == NetworkStatus.connected;
  bool get isOnWifi => _connectionType == ConnectionType.wifi;
  bool get isOnMobile => _connectionType == ConnectionType.mobile;

  Future<void> initialize() async {
    await _checkConnectivity();
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(NetworkStatus.connected);
      } else {
        _updateStatus(NetworkStatus.disconnected);
      }
    } on SocketException catch (_) {
      _updateStatus(NetworkStatus.disconnected);
    } on TimeoutException catch (_) {
      _updateStatus(NetworkStatus.disconnected);
    } catch (e) {
      if (kDebugMode) {
        print('Network check error: $e');
      }
      _updateStatus(NetworkStatus.unknown);
    }
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  Future<bool> testConnection({String host = 'google.com', Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canReachFirebase() async {
    return await testConnection(host: 'firebase.google.com');
  }

  String getConnectionQualityDescription() {
    switch (_currentStatus) {
      case NetworkStatus.connected:
        return isOnWifi ? 'Connected via Wi-Fi' : 'Connected via Mobile Data';
      case NetworkStatus.disconnected:
        return 'No Internet Connection';
      case NetworkStatus.unknown:
        return 'Connection Status Unknown';
    }
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _statusController.close();
  }
}