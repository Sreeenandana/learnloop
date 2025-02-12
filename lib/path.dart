import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  List<String> _topics = [];
  final Map<String, List<Map<String, dynamic>>> _subtopics = {};
  final Map<String, bool> _selectedTopics = {}; // Store user-selected topics

  final _auth = FirebaseAuth.instance;

  // Google Generative AI API Key (Consider storing securely)
  final String _apiKey =
      'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'; // Store securely in env vars

  @override
  void initState() {
    super.initState();
    _loadUserLearningPath();
  }

  Future<void> _loadUserLearningPath() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final learningPathSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('learningPath')
          .get();

      if (learningPathSnapshot.docs.isNotEmpty) {
        _loadExistingLearningPath(learningPathSnapshot);
        return;
      }

      final userDoc = await firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      if (data == null || !data.containsKey('topic_scores')) {
        setState(() {
          _errorMessage =
              'No learning path or initial assessment data found. Please complete the initial assessment.';
          _isLoading = false;
        });
        return;
      }

      final Map<String, int> topicScores =
          Map<String, int>.from(data['topic_scores']);
      if (topicScores.isEmpty) {
        setState(() {
          _errorMessage = 'No topic scores found in the initial assessment.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _selectedTopics.clear();
        for (var topic in topicScores.keys) {
          _selectedTopics[topic] = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading learning path: $e';
        _isLoading = false;
      });
    }
  }

  void _loadExistingLearningPath(QuerySnapshot learningPathSnapshot) {
    final List<String> topics = [];
    final Map<String, List<Map<String, dynamic>>> subtopics = {};

    for (var doc in learningPathSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      topics.add(doc.id);
      subtopics[doc.id] = List<Map<String, dynamic>>.from(data['subtopics']);
    }

    setState(() {
      _topics = topics;
      _subtopics.addAll(subtopics);
      _isLoading = false;
    });
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

      _topics = _selectedTopics.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      for (var topic in _topics) {
        await _generateAndLoadSubtopics(topic);
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

  Future<void> _generateAndLoadSubtopics(String topic) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = _auth.currentUser?.uid;

    if (userId == null) return;
    if (_subtopics.containsKey(topic) && _subtopics[topic]!.isNotEmpty) return;

    try {
      final prompt = "Generate 5 subtopics for the topic $topic.";

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
        .map((subtopic) => {'name': subtopic, 'status': 'incomplete'})
        .toList();
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
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _generateLearningPath,
            child: const Text('Generate Learning Path'),
          ),
          Expanded(
            child: ListView(
              children: _selectedTopics.keys.map((topic) {
                return CheckboxListTile(
                  title: Text(topic),
                  value: _selectedTopics[topic],
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedTopics[topic] = value ?? false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
