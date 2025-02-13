import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'content.dart'; // Make sure this exists
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
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  @override
  void initState() {
    super.initState();
    _generateLearningPath();
  }

  Future<void> _generateLearningPath() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _errorMessage = 'No user is logged in.';
          _isLoading = false;
        });
        return;
      }

      // If topicScores is not provided, try to fetch from Firestore
      Map<String, int> topicScores = widget.topicScores ?? {};

      if (topicScores.isEmpty) {
        final learningPathSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .get();

        if (learningPathSnapshot.docs.isNotEmpty) {
          for (var doc in learningPathSnapshot.docs) {
            topicScores[doc.id.replaceAll('_', ' ')] =
                0; // Default score 0 if missing
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

      // Load subtopics for each topic
      for (var topic in topicScores.keys) {
        await _generateAndLoadSubtopics(topic, topicScores[topic]!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating learning path: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAndLoadSubtopics(String topic, int score) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = _auth.currentUser?.uid;

    if (userId == null) return;
    if (_subtopics.containsKey(topic) && _subtopics[topic]!.isNotEmpty) return;

    try {
      int subtopicCount = score < 40 ? 7 : (score < 70 ? 5 : 3);

      final prompt = "Generate $subtopicCount subtopics for the topic $topic. "
          "Give only subtopic names, no descriptions, no numbering."
          "lastly also give a quiz title for the given topic. it should be'quiz:$topic.' ";

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
        .map((subtopic) => {'name': subtopic}) // Default status
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
      // Navigate to QuizContentPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterQuiz(
            topic: topic,
            userId: userId,
            onQuizFinished: () {
              // Handle quiz completion, e.g., navigate back
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      // Navigate to SubtopicContentPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubtopicContentPage(
            topic: topic,
            subtopic: subtopic,
            userId: userId,
            onSubtopicFinished: () {
              setState(() {
                // Mark current subtopic as complete
                subtopics[currentIndex]['status'] = 'complete';
              });

              // Move to next subtopic if available
              if (currentIndex + 1 < subtopics.length) {
                _navigateToContent(topic, subtopics[currentIndex + 1]['name']);
              } else {
                Navigator.pop(context); // Go back if no more subtopics
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
                        : null, // Show tick only if complete
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
