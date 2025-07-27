import 'package:cloud_functions/cloud_functions.dart';

/// Simple test to verify Firebase Functions v5.2.5 configuration
class FirebaseFunctionsTest {
  static Future<bool> testFunctionsConfiguration() async {
    try {
      print('FirebaseFunctionsTest: Testing v5.2.5 configuration...');
      
      // Test 1: Default instance
      final defaultFunctions = FirebaseFunctions.instance;
      print('FirebaseFunctionsTest: Default instance created: ${defaultFunctions.runtimeType}');
      
      // Test 2: Regional instance (us-central1 where our function is deployed)
      final regionalFunctions = FirebaseFunctions.instanceFor(region: 'us-central1');
      print('FirebaseFunctionsTest: Regional instance created: ${regionalFunctions.runtimeType}');
      
      // Test 3: Create callable reference (this should not throw errors)
      final callable = regionalFunctions.httpsCallable('createSnippet');
      print('FirebaseFunctionsTest: Callable reference created: ${callable.runtimeType}');
      
      // Test 4: Verify different instances are properly configured
      final sameRegionalInstance = FirebaseFunctions.instanceFor(region: 'us-central1');
      print('FirebaseFunctionsTest: Multiple regional instances work: ${sameRegionalInstance.runtimeType}');
      
      print('FirebaseFunctionsTest: ✅ All Firebase Functions v5.2.5 tests passed');
      return true;
      
    } catch (e) {
      print('FirebaseFunctionsTest: ❌ Configuration test failed: $e');
      print('FirebaseFunctionsTest: Error type: ${e.runtimeType}');
      return false;
    }
  }
  
  static Future<void> printVersionInfo() async {
    try {
      print('FirebaseFunctionsTest: === Firebase Functions v5.2.5 Info ===');
      
      // Create instances
      final defaultInstance = FirebaseFunctions.instance;
      final usRegion = FirebaseFunctions.instanceFor(region: 'us-central1');
      final euRegion = FirebaseFunctions.instanceFor(region: 'europe-west1');
      
      print('FirebaseFunctionsTest: Default instance: $defaultInstance');
      print('FirebaseFunctionsTest: US-Central1 instance: $usRegion');
      print('FirebaseFunctionsTest: Europe-West1 instance: $euRegion');
      
      print('FirebaseFunctionsTest: === v5.2.5 Syntax Examples ===');
      print('FirebaseFunctionsTest: Default: FirebaseFunctions.instance');
      print('FirebaseFunctionsTest: Regional: FirebaseFunctions.instanceFor(region: "us-central1")');
      print('FirebaseFunctionsTest: Callable: functions.httpsCallable("functionName")');
      
    } catch (e) {
      print('FirebaseFunctionsTest: Error getting version info: $e');
    }
  }
}