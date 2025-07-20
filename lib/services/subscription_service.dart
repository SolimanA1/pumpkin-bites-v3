import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Product configuration
  static const String monthlyProductId = 'pumpkin_bites_monthly';
  static const int trialDurationDays = 7;
  
  // State management
  bool _isSubscriptionActive = false;
  bool _isInTrialPeriod = false;
  DateTime? _trialStartDate;
  DateTime? _trialEndDate;
  DateTime? _subscriptionStartDate;
  List<ProductDetails> _products = [];
  
  // Stream controllers for state updates
  final StreamController<bool> _subscriptionStatusController = StreamController<bool>.broadcast();
  final StreamController<bool> _trialStatusController = StreamController<bool>.broadcast();
  final StreamController<int> _trialDaysRemainingController = StreamController<int>.broadcast();
  
  // Getters
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isInTrialPeriod => _isInTrialPeriod;
  DateTime? get trialEndDate => _trialEndDate;
  int get trialDaysRemaining {
    if (!_isInTrialPeriod || _trialEndDate == null) return 0;
    final now = DateTime.now();
    final difference = _trialEndDate!.difference(now);
    return difference.inDays.clamp(0, trialDurationDays);
  }
  
  // Streams
  Stream<bool> get subscriptionStatusStream => _subscriptionStatusController.stream;
  Stream<bool> get trialStatusStream => _trialStatusController.stream;
  Stream<int> get trialDaysRemainingStream => _trialDaysRemainingController.stream;
  
  bool get hasContentAccess => _isSubscriptionActive || _isInTrialPeriod;
  
  Future<void> initialize() async {
    try {
      // Check if in-app purchase is available
      final bool isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        throw Exception('In-app purchase not available');
      }
      
      // Load existing subscription state
      await _loadSubscriptionState();
      
      // Set up purchase updates listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('Purchase stream error: $error'),
      );
      
      // Load product details
      await _loadProducts();
      
      // Check and update trial status
      _updateTrialStatus();
      
    } catch (e) {
      print('Subscription service initialization error: $e');
    }
  }
  
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = {monthlyProductId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }
      
      _products = response.productDetails;
    } catch (e) {
      print('Error loading products: $e');
    }
  }
  
  Future<void> _loadSubscriptionState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load trial information
    final trialStartMillis = prefs.getInt('trial_start_date');
    if (trialStartMillis != null) {
      _trialStartDate = DateTime.fromMillisecondsSinceEpoch(trialStartMillis);
      _trialEndDate = _trialStartDate!.add(Duration(days: trialDurationDays));
    }
    
    // Load subscription information
    final subscriptionStartMillis = prefs.getInt('subscription_start_date');
    if (subscriptionStartMillis != null) {
      _subscriptionStartDate = DateTime.fromMillisecondsSinceEpoch(subscriptionStartMillis);
      _isSubscriptionActive = true;
    }
    
    _updateTrialStatus();
  }
  
  Future<void> _saveSubscriptionState() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_trialStartDate != null) {
      await prefs.setInt('trial_start_date', _trialStartDate!.millisecondsSinceEpoch);
    }
    
    if (_subscriptionStartDate != null) {
      await prefs.setInt('subscription_start_date', _subscriptionStartDate!.millisecondsSinceEpoch);
    }
  }
  
  void _updateTrialStatus() {
    final now = DateTime.now();
    
    // Check if trial is active
    if (_trialStartDate != null && _trialEndDate != null) {
      _isInTrialPeriod = now.isBefore(_trialEndDate!) && !_isSubscriptionActive;
    }
    
    // Emit status updates
    _subscriptionStatusController.add(_isSubscriptionActive);
    _trialStatusController.add(_isInTrialPeriod);
    _trialDaysRemainingController.add(trialDaysRemaining);
  }
  
  Future<void> startFreeTrial() async {
    if (_trialStartDate != null) {
      throw Exception('Trial already started');
    }
    
    final now = DateTime.now();
    _trialStartDate = now;
    _trialEndDate = now.add(Duration(days: trialDurationDays));
    _isInTrialPeriod = true;
    
    await _saveSubscriptionState();
    _updateTrialStatus();
  }
  
  Future<bool> purchaseSubscription() async {
    try {
      if (_products.isEmpty) {
        await _loadProducts();
      }
      
      final productDetails = _products.firstWhere(
        (product) => product.id == monthlyProductId,
        orElse: () => throw Exception('Product not found'),
      );
      
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      if (Platform.isIOS) {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
      
      return true;
    } catch (e) {
      print('Purchase error: $e');
      return false;
    }
  }
  
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Restore purchases error: $e');
    }
  }
  
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending purchase
        continue;
      }
      
      if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
        print('Purchase error: ${purchaseDetails.error}');
        continue;
      }
      
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        
        // Verify the purchase
        if (purchaseDetails.productID == monthlyProductId) {
          await _activateSubscription();
        }
        
        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }
  
  Future<void> _activateSubscription() async {
    _isSubscriptionActive = true;
    _isInTrialPeriod = false;
    _subscriptionStartDate = DateTime.now();
    
    await _saveSubscriptionState();
    _updateTrialStatus();
  }
  
  void dispose() {
    _subscription.cancel();
    _subscriptionStatusController.close();
    _trialStatusController.close();
    _trialDaysRemainingController.close();
  }
}