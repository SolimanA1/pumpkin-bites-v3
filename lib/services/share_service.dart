import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/bite_model.dart';
import '../services/audio_player_service.dart';
import '../services/snippet_service.dart';
import '../screens/share_dialog.dart';
import '../widgets/instagram_story_generator.dart';

class ShareService {
  // Singleton pattern
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final SnippetService _snippetService = SnippetService();

  // Enhanced share method with dialog for snippet selection
  Future<void> shareBite(BuildContext context, BiteModel bite, {
    AudioPlayerService? audioService,
    Duration? currentPosition,
    Duration? totalDuration,
  }) async {
    try {
      if (audioService != null && currentPosition != null && totalDuration != null) {
        // Show the enhanced share dialog
        await showDialog<bool>(
          context: context,
          builder: (context) => ShareDialog(
            bite: bite,
            audioService: audioService,
            currentPosition: currentPosition,
            totalDuration: totalDuration,
          ),
        );
        
        // The dialog handles everything internally
        return;
      }
      
      // Fallback to simple sharing if no audio service is provided
      await _simpleShare(context, bite);
    } catch (e) {
      print('Error in shareBite: $e');
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share content: $e')),
        );
      } catch (scaffoldError) {
        print('Could not show error snackbar: $scaffoldError');
      }
    }
  }
  
  // Simple share method without snippet selection (for backward compatibility)
  Future<void> _simpleShare(BuildContext context, BiteModel bite) async {
    try {
      // Generate a web link for the bite
      final webLink = await _generateWebLink(bite.id);
      
      // Create a message to share
      final message = _createShareMessage(bite, webLink);
      
      // Use the Share.share from share_plus package
      await Share.share(message, subject: 'Check out this bite from Pumpkin Bites!');
      
      // Track the share in analytics
      _trackShare(bite.id);
    } catch (e) {
      print('Error in _simpleShare: $e');
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share content: $e')),
        );
      } catch (scaffoldError) {
        print('Could not show error snackbar: $scaffoldError');
      }
    }
  }
  
  // Create a share message based on the bite content
  String _createShareMessage(BiteModel bite, String webLink) {
    return '''
I just listened to "${bite.title}" on Pumpkin Bites and thought you might enjoy it too!

${bite.description}

Listen here: $webLink
''';
  }
  
  // Generate a web link using the new snippet service (DEPRECATED)
  Future<String> _generateWebLink(String biteId, {int? startSeconds, int? durationSeconds}) async {
    // Generate a fallback snippet ID for old calls
    final fallbackSnippetId = 'legacy_${biteId}_${DateTime.now().millisecondsSinceEpoch}';
    
    print('WARNING: Using deprecated _generateWebLink method');
    print('WARNING: This should be replaced with createSnippetAndShare for proper snippet URLs');
    
    // Return snippet format URL instead of bite URL
    return 'https://pumpkinbites.com/snippet/$fallbackSnippetId';
  }

  // NEW: Create snippet and share with web URL
  Future<void> createSnippetAndShare(
    BuildContext context,
    BiteModel bite, {
    required Duration startTime,
    required Duration endTime,
    String? personalMessage,
  }) async {
    try {
      print('DEBUG: Starting text sharing for bite: ${bite.title}');
      print('DEBUG: Text sharing - Creating snippet with:');
      print('DEBUG:   Bite ID: ${bite.id}');
      print('DEBUG:   Start time: ${startTime.inSeconds}s');
      print('DEBUG:   End time: ${endTime.inSeconds}s');
      print('DEBUG:   Duration: ${(endTime - startTime).inSeconds}s');
      print('DEBUG:   Audio URL: ${bite.audioUrl}');
      print('DEBUG:   Personal message: ${personalMessage ?? 'none'}');
      
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Creating snippet...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Test Firebase connectivity first
      print('DEBUG: Testing Firebase Functions connectivity for text sharing...');
      final functionsConnected = await testFirebaseFunctionConnectivity();
      print('DEBUG: Text sharing - Firebase Functions connected: $functionsConnected');
      
      // Test basic connectivity first
      print('DEBUG: Text sharing - Testing basic connectivity...');
      final connectivityTest = await testConnectivity();
      print('DEBUG: Text sharing - Connectivity test result: ${connectivityTest ? 'PASSED' : 'FAILED'}');
      
      // Test authentication and permissions
      print('DEBUG: Text sharing - Testing Firebase authentication...');
      final authTestResult = await testFirebaseAuth();
      print('DEBUG: Text sharing - Auth test completed - User logged in: ${authTestResult['user_logged_in']}');
      
      // Run direct function test to diagnose issues
      print('DEBUG: Text sharing - Running direct Firebase Function test...');
      final directTestResult = await testCreateSnippetFunction();
      print('DEBUG: Text sharing - Direct function test result: ${directTestResult != null ? 'SUCCESS' : 'FAILED'}');
      
      final isAvailable = await _snippetService.isSnippetCreationAvailable();
      print('DEBUG: Text sharing - Snippet creation available: $isAvailable');
      
      if (!isAvailable) {
        throw Exception('Snippet creation service is not available - Direct test: ${directTestResult != null ? 'passed' : 'failed'}');
      }
      
      print('DEBUG: Calling SnippetService.createSnippet for text sharing...');
      print('DEBUG: Text sharing - About to call Firebase Function through SnippetService');
      
      final startTime2 = DateTime.now();
      // Create the snippet and get web URL
      final webUrl = await _snippetService.createSnippet(
        bite: bite,
        startTime: startTime,
        endTime: endTime,
      );
      final endTime2 = DateTime.now();

      print('DEBUG: Text sharing - SnippetService call completed in ${endTime2.difference(startTime2).inMilliseconds}ms');
      print('DEBUG: Text sharing - SnippetService returned URL: $webUrl');
      print('DEBUG: Text sharing - URL validation:');
      print('DEBUG:   - starts with https: ${webUrl.startsWith('https://')}');
      print('DEBUG:   - contains pumpkinbites.com: ${webUrl.contains('pumpkinbites.com')}');
      print('DEBUG:   - contains /snippet/ path: ${webUrl.contains('/snippet/')}');
      print('DEBUG:   - URL length: ${webUrl.length}');
      print('DEBUG:   - Full URL: $webUrl');
      
      // Validate the expected format for text sharing
      final expectedPattern = RegExp(r'^https://pumpkinbites\.com/snippet/[a-zA-Z0-9_-]+$');
      final isValidFormat = expectedPattern.hasMatch(webUrl);
      print('DEBUG: Text sharing - Matches expected snippet URL format: $isValidFormat');
      
      if (!isValidFormat) {
        print('ERROR: Text sharing - URL does not match expected format: https://pumpkinbites.com/snippet/[id]');
        print('ERROR: Text sharing - Actual URL: $webUrl');
      }

      // Hide loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Create share message
      final snippetDuration = endTime - startTime;
      final message = _createSnippetShareMessage(bite, webUrl, snippetDuration, personalMessage);
      print('DEBUG: Created share message: $message');

      // Share using the web URL
      print('DEBUG: Initiating share with URL: $webUrl');
      await Share.share(message, subject: 'Check out this bite from Pumpkin Bites!');

      // Track the share
      await _trackSnippetShare(bite.id, startTime, endTime, personalMessage);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snippet created and shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      print('DEBUG: Text sharing completed successfully');
    } catch (e) {
      print('=== TEXT SHARING ERROR ANALYSIS ===');
      print('ERROR: Text sharing failed: $e');
      print('ERROR: Error type: ${e.runtimeType}');
      print('ERROR: Error toString(): ${e.toString()}');
      
      // Detailed error analysis
      if (e.toString().contains('Could not access the audio file')) {
        print('ERROR: Audio access issue detected');
      } else if (e.toString().contains('timed out')) {
        print('ERROR: Timeout issue detected');
      } else if (e.toString().contains('Firebase')) {
        print('ERROR: Firebase-related issue detected');
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        print('ERROR: Network connectivity issue detected');
      } else if (e.toString().contains('permission')) {
        print('ERROR: Permission issue detected');
      } else {
        print('ERROR: Unknown/unexpected error type');
      }
      
      print('ERROR: Full stack trace:');
      print(StackTrace.current.toString());
      print('=== END ERROR ANALYSIS ===');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Get user-friendly error message from SnippetService
        String userMessage = 'Failed to create snippet';
        String detailedMessage = e.toString();
        
        if (e is Exception) {
          userMessage = _snippetService.getUserFriendlyErrorMessage(e);
          print('DEBUG: User-friendly error message: $userMessage');
          print('DEBUG: Original error message: $detailedMessage');
        }
        
        // Show both user-friendly and detailed error for debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userMessage),
                const SizedBox(height: 4),
                Text(
                  'Debug: ${detailedMessage.length > 100 ? '${detailedMessage.substring(0, 100)}...' : detailedMessage}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () {
                // Retry the sharing process
                createSnippetAndShare(context, bite, startTime: startTime, endTime: endTime, personalMessage: personalMessage);
              },
            ),
          ),
        );
      }
    }
  }

  // Create share message for snippets
  String _createSnippetShareMessage(BiteModel bite, String webUrl, Duration snippetDuration, String? personalMessage) {
    final durationText = '${snippetDuration.inMinutes}:${(snippetDuration.inSeconds % 60).toString().padLeft(2, '0')}';
    
    String message = '';
    
    if (personalMessage != null && personalMessage.isNotEmpty) {
      message += '"$personalMessage"\n\n';
    }
    
    message += '''🎧 Listen to this ${durationText} snippet from "${bite.title}" on Pumpkin Bites!

${bite.description}

🔗 Listen here: $webUrl

📱 Get the full Pumpkin Bites experience: https://pumpkinbites.com''';

    return message;
  }
  
  // Track the share in analytics
  Future<void> _trackShare(String biteId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the user's share count
      await _firestore.collection('users').doc(user.uid).update({
        'shares': FieldValue.increment(1),
      });
      
      // Add to share history
      await _firestore.collection('users').doc(user.uid).collection('shares').add({
        'biteId': biteId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update the bite's share count
      await _firestore.collection('bites').doc(biteId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking share: $e');
    }
  }

  // Track snippet shares
  Future<void> _trackSnippetShare(String biteId, Duration startTime, Duration endTime, String? personalMessage) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the user's share count
      await _firestore.collection('users').doc(user.uid).update({
        'shares': FieldValue.increment(1),
        'snippetShares': FieldValue.increment(1),
      });
      
      // Add to share history
      await _firestore.collection('users').doc(user.uid).collection('shares').add({
        'biteId': biteId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'snippet_web',
        'snippetStart': startTime.inSeconds,
        'snippetEnd': endTime.inSeconds,
        'snippetDuration': (endTime - startTime).inSeconds,
        'message': personalMessage ?? '',
      });
      
      // Update the bite's share count
      await _firestore.collection('bites').doc(biteId).update({
        'shareCount': FieldValue.increment(1),
        'snippetShares': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking snippet share: $e');
    }
  }
  
  // Share to Instagram Stories with improved UX
  Future<void> shareToInstagramStories(
    BuildContext context,
    BiteModel bite, {
    required String personalComment,
    required int snippetDuration,
    Duration? startPosition,
  }) async {
    try {
      print('DEBUG: Starting Instagram story sharing for bite: ${bite.title}');
      
      // Step 1: Create snippet and get web URL immediately
      String webLink;
      try {
        final startTime = startPosition ?? Duration.zero;
        final endTime = startTime + Duration(seconds: snippetDuration);
        
        print('DEBUG: Instagram sharing - Creating snippet with:');
        print('DEBUG:   Bite ID: ${bite.id}');
        print('DEBUG:   Start time: ${startTime.inSeconds}s');
        print('DEBUG:   End time: ${endTime.inSeconds}s');
        print('DEBUG:   Duration: ${(endTime - startTime).inSeconds}s');
        print('DEBUG:   Audio URL: ${bite.audioUrl}');
        
        // Show loading for snippet creation
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Creating snippet for Instagram...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }
        
        // Test Firebase connectivity first
        print('DEBUG: Testing Firebase Functions connectivity...');
        final functionsConnected = await testFirebaseFunctionConnectivity();
        print('DEBUG: Firebase Functions connected: $functionsConnected');
        
        // Test basic connectivity first
        print('DEBUG: Testing basic connectivity...');
        final connectivityTest = await testConnectivity();
        print('DEBUG: Connectivity test result: ${connectivityTest ? 'PASSED' : 'FAILED'}');
        
        // Test authentication and permissions
        print('DEBUG: Testing Firebase authentication...');
        final authTestResult = await testFirebaseAuth();
        print('DEBUG: Auth test completed - User logged in: ${authTestResult['user_logged_in']}');
        
        // Run direct function test to diagnose issues
        print('DEBUG: Running direct Firebase Function test...');
        final directTestResult = await testCreateSnippetFunction();
        print('DEBUG: Direct function test result: ${directTestResult != null ? 'SUCCESS' : 'FAILED'}');
        
        final isAvailable = await _snippetService.isSnippetCreationAvailable();
        print('DEBUG: Snippet creation available: $isAvailable');
        
        if (!isAvailable) {
          throw Exception('Snippet creation service is not available - Direct test: ${directTestResult != null ? 'passed' : 'failed'}');
        }
        
        print('DEBUG: Calling SnippetService.createSnippet...');
        print('DEBUG: About to call Firebase Function through SnippetService');
        
        final startTime1 = DateTime.now();
        webLink = await _snippetService.createSnippet(
          bite: bite,
          startTime: startTime,
          endTime: endTime,
        );
        final endTime1 = DateTime.now();
        
        print('DEBUG: SnippetService call completed in ${endTime1.difference(startTime1).inMilliseconds}ms');
        print('DEBUG: SnippetService returned URL: $webLink');
        print('DEBUG: URL validation:');
        print('DEBUG:   - starts with https: ${webLink.startsWith('https://')}');
        print('DEBUG:   - contains pumpkinbites.com: ${webLink.contains('pumpkinbites.com')}');
        print('DEBUG:   - contains /snippet/ path: ${webLink.contains('/snippet/')}');
        print('DEBUG:   - URL length: ${webLink.length}');
        print('DEBUG:   - Full URL: $webLink');
        
        // Validate the expected format
        final expectedPattern = RegExp(r'^https://pumpkinbites\.com/snippet/[a-zA-Z0-9_-]+$');
        final isValidFormat = expectedPattern.hasMatch(webLink);
        print('DEBUG:   - Matches expected snippet URL format: $isValidFormat');
        
        if (!isValidFormat) {
          print('ERROR: URL does not match expected format: https://pumpkinbites.com/snippet/[id]');
          print('ERROR: Actual URL: $webLink');
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      } catch (e) {
        print('ERROR: Failed to create snippet for Instagram: $e');
        print('ERROR: Error type: ${e.runtimeType}');
        print('ERROR: Error details: ${e.toString()}');
        
        // Generate a temporary snippet ID for fallback
        final fallbackSnippetId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
        webLink = 'https://pumpkinbites.com/snippet/$fallbackSnippetId';
        print('DEBUG: Using fallback snippet URL: $webLink');
        print('DEBUG: Note: This fallback URL may not work until snippet is properly created');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
      
      // Step 2: Copy URL to clipboard IMMEDIATELY
      await Clipboard.setData(ClipboardData(text: webLink));
      print('DEBUG: URL copied to clipboard: $webLink');
      
      // Step 3: Show clipboard success notification 
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.link, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Link copied! Add it to your story using Instagram\'s link sticker 📋',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      
      // Step 4: Generate Instagram Story image
      print('DEBUG: Generating Instagram story image...');
      final storyImage = await _generateInstagramStoryImage(
        bite, 
        personalComment, 
        snippetDuration
      );
      print('DEBUG: Instagram story image generated: ${storyImage != null}');
      
      if (storyImage == null) {
        throw Exception('Failed to generate story image');
      }
      
      // Step 5: Save image to temporary file
      final tempDir = await getTemporaryDirectory();
      final imageFile = File('${tempDir.path}/pumpkin_bites_story.png');
      await imageFile.writeAsBytes(storyImage);
      
      // Step 6: Open Instagram with the branded story ready to share
      print('DEBUG: Attempting to open Instagram with story image...');
      
      // Try Instagram-specific sharing first
      if (Platform.isIOS) {
        final instagramUrl = Uri.parse('instagram-stories://share?source_application=pumpkin_bites');
        if (await canLaunchUrl(instagramUrl)) {
          // For iOS, use Instagram URL scheme if available
          await Share.shareXFiles(
            [XFile(imageFile.path)],
          );
        } else {
          // Fallback to regular sharing
          await Share.shareXFiles(
            [XFile(imageFile.path)],
          );
        }
      } else {
        // For Android, use standard sharing with proper MIME type
        await Share.shareXFiles(
          [XFile(imageFile.path, mimeType: 'image/png')],
          subject: 'Pumpkin Bites - ${bite.title}',
        );
      }
      
      // Track the share
      await _trackInstagramShare(bite.id, personalComment, snippetDuration);
      
      print('DEBUG: Instagram sharing flow completed successfully');
      
    } catch (e) {
      print('Error sharing to Instagram Stories: $e');
      if (context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share to Instagram Stories: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (scaffoldError) {
          print('Could not show error snackbar: $scaffoldError');
          print('Failed to share to Instagram Stories: ${e.toString()}');
        }
      }
    }
  }
  
  // TODO: Implement real audio snippet generation with FFmpeg
  // For now, Instagram sharing focuses on image-only content
  
  // Generate Instagram Story image
  Future<Uint8List?> _generateInstagramStoryImage(
    BiteModel bite,
    String personalComment,
    int snippetDuration,
  ) async {
    try {
      print('DEBUG: Creating screenshot controller...');
      final screenshotController = ScreenshotController();
      
      print('DEBUG: Creating story widget...');
      // Create a simplified story widget without complex nesting
      final storyWidget = InstagramStoryGenerator(
        bite: bite,
        personalComment: personalComment,
        snippetDuration: snippetDuration,
        screenshotController: screenshotController,
      );
      
      print('DEBUG: Capturing widget to image...');
      // Capture the image with proper sizing
      final image = await screenshotController.captureFromWidget(
        storyWidget,
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 100),
      );
      
      print('DEBUG: Image captured successfully: ${image.length} bytes');
      return image;
    } catch (e) {
      print('DEBUG: Error generating Instagram story image: $e');
      print('DEBUG: Error stack trace: ${StackTrace.current}');
      return null;
    }
  }
  
  // Track Instagram share
  Future<void> _trackInstagramShare(
    String biteId,
    String personalComment,
    int snippetDuration,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update the user's share count
      await _firestore.collection('users').doc(user.uid).update({
        'shares': FieldValue.increment(1),
        'instagramShares': FieldValue.increment(1),
      });
      
      // Add to share history
      await _firestore.collection('users').doc(user.uid).collection('shares').add({
        'biteId': biteId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'instagram_stories',
        'snippetDuration': snippetDuration,
        'message': personalComment,
      });
      
      // Update the bite's share count
      await _firestore.collection('bites').doc(biteId).update({
        'shareCount': FieldValue.increment(1),
        'instagramShares': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking Instagram share: $e');
    }
  }
  
  // Check if Instagram is available
  Future<bool> isInstagramAvailable() async {
    try {
      // For iOS, check Instagram URL scheme
      if (Platform.isIOS) {
        final uri = Uri.parse('instagram://story-camera');
        return await canLaunchUrl(uri);
      }
      
      // For Android, Instagram sharing works through the standard share intent
      // So we default to true and let the system handle it
      if (Platform.isAndroid) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking Instagram availability: $e');
      return true; // Default to true to show the option
    }
  }
  
  // Quick test to validate Firebase Function connectivity
  Future<bool> testFirebaseFunctionConnectivity() async {
    try {
      print('DEBUG: Testing Firebase Function connectivity...');
      
      // Try to create a simple callable reference
      final callable = _functions.httpsCallable('createSnippet');
      print('DEBUG: Firebase Functions callable created successfully');
      
      // Test if we can access the function (this won't call it, just test accessibility)
      final functionExists = callable != null;
      print('DEBUG: Function accessibility test: $functionExists');
      
      return functionExists;
    } catch (e) {
      print('ERROR: Firebase Function connectivity test failed: $e');
      return false;
    }
  }

  // Direct test of Firebase Function with minimal data
  Future<Map<String, dynamic>?> testCreateSnippetFunction() async {
    try {
      print('=== DIRECT FIREBASE FUNCTION TEST ===');
      print('DEBUG: Testing createSnippet function with minimal data...');
      print('DEBUG: Project ID: pumpkin-bites-jvouko');
      print('DEBUG: Region: us-central1');
      print('DEBUG: Function name: createSnippet');
      
      // Check authentication first
      final user = _auth.currentUser;
      print('DEBUG: User authenticated: ${user != null}');
      if (user != null) {
        print('DEBUG: User ID: ${user.uid}');
        print('DEBUG: User email: ${user.email}');
      }
      
      // Test network connectivity first
      print('DEBUG: Testing network connectivity...');
      try {
        final uri = Uri.parse('https://google.com');
        final request = await HttpClient().getUrl(uri).timeout(const Duration(seconds: 5));
        final response = await request.close().timeout(const Duration(seconds: 5));
        print('DEBUG: ✅ Network connectivity OK (status: ${response.statusCode})');
      } catch (e) {
        print('DEBUG: ❌ Network connectivity failed: $e');
        throw Exception('No internet connection available');
      }

      // Create the callable with enhanced error handling
      HttpsCallable? callable;
      try {
        // Try regional instance first
        callable = _functions.httpsCallable(
          'createSnippet',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 60),
          ),
        );
        print('DEBUG: ✅ Regional callable created with 60s timeout');
      } catch (e) {
        print('DEBUG: ❌ Regional callable failed: $e');
        try {
          // Fallback to default instance
          callable = FirebaseFunctions.instance.httpsCallable(
            'createSnippet',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 60),
            ),
          );
          print('DEBUG: ✅ Default callable created as fallback');
        } catch (e2) {
          print('DEBUG: ❌ Default callable also failed: $e2');
          throw Exception('Cannot create Firebase Functions callable: $e2');
        }
      }
      
      // Test data (minimal but valid) - using correct parameter names
      final testData = {
        'biteId': 'test_bite_123',
        'title': 'Test Bite',
        'category': 'Test',
        'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // FIXED: Use audioUrl as expected by Firebase Function
        'startTime': 10,
        'endTime': 40,
        'duration': '0:30',
        'authorName': 'Test Author',
        'description': 'Test description',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'processingMode': 'server-side',
      };
      
      print('DEBUG: Test data prepared:');
      testData.forEach((key, value) {
        print('DEBUG:   $key: $value');
      });
      
      // Validate audioUrl in test data
      final testAudioUrl = testData['audioUrl'] as String;
      print('DEBUG: audioUrl validation:');
      print('DEBUG:   - audioUrl: "$testAudioUrl"');
      print('DEBUG:   - audioUrl.isEmpty: ${testAudioUrl.isEmpty}');
      print('DEBUG:   - audioUrl.startsWith("http"): ${testAudioUrl.startsWith("http")}');
      
      if (testAudioUrl.isEmpty) {
        throw Exception('Test audioUrl is empty');
      }
      
      print('DEBUG: Testing minimal function call first...');
      try {
        final testResult = await callable.call({'test': true}).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Minimal function test timed out');
          },
        );
        print('DEBUG: ✅ Minimal function call successful: $testResult');
      } catch (e) {
        print('DEBUG: ❌ Minimal function call failed: $e');
        print('DEBUG: This indicates the function exists but may have validation issues');
      }
      
      print('DEBUG: Calling Firebase Function with full test data...');
      final startTime = DateTime.now();
      
      final result = await callable.call(testData);
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      print('DEBUG: Function call completed in ${duration.inMilliseconds}ms');
      print('DEBUG: Raw result: $result');
      print('DEBUG: Result type: ${result.runtimeType}');
      print('DEBUG: Result data: ${result.data}');
      
      if (result.data != null) {
        final data = result.data as Map<String, dynamic>;
        print('DEBUG: Function response data:');
        data.forEach((key, value) {
          print('DEBUG:   $key: $value');
        });
        
        final success = data['success'] ?? false;
        print('DEBUG: Function execution success: $success');
        
        if (success) {
          final url = data['url'];
          final snippetId = data['snippetId'];
          print('DEBUG: Generated URL: $url');
          print('DEBUG: Generated snippet ID: $snippetId');
          print('SUCCESS: Firebase Function test PASSED!');
          return data;
        } else {
          final error = data['error'];
          final code = data['code'];
          print('ERROR: Function execution failed - $code: $error');
          return null;
        }
      } else {
        print('ERROR: Function returned null data');
        return null;
      }
      
    } catch (e) {
      print('ERROR: Direct function test failed: $e');
      print('ERROR: Error type: ${e.runtimeType}');
      
      if (e.toString().contains('UNAUTHENTICATED')) {
        print('ERROR: Authentication issue - user may not be logged in');
      } else if (e.toString().contains('NOT_FOUND')) {
        print('ERROR: Function not found - check function name and deployment');
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        print('ERROR: Permission denied - check Firebase rules and IAM');
      } else if (e.toString().contains('DEADLINE_EXCEEDED')) {
        print('ERROR: Function timeout - check function performance');
      } else if (e.toString().contains('UNAVAILABLE')) {
        print('ERROR: Service unavailable - check Firebase status');
      } else if (e.toString().contains('INTERNAL')) {
        print('ERROR: INTERNAL error - function crashed during execution');
        print('ERROR: Check Firebase Console for function logs');
        print('ERROR: Function may need more memory or timeout settings');
      } else {
        print('ERROR: Unknown error type');
      }
      
      // Print console URLs for debugging
      print('=== FIREBASE DEBUGGING URLS ===');
      print('Function Logs: https://console.firebase.google.com/project/pumpkin-bites-jvouko/functions/logs');
      print('Function Status: https://console.firebase.google.com/project/pumpkin-bites-jvouko/functions');
      print('Cloud Logs: https://console.cloud.google.com/logs/query?project=pumpkin-bites-jvouko');
      
      print('=== END DIRECT FUNCTION TEST ===');
      return null;
    }
  }

  // Debug helper method to test all components
  Future<Map<String, dynamic>> debugShareComponents() async {
    final results = <String, dynamic>{};
    
    try {
      print('DEBUG: Running comprehensive share components test...');
      
      // Test 1: Firebase Auth
      final user = _auth.currentUser;
      results['firebase_auth'] = {
        'available': user != null,
        'uid': user?.uid ?? 'none',
      };
      print('DEBUG: Firebase Auth - Available: ${user != null}');
      
      // Test 2: Firebase Functions availability
      try {
        final callable = _functions.httpsCallable('createSnippet');
        results['firebase_functions'] = {
          'available': true,
          'callable_created': callable != null,
        };
        print('DEBUG: Firebase Functions - Available: true');
      } catch (e) {
        results['firebase_functions'] = {
          'available': false,
          'error': e.toString(),
        };
        print('DEBUG: Firebase Functions - Error: $e');
      }
      
      // Test 3: Storage permissions
      final storageAvailable = await _snippetService.testStoragePermissions();
      results['firebase_storage'] = {
        'available': storageAvailable,
      };
      print('DEBUG: Firebase Storage - Available: $storageAvailable');
      
      // Test 4: Snippet service availability
      final snippetAvailable = await _snippetService.isSnippetCreationAvailable();
      results['snippet_service'] = {
        'available': snippetAvailable,
      };
      print('DEBUG: Snippet Service - Available: $snippetAvailable');
      
      // Test 5: Direct Firebase Function test
      final directFunctionResult = await testCreateSnippetFunction();
      results['direct_function_test'] = {
        'available': directFunctionResult != null,
        'response': directFunctionResult,
      };
      print('DEBUG: Direct Function Test - Success: ${directFunctionResult != null}');
      
      // Test 6: Network connectivity
      try {
        final uri = Uri.parse('https://pumpkinbites.com');
        final request = await HttpClient().getUrl(uri).timeout(const Duration(seconds: 5));
        final response = await request.close().timeout(const Duration(seconds: 5));
        results['network_connectivity'] = {
          'available': response.statusCode == 200,
          'status_code': response.statusCode,
        };
        print('DEBUG: Network Connectivity - Status: ${response.statusCode}');
      } catch (e) {
        results['network_connectivity'] = {
          'available': false,
          'error': e.toString(),
        };
        print('DEBUG: Network Connectivity - Error: $e');
      }
      
      results['overall_status'] = 'completed';
      print('DEBUG: Component test completed successfully');
      
    } catch (e) {
      results['overall_status'] = 'failed';
      results['error'] = e.toString();
      print('DEBUG: Component test failed: $e');
    }
    
    return results;
  }

  // Test Firebase authentication and permissions
  Future<Map<String, dynamic>> testFirebaseAuth() async {
    final authResults = <String, dynamic>{};
    
    try {
      print('=== FIREBASE AUTH TEST ===');
      
      // Test 1: Current user
      final user = _auth.currentUser;
      authResults['user_logged_in'] = user != null;
      print('DEBUG: User logged in: ${user != null}');
      
      if (user != null) {
        authResults['user_id'] = user.uid;
        authResults['user_email'] = user.email;
        authResults['email_verified'] = user.emailVerified;
        
        print('DEBUG: User ID: ${user.uid}');
        print('DEBUG: User email: ${user.email}');
        print('DEBUG: Email verified: ${user.emailVerified}');
        
        // Test 2: Get ID token
        try {
          final idToken = await user.getIdToken();
          final tokenAvailable = idToken?.isNotEmpty ?? false;
          authResults['id_token_available'] = tokenAvailable;
          print('DEBUG: ID token available: $tokenAvailable');
          print('DEBUG: ID token length: ${idToken?.length ?? 0}');
        } catch (e) {
          authResults['id_token_available'] = false;
          authResults['id_token_error'] = e.toString();
          print('ERROR: Getting ID token failed: $e');
        }
        
        // Test 3: Get ID token result with claims
        try {
          final idTokenResult = await user.getIdTokenResult();
          authResults['token_claims_available'] = idTokenResult.claims != null;
          print('DEBUG: Token claims available: ${idTokenResult.claims != null}');
          print('DEBUG: Token claims: ${idTokenResult.claims}');
        } catch (e) {
          authResults['token_claims_available'] = false;
          authResults['token_claims_error'] = e.toString();
          print('ERROR: Getting token claims failed: $e');
        }
      }
      
      // Test 4: Firebase project access
      try {
        // Try to access a simple Firestore collection (this tests project permissions)
        final testDoc = await _firestore.collection('test').limit(1).get().timeout(
          const Duration(seconds: 10),
        );
        authResults['firestore_access'] = true;
        print('DEBUG: Firestore access: SUCCESS');
      } catch (e) {
        authResults['firestore_access'] = false;
        authResults['firestore_error'] = e.toString();
        print('DEBUG: Firestore access: FAILED - $e');
      }
      
      print('=== END FIREBASE AUTH TEST ===');
      return authResults;
      
    } catch (e) {
      authResults['test_failed'] = true;
      authResults['error'] = e.toString();
      print('ERROR: Firebase auth test failed: $e');
      return authResults;
    }
  }

  // Simple connectivity test
  Future<bool> testConnectivity() async {
    try {
      print('=== SIMPLE CONNECTIVITY TEST ===');
      
      // Test 1: Network
      print('DEBUG: Testing network...');
      final uri = Uri.parse('https://google.com');
      final request = await HttpClient().getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      print('DEBUG: Network: ${response.statusCode == 200 ? "✅ OK" : "❌ FAILED"}');
      
      // Test 2: Firebase project connectivity
      print('DEBUG: Testing Firebase project access...');
      try {
        await _firestore.collection('test').limit(1).get().timeout(const Duration(seconds: 10));
        print('DEBUG: Firebase project access: ✅ OK');
      } catch (e) {
        print('DEBUG: Firebase project access: ❌ FAILED - $e');
        return false;
      }
      
      // Test 3: Functions callable creation
      print('DEBUG: Testing Functions callable creation...');
      try {
        final callable = _functions.httpsCallable('createSnippet');
        print('DEBUG: Functions callable: ✅ OK');
      } catch (e) {
        print('DEBUG: Functions callable: ❌ FAILED - $e');
        return false;
      }
      
      print('DEBUG: All connectivity tests passed ✅');
      return true;
    } catch (e) {
      print('DEBUG: Connectivity test failed: $e');
      return false;
    }
  }

  // Get user's share history
  Future<List<Map<String, dynamic>>> getShareHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('shares')
          .orderBy('timestamp', descending: true)
          .get();
      
      final List<Map<String, dynamic>> shares = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final biteId = data['biteId'] as String;
        
        // Get bite details
        try {
          final biteDoc = await _firestore.collection('bites').doc(biteId).get();
          if (biteDoc.exists) {
            final biteData = biteDoc.data()!;
            shares.add({
              'id': doc.id,
              'biteId': biteId,
              'biteTitle': biteData['title'] ?? 'Unknown Bite',
              'timestamp': data['timestamp'],
              'platform': data['platform'] ?? 'default',
              'snippetStart': data['snippetStart'],
              'snippetDuration': data['snippetDuration'],
              'message': data['message'],
            });
          }
        } catch (e) {
          print('Error getting bite details: $e');
        }
      }
      
      return shares;
    } catch (e) {
      print('Error getting share history: $e');
      return [];
    }
  }
}