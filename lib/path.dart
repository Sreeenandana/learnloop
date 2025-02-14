import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'content.dart'; // Ensure this exists
import 'quizcontent.dart';
import 'resultpage.dart';

class LearningPathPage extends StatefulWidget {
  final Map<String, int>? topicScores;

  const LearningPathPage({Key? key, this.topicScores}) : super(key: key);

  @override
  _LearningPathPageState createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  final Map<String, List<Map<String, dynamic>>> _subtopics = {};

  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  @override
  void initState() {
    super.initState();
    _fetchLearningPath();
  }

  Future<void> _fetchLearningPath() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _errorMessage = 'No user is logged in.';
          _isLoading = false;
        });
        return;
      }

      Map<String, int> topicScores = widget.topicScores ?? {};

      if (topicScores.isEmpty) {
        final learningPathSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .get();

        if (learningPathSnapshot.docs.isNotEmpty) {
          for (var doc in learningPathSnapshot.docs) {
            topicScores[doc.id] = 0;
          }
        } else {
          setState(() {
            _errorMessage =
                'No topic scores available to generate a learning path.';
            _isLoading = false;
          });
          return;
        }
      }

      // Fetch existing learning path from Firestore
      for (var topic in topicScores.keys) {
        await _loadSubtopicsFromFirestore(topic, topicScores[topic]!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching learning path: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubtopicsFromFirestore(String topic, int score) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('learningPath')
        .doc(topic);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists && docSnapshot.data()!.containsKey('subtopics')) {
      setState(() {
        _subtopics[topic] = List<Map<String, dynamic>>.from(
            docSnapshot.data()!['subtopics'] ?? []);
      });
    } else {
      await _generateAndStoreSubtopics(topic, score);
    }
  }

  Future<void> _generateAndStoreSubtopics(String topic, int score) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      int subtopicCount = score < 3 ? 7 : (score < 7 ? 5 : 3);

      final prompt =
          "Generate $subtopicCount subtopics for the topic $topic in the context of java in the learning order. "
          "Give only subtopic names, no descriptions, no numbering."
          "Lastly, also provide a quiz title in the format 'Quiz: $topic'.";

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        final subtopics = _parseSubtopics(response.text!);

        if (subtopics.isEmpty) {
          setState(() {
            _errorMessage = 'Generated subtopics for $topic are empty.';
          });
          return;
        }

        for (var subtopic in subtopics) {
          subtopic['status'] = 'pending'; // Default status
        }

        setState(() {
          _subtopics[topic] = subtopics;
        });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .doc(topic)
            .set({'subtopics': subtopics}, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating subtopics: $e';
      });
    }
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    return responseText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((subtopic) => {'name': subtopic.trim(), 'status': 'pending'})
        .toList();
  }

  void _navigateToContent(String topic, String subtopic) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _errorMessage = 'User not logged in.';
      });
      return;
    }

    final subtopics = _subtopics[topic];
    if (subtopics == null) return;

    int currentIndex = subtopics.indexWhere((item) => item['name'] == subtopic);

    if (subtopic.toLowerCase().startsWith("quiz:")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterQuiz(
            topic: topic,
            userId: userId,
            onQuizFinished: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubtopicContentPage(
            topic: topic,
            subtopic: subtopic,
            userId: userId,
            onSubtopicFinished: () async {
              setState(() {
                subtopics[currentIndex]['status'] = 'complete';
              });

              await firestore
                  .collection('users')
                  .doc(userId)
                  .collection('learningPath')
                  .doc(topic)
                  .update({'subtopics': subtopics});

              if (currentIndex + 1 < subtopics.length) {
                _navigateToContent(topic, subtopics[currentIndex + 1]['name']);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning Path')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning Path')),
        body: Center(
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Path')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: _subtopics.keys.map((topic) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                title: Text(topic,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                children: _subtopics[topic]!.map((subtopic) {
                  return ListTile(
                    title: Text(subtopic['name']),
                    trailing: subtopic['status'] == 'complete'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => _navigateToContent(topic, subtopic['name']),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
