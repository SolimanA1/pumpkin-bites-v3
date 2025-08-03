import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  late StreamSubscription<User?> _authSubscription;
  
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
  bool _isInitialized = false;
  bool _isInAppPurchaseAvailable = false;
  
  // Performance optimization: Cache trial calculations
  int? _cachedTrialDaysRemaining;
  DateTime? _lastTrialCalculation;
  static const Duration _cacheValidityDuration = Duration(minutes: 1); // Cache for 1 minute
  
  // Performance optimization: Cache status to prevent unnecessary stream emissions
  bool? _lastEmittedSubscriptionStatus;
  bool? _lastEmittedTrialStatus;
  int? _lastEmittedTrialDaysRemaining;
  
  // Stream controllers for state updates
  final StreamController<bool> _subscriptionStatusController = StreamController<bool>.broadcast();
  final StreamController<bool> _trialStatusController = StreamController<bool>.broadcast();
  final StreamController<int> _trialDaysRemainingController = StreamController<int>.broadcast();
  
  // Getters
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isInTrialPeriod => _isInTrialPeriod;
  DateTime? get trialEndDate => _trialEndDate;
  bool get isSubscriptionFeaturesAvailable => _isInAppPurchaseAvailable;
  int get trialDaysRemaining {
    if (!_isInTrialPeriod || _trialEndDate == null) {
      return 0;
    }
    
    // Performance optimization: Use cached value if still valid
    final now = DateTime.now();
    if (_cachedTrialDaysRemaining != null && 
        _lastTrialCalculation != null &&
        now.difference(_lastTrialCalculation!).abs() < _cacheValidityDuration) {
      return _cachedTrialDaysRemaining!;
    }
    
    // Calculate and cache the result
    final difference = _trialEndDate!.difference(now);
    
    int daysRemaining;
    if (difference.isNegative || difference.inSeconds <= 0) {
      daysRemaining = 0;
    } else {
      // Use hours-based calculation with rounding for natural day progression
      final totalHours = difference.inHours;
      final exactDays = totalHours / 24.0;
      daysRemaining = exactDays.round();
    }
    
    final result = daysRemaining.clamp(0, trialDurationDays);
    
    // Cache the result
    _cachedTrialDaysRemaining = result;
    _lastTrialCalculation = now;
    
    return result;
  }
  
  // Streams
  Stream<bool> get subscriptionStatusStream => _subscriptionStatusController.stream;
  Stream<bool> get trialStatusStream => _trialStatusController.stream;
  Stream<int> get trialDaysRemainingStream => _trialDaysRemainingController.stream;
  
  bool get hasContentAccess => _isSubscriptionActive || _isInTrialPeriod;
  
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Check if in-app purchase is available
      final bool isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        _isInitialized = true;
        _isInAppPurchaseAvailable = false;
        return; // Continue without subscription features
      }
      
      _isInAppPurchaseAvailable = true;
      
      // Set up auth state listener to reload subscription data when user logs in
      _authSubscription = _auth.authStateChanges().listen((user) async {
        if (user != null) {
          await _loadSubscriptionState();
        } else {
          _clearSubscriptionData();
        }
      });
      
      // Load existing subscription state (if user is already logged in)
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
      
      _isInitialized = true;
      
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
  
  void _clearSubscriptionData() {
    _isSubscriptionActive = false;
    _isInTrialPeriod = false;
    _trialStartDate = null;
    _trialEndDate = null;
    _subscriptionStartDate = null;
    _updateTrialStatus();
  }

  Future<void> _loadSubscriptionState() async {
    // Get current user
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    
    try {
      // Add retry logic for new users - try up to 3 times
      for (int attempt = 0; attempt < 3; attempt++) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData == null) {
            break;
          }
          
          // Load trial start date from Firestore
          final trialStartTimestamp = userData['trialStartDate'] as Timestamp?;
          if (trialStartTimestamp != null) {
            _trialStartDate = trialStartTimestamp.toDate();
            _trialEndDate = _trialStartDate!.add(Duration(days: trialDurationDays));
            
            // Load subscription information
            final subscriptionStartTimestamp = userData['subscriptionStartDate'] as Timestamp?;
            if (subscriptionStartTimestamp != null) {
              _subscriptionStartDate = subscriptionStartTimestamp.toDate();
              _isSubscriptionActive = true;
            }
            
            _updateTrialStatus();
            return; // Success, exit retry loop
          } else {
            // No trial date found - check if this is a very old user who needs migration
            final createdAt = userData['createdAt'] as Timestamp?;
            if (createdAt != null) {
              // This is an existing user - use their ORIGINAL creation date for trial start
              _trialStartDate = createdAt.toDate();
              _trialEndDate = _trialStartDate!.add(Duration(days: trialDurationDays));
              
              try {
                await userDoc.reference.update({
                  'trialStartDate': createdAt, // Use ORIGINAL timestamp, not current time
                });
                
                _updateTrialStatus();
                return; // Success
              } catch (migrationError) {
                print('Error migrating user trial: $migrationError');
              }
            }
          }
        } else if (attempt < 2) {
          // Document not found, wait and retry (for new users)
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
      
    } catch (e) {
      print('Error loading subscription state from Firestore: $e');
    }
    
    _updateTrialStatus();
  }
  
  Future<void> _saveSubscriptionState() async {
    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    
    try {
      final updateData = <String, dynamic>{};
      
      if (_trialStartDate != null) {
        updateData['trialStartDate'] = Timestamp.fromDate(_trialStartDate!);
      }
      
      if (_subscriptionStartDate != null) {
        updateData['subscriptionStartDate'] = Timestamp.fromDate(_subscriptionStartDate!);
      }
      
      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);
      }
      
    } catch (e) {
      print('Error saving subscription state to Firestore: $e');
    }
  }
  
  void _updateTrialStatus() {
    final now = DateTime.now();
    
    // Check if trial is active
    if (_trialStartDate != null && _trialEndDate != null) {
      final isBeforeEndDate = now.isBefore(_trialEndDate!);
      _isInTrialPeriod = isBeforeEndDate && !_isSubscriptionActive;
    } else {
      _isInTrialPeriod = false;
    }
    
    // Performance optimization: Only emit if values have actually changed
    final currentTrialDaysRemaining = trialDaysRemaining;
    
    if (_lastEmittedSubscriptionStatus != _isSubscriptionActive) {
      _subscriptionStatusController.add(_isSubscriptionActive);
      _lastEmittedSubscriptionStatus = _isSubscriptionActive;
    }
    
    if (_lastEmittedTrialStatus != _isInTrialPeriod) {
      _trialStatusController.add(_isInTrialPeriod);
      _lastEmittedTrialStatus = _isInTrialPeriod;
    }
    
    if (_lastEmittedTrialDaysRemaining != currentTrialDaysRemaining) {
      _trialDaysRemainingController.add(currentTrialDaysRemaining);
      _lastEmittedTrialDaysRemaining = currentTrialDaysRemaining;
    }
  }
  
  Future<void> startFreeTrial() async {
    if (_trialStartDate != null) {
      return; // Trial already exists, no need to create a new one
    }
    
    // This should not happen for new users as trial is set during registration
    // But we'll handle it as a fallback
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
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
    _authSubscription.cancel();
    _subscriptionStatusController.close();
    _trialStatusController.close();
    _trialDaysRemainingController.close();
  }
}