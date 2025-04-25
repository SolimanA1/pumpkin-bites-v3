import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestBiteCreator extends StatefulWidget {
  const TestBiteCreator({Key? key}) : super(key: key);

  @override
  State<TestBiteCreator> createState() => _TestBiteCreatorState();
}

class _TestBiteCreatorState extends State<TestBiteCreator> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '180');
  
  bool _isCreating = false;
  List<String> _logs = [];
  
  // Some test audio URLs with real production-length audio
  final List<String> _testAudioUrls = [
    'https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3', // 2:55 sample
    'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8e9d46df7.mp3', // 3:42 sample
    'https://cdn.pixabay.com/download/audio/2021/08/09/audio_c8c8a73acc.mp3', // 4:17 sample
    'https://cdn.pixabay.com/download/audio/2021/11/25/audio_c997a7e3cf.mp3', // 5:24 sample
  ];
  
  String _selectedAudioUrl = '';
  
  @override
  void initState() {
    super.initState();
    if (_testAudioUrls.isNotEmpty) {
      _selectedAudioUrl = _testAudioUrls[0];
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
  
  void _log(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }
  
  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }
  
  Future<void> _createTestBite() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      _log('Creating test bite...');
      
      final String title = _titleController.text.trim().isNotEmpty 
          ? _titleController.text.trim() 
          : 'Test Bite ${DateTime.now().millisecondsSinceEpoch}';
          
      final String description = _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : 'This is a test bite created for testing real audio playback. This has a duration of ${_durationController.text} seconds.';
          
      final int duration = int.tryParse(_durationController.text.trim()) ?? 180;
      
      // Generate thumbnail URL
      final int index = _testAudioUrls.indexOf(_selectedAudioUrl);
      final String thumbnailUrl = 'https://picsum.photos/seed/${index + 1}/400/225';
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create test content');
      }
      
      // Create bite document
      final biteRef = await FirebaseFirestore.instance.collection('bites').add({
        'title': title,
        'description': description,
        'audioUrl': _selectedAudioUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': 'Test',
        'authorName': 'Test Author',
        'date': Timestamp.now(),
        'duration': duration, // Important: Set duration in seconds
        'isPremium': false,
        'isPremiumOnly': false,
        'dayNumber': DateTime.now().day,
        'commentCount': 0,
      });
      
      _log('[SUCCESS] Created test bite with ID: ${biteRef.id}');
      
      // Add to current user's unlocked content
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'unlockedContent': FieldValue.arrayUnion([biteRef.id]),
      });
      _log('[SUCCESS] Added bite to user\'s unlocked content');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test bite with real audio created successfully!')),
      );
    } catch (e) {
      _log('[ERROR] Exception creating test bite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating test bite: $e')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Production Test Bites'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Test Bites with Real Audio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This tool helps you create test bites with real production-length audio files for testing.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a duration';
                      }
                      final duration = int.tryParse(value);
                      if (duration == null || duration <= 0) {
                        return 'Please enter a valid duration';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Audio URL:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final url in _testAudioUrls)
                    RadioListTile<String>(
                      title: Text('${_testAudioUrls.indexOf(url) + 1}. ${url.split('/').last}'),
                      subtitle: Text(
                        _getAudioDescription(_testAudioUrls.indexOf(url)),
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: url,
                      groupValue: _selectedAudioUrl,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedAudioUrl = value;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createTestBite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isCreating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('CREATE TEST BITE'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearLogs,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Divider(),
            for (final log in _logs.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  log,
                  style: TextStyle(
                    fontSize: 12,
                    color: log.contains('[ERROR]')
                        ? Colors.red
                        : log.contains('[SUCCESS]')
                            ? Colors.green
                            : Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _getAudioDescription(int index) {
    switch (index) {
      case 0: return "2 minutes 55 seconds - Calm piano";
      case 1: return "3 minutes 42 seconds - Acoustic guitar";
      case 2: return "4 minutes 17 seconds - Ambient soundscape";
      case 3: return "5 minutes 24 seconds - Relaxing music";
      default: return "Audio sample";
    }
  }
}