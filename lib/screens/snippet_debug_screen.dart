import 'package:flutter/material.dart';
import '../services/snippet_service.dart';
import '../services/firebase_functions_test.dart';
import '../models/bite_model.dart';

class SnippetDebugScreen extends StatefulWidget {
  const SnippetDebugScreen({Key? key}) : super(key: key);

  @override
  State<SnippetDebugScreen> createState() => _SnippetDebugScreenState();
}

class _SnippetDebugScreenState extends State<SnippetDebugScreen> {
  final SnippetService _snippetService = SnippetService();
  final List<String> _debugLogs = [];
  bool _isTestingStorage = false;
  bool _isTestingSnippet = false;
  bool _isTestingFunctions = false;
  bool? _storageTestResult;
  bool? _availabilityTestResult;
  bool? _functionsTestResult;

  @override
  void initState() {
    super.initState();
    _addLog('Snippet Debug Screen initialized');
  }

  void _addLog(String message) {
    setState(() {
      _debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print('SnippetDebug: $message');
  }

  Future<void> _testStoragePermissions() async {
    setState(() {
      _isTestingStorage = true;
      _storageTestResult = null;
    });

    _addLog('Starting Firebase Storage permissions test...');

    try {
      final result = await _snippetService.testStoragePermissions();
      setState(() {
        _storageTestResult = result;
      });

      if (result) {
        _addLog('✅ Storage permissions test PASSED');
      } else {
        _addLog('❌ Storage permissions test FAILED');
      }
    } catch (e) {
      _addLog('❌ Storage test error: $e');
      setState(() {
        _storageTestResult = false;
      });
    } finally {
      setState(() {
        _isTestingStorage = false;
      });
    }
  }

  Future<void> _testFunctionsConfiguration() async {
    setState(() {
      _isTestingFunctions = true;
      _functionsTestResult = null;
    });

    _addLog('Testing Firebase Functions v5.2.5 configuration...');

    try {
      await FirebaseFunctionsTest.printVersionInfo();
      final result = await FirebaseFunctionsTest.testFunctionsConfiguration();
      
      setState(() {
        _functionsTestResult = result;
      });

      if (result) {
        _addLog('✅ Firebase Functions v5.2.5 configuration test PASSED');
      } else {
        _addLog('❌ Firebase Functions v5.2.5 configuration test FAILED');
      }
    } catch (e) {
      _addLog('❌ Functions configuration test error: $e');
      setState(() {
        _functionsTestResult = false;
      });
    } finally {
      setState(() {
        _isTestingFunctions = false;
      });
    }
  }

  Future<void> _testAvailability() async {
    setState(() {
      _availabilityTestResult = null;
    });

    _addLog('Testing snippet creation availability...');

    try {
      final result = await _snippetService.isSnippetCreationAvailable();
      setState(() {
        _availabilityTestResult = result;
      });

      if (result) {
        _addLog('✅ Snippet creation is available');
      } else {
        _addLog('❌ Snippet creation is not available');
      }
    } catch (e) {
      _addLog('❌ Availability test error: $e');
      setState(() {
        _availabilityTestResult = false;
      });
    }
  }

  Future<void> _testSnippetCreation() async {
    setState(() {
      _isTestingSnippet = true;
    });

    _addLog('Starting snippet creation test...');

    try {
      // Create a test bite with a known working audio URL
      final testBite = BiteModel(
        id: 'test_snippet_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Snippet Creation',
        description: 'Testing snippet creation functionality',
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        thumbnailUrl: '',
        category: 'Test',
        authorName: 'Test System',
        date: DateTime.now(),
        duration: 180,
        isPremium: false,
      );

      _addLog('Created test bite: ${testBite.title}');
      _addLog('Test audio URL: ${testBite.audioUrl}');

      // Test snippet creation with 30-second duration
      const startTime = Duration(seconds: 10);
      const endTime = Duration(seconds: 40);

      _addLog('Attempting snippet creation (${startTime.inSeconds}s to ${endTime.inSeconds}s)...');

      final snippetUrl = await _snippetService.createSnippet(
        bite: testBite,
        startTime: startTime,
        endTime: endTime,
      );

      _addLog('✅ Snippet creation successful!');
      _addLog('Generated URL: $snippetUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Snippet creation test passed!\nURL: $snippetUrl'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _addLog('❌ Snippet creation failed: $e');

      if (e is Exception) {
        final userMessage = _snippetService.getUserFriendlyErrorMessage(e);
        _addLog('User-friendly message: $userMessage');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Snippet creation test failed:\n${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isTestingSnippet = false;
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _debugLogs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippet Debug'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diagnostic Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Storage test
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingStorage ? null : _testStoragePermissions,
                            icon: _isTestingStorage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: const Text('Test Storage'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _storageTestResult == true 
                                  ? Colors.green 
                                  : _storageTestResult == false 
                                      ? Colors.red 
                                      : Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_storageTestResult != null)
                          Icon(
                            _storageTestResult! ? Icons.check_circle : Icons.error,
                            color: _storageTestResult! ? Colors.green : Colors.red,
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Functions configuration test
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingFunctions ? null : _testFunctionsConfiguration,
                            icon: _isTestingFunctions
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.settings),
                            label: const Text('Test Functions v5.2.5'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _functionsTestResult == true 
                                  ? Colors.green 
                                  : _functionsTestResult == false 
                                      ? Colors.red 
                                      : Colors.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_functionsTestResult != null)
                          Icon(
                            _functionsTestResult! ? Icons.check_circle : Icons.error,
                            color: _functionsTestResult! ? Colors.green : Colors.red,
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Availability test
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testAvailability,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Test Availability'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _availabilityTestResult == true 
                                  ? Colors.green 
                                  : _availabilityTestResult == false 
                                      ? Colors.red 
                                      : Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_availabilityTestResult != null)
                          Icon(
                            _availabilityTestResult! ? Icons.check_circle : Icons.error,
                            color: _availabilityTestResult! ? Colors.green : Colors.red,
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Full snippet test
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingSnippet ? null : _testSnippetCreation,
                            icon: _isTestingSnippet
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.play_circle_filled),
                            label: const Text('Test Full Snippet Creation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Debug logs
            const Text(
              'Debug Logs:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _debugLogs.isEmpty
                        ? [
                            const Text(
                              'No logs yet. Run a test to see debug output.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ]
                        : _debugLogs.map((log) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: log.contains('❌') 
                                      ? Colors.red
                                      : log.contains('✅') 
                                          ? Colors.green
                                          : Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            )).toList(),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Test Storage: Checks Firebase Storage permissions\n'
                    '2. Test Functions v5.2.5: Verifies Functions configuration\n'
                    '3. Test Availability: Verifies all services are ready\n'
                    '4. Test Full Snippet: Creates an actual snippet end-to-end\n\n'
                    'Watch the debug logs for detailed information about each step.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}