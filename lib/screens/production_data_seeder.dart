import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductionDataSeeder extends StatefulWidget {
  const ProductionDataSeeder({Key? key}) : super(key: key);

  @override
  State<ProductionDataSeeder> createState() => _ProductionDataSeederState();
}

class _ProductionDataSeederState extends State<ProductionDataSeeder> {
  bool _isSeeding = false;
  bool _isClearing = false;
  List<String> _logs = [];

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

  // Production-ready bite data with intriguing titles that combine mystery with wisdom
  final List<Map<String, dynamic>> _productionBites = [
    // Required exact titles
    {
      'title': 'The Tiny Revolution',
      'description': 'How the smallest changes create the biggest transformations. Discover why incremental shifts are more powerful than dramatic overhauls.',
      'category': 'Psychology',
      'duration': 195, // 3:15
      'authorName': 'Dr. Sarah Chen',
      'isPremium': false,
      'dayNumber': 1,
    },
    {
      'title': 'The Undoing Hypothesis',
      'description': 'Sometimes growth means unlearning what we thought we knew. Explore the counterintuitive art of letting go of harmful patterns.',
      'category': 'Psychology',
      'duration': 167, // 2:47
      'authorName': 'Marcus Rivera',
      'isPremium': false,
      'dayNumber': 2,
    },
    {
      'title': 'The Midnight Text Dilemma',
      'description': 'Why we reach for our phones at 2 AM and what it reveals about modern connection. Navigate digital boundaries without losing intimacy.',
      'category': 'Relationships',
      'duration': 203, // 3:23
      'authorName': 'Dr. Ava Thompson',
      'isPremium': false,
      'dayNumber': 3,
    },
    {
      'title': 'The Permission Paradox',
      'description': 'The more permission we seek, the less permission we have. Break free from the approval-seeking trap that keeps us small.',
      'category': 'Life Skills',
      'duration': 189, // 3:09
      'authorName': 'Jordan Blake',
      'isPremium': false,
      'dayNumber': 4,
    },
    {
      'title': 'The Tuesday Effect',
      'description': 'Why Tuesday rituals are more transformative than Monday motivation. The hidden psychology of weekly rhythms.',
      'category': 'Psychology',
      'duration': 174, // 2:54
      'authorName': 'Dr. Lisa Park',
      'isPremium': false,
      'dayNumber': 5,
    },
    {
      'title': 'The Invisible Contract',
      'description': 'Every relationship has unspoken rules we never agreed to. Learn to recognize and renegotiate these hidden expectations.',
      'category': 'Relationships',
      'duration': 210, // 3:30
      'authorName': 'Dr. Michael Torres',
      'isPremium': false,
      'dayNumber': 6,
    },
    {
      'title': 'The 37% Rule',
      'description': 'Mathematicians discovered the optimal point to stop searching and commit. How this applies to love, careers, and life decisions.',
      'category': 'Relationships',
      'duration': 198, // 3:18
      'authorName': 'Emma Rodriguez',
      'isPremium': true,
      'dayNumber': 7,
    },
    {
      'title': 'What Poker Players Know About Life Decisions',
      'description': 'Professional gamblers understand probability and emotion in ways that can transform how you make choices.',
      'category': 'Business',
      'duration': 185, // 3:05
      'authorName': 'Alex Chen',
      'isPremium': false,
      'dayNumber': 8,
    },
    // Additional intriguing titles following the pattern
    {
      'title': 'The Coffee Shop Theory',
      'description': 'Why the best conversations happen in public spaces, and what this reveals about vulnerability and connection.',
      'category': 'Relationships',
      'duration': 192, // 3:12
      'authorName': 'Dr. Nina Patel',
      'isPremium': false,
      'dayNumber': 9,
    },
    {
      'title': 'The Sunday Syndrome',
      'description': 'That peculiar anxiety that hits every weekend. Understanding the psychology of anticipation and how to reclaim your Sundays.',
      'category': 'Psychology',
      'duration': 176, // 2:56
      'authorName': 'Dr. James Wright',
      'isPremium': false,
      'dayNumber': 10,
    },
    {
      'title': 'What Comedians Know About Pain',
      'description': 'Stand-up comics are masters of transforming suffering into connection. Their secrets for turning wounds into wisdom.',
      'category': 'Life Skills',
      'duration': 208, // 3:28
      'authorName': 'Rachel Stone',
      'isPremium': true,
      'dayNumber': 11,
    },
    {
      'title': 'The Art of Disappointing People',
      'description': 'Why learning to let others down gracefully is one of the most generous things you can do. The freedom in saying no.',
      'category': 'Life Skills',
      'duration': 194, // 3:14
      'authorName': 'Dr. Carlos Mendez',
      'isPremium': false,
      'dayNumber': 12,
    },
    {
      'title': 'The Phantom Vibration',
      'description': 'Why your phone buzzes when it doesn\'t, and what this phantom sensation reveals about modern anxiety and attention.',
      'category': 'Psychology',
      'duration': 162, // 2:42
      'authorName': 'Dr. Sophie Miller',
      'isPremium': false,
      'dayNumber': 13,
    },
    {
      'title': 'The Bathroom Mirror Moment',
      'description': 'That split second when you catch your own eye. The psychology of self-recognition and why it matters more than you think.',
      'category': 'Psychology',
      'duration': 183, // 3:03
      'authorName': 'Dr. Ryan Foster',
      'isPremium': false,
      'dayNumber': 14,
    },
    {
      'title': 'What Bartenders Know About Listening',
      'description': 'Behind every great bar is someone who\'s mastered the art of holding space. Professional secrets for better conversations.',
      'category': 'Relationships',
      'duration': 201, // 3:21
      'authorName': 'Maria Santos',
      'isPremium': false,
      'dayNumber': 15,
    },
    {
      'title': 'The Grocery Store Philosophy',
      'description': 'How your shopping habits reveal your deepest beliefs about abundance, control, and planning for the future.',
      'category': 'Philosophy',
      'duration': 177, // 2:57
      'authorName': 'Dr. Elena Volkov',
      'isPremium': true,
      'dayNumber': 16,
    },
    {
      'title': 'The 3am Clarity',
      'description': 'Why the most profound insights come when you\'re supposed to be sleeping. The neuroscience of late-night wisdom.',
      'category': 'Psychology',
      'duration': 186, // 3:06
      'authorName': 'Dr. Kevin Liu',
      'isPremium': false,
      'dayNumber': 17,
    },
    {
      'title': 'The Elevator Experiment',
      'description': 'What 30 seconds in a small box with strangers teaches us about human nature, status, and social scripts.',
      'category': 'Philosophy',
      'duration': 195, // 3:15
      'authorName': 'Dr. Priya Sharma',
      'isPremium': false,
      'dayNumber': 18,
    },
    {
      'title': 'Why Smart People Make Dumb Decisions',
      'description': 'Intelligence isn\'t immunity to poor choices. The cognitive biases that trip up even the brightest minds.',
      'category': 'Business',
      'duration': 212, // 3:32
      'authorName': 'Dr. Thomas Anderson',
      'isPremium': true,
      'dayNumber': 19,
    },
    {
      'title': 'The Apology Algorithm',
      'description': 'There\'s a formula to saying sorry that actually works. The science behind meaningful apologies and genuine repair.',
      'category': 'Relationships',
      'duration': 199, // 3:19
      'authorName': 'Dr. Isabella Martinez',
      'isPremium': false,
      'dayNumber': 20,
    },
    {
      'title': 'The Comparison Trap 2.0',
      'description': 'Social media didn\'t invent comparison, but it weaponized it. Ancient wisdom meets modern algorithms.',
      'category': 'Psychology',
      'duration': 188, // 3:08
      'authorName': 'Dr. Nathan Green',
      'isPremium': false,
      'dayNumber': 21,
    },
    {
      'title': 'What Chefs Know About Pressure',
      'description': 'Kitchen wisdom that applies far beyond cooking. How professionals thrive when everything\'s on fire.',
      'category': 'Business',
      'duration': 204, // 3:24
      'authorName': 'Chef Antonio Rossi',
      'isPremium': false,
      'dayNumber': 22,
    },
    {
      'title': 'The Waiting Room Wisdom',
      'description': 'What happens to your mind when you\'re forced to sit still. The lost art of productive boredom.',
      'category': 'Philosophy',
      'duration': 171, // 2:51
      'authorName': 'Dr. Rebecca Kim',
      'isPremium': false,
      'dayNumber': 23,
    },
    {
      'title': 'The Ghost of Future Conversations',
      'description': 'How imaginary arguments shape real relationships. Breaking free from the conversations that never happened.',
      'category': 'Relationships',
      'duration': 207, // 3:27
      'authorName': 'Dr. David Clarke',
      'isPremium': true,
      'dayNumber': 24,
    },
    {
      'title': 'Why Procrastination Is Perfect',
      'description': 'What if delay isn\'t dysfunction but intelligence? The hidden benefits of strategic procrastination.',
      'category': 'Life Skills',
      'duration': 193, // 3:13
      'authorName': 'Dr. Amanda Walsh',
      'isPremium': false,
      'dayNumber': 25,
    },
    {
      'title': 'The Commute Meditation',
      'description': 'Transform your daily journey from dead time to deep time. The spiritual practice hiding in plain sight.',
      'category': 'Life Skills',
      'duration': 180, // 3:00
      'authorName': 'Dr. Hassan Ahmed',
      'isPremium': false,
      'dayNumber': 26,
    },
    {
      'title': 'What Librarians Know About Silence',
      'description': 'The keepers of quiet spaces understand something profound about rest, attention, and the power of pause.',
      'category': 'Philosophy',
      'duration': 191, // 3:11
      'authorName': 'Dr. Grace Mitchell',
      'isPremium': false,
      'dayNumber': 27,
    },
    {
      'title': 'The Birthday Paradox of Happiness',
      'description': 'Why the day meant to celebrate you often feels hollow. Redefining celebration in a performance-driven world.',
      'category': 'Psychology',
      'duration': 196, // 3:16
      'authorName': 'Dr. Lucas Brown',
      'isPremium': true,
      'dayNumber': 28,
    },
    {
      'title': 'The Weather Report of Emotions',
      'description': 'Feelings aren\'t facts, they\'re forecasts. Learning to read your internal climate without being ruled by it.',
      'category': 'Psychology',
      'duration': 182, // 3:02
      'authorName': 'Dr. Zoe Chen',
      'isPremium': false,
      'dayNumber': 29,
    },
    {
      'title': 'What Gardeners Know About Timing',
      'description': 'The wisdom of seasons applies to more than plants. When to plant, when to prune, when to let things lie fallow.',
      'category': 'Life Skills',
      'duration': 205, // 3:25
      'authorName': 'Dr. Robert Taylor',
      'isPremium': false,
      'dayNumber': 30,
    },
  ];

