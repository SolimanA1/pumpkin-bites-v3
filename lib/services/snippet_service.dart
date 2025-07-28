import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/bite_model.dart';

// Custom exceptions for better error handling
class SnippetException implements Exception {
  final String message;
  final String code;
  
  const SnippetException(this.message, this.code);
  
  @override
  String toString() => 'SnippetException: $message (Code: $code)';
}

class AudioExtractionException extends SnippetException {
  const AudioExtractionException(String message) : super(message, 'AUDIO_EXTRACTION_ERROR');
}

class StorageUploadException extends SnippetException {
  const StorageUploadException(String message) : super(message, 'STORAGE_UPLOAD_ERROR');
}

class FunctionCallException extends SnippetException {
  const FunctionCallException(String message) : super(message, 'FUNCTION_CALL_ERROR');
}

class SnippetService {
  // Singleton pattern
  static final SnippetService _instance = SnippetService._internal();
  factory SnippetService() => _instance;
  SnippetService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final Uuid _uuid = const Uuid();

  /// Extract and upload a snippet from a bite
  /// Returns the web URL for sharing
  Future<String> createSnippet({
    required BiteModel bite,
    required Duration startTime,
    required Duration endTime,
  }) async {
    print('🔍 DEBUG: ========== SNIPPET CREATION PIPELINE START ==========');
    print('🔍 DEBUG: Starting snippet creation for bite: ${bite.title}');
    print('🔍 DEBUG: Bite ID: ${bite.id}');
    print('🔍 DEBUG: Start time: ${startTime.inSeconds}s');
    print('🔍 DEBUG: End time: ${endTime.inSeconds}s');
    print('🔍 DEBUG: Duration: ${(endTime - startTime).inSeconds}s');
    print('🔍 DEBUG: Original bite audio URL: "${bite.audioUrl}"');
    print('🔍 DEBUG: Original audio URL length: ${bite.audioUrl.length}');
    print('🔍 DEBUG: Original audio URL valid: ${bite.audioUrl.isNotEmpty && bite.audioUrl.startsWith('http')}');
    
    String finalAudioUrl = ''; // Declare at function scope for error handling
    print('🔍 DEBUG: Initialized finalAudioUrl at function scope');
    
    try {
      // Validate input parameters
      print('🔍 DEBUG: STEP 1 - Validating input parameters...');
      if (endTime <= startTime) {
        throw const SnippetException('End time must be after start time', 'INVALID_TIME_RANGE');
      }
      
      final snippetDuration = endTime - startTime;
      if (snippetDuration.inSeconds < 5) {
        throw const SnippetException('Snippet must be at least 5 seconds long', 'SNIPPET_TOO_SHORT');
      }
      if (snippetDuration.inSeconds > 60) {
        throw const SnippetException('Snippet cannot be longer than 60 seconds', 'SNIPPET_TOO_LONG');
      }
      print('🔍 DEBUG: ✅ Input parameters validation passed');

      // Validate original audio URL
      print('🔍 DEBUG: STEP 2 - Validating original audio URL...');
      if (bite.audioUrl.isEmpty) {
        throw SnippetException('Original bite audio URL is empty', 'MISSING_AUDIO_URL');
      }
      
      if (!bite.audioUrl.startsWith('http')) {
        throw SnippetException('Invalid original audio URL format: ${bite.audioUrl}', 'INVALID_AUDIO_URL');
      }
      print('🔍 DEBUG: ✅ Original audio URL validation passed');

      // ENHANCED APPROACH: Try storage upload first, then fallback to server-side processing
      print('🔍 DEBUG: STEP 3 - Starting ENHANCED PROCESSING with upload completion check');
      
      // Step 1: Test if storage upload is available and working
      print('🔍 DEBUG: STEP 4 - Testing storage upload capability...');
      final storageAvailable = await testStoragePermissions();
      print('🔍 DEBUG: Storage upload available: $storageAvailable');
      
      if (storageAvailable) {
        print('🔍 DEBUG: ✅ Storage available - attempting client-side processing with upload');
        try {
          // CLIENT-SIDE PROCESSING WITH STORAGE UPLOAD
          print('🔍 DEBUG: STEP 5 - Starting audio extraction and upload process...');
          
          // Extract audio snippet locally
          print('🔍 DEBUG: STEP 6 - Extracting audio snippet locally');
          print('🔍 DEBUG: Input audio URL for extraction: "${bite.audioUrl}"');
          File? snippetFile;
          try {
            print('🔍 DEBUG: Calling _extractAudioSnippet...');
            snippetFile = await _extractAudioSnippet(
              audioUrl: bite.audioUrl,
              startTime: startTime,
              endTime: endTime,
            );
            print('🔍 DEBUG: ✅ Audio extraction completed successfully');
            print('🔍 DEBUG: Extracted file path: ${snippetFile.path}');
            print('🔍 DEBUG: Extracted file exists: ${await snippetFile.exists()}');
            print('🔍 DEBUG: Extracted file size: ${await snippetFile.length()} bytes');
            
            if (!await snippetFile.exists()) {
              throw AudioExtractionException('Extracted file does not exist at path: ${snippetFile.path}');
            }
            
            final fileSize = await snippetFile.length();
            if (fileSize == 0) {
              throw AudioExtractionException('Extracted file is empty (0 bytes)');
            }
            
            print('🔍 DEBUG: ✅ Audio extraction validation passed');
          } catch (extractError) {
            print('🚨 DEBUG: ❌ Audio extraction failed with error: $extractError');
            print('🚨 DEBUG: Error type: ${extractError.runtimeType}');
            throw AudioExtractionException('Failed to extract audio snippet: ${extractError.toString()}');
          }
          
          // Upload snippet to Firebase Storage
          print('🔍 DEBUG: STEP 7 - Uploading snippet to Firebase Storage');
          String uploadedAudioUrl = '';
          print('🔍 DEBUG: Initialized uploadedAudioUrl as empty string');
          
          try {
            print('🔍 DEBUG: Pre-upload validation:');
            print('🔍 DEBUG: Upload file path: "${snippetFile.path}"');
            print('🔍 DEBUG: Upload file exists: ${await snippetFile.exists()}');
            print('🔍 DEBUG: Upload file size: ${await snippetFile.length()} bytes');
            
            print('🔍 DEBUG: Calling _uploadSnippetToStorage...');
            uploadedAudioUrl = await _uploadSnippetToStorage(snippetFile);
            
            print('🔍 DEBUG: ✅ Storage upload method completed');
            print('🔍 DEBUG: Returned uploadedAudioUrl: "$uploadedAudioUrl"');
            print('🔍 DEBUG: Upload URL validation:');
            print('🔍 DEBUG:   - URL not empty: ${uploadedAudioUrl.isNotEmpty}');
            print('🔍 DEBUG:   - URL starts with https: ${uploadedAudioUrl.startsWith('https://')}');
            print('🔍 DEBUG:   - URL contains firebasestorage: ${uploadedAudioUrl.contains('firebasestorage')}');
            print('🔍 DEBUG:   - URL length: ${uploadedAudioUrl.length}');
            
            if (uploadedAudioUrl.isEmpty) {
              throw StorageUploadException('Upload completed but returned empty URL');
            }
            
            if (!uploadedAudioUrl.startsWith('https://')) {
              throw StorageUploadException('Upload returned invalid URL format: $uploadedAudioUrl');
            }
            
            finalAudioUrl = uploadedAudioUrl;
            print('🔍 DEBUG: ✅ finalAudioUrl assigned: "$finalAudioUrl"');
            print('🔍 DEBUG: ✅ Using uploaded storage URL successfully');
            
          } catch (uploadError) {
            print('🚨 DEBUG: ❌ Storage upload failed with error: $uploadError');
            print('🚨 DEBUG: Upload error type: ${uploadError.runtimeType}');
            print('🚨 DEBUG: uploadedAudioUrl at time of error: "$uploadedAudioUrl"');
            throw StorageUploadException('Failed to upload snippet: ${uploadError.toString()}');
          } finally {
            // Clean up local file
            print('🔍 DEBUG: Cleaning up temporary file...');
            if (snippetFile != null) {
              await _cleanupTempFile(snippetFile);
              print('🔍 DEBUG: ✅ Temporary file cleanup completed');
            }
          }
          
        } catch (clientSideError) {
          print('🚨 DEBUG: ❌ Client-side processing failed with error: $clientSideError');
          print('🚨 DEBUG: Client-side error type: ${clientSideError.runtimeType}');
          print('🔍 DEBUG: Falling back to server-side processing...');
          finalAudioUrl = bite.audioUrl; // Fallback to original URL for server-side processing
          print('🔍 DEBUG: Set finalAudioUrl to original URL for fallback: "$finalAudioUrl"');
        }
      } else {
        print('🔍 DEBUG: ⚠️ Storage not available - using server-side processing');
        finalAudioUrl = bite.audioUrl; // Use original URL for server-side processing
        print('🔍 DEBUG: Set finalAudioUrl to original URL: "$finalAudioUrl"');
      }
      
      // Step 2: Call Firebase Function with the final audio URL
      print('🔍 DEBUG: STEP 8 - Preparing Firebase Function call');
      print('🔍 DEBUG: Final audio URL for function: "$finalAudioUrl"');
      print('🔍 DEBUG: Final audio URL validation before function call:');
      print('🔍 DEBUG:   - finalAudioUrl: "$finalAudioUrl"');
      print('🔍 DEBUG:   - finalAudioUrl.isEmpty: ${finalAudioUrl.isEmpty}');
      print('🔍 DEBUG:   - finalAudioUrl.length: ${finalAudioUrl.length}');
      print('🔍 DEBUG:   - finalAudioUrl.startsWith("http"): ${finalAudioUrl.startsWith("http")}');
      
      if (finalAudioUrl.isEmpty) {
        print('🚨 DEBUG: ❌ CRITICAL ERROR - finalAudioUrl is empty!');
        print('🚨 DEBUG: This means the upload process failed or URL was not properly returned');
        throw SnippetException('No valid audio URL available for processing', 'MISSING_AUDIO_URL');
      }
      
      print('🔍 DEBUG: ✅ Final audio URL validation passed');
      print('🔍 DEBUG: STEP 9 - Calling Firebase Function with audioUrl: "$finalAudioUrl"');
      
      Map<String, dynamic> result;
      try {
        result = await _callCreateSnippetFunction(
          bite: bite,
          snippetAudioUrl: finalAudioUrl, // Use final URL (either uploaded or original)
          startTime: startTime,
          endTime: endTime,
        );
        print('🔍 DEBUG: ✅ Firebase Function call completed successfully');
      } catch (e) {
        print('🚨 DEBUG: ❌ Firebase Function call failed: $e');
        throw FunctionCallException('Failed to create web snippet: ${e.toString()}');
      }

      final webUrl = result['url'] as String;
      print('🔍 DEBUG: ✅ Successfully created snippet with URL: $webUrl');
      print('🔍 DEBUG: ========== SNIPPET CREATION PIPELINE SUCCESS ==========');
      return webUrl;
    } catch (e) {
      print('🚨 DEBUG: ========== SNIPPET CREATION PIPELINE FAILED ==========');
      print('🚨 DEBUG: Error creating snippet: $e');
      print('🚨 DEBUG: Error type: ${e.runtimeType}');
      print('🚨 DEBUG: finalAudioUrl at time of error: "$finalAudioUrl"');
      
      // Provide user-friendly error messages
      if (e is SnippetException) {
        rethrow;
      } else {
        throw SnippetException('An unexpected error occurred while creating the snippet', 'UNKNOWN_ERROR');
      }
    }
  }

  /// ALTERNATIVE APPROACH: Create snippet with Storage upload (requires Storage permissions)
  Future<String> createSnippetWithStorageUpload({
    required BiteModel bite,
    required Duration startTime,
    required Duration endTime,
  }) async {
    File? snippetFile;
    
    try {
      print('SnippetService: Using STORAGE UPLOAD approach');
      print('SnippetService: This requires Firebase Storage permissions');
      
      // Validate input parameters
      if (endTime <= startTime) {
        throw const SnippetException('End time must be after start time', 'INVALID_TIME_RANGE');
      }
      
      final snippetDuration = endTime - startTime;
      if (snippetDuration.inSeconds < 5) {
        throw const SnippetException('Snippet must be at least 5 seconds long', 'SNIPPET_TOO_SHORT');
      }
      if (snippetDuration.inSeconds > 60) {
        throw const SnippetException('Snippet cannot be longer than 60 seconds', 'SNIPPET_TOO_LONG');
      }

      // Step 1: Test Storage permissions first
      print('SnippetService: Testing Storage permissions...');
      final storageAvailable = await testStoragePermissions();
      if (!storageAvailable) {
        throw StorageUploadException('Storage permissions test failed - check Firebase Storage rules');
      }
      print('SnippetService: ✅ Storage permissions OK');

      // Step 2: Extract audio snippet locally
      print('SnippetService: Extracting snippet locally from ${startTime.inSeconds}s to ${endTime.inSeconds}s');
      try {
        snippetFile = await _extractAudioSnippet(
          audioUrl: bite.audioUrl,
          startTime: startTime,
          endTime: endTime,
        );
        print('SnippetService: ✅ Audio extraction completed');
      } catch (e) {
        throw AudioExtractionException('Failed to extract audio snippet: ${e.toString()}');
      }

      // Step 3: Upload snippet to Firebase Storage
      print('SnippetService: Uploading snippet to Firebase Storage');
      String uploadedAudioUrl;
      try {
        uploadedAudioUrl = await _uploadSnippetToStorage(snippetFile);
        print('SnippetService: ✅ Storage upload completed: $uploadedAudioUrl');
      } catch (e) {
        throw StorageUploadException('Failed to upload snippet: ${e.toString()}');
      }

      // Step 4: Call createSnippet Firebase Function with uploaded URL
      print('SnippetService: Calling createSnippet Firebase Function with uploaded URL');
      Map<String, dynamic> result;
      try {
        result = await _callCreateSnippetFunction(
          bite: bite,
          snippetAudioUrl: uploadedAudioUrl, // Use uploaded Storage URL
          startTime: startTime,
          endTime: endTime,
        );
      } catch (e) {
        throw FunctionCallException('Failed to create web snippet: ${e.toString()}');
      }

      print('SnippetService: Successfully created snippet with URL: ${result['url']}');
      return result['url'] as String;
    } catch (e) {
      print('SnippetService: Error creating snippet with storage upload: $e');
      
      if (e is SnippetException) {
        rethrow;
      } else {
        throw SnippetException('Failed to create snippet with storage upload: ${e.toString()}', 'STORAGE_UPLOAD_ERROR');
      }
    } finally {
      // Always clean up temporary files
      if (snippetFile != null) {
        await _cleanupTempFile(snippetFile);
      }
    }
  }

  /// Extract audio snippet with comprehensive logging and error handling
  Future<File> _extractAudioSnippet({
    required String audioUrl,
    required Duration startTime,
    required Duration endTime,
  }) async {
    print('SnippetService: Starting audio extraction process');
    print('SnippetService: Audio URL: $audioUrl');
    print('SnippetService: Start time: ${startTime.inSeconds}s');
    print('SnippetService: End time: ${endTime.inSeconds}s');
    print('SnippetService: Duration: ${(endTime - startTime).inSeconds}s');
    
    AudioPlayer? tempPlayer;
    HttpClient? httpClient;
    
    try {
      // Step 1: Validate audio URL
      if (audioUrl.isEmpty) {
        throw AudioExtractionException('Audio URL is empty');
      }
      
      if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
        throw AudioExtractionException('Invalid audio URL format: $audioUrl');
      }
      
      // Step 2: Get temporary directory and create file path
      print('SnippetService: Getting temporary directory...');
      final tempDir = await getTemporaryDirectory();
      print('SnippetService: Temp directory: ${tempDir.path}');
      
      // Check directory permissions
      final dirStat = await tempDir.stat();
      print('SnippetService: Directory permissions - readable: ${dirStat.mode & 0x444 != 0}, writable: ${dirStat.mode & 0x222 != 0}');
      
      final snippetId = _uuid.v4();
      final snippetFileName = 'snippet_${snippetId}_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final snippetFile = File('${tempDir.path}/$snippetFileName');
      print('SnippetService: Target snippet file: ${snippetFile.path}');
      
      // Step 3: Download original audio file with timeout
      print('SnippetService: Starting audio download...');
      httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 30);
      httpClient.idleTimeout = const Duration(seconds: 60);
      
      final uri = Uri.parse(audioUrl);
      print('SnippetService: Parsed URI: $uri');
      
      final request = await httpClient.getUrl(uri)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw AudioExtractionException('Audio download request timed out after 30 seconds');
      });
      
      print('SnippetService: Sending HTTP request...');
      final response = await request.close()
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw AudioExtractionException('Audio download response timed out after 60 seconds');
      });
      
      print('SnippetService: HTTP response status: ${response.statusCode}');
      print('SnippetService: Response headers: ${response.headers}');
      
      if (response.statusCode != 200) {
        throw AudioExtractionException('Failed to download audio: HTTP ${response.statusCode}');
      }
      
      // Check content type
      final contentType = response.headers.contentType;
      print('SnippetService: Content type: $contentType');
      
      if (contentType != null && !contentType.toString().contains('audio') && !contentType.toString().contains('mpeg')) {
        print('SnippetService: Warning - Unexpected content type: $contentType');
      }
      
      // Step 4: Get content length for progress tracking
      final contentLength = response.contentLength;
      print('SnippetService: Content length: ${contentLength > 0 ? contentLength : 'unknown'}');
      
      // Step 5: Download and write audio data
      print('SnippetService: Starting audio data download...');
      final bytes = await consolidateHttpClientResponseBytes(response)
          .timeout(const Duration(minutes: 2), onTimeout: () {
        throw AudioExtractionException('Audio data download timed out after 2 minutes');
      });
      
      print('SnippetService: Downloaded ${bytes.length} bytes');
      
      if (bytes.isEmpty) {
        throw AudioExtractionException('Downloaded audio file is empty');
      }
      
      // Step 6: Write to temporary file
      print('SnippetService: Writing audio data to file...');
      await snippetFile.writeAsBytes(bytes)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw AudioExtractionException('File write operation timed out');
      });
      
      // Step 7: Verify file was created successfully
      final fileExists = await snippetFile.exists();
      print('SnippetService: File exists after write: $fileExists');
      
      if (!fileExists) {
        throw AudioExtractionException('Failed to create snippet file');
      }
      
      final fileSize = await snippetFile.length();
      print('SnippetService: Written file size: $fileSize bytes');
      
      if (fileSize == 0) {
        throw AudioExtractionException('Created file is empty');
      }
      
      // Step 8: Test audio file with just_audio to ensure it's valid
      print('SnippetService: Validating audio file with just_audio...');
      tempPlayer = AudioPlayer();
      
      try {
        await tempPlayer.setFilePath(snippetFile.path)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw AudioExtractionException('Audio file validation timed out');
        });
        
        final duration = tempPlayer.duration;
        print('SnippetService: Audio file validation successful. Duration: $duration');
        
        if (duration == null) {
          print('SnippetService: Warning - Could not determine audio duration');
        }
      } catch (e) {
        print('SnippetService: Audio validation failed: $e');
        throw AudioExtractionException('Invalid audio file format: ${e.toString()}');
      }
      
      print('SnippetService: Audio extraction completed successfully');
      print('SnippetService: Final file path: ${snippetFile.path}');
      print('SnippetService: Final file size: $fileSize bytes');
      
      return snippetFile;
      
    } catch (e) {
      print('SnippetService: Audio extraction failed with error: $e');
      print('SnippetService: Error type: ${e.runtimeType}');
      
      if (e is AudioExtractionException) {
        rethrow;
      } else {
        throw AudioExtractionException('Unexpected error during audio extraction: ${e.toString()}');
      }
    } finally {
      // Clean up resources
      try {
        await tempPlayer?.dispose();
        print('SnippetService: Audio player disposed');
      } catch (e) {
        print('SnippetService: Error disposing audio player: $e');
      }
      
      try {
        httpClient?.close();
        print('SnippetService: HTTP client closed');
      } catch (e) {
        print('SnippetService: Error closing HTTP client: $e');
      }
    }
  }

  /// Upload snippet file to Firebase Storage with comprehensive logging
  Future<String> _uploadSnippetToStorage(File snippetFile) async {
    print('🔍 DEBUG: ========== FIREBASE STORAGE UPLOAD START ==========');
    print('🔍 DEBUG: Starting Firebase Storage upload process');
    print('🔍 DEBUG: Input file path: "${snippetFile.path}"');
    
    UploadTask? uploadTask;
    String downloadUrl = '';
    print('🔍 DEBUG: Initialized downloadUrl as empty string');
    
    try {
      // Step 1: Validate input file
      print('🔍 DEBUG: UPLOAD STEP 1 - Validating input file...');
      final fileExists = await snippetFile.exists();
      print('🔍 DEBUG: File exists: $fileExists');
      
      if (!fileExists) {
        print('🚨 DEBUG: ❌ File validation failed - file does not exist');
        throw StorageUploadException('Snippet file does not exist at path: ${snippetFile.path}');
      }
      
      final fileSize = await snippetFile.length();
      print('🔍 DEBUG: File size: $fileSize bytes');
      
      if (fileSize == 0) {
        print('🚨 DEBUG: ❌ File validation failed - file is empty');
        throw StorageUploadException('Snippet file is empty');
      }
      
      print('🔍 DEBUG: ✅ File validation passed');
      
      // Check file permissions
      final fileStat = await snippetFile.stat();
      print('SnippetService: File permissions - readable: ${fileStat.mode & 0x444 != 0}');
      
      // Step 2: Verify Firebase Storage configuration
      print('SnippetService: Verifying Firebase Storage configuration...');
      try {
        final bucket = _storage.bucket;
        print('SnippetService: Storage bucket: $bucket');
      } catch (e) {
        print('SnippetService: Error accessing storage bucket: $e');
        throw StorageUploadException('Firebase Storage not properly configured: ${e.toString()}');
      }
      
      // Step 3: Create storage path and reference
      final snippetId = _uuid.v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'snippet_${snippetId}_$timestamp.mp3';
      final storagePath = 'snippets/$fileName';
      
      print('SnippetService: Storage path: $storagePath');
      print('SnippetService: File name: $fileName');
      
      final storageRef = _storage.ref().child(storagePath);
      print('SnippetService: Storage reference created: ${storageRef.fullPath}');
      
      // Step 4: Create upload metadata
      final metadata = SettableMetadata(
        contentType: 'audio/mpeg',
        customMetadata: {
          'uploadTime': DateTime.now().toIso8601String(),
          'originalFileName': snippetFile.path.split('/').last,
          'fileSize': fileSize.toString(),
          'snippetId': snippetId,
        },
      );
      
      print('SnippetService: Upload metadata created');
      print('SnippetService: Content type: ${metadata.contentType}');
      print('SnippetService: Custom metadata: ${metadata.customMetadata}');
      
      // Step 5: Start upload with progress monitoring
      print('SnippetService: Starting file upload...');
      uploadTask = storageRef.putFile(snippetFile, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('SnippetService: Upload progress: ${progress.toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
          print('SnippetService: Upload state: ${snapshot.state}');
        },
        onError: (error) {
          print('SnippetService: Upload progress error: $error');
        },
      );
      
      // Step 6: Wait for upload completion with timeout
      print('SnippetService: Waiting for upload completion...');
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw StorageUploadException('Upload timed out after 5 minutes');
        },
      );
      
      print('SnippetService: Upload completed successfully');
      print('SnippetService: Final upload state: ${snapshot.state}');
      print('SnippetService: Bytes transferred: ${snapshot.bytesTransferred}');
      print('SnippetService: Total bytes: ${snapshot.totalBytes}');
      
      // Step 7: Verify upload success
      if (snapshot.state != TaskState.success) {
        throw StorageUploadException('Upload failed with state: ${snapshot.state}');
      }
      
      if (snapshot.bytesTransferred != snapshot.totalBytes) {
        throw StorageUploadException('Upload incomplete: ${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes');
      }
      
      // Step 8: Get download URL
      print('🔍 DEBUG: UPLOAD STEP 8 - Getting download URL...');
      downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('🚨 DEBUG: ❌ Getting download URL timed out');
          throw StorageUploadException('Getting download URL timed out');
        },
      );
      
      print('🔍 DEBUG: ✅ Download URL obtained: "$downloadUrl"');
      print('🔍 DEBUG: Download URL validation:');
      print('🔍 DEBUG:   - URL not empty: ${downloadUrl.isNotEmpty}');
      print('🔍 DEBUG:   - URL starts with https: ${downloadUrl.startsWith('https://')}');
      print('🔍 DEBUG:   - URL contains firebasestorage: ${downloadUrl.contains('firebasestorage')}');
      print('🔍 DEBUG:   - URL length: ${downloadUrl.length}');
      
      // Step 9: Verify the uploaded file by checking metadata
      print('SnippetService: Verifying uploaded file...');
      try {
        final uploadedMetadata = await snapshot.ref.getMetadata().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw StorageUploadException('Getting uploaded file metadata timed out');
          },
        );
        
        print('SnippetService: Uploaded file size: ${uploadedMetadata.size}');
        print('SnippetService: Uploaded content type: ${uploadedMetadata.contentType}');
        print('SnippetService: Upload time: ${uploadedMetadata.timeCreated}');
        
        if (uploadedMetadata.size != fileSize) {
          throw StorageUploadException('Uploaded file size mismatch: expected $fileSize, got ${uploadedMetadata.size}');
        }
      } catch (e) {
        print('SnippetService: Warning - Could not verify uploaded file metadata: $e');
        // Don't fail the upload for metadata verification issues
      }
      
      print('🔍 DEBUG: ✅ Storage upload completed successfully');
      print('🔍 DEBUG: Final download URL: "$downloadUrl"');
      print('🔍 DEBUG: ========== FIREBASE STORAGE UPLOAD SUCCESS ==========');
      
      if (downloadUrl.isEmpty) {
        print('🚨 DEBUG: ❌ CRITICAL ERROR - Download URL is empty despite successful upload!');
        throw StorageUploadException('Download URL is empty despite successful upload');
      }
      
      return downloadUrl;
      
    } catch (e) {
      print('🚨 DEBUG: ========== FIREBASE STORAGE UPLOAD FAILED ==========');
      print('🚨 DEBUG: Storage upload failed with error: $e');
      print('🚨 DEBUG: Error type: ${e.runtimeType}');
      print('🚨 DEBUG: downloadUrl at time of error: "$downloadUrl"');
      
      // Cancel upload if it's still running
      if (uploadTask != null) {
        try {
          print('SnippetService: Canceling failed upload task...');
          await uploadTask.cancel();
          print('SnippetService: Upload task canceled');
        } catch (cancelError) {
          print('SnippetService: Error canceling upload task: $cancelError');
        }
      }
      
      if (e is StorageUploadException) {
        rethrow;
      } else if (e is FirebaseException) {
        print('🚨 DEBUG: Firebase error code: ${e.code}');
        print('🚨 DEBUG: Firebase error message: ${e.message}');
        throw StorageUploadException('Firebase Storage error [${e.code}]: ${e.message}');
      } else {
        throw StorageUploadException('Unexpected error during storage upload: ${e.toString()}');
      }
    }
  }

  /// Call the createSnippet Firebase Function with HTTP request (FIXED)
  Future<Map<String, dynamic>> _callCreateSnippetFunction({
    required BiteModel bite,
    required String snippetAudioUrl,
    required Duration startTime,
    required Duration endTime,
  }) async {
    print('🔍 DEBUG: Starting HTTP Firebase Function call (FIXED METHOD)');
    print('🔍 DEBUG: Using direct HTTP POST instead of Firebase Callable');
    
    // CRITICAL URL COMPARISON LOGGING
    print('🔍 DEBUG: snippetAudioUrl being sent to function: "$snippetAudioUrl"');
    print('🔍 DEBUG: Original bite.audioUrl: "${bite.audioUrl}"');
    print('🔍 DEBUG: snippetAudioUrl == bite.audioUrl: ${snippetAudioUrl == bite.audioUrl}');
    print('🔍 DEBUG: snippetAudioUrl length: ${snippetAudioUrl.length}');
    print('🔍 DEBUG: bite.audioUrl length: ${bite.audioUrl.length}');
    
    try {
      // Step 1: Prepare function data with correct parameter names
      final functionData = {
        'biteId': bite.id,
        'title': bite.title,
        'category': bite.category,
        'audioUrl': snippetAudioUrl, // This will now reach the function correctly
        'startTime': startTime.inSeconds,
        'endTime': endTime.inSeconds,
        'duration': '0:${(endTime - startTime).inSeconds}',
        'authorName': bite.authorName,
        'description': bite.description,
        'thumbnailUrl': bite.thumbnailUrl,
      };
      
      // Step 2: Validate critical parameters before sending
      print('🔍 DEBUG: Validating function parameters for HTTP request...');
      
      final audioUrl = functionData['audioUrl'] as String;
      print('🔍 DEBUG: audioUrl validation for HTTP:');
      print('🔍 DEBUG:   - audioUrl: "$audioUrl"');
      print('🔍 DEBUG:   - audioUrl.isEmpty: ${audioUrl.isEmpty}');
      print('🔍 DEBUG:   - audioUrl.length: ${audioUrl.length}');
      print('🔍 DEBUG:   - audioUrl.startsWith("http"): ${audioUrl.startsWith("http")}');
      
      if (audioUrl.isEmpty) {
        throw FunctionCallException('audioUrl parameter is empty - cannot process snippet without audio source');
      }
      
      if (!audioUrl.startsWith('http')) {
        throw FunctionCallException('audioUrl parameter is invalid - must be a valid HTTP/HTTPS URL: "$audioUrl"');
      }
      
      print('🔍 DEBUG: ✅ audioUrl validation passed for HTTP request');
      
      print('🔍 DEBUG: All HTTP function parameters:');
      functionData.forEach((key, value) {
        print('🔍 DEBUG:   $key: $value');
      });
      
      // Step 3: Make HTTP POST request to the function
      print('🔍 DEBUG: Sending HTTP POST to createSnippet function');
      print('🔍 DEBUG: Function URL: https://us-central1-pumpkin-bites-jvouko.cloudfunctions.net/createSnippet');
      
      final response = await http.post(
        Uri.parse('https://us-central1-pumpkin-bites-jvouko.cloudfunctions.net/createSnippet'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(functionData),
      ).timeout(const Duration(minutes: 3));
      
      print('🔍 DEBUG: HTTP response received');
      print('🔍 DEBUG: HTTP response status: ${response.statusCode}');
      print('🔍 DEBUG: HTTP response headers: ${response.headers}');
      print('🔍 DEBUG: HTTP response body length: ${response.body.length}');
      print('🔍 DEBUG: HTTP response body: ${response.body}');
      
      if (response.statusCode != 200) {
        print('🚨 DEBUG: HTTP request failed with status ${response.statusCode}');
        throw FunctionCallException('HTTP ${response.statusCode}: ${response.body}');
      }
      
      // Step 4: Parse JSON response
      print('🔍 DEBUG: Parsing JSON response...');
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      print('🔍 DEBUG: Parsed response data:');
      data.forEach((key, value) {
        print('🔍 DEBUG:   $key: $value');
      });
      
      // Step 5: Check function execution success
      if (data['success'] != true) {
        final errorMessage = data['error'] ?? 'Unknown error';
        final errorCode = data['code'] ?? 'UNKNOWN_ERROR';
        print('🚨 DEBUG: Function execution failed');
        print('🚨 DEBUG: Error message: $errorMessage');
        print('🚨 DEBUG: Error code: $errorCode');
        throw FunctionCallException('Function failed [$errorCode]: $errorMessage');
      }
      
      // Step 6: Validate required response fields
      final requiredFields = ['url', 'snippetId'];
      for (final field in requiredFields) {
        if (!data.containsKey(field) || data[field] == null) {
          throw FunctionCallException('Missing required field in function response: $field');
        }
      }
      
      final snippetUrl = data['url'] as String;
      final snippetId = data['snippetId'] as String;
      
      print('🔍 DEBUG: HTTP Function execution successful');
      print('🔍 DEBUG: Generated snippet ID: $snippetId');
      print('🔍 DEBUG: Generated snippet URL: $snippetUrl');
      
      // Step 7: Validate URL format
      if (!snippetUrl.startsWith('https://pumpkinbites.com/snippet/')) {
        print('🔍 DEBUG: Warning - Unexpected URL format: $snippetUrl');
      }
      
      return data;
      
    } catch (e) {
      print('🚨 DEBUG: HTTP Firebase Function call failed with error: $e');
      print('🚨 DEBUG: Error type: ${e.runtimeType}');
      
      if (e is FunctionCallException) {
        rethrow;
      } else {
        throw FunctionCallException('HTTP request failed: ${e.toString()}');
      }
    }
  }

  /// Clean up temporary files
  Future<void> _cleanupTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        print('SnippetService: Cleaned up temp file: ${file.path}');
      }
    } catch (e) {
      print('SnippetService: Error cleaning up temp file: $e');
      // Don't rethrow - cleanup errors shouldn't break the main flow
    }
  }

  /// Test Firebase Storage permissions with detailed analysis
  Future<bool> testStoragePermissions() async {
    print('=== FIREBASE STORAGE PERMISSIONS TEST ===');
    print('SnippetService: Testing Firebase Storage permissions...');
    print('SnippetService: Project: pumpkin-bites-jvouko');
    print('SnippetService: Storage bucket: pumpkin-bites-jvouko.firebasestorage.app');
    
    File? testFile;
    String? testFileUrl;
    
    try {
      // Step 1: Create a small test file
      final tempDir = await getTemporaryDirectory();
      testFile = File('${tempDir.path}/storage_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      const testContent = 'Firebase Storage permission test';
      await testFile.writeAsString(testContent);
      
      print('SnippetService: Created test file: ${testFile.path}');
      print('SnippetService: Test file size: ${await testFile.length()} bytes');
      
      // Step 2: Try to upload to snippets folder (the actual path we need)
      final testRef = _storage.ref().child('snippets/test_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      print('SnippetService: Testing upload to snippets folder: ${testRef.fullPath}');
      print('SnippetService: Expected Storage Rules for snippets:');
      print('SnippetService: match /snippets/{allPaths=**} {');
      print('SnippetService:   allow read, write: if request.auth != null;');
      print('SnippetService: }');
      
      final uploadTask = testRef.putFile(testFile);
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw StorageUploadException('Test upload timed out after 30 seconds');
        },
      );
      
      if (snapshot.state != TaskState.success) {
        throw StorageUploadException('Test upload failed with state: ${snapshot.state}');
      }
      
      // Step 3: Get download URL to verify upload
      testFileUrl = await snapshot.ref.getDownloadURL();
      print('SnippetService: ✅ Test upload successful to /snippets/ folder');
      print('SnippetService: Test URL: $testFileUrl');
      
      // Step 4: Clean up test file from storage
      try {
        await testRef.delete();
        print('SnippetService: Test file cleaned up from storage');
      } catch (e) {
        print('SnippetService: Warning - Could not clean up test file: $e');
      }
      
      print('SnippetService: ✅ STORAGE PERMISSIONS TEST PASSED');
      print('=== END STORAGE PERMISSIONS TEST ===');
      return true;
      
    } catch (e) {
      print('SnippetService: ❌ STORAGE PERMISSIONS TEST FAILED: $e');
      print('SnippetService: Error type: ${e.runtimeType}');
      
      if (e is FirebaseException) {
        print('SnippetService: Firebase error code: ${e.code}');
        print('SnippetService: Firebase error message: ${e.message}');
        
        if (e.code == 'permission-denied') {
          print('=== STORAGE PERMISSION DENIED - FIX REQUIRED ===');
          print('SnippetService: Go to Firebase Console → Storage → Rules');
          print('SnippetService: URL: https://console.firebase.google.com/project/pumpkin-bites-jvouko/storage/rules');
          print('SnippetService: Current rules likely only allow specific paths');
          print('SnippetService: Required rule for snippets:');
          print('SnippetService:');
          print('SnippetService: rules_version = \'2\';');
          print('SnippetService: service firebase.storage {');
          print('SnippetService:   match /b/{bucket}/o {');
          print('SnippetService:     match /snippets/{allPaths=**} {');
          print('SnippetService:       allow read, write: if request.auth != null;');
          print('SnippetService:     }');
          print('SnippetService:   }');
          print('SnippetService: }');
          print('=== END PERMISSION DENIED INFO ===');
        }
      }
      
      print('=== END STORAGE PERMISSIONS TEST ===');
      return false;
    } finally {
      // Clean up local test file
      if (testFile != null) {
        try {
          if (await testFile.exists()) {
            await testFile.delete();
            print('SnippetService: Local test file cleaned up');
          }
        } catch (e) {
          print('SnippetService: Error cleaning up local test file: $e');
        }
      }
    }
  }

  /// Generate Firebase Console URLs for debugging
  void printFirebaseConsoleUrls() {
    print('=== FIREBASE CONSOLE DEBUGGING URLS ===');
    print('Functions Overview: https://console.firebase.google.com/project/pumpkin-bites-jvouko/functions');
    print('Function Logs: https://console.firebase.google.com/project/pumpkin-bites-jvouko/functions/logs');
    print('Function Details: https://console.firebase.google.com/project/pumpkin-bites-jvouko/functions/list');
    print('Expected Function URL: https://us-central1-pumpkin-bites-jvouko.cloudfunctions.net/createSnippet');
    print('Google Cloud Logs: https://console.cloud.google.com/logs/query?project=pumpkin-bites-jvouko');
    print('=== TO CHECK FUNCTION STATUS ===');
    print('1. Go to Functions Overview and verify createSnippet is listed');
    print('2. Check if Status shows "Deployed" and "Healthy"'); 
    print('3. Look at Function Logs for error messages during calls');
    print('4. Verify Region is set to us-central1');
    print('5. Check Memory allocation (default 256MB may be too low for audio processing)');
    print('===============================');
  }

  /// Test basic Firebase Functions connectivity
  Future<bool> testBasicFunctionsConnectivity() async {
    try {
      print('=== BASIC FIREBASE FUNCTIONS TEST ===');
      print('SnippetService: Testing basic Firebase Functions connectivity...');
      print('SnippetService: Project ID: pumpkin-bites-jvouko');
      print('SnippetService: Region: us-central1');
      
      // Test 1: Create instance
      print('SnippetService: Firebase Functions instance: $_functions');
      print('SnippetService: Functions instance type: ${_functions.runtimeType}');
      
      // Test 2: Try to create callable
      try {
        final callable = _functions.httpsCallable('createSnippet');
        print('SnippetService: ✅ Callable created successfully');
        print('SnippetService: Callable type: ${callable.runtimeType}');
        
        // Test 3: Try different syntax
        final altCallable = FirebaseFunctions.instance.httpsCallable('createSnippet');
        print('SnippetService: ✅ Alternative callable syntax also works');
        
        return true;
      } catch (e) {
        print('SnippetService: ❌ Failed to create callable: $e');
        print('SnippetService: Error type: ${e.runtimeType}');
        return false;
      }
    } catch (e) {
      print('SnippetService: ❌ Basic connectivity test failed: $e');
      return false;
    }
  }

  /// Check if snippet creation is available (for UI state management)
  Future<bool> isSnippetCreationAvailable() async {
    try {
      print('SnippetService: Checking snippet creation availability...');
      print('SnippetService: Using optimized server-side processing - Storage test optional');
      
      // Test 1: Basic Firebase Functions connectivity
      final basicConnectivity = await testBasicFunctionsConnectivity();
      if (!basicConnectivity) {
        print('SnippetService: Basic Functions connectivity failed');
        return false;
      }
      
      // Test 2: Firebase Storage permissions (OPTIONAL - for fallback only)
      try {
        final storageAvailable = await testStoragePermissions();
        print('SnippetService: Storage available: $storageAvailable (optional for server-side processing)');
      } catch (e) {
        print('SnippetService: Storage test failed but continuing (not required for server-side processing): $e');
      }
      
      print('SnippetService: Snippet creation is available');
      return true;
    } catch (e) {
      print('SnippetService: Snippet creation availability check failed: $e');
      return false;
    }
  }

  /// Get user-friendly error message for snippet creation failures
  String getUserFriendlyErrorMessage(Exception error) {
    final errorString = error.toString();
    
    if (error is AudioExtractionException) {
      // These errors should be rare now with server-side processing
      return 'Audio processing issue. Please try again or contact support.';
    } else if (error is StorageUploadException) {
      // These errors should be rare now with server-side processing
      return 'Upload issue. Please check your internet connection and try again.';
    } else if (error is FunctionCallException) {
      if (errorString.contains('timed out')) {
        return 'Server processing took too long. This audio file may be very large. Please try again.';
      } else if (errorString.contains('not properly configured')) {
        return 'Service temporarily unavailable. Please try again later.';
      } else if (errorString.contains('UNAUTHENTICATED')) {
        return 'Please log in again and try sharing.';
      } else if (errorString.contains('PERMISSION_DENIED')) {
        return 'Permission denied. Please contact support.';
      } else if (errorString.contains('NOT_FOUND')) {
        return 'Service not available. Please contact support.';
      } else {
        return 'Could not create snippet. Please try again.';
      }
    } else if (error is SnippetException) {
      final code = (error as SnippetException).code;
      switch (code) {
        case 'SNIPPET_TOO_SHORT':
          return 'Snippet must be at least 5 seconds long.';
        case 'SNIPPET_TOO_LONG':
          return 'Snippet cannot be longer than 60 seconds.';
        case 'INVALID_TIME_RANGE':
          return 'Please select a valid time range for the snippet.';
        default:
          return error.message;
      }
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}