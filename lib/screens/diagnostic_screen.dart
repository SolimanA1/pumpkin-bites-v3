import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'test_bite_creator.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({Key? key}) : super(key: key);

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Controllers for creating a new bite
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _audioUrlController = TextEditingController(
    text: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
  );
  final TextEditingController _thumbnailUrlController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Test Category'
  );
  final TextEditingController _durationController = TextEditingController(
    text: '180'
  );
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _audioUrlController.dispose();
    _thumbnailUrlController.dispose();
    _categoryController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const TestBiteCreator(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                    child: const Text('Create Real Audio Test Bite'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _createTestBite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Create Basic Test Bite'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runGiftDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Check Gifts'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runAudioDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Check Audio'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isRunning
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 12,
                            color: log.startsWith('[ERROR]')
                                ? Colors.red
                                : log.startsWith('[SUCCESS]')
                                    ? Colors.green
                                    : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRunning ? null : () => _showCreateBiteDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Create New Bite',
      ),
    );
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _copyLogs() async {
    final text = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Future<void> _runGiftDiagnostics() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Starting gift diagnostics...');
      
      // Check current user
      final user = _auth.currentUser;
      if (user == null) {
        _log('[ERROR] No user logged in');
        return;
      }
      
      _log('Current user: ${user.email} (${user.uid})');
      
      // Check user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _log('[ERROR] User document does not exist');
        return;
      }
      
      _log('User document exists');
      
      // Check gifts collection
      final giftsQuery = await _firestore
          .collection('gifts')
          .where('recipientEmail', isEqualTo: user.email)
          .get();
      
      _log('Found ${giftsQuery.docs.length} gifts for this email');
      
      // List all gifts
      for (final doc in giftsQuery.docs) {
        final data = doc.data();
        _log('Gift: ${doc.id}');
        _log('  Type: ${data['type']}');
        _log('  Status: ${data['status']}');
        _log('  Sender: ${data['senderName']}');
        _log('  Sent at: ${data['sentAt']}');
        
        if (data['status'] == 'awaiting_registration') {
          _log('[ISSUE] Gift is still awaiting registration even though user is registered');
          
          // Try to fix - using Timestamp.now() instead of serverTimestamp
          _log('Attempting to fix gift...');
          try {
            await _firestore.collection('gifts').doc(doc.id).update({
              'recipientUid': user.uid,
              'status': 'pending',
              'receivedAt': Timestamp.now(),
            });
            
            // Add to user's gifted episodes
            if (data['type'] == 'episode') {
              final biteId = data['biteId'];
              await _firestore.collection('users').doc(user.uid).update({
                'giftedEpisodes': FieldValue.arrayUnion([{
                  'giftId': doc.id,
                  'biteId': biteId,
                  'senderUid': data['senderUid'],
                  'senderName': data['senderName'],
                  'receivedAt': Timestamp.now(),
                }]),
                'unreadGifts': FieldValue.increment(1),
              });
              _log('[SUCCESS] Fixed gift and added to user\'s gifted episodes');
            }
          } catch (e) {
            _log('[ERROR] Failed to fix gift: $e');
          }
        }
      }
      
      // Check user's gifted episodes
      try {
        final data = userDoc.data() ?? {};
        final giftedEpisodesRaw = data['giftedEpisodes'];
        
        if (giftedEpisodesRaw == null) {
          _log('User has no giftedEpisodes field');
        } else if (giftedEpisodesRaw is! List) {
          _log('[ERROR] giftedEpisodes is not a List (${giftedEpisodesRaw.runtimeType})');
        } else {
          final giftedEpisodes = List<dynamic>.from(giftedEpisodesRaw);
          _log('User has ${giftedEpisodes.length} gifted episodes in their document');
          
          for (final episode in giftedEpisodes) {
            if (episode is! Map) {
              _log('[ERROR] Episode is not a Map: $episode');
              continue;
            }
            
            try {
              _log('Gifted episode: ${episode['biteId']}');
              _log('  From: ${episode['senderName']}');
            } catch (e) {
              _log('[ERROR] Error accessing episode data: $e');
              _log('  Episode data: $episode');
            }
          }
        }
      } catch (e) {
        _log('[ERROR] Exception processing gifted episodes: $e');
      }
      
      _log('Gift diagnostics completed');
    } catch (e) {
      _log('[ERROR] Exception during gift diagnostics: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runAudioDiagnostics() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Starting audio diagnostics...');
      
      // Get all bites
      final querySnapshot = await _firestore.collection('bites').get();
      _log('Found ${querySnapshot.docs.length} bites');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final title = data['title'] ?? 'Untitled';
        final audioUrl = data['audioUrl'] ?? '';
        final duration = data['duration'] ?? 0;
        
        _log('Bite: $title ($id)');
        _log('  Audio URL: $audioUrl');
        _log('  Duration: $duration seconds');
        
        if (audioUrl.trim().isEmpty) {
          _log('[ERROR] Empty audio URL');
          continue;
        }
        
        if (audioUrl.trim() != audioUrl) {
          _log('[ISSUE] Audio URL has leading/trailing whitespace');
          
          // Try to fix
          _log('Attempting to fix audio URL...');
          try {
            await _firestore.collection('bites').doc(id).update({
              'audioUrl': audioUrl.trim(),
            });
            _log('[SUCCESS] Fixed audio URL whitespace');
          } catch (e) {
            _log('[ERROR] Failed to fix audio URL: $e');
          }
        }
        
        if (!audioUrl.trim().startsWith('http')) {
          _log('[ERROR] Invalid audio URL format: ${audioUrl.trim()}');
          
          // Try to fix with a placeholder
          _log('Attempting to fix invalid URL...');
          try {
            await _firestore.collection('bites').doc(id).update({
              'audioUrl': 'https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3',
              'duration': 175, // 2:55 in seconds
            });
            _log('[SUCCESS] Replaced invalid URL with placeholder');
          } catch (e) {
            _log('[ERROR] Failed to fix invalid URL: $e');
          }
        }
        
        if (duration <= 0) {
          _log('[ERROR] Invalid duration: $duration');
          
          // Try to fix with a reasonable default
          _log('Attempting to fix invalid duration...');
          try {
            await _firestore.collection('bites').doc(id).update({
              'duration': 180, // 3 minutes in seconds
            });
            _log('[SUCCESS] Fixed invalid duration');
          } catch (e) {
            _log('[ERROR] Failed to fix invalid duration: $e');
          }
        }
      }
      
      _log('Audio diagnostics completed');
    } catch (e) {
      _log('[ERROR] Exception during audio diagnostics: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _showCreateBiteDialog(BuildContext context) {
    // Create a test bite
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Test Bite'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter bite title',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter bite description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _audioUrlController,
                decoration: const InputDecoration(
                  labelText: 'Audio URL',
                  hintText: 'Enter audio URL',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _thumbnailUrlController,
                decoration: const InputDecoration(
                  labelText: 'Thumbnail URL (optional)',
                  hintText: 'Enter thumbnail URL',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Enter category',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (seconds)',
                  hintText: 'Enter duration in seconds',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createTestBite();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestBite() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Creating test bite...');
      
      final String title = _titleController.text.trim().isNotEmpty 
          ? _titleController.text.trim() 
          : 'Test Bite ${DateTime.now().millisecondsSinceEpoch}';
          
      final String description = _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : 'This is a test bite created for debugging purposes. Use this to test player functionality.';
          
      final String audioUrl = _audioUrlController.text.trim().isNotEmpty 
          ? _audioUrlController.text.trim() 
          : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
          
      final String thumbnailUrl = _thumbnailUrlController.text.trim();
      
      final String category = _categoryController.text.trim().isNotEmpty 
          ? _categoryController.text.trim() 
          : 'Test';
          
      final int duration = int.tryParse(_durationController.text.trim()) ?? 180;
      
      // Create bite document
      final biteData = {
        'title': title,
        'description': description,
        'audioUrl': audioUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'authorName': 'Test Author',
        'date': Timestamp.now(),
        'duration': duration, // in seconds
        'isPremium': false,
        'isPremiumOnly': false,
        'dayNumber': DateTime.now().day,
        'commentCount': 0,
      };
      
      final docRef = await _firestore.collection('bites').add(biteData);
      
      _log('[SUCCESS] Created test bite with ID: ${docRef.id}');
      
      // Add to current user's unlocked content
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'unlockedContent': FieldValue.arrayUnion([docRef.id]),
        });
        _log('[SUCCESS] Added bite to user\'s unlocked content');
      }
      
      // Clear input fields
      _titleController.clear();
      _descriptionController.clear();
      _audioUrlController.text = 'https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3';
      _thumbnailUrlController.clear();
      _categoryController.text = 'Test Category';
      _durationController.text = '180';
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test bite created successfully')),
      );
    } catch (e) {
      _log('[ERROR] Exception creating test bite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating test bite: $e')),
      );
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}