  // High-quality audio URLs for production content
  final List<String> _productionAudioUrls = [
    'https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3', // Calm piano
    'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8e9d46df7.mp3', // Acoustic guitar
    'https://cdn.pixabay.com/download/audio/2021/08/09/audio_c8c8a73acc.mp3', // Ambient soundscape
    'https://cdn.pixabay.com/download/audio/2021/11/25/audio_c997a7e3cf.mp3', // Relaxing music
    'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3', // Nature sounds
    'https://cdn.pixabay.com/download/audio/2021/07/12/audio_fb8f8a7ea8.mp3', // Meditation music
  ];

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Dangerous Operation'),
          content: const Text(
            'This will permanently delete ALL existing bites from the database. '
            'This action cannot be undone.\n\n'
            'Are you absolutely sure you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllBites();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('DELETE ALL', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _generateThumbnailUrl(String title, String category) {
    // Generate deterministic thumbnail URLs based on title hash for consistency
    final hash = title.hashCode.abs();
    
    // Create high-quality branded thumbnails using different services for variety
    final services = [
      // Gradient backgrounds with category text
      'https://dummyimage.com/400x225/FF6B35/FFFFFF.png&text=${Uri.encodeComponent(category)}',
      'https://dummyimage.com/400x225/F7931E/FFFFFF.png&text=${Uri.encodeComponent(category)}',
      'https://dummyimage.com/400x225/EE964B/FFFFFF.png&text=${Uri.encodeComponent(category)}',
      'https://dummyimage.com/400x225/C73E1D/FFFFFF.png&text=${Uri.encodeComponent(category)}',
      
      // Picsum photos with orange overlay effect (deterministic by hash)
      'https://picsum.photos/seed/${hash}/400/225',
      'https://picsum.photos/seed/${hash + 1}/400/225',
      'https://picsum.photos/seed/${hash + 2}/400/225',
      
      // Abstract patterns for variety
      'https://via.placeholder.com/400x225/FF6B35/FFFFFF.png?text=${Uri.encodeComponent(category)}',
    ];
    
    return services[hash % services.length];
  }

