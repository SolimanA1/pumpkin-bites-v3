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
  
  // Stream controllers for state updates
  final StreamController<bool> _subscriptionStatusController = StreamController<bool>.broadcast();
  final StreamController<bool> _trialStatusController = StreamController<bool>.broadcast();
  final StreamController<int> _trialDaysRemainingController = StreamController<int>.broadcast();
  
  // Getters
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isInTrialPeriod => _isInTrialPeriod;
  DateTime? get trialEndDate => _trialEndDate;
  int get trialDaysRemaining {
    if (!_isInTrialPeriod || _trialEndDate == null) {
      print('⚠️ DEBUG: trialDaysRemaining = 0 (not in trial period or no end date)');
      return 0;
    }
    
    final now = DateTime.now();
    final difference = _trialEndDate!.difference(now);
    
    print('📊 DEBUG: trialDaysRemaining calculation:');
    print('📊 DEBUG: - Current time: $now');
    print('📊 DEBUG: - Trial end date: $_trialEndDate');
    print('📊 DEBUG: - Time difference: $difference');
    print('📊 DEBUG: - Difference in hours: ${difference.inHours}');
    print('📊 DEBUG: - Difference in days (raw): ${difference.inDays}');
    
    // FIXED CALCULATION: Use proper ceiling logic for remaining days
    int daysRemaining;
    if (difference.isNegative || difference.inSeconds <= 0) {
      daysRemaining = 0;
      print('📊 DEBUG: Trial expired, setting to 0');
    } else {
      // Use hours-based calculation with rounding for natural day progression
      final totalHours = difference.inHours;
      final exactDays = totalHours / 24.0;
      daysRemaining = exactDays.round();
      
      print('📊 DEBUG: Total hours remaining: $totalHours');
      print('📊 DEBUG: Exact days remaining: $exactDays');
      print('📊 DEBUG: Calculated days remaining (rounded): $daysRemaining');
    }
    
    final result = daysRemaining.clamp(0, trialDurationDays);
    print('📊 DEBUG: Final result (clamped): $result');
    return result;
  }
  
  // Streams
  Stream<bool> get subscriptionStatusStream => _subscriptionStatusController.stream;
  Stream<bool> get trialStatusStream => _trialStatusController.stream;
  Stream<int> get trialDaysRemainingStream => _trialDaysRemainingController.stream;
  
  bool get hasContentAccess => _isSubscriptionActive || _isInTrialPeriod;
  
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🚀 DEBUG: SubscriptionService already initialized, skipping...');
      return;
    }
    
    try {
      print('🚀 DEBUG: Initializing SubscriptionService...');
      
      // Check if in-app purchase is available
      final bool isAvailable = await _inAppPurchase.isAvailable();
      print('🚀 DEBUG: In-app purchase available: $isAvailable');
      if (!isAvailable) {
        throw Exception('In-app purchase not available');
      }
      
      // Set up auth state listener to reload subscription data when user logs in
      _authSubscription = _auth.authStateChanges().listen((user) async {
        print('🚀 DEBUG: Auth state changed - user: ${user?.uid}');
        if (user != null) {
          print('🚀 DEBUG: User logged in, reloading subscription state...');
          await _loadSubscriptionState();
        } else {
          print('🚀 DEBUG: User logged out, clearing subscription data...');
          _clearSubscriptionData();
        }
      });
      
      // Load existing subscription state (if user is already logged in)
      print('🚀 DEBUG: Loading existing subscription state...');
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
      print('🚀 DEBUG: Updating trial status...');
      _updateTrialStatus();
      
      _isInitialized = true;
      
      print('🚀 DEBUG: SubscriptionService initialized successfully');
      print('🚀 DEBUG: - Is in trial: $_isInTrialPeriod');
      print('🚀 DEBUG: - Trial start: $_trialStartDate');
      print('🚀 DEBUG: - Trial end: $_trialEndDate');
      print('🚀 DEBUG: - Days remaining: $trialDaysRemaining');
      
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
    print('🔍 DEBUG: Clearing subscription data...');
    _isSubscriptionActive = false;
    _isInTrialPeriod = false;
    _trialStartDate = null;
    _trialEndDate = null;
    _subscriptionStartDate = null;
    _updateTrialStatus();
  }

  Future<void> _loadSubscriptionState() async {
    print('🔍 DEBUG: Loading subscription state from Firestore (user-specific)...');
    
    // Get current user
    final user = _auth.currentUser;
    if (user == null) {
      print('🔍 DEBUG: No authenticated user, cannot load subscription state');
      return;
    }
    
    try {
      // Add retry logic for new users - try up to 3 times
      for (int attempt = 0; attempt < 3; attempt++) {
        print('🔍 DEBUG: Loading user document, attempt ${attempt + 1}/3');
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData == null) {
            print('🔍 DEBUG: User document has no data');
            break;
          }
          
          // Load trial start date from Firestore
          final trialStartTimestamp = userData['trialStartDate'] as Timestamp?;
          if (trialStartTimestamp != null) {
            _trialStartDate = trialStartTimestamp.toDate();
            _trialEndDate = _trialStartDate!.add(Duration(days: trialDurationDays));
            
            print('🔍 DEBUG: ✅ Loaded trial start from Firestore: $_trialStartDate');
            print('🔍 DEBUG: ✅ Calculated trial end: $_trialEndDate');
            print('🔍 DEBUG: ✅ Current time: ${DateTime.now()}');
            print('🔍 DEBUG: ✅ Days remaining (raw): ${_trialEndDate!.difference(DateTime.now()).inDays}');
            
            // Load subscription information
            final subscriptionStartTimestamp = userData['subscriptionStartDate'] as Timestamp?;
            if (subscriptionStartTimestamp != null) {
              _subscriptionStartDate = subscriptionStartTimestamp.toDate();
              _isSubscriptionActive = true;
              print('🔍 DEBUG: ✅ Loaded subscription start: $_subscriptionStartDate');
            } else {
              print('🔍 DEBUG: No subscription found');
            }
            
            _updateTrialStatus();
            return; // Success, exit retry loop
          } else {
            // No trial date found - check if this is a very old user who needs migration
            print('🔍 DEBUG: No trial start date found in user document');
            
            final createdAt = userData['createdAt'] as Timestamp?;
            if (createdAt != null) {
              // This is an existing user - use their ORIGINAL creation date for trial start
              print('🔧 DEBUG: MIGRATING old user - using ORIGINAL creation date for trial...');
              print('🔧 DEBUG: User created at: ${createdAt.toDate()}');
              
              _trialStartDate = createdAt.toDate();
              _trialEndDate = _trialStartDate!.add(Duration(days: trialDurationDays));
              
              // Calculate how much time has actually passed since their registration
              final now = DateTime.now();
              final actualDaysElapsed = now.difference(_trialStartDate!).inDays;
              print('🔧 DEBUG: Days elapsed since registration: $actualDaysElapsed');
              
              try {
                await userDoc.reference.update({
                  'trialStartDate': createdAt, // Use ORIGINAL timestamp, not current time
                });
                
                print('🔧 DEBUG: ✅ Migration complete - trial start: $_trialStartDate (ORIGINAL date)');
                print('🔧 DEBUG: ✅ Migration complete - trial end: $_trialEndDate');
                print('🔧 DEBUG: ✅ Migration complete - actual days remaining: ${_trialEndDate!.difference(now).inDays}');
                
                if (actualDaysElapsed >= trialDurationDays) {
                  print('🔧 DEBUG: ⚠️ User trial should be EXPIRED (registered ${actualDaysElapsed} days ago)');
                } else {
                  print('🔧 DEBUG: ✅ User has ${trialDurationDays - actualDaysElapsed} days remaining');
                }
                
                _updateTrialStatus();
                return; // Success
              } catch (migrationError) {
                print('🔧 DEBUG: Error migrating user trial: $migrationError');
              }
            } else {
              print('🔧 DEBUG: No createdAt found, cannot migrate user');
            }
          }
        } else if (attempt < 2) {
          // Document not found, wait and retry (for new users)
          print('🔄 DEBUG: User document not found, retrying in ${attempt + 1}s...');
          await Future.delayed(Duration(seconds: attempt + 1));
        } else {
          print('❌ DEBUG: User document not found after 3 attempts');
        }
      }
      
    } catch (e) {
      print('🔍 DEBUG: Error loading subscription state from Firestore: $e');
    }
    
    _updateTrialStatus();
  }
  
  Future<void> _saveSubscriptionState() async {
    print('💾 DEBUG: Saving subscription state to Firestore (user-specific)...');
    
    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('💾 DEBUG: No authenticated user, cannot save subscription state');
      return;
    }
    
    try {
      final updateData = <String, dynamic>{};
      
      if (_trialStartDate != null) {
        updateData['trialStartDate'] = Timestamp.fromDate(_trialStartDate!);
        print('💾 DEBUG: Will save trial start date to Firestore: $_trialStartDate');
      }
      
      if (_subscriptionStartDate != null) {
        updateData['subscriptionStartDate'] = Timestamp.fromDate(_subscriptionStartDate!);
        print('💾 DEBUG: Will save subscription start date to Firestore: $_subscriptionStartDate');
      }
      
      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);
        print('💾 DEBUG: Subscription state saved to Firestore successfully');
      }
      
    } catch (e) {
      print('💾 DEBUG: Error saving subscription state to Firestore: $e');
    }
  }
  
  void _updateTrialStatus() {
    final now = DateTime.now();
    
    print('🔄 DEBUG: Updating trial status...');
    print('🔄 DEBUG: - Current time: $now');
    print('🔄 DEBUG: - Trial start: $_trialStartDate');
    print('🔄 DEBUG: - Trial end: $_trialEndDate');
    print('🔄 DEBUG: - Is subscription active: $_isSubscriptionActive');
    
    // Check if trial is active
    if (_trialStartDate != null && _trialEndDate != null) {
      final isBeforeEndDate = now.isBefore(_trialEndDate!);
      _isInTrialPeriod = isBeforeEndDate && !_isSubscriptionActive;
      
      print('🔄 DEBUG: - Is before end date: $isBeforeEndDate');
      print('🔄 DEBUG: - Calculated is in trial period: $_isInTrialPeriod');
    } else {
      _isInTrialPeriod = false;
      print('🔄 DEBUG: - No trial dates set, not in trial period');
    }
    
    // Emit status updates
    _subscriptionStatusController.add(_isSubscriptionActive);
    _trialStatusController.add(_isInTrialPeriod);
    _trialDaysRemainingController.add(trialDaysRemaining);
    
    print('🔄 DEBUG: Trial status update completed. Days remaining: $trialDaysRemaining');
  }
  
  Future<void> startFreeTrial() async {
    print('🔥 DEBUG: startFreeTrial called - but trial should already be set during user registration');
    
    if (_trialStartDate != null) {
      print('🚨 DEBUG: Trial already exists - start date: $_trialStartDate, end date: $_trialEndDate');
      print('🚨 DEBUG: Days remaining: $trialDaysRemaining');
      return; // Trial already exists, no need to create a new one
    }
    
    // This should not happen for new users as trial is set during registration
    // But we'll handle it as a fallback
    print('⚠️ DEBUG: No trial found, creating fallback trial');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🚨 DEBUG: No authenticated user, cannot start trial');
      throw Exception('No authenticated user');
    }
    
    final now = DateTime.now();
    print('🔥 DEBUG: Creating fallback trial at: $now (timezone: ${now.timeZoneName})');
    
    _trialStartDate = now;
    _trialEndDate = now.add(Duration(days: trialDurationDays));
    _isInTrialPeriod = true;
    
    await _saveSubscriptionState();
    _updateTrialStatus();
    
    print('🔥 DEBUG: Fallback trial created. Days remaining: $trialDaysRemaining');
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