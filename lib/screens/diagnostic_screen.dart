import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _repairGiftedEpisodes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Repair Gifts'),
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
                    onPressed: _isRunning ? null : _fixAwaitingGifts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text('Fix Awaiting Gifts'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _addGiftManually,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Add Gift Manually'),
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
      
      // Check user's gifted episodes - FIXED VERSION
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
        
        _log('Bite: $title ($id)');
        _log('  Audio URL: $audioUrl');
        
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
              'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            });
            _log('[SUCCESS] Replaced invalid URL with placeholder');
          } catch (e) {
            _log('[ERROR] Failed to fix invalid URL: $e');
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

  Future<void> _repairGiftedEpisodes() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Starting gifted episodes repair...');
      
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
      
      // Replace the giftedEpisodes array with a valid structure
      _log('Replacing giftedEpisodes with a valid structure...');
      
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'giftedEpisodes': []
        });
        _log('[SUCCESS] Reset giftedEpisodes to an empty array');
        
        // Scan for any gifts and add them properly
        final giftsQuery = await _firestore
            .collection('gifts')
            .where('recipientEmail', isEqualTo: user.email)
            .where('type', isEqualTo: 'episode')
            .get();
        
        _log('Found ${giftsQuery.docs.length} episode gifts to restore');
        
        for (final doc in giftsQuery.docs) {
          final data = doc.data();
          try {
            // Use Timestamp.now() instead of FieldValue.serverTimestamp()
            final timestamp = Timestamp.now();
            
            final giftedEpisode = {
              'giftId': doc.id,
              'biteId': data['biteId'],
              'senderUid': data['senderUid'],
              'senderName': data['senderName'],
              'receivedAt': timestamp,
            };
            
            await _firestore.collection('users').doc(user.uid).update({
              'giftedEpisodes': FieldValue.arrayUnion([giftedEpisode]),
            });
            
            _log('[SUCCESS] Restored gift: ${doc.id}');
          } catch (e) {
            _log('[ERROR] Failed to restore gift ${doc.id}: $e');
          }
        }
      } catch (e) {
        _log('[ERROR] Failed to reset giftedEpisodes: $e');
      }
      
      _log('Repair completed');
    } catch (e) {
      _log('[ERROR] Exception during repair: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  // New function to fix awaiting gifts 
  Future<void> _fixAwaitingGifts() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Starting to fix awaiting gifts...');
      
      // Check current user
      final user = _auth.currentUser;
      if (user == null) {
        _log('[ERROR] No user logged in');
        return;
      }
      
      _log('Current user: ${user.email} (${user.uid})');
      
      // Find all awaiting gifts for this user
      final giftsQuery = await _firestore
          .collection('gifts')
          .where('recipientEmail', isEqualTo: user.email)
          .where('status', isEqualTo: 'awaiting_registration')
          .get();
      
      _log('Found ${giftsQuery.docs.length} awaiting gifts');
      
      for (final doc in giftsQuery.docs) {
        try {
          await _firestore.collection('gifts').doc(doc.id).update({
            'recipientUid': user.uid,
            'status': 'pending',
            'receivedAt': Timestamp.now(),
          });
          _log('[SUCCESS] Updated gift status: ${doc.id}');
        } catch (e) {
          _log('[ERROR] Failed to update gift: $e');
        }
      }
      
      _log('Fix awaiting gifts completed');
    } catch (e) {
      _log('[ERROR] Exception fixing awaiting gifts: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  // New function to add a gift manually
  Future<void> _addGiftManually() async {
    setState(() {
      _isRunning = true;
    });

    try {
      _log('Starting to add gift manually...');
      
      // Check current user
      final user = _auth.currentUser;
      if (user == null) {
        _log('[ERROR] No user logged in');
        return;
      }
      
      _log('Current user: ${user.email} (${user.uid})');
      
      // Get the bites for selection
      final bitesQuery = await _firestore
          .collection('bites')
          .limit(1)
          .get();
      
      if (bitesQuery.docs.isEmpty) {
        _log('[ERROR] No bites found');
        return;
      }
      
      final biteDoc = bitesQuery.docs.first;
      final biteId = biteDoc.id;
      final biteTitle = biteDoc.data()['title'] ?? 'Unknown Bite';
      
      _log('Selected bite: $biteTitle ($biteId)');
      
      // Create a timestamp
      final timestamp = Timestamp.now();
      
      // Add to giftedEpisodes directly
      try {
        final giftedEpisode = {
          'giftId': 'manual-${DateTime.now().millisecondsSinceEpoch}',
          'biteId': biteId,
          'senderUid': 'manual',
          'senderName': 'Manual Addition',
          'receivedAt': timestamp,
        };
        
        await _firestore.collection('users').doc(user.uid).update({
          'giftedEpisodes': FieldValue.arrayUnion([giftedEpisode]),
          'unreadGifts': FieldValue.increment(1),
        });
        
        _log('[SUCCESS] Manually added gift for bite: $biteTitle');
      } catch (e) {
        _log('[ERROR] Failed to add gift manually: $e');
      }
      
      _log('Manual gift addition completed');
    } catch (e) {
      _log('[ERROR] Exception during manual gift addition: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}