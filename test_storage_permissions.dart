import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/snippet_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== FIREBASE STORAGE PERMISSIONS TEST ===');
  print('This script will test if Firebase Storage permissions are working');
  print('Make sure you have updated the Storage Rules in Firebase Console');
  print('');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Test storage permissions
    final snippetService = SnippetService();
    
    print('');
    print('Testing Firebase Storage permissions...');
    final permissionsWork = await snippetService.testStoragePermissions();
    
    if (permissionsWork) {
      print('');
      print('🎉 SUCCESS: Firebase Storage permissions are working!');
      print('The entire system should now work correctly.');
      print('');
      print('Next steps:');
      print('1. Your app should now handle snippet creation properly');
      print('2. Both Instagram and text sharing should work');
      print('3. URLs should be in the correct format: https://pumpkinbites.com/snippet/[id]');
    } else {
      print('');
      print('❌ FAILED: Firebase Storage permissions still not working');
      print('');
      print('Please check:');
      print('1. Go to: https://console.firebase.google.com/project/pumpkin-bites-jvouko/storage/rules');
      print('2. Add this rule inside match /b/{bucket}/o:');
      print('   match /snippets/{allPaths=**} {');
      print('     allow read, write: if request.auth != null;');
      print('   }');
      print('3. Click "Publish" to save the rules');
      print('4. Run this test again');
    }
  } catch (e) {
    print('❌ ERROR: $e');
    print('');
    print('Make sure you are logged in to the app first, then run this test');
  }
}