  Future<void> _clearAllBites() async {
    if (!mounted) return;
    
    setState(() {
      _isClearing = true;
    });

    try {
      _log('Starting to clear all existing bites...');
      
      final QuerySnapshot bitesSnapshot = await FirebaseFirestore.instance
          .collection('bites')
          .get();
      
      _log('Found ${bitesSnapshot.docs.length} bites to delete');
      
      // Delete in smaller batches to avoid timeout and reduce memory usage
      const batchSize = 100; // Reduced from 500
      final docs = bitesSnapshot.docs;
      
      for (int i = 0; i < docs.length; i += batchSize) {
        if (!mounted) return; // Check if widget is still mounted
        
        final batch = FirebaseFirestore.instance.batch();
        final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(docs[j].reference);
        }
        
        await batch.commit();
        _log('Deleted batch ${(i ~/ batchSize) + 1}: ${end - i} bites');
        
        // Add small delay to prevent overwhelming Firestore
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (mounted) {
        _log('[SUCCESS] All existing bites cleared');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All bites cleared successfully!')),
        );
      }
    } catch (e) {
      _log('[ERROR] Failed to clear bites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing bites: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  Future<void> _seedProductionData() async {
    if (!mounted) return;
    
    setState(() {
      _isSeeding = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to seed production data');
      }

      _log('Starting production data seeding...');
      _log('Creating ${_productionBites.length} production-ready bites');

      final List<String> createdBiteIds = [];

      // Create bites in smaller batches to avoid timeouts
      const batchSize = 10; // Smaller batches for better performance
      
      for (int i = 0; i < _productionBites.length; i += batchSize) {
        if (!mounted) return; // Check if widget is still mounted
        
        final batch = FirebaseFirestore.instance.batch();
        final end = (i + batchSize < _productionBites.length) ? i + batchSize : _productionBites.length;
        
        for (int j = i; j < end; j++) {
          final biteData = _productionBites[j];
          final biteRef = FirebaseFirestore.instance.collection('bites').doc();
          
          // Select audio URL based on category and index
          final audioUrl = _productionAudioUrls[j % _productionAudioUrls.length];
          
          // Generate thumbnail URL
          final thumbnailUrl = _generateThumbnailUrl(biteData['title'], biteData['category']);
          
          // Create the bite document
          final biteDocument = {
            'title': biteData['title'],
            'description': biteData['description'],
            'audioUrl': audioUrl,
            'thumbnailUrl': thumbnailUrl,
            'category': biteData['category'],
            'authorName': biteData['authorName'],
            'date': Timestamp.now(),
            'duration': biteData['duration'],
            'isPremium': biteData['isPremium'],
            'isPremiumOnly': false,
            'dayNumber': biteData['dayNumber'],
            'commentCount': 0,
            'giftedBy': '',
            'giftMessage': '',
          };

          batch.set(biteRef, biteDocument);
          createdBiteIds.add(biteRef.id);
          
          _log('Prepared bite ${j + 1}/${_productionBites.length}: "${biteData['title']}"');
        }

        // Commit this batch
        await batch.commit();
        _log('[SUCCESS] Created batch ${(i ~/ batchSize) + 1}: ${end - i} bites');
        
        // Small delay to prevent overwhelming Firestore
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        _log('[SUCCESS] Created ${_productionBites.length} production bites');

        // Add all created bites to current user's unlocked content
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'unlockedContent': FieldValue.arrayUnion(createdBiteIds),
        });
        _log('[SUCCESS] Added all bites to user\'s unlocked content');

        _log('[COMPLETE] Production data seeding finished successfully!');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created ${_productionBites.length} production-ready bites!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log('[ERROR] Failed to seed production data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding production data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Data Manager'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Production Data Manager',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Replace test data with production-ready Pumpkin Bites content featuring intriguing titles and authentic wisdom.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Statistics Card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Production Content Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Total Bites: ${_productionBites.length}'),
                    Text('Categories: Psychology, Philosophy, Business, Life Skills, Relationships'),
                    Text('Duration Range: 2:42 - 3:32 minutes'),
                    Text('Premium Bites: ${_productionBites.where((b) => b['isPremium']).length}'),
                    Text('Free Bites: ${_productionBites.where((b) => !b['isPremium']).length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSeeding || _isClearing ? null : () => _showClearConfirmation(context),
                icon: _isClearing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_sweep),
                label: const Text('CLEAR ALL EXISTING BITES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSeeding || _isClearing ? null : _seedProductionData,
                icon: _isSeeding 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create),
                label: const Text('SEED PRODUCTION DATA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Activity Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearLogs,
                  child: const Text('Clear Log'),
                ),
              ],
            ),
            const Divider(),
            
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs.reversed.map((log) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: log.contains('[ERROR]')
                            ? Colors.red
                            : log.contains('[SUCCESS]')
                                ? Colors.green
                                : log.contains('[COMPLETE]')
                                    ? Colors.blue
                                    : Colors.black87,
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}