import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'content.dart';
import 'quizcontent.dart'; // Assuming you have SubtopicContentPage here

class LearningPathPage extends StatefulWidget {
  final Map<String, int>? topicScores;

  const LearningPathPage({super.key, this.topicScores});

  @override
  State<LearningPathPage> createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _priorities = [];
  final Map<String, List<String>> _subtopics = {};

  @override
  void initState() {
    super.initState();
    _loadUserLearningPath();
  }

  Future<void> _loadUserLearningPath() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
        _isLoading = false;
      });
      return;
    }

    Map<String, int> topicScores = widget.topicScores ?? {};

    if (topicScores.isEmpty) {
      try {
        final userDoc = await firestore.collection('users').doc(userId).get();
        topicScores = Map<String, int>.from(userDoc.data()?['marks'] ?? {});
      } catch (e) {
        setState(() {
          _errorMessage = 'Error fetching topic scores: $e';
          _isLoading = false;
        });
        return;
      }
    }

    if (topicScores.isEmpty) {
      setState(() {
        _errorMessage = 'No topic scores found.';
        _isLoading = false;
      });
      return;
    }

    await _generateLearningPath(userId, topicScores);
  }

  Future<void> _generateLearningPath(
      String userId, Map<String, int> topicScores) async {
    try {
      final maxScore = topicScores.values.isNotEmpty
          ? topicScores.values.reduce((a, b) => a > b ? a : b)
          : 1;

      List<Map<String, dynamic>> priorities = topicScores.entries.map((entry) {
        final normalizedScore = entry.value / maxScore;
        final priority = 1 - normalizedScore;
        return {
          'topic': entry.key,
          'priority': priority,
          'score': entry.value,
        };
      }).toList();

      await _fetchSubtopics(priorities);

      if (mounted) {
        setState(() {
          _priorities = priorities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error generating learning path: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSubtopics(List<Map<String, dynamic>> priorities) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
      });
      return;
    }

    try {
      for (var priority in priorities) {
        final topic = priority['topic'];
        final topicPriority = priority['priority'];

        final response = await http.get(Uri.parse(
            'http://127.0.0.1:5000/subtopics?topic=$topic&priority=$topicPriority'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final subtopics = List<String>.from(data['subtopics']);
          final quizTitle = data['quizTitle'] ?? 'Quiz for $topic';

          setState(() {
            _subtopics[topic] = [...subtopics, quizTitle];
          });

          // Save the subtopics and quiz title in Firestore (root collection 'learningPath')
          await firestore.collection('learningPath').doc(topic).set(
            {
              'subtopics': subtopics,
              'quizTitle': quizTitle,
            },
            SetOptions(
                merge: true), // Use merge to avoid overwriting existing data
          );
        } else {
          setState(() {
            _errorMessage =
                'Failed to load subtopics for $topic: ${response.body}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching subtopics: $e';
      });
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
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Path')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _priorities.length,
          itemBuilder: (context, index) {
            final topic = _priorities[index]['topic'];
            final score = _priorities[index]['score'];
            final priority = _priorities[index]['priority'];
            final subtopics = _subtopics[topic] ?? [];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text(
                  topic,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    'Score: $score, Priority: ${priority.toStringAsFixed(2)}'),
                children: subtopics.map((item) {
                  final isQuiz = item.startsWith('Quiz');
                  return ListTile(
                    title: Text(item),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => isQuiz
                              ? QuizContentPage(topic: topic)
                              : SubtopicContentPage(subtopic: item),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
