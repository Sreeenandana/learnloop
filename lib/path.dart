import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:learnloop/content.dart';
import 'initial.dart';
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

  final _auth = FirebaseAuth.instance;

  // Google Generative AI API Key
  final String _apiKey =
      'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'; // Replace with your actual API key

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
      if (data == null || !data.containsKey('marks')) {
        setState(() {
          _errorMessage =
              'No learning path or initial assessment data found. Please complete the initial assessment.';
          _isLoading = false;
        });
        return;
      }

      final Map<String, int> topicScores = Map<String, int>.from(data['marks']);
      if (topicScores.isEmpty) {
        setState(() {
          _errorMessage = 'No topic scores found in the initial assessment.';
          _isLoading = false;
        });
        return;
      }

      _generateLearningPath(topicScores);
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

  Future<void> _generateLearningPath(Map<String, int> topicScores) async {
    try {
      final maxScore = topicScores.values.isNotEmpty
          ? topicScores.values.reduce((a, b) => a > b ? a : b)
          : 1;

      for (var entry in topicScores.entries) {
        final normalizedScore = entry.value / maxScore;
        final priority = 1 - normalizedScore;
        final topic = entry.key;

        await _generateAndLoadSubtopics(topic, priority, entry.value);
      }

      setState(() {
        _topics = topicScores.keys.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating learning path: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAndLoadSubtopics(
      String topic, double priority, int score) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
      });
      return;
    }

    if (_subtopics.containsKey(topic) && _subtopics[topic]!.isNotEmpty) {
      return;
    }

    try {
      final prompt = _generateSubtopicPrompt(topic, priority);

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
            _errorMessage =
                'Generated subtopics for $topic are empty. Skipping topic.';
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
            .set(
          {
            'priority': priority,
            'score': score,
            'subtopics': subtopics,
            'totalSubtopics': subtopics.length,
            'completedSubtopics': 0,
            'progressPercentage': 0,
          },
          SetOptions(merge: true),
        );
      } else {
        setState(() {
          _errorMessage =
              'Failed to load subtopics for $topic: Unable to generate response.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating subtopics: $e';
      });
    }
  }

  String _generateSubtopicPrompt(String topic, double priority) {
    return "Generate 5 subtopics for the topic $topic based on its priority $priority (0: high priority, 1: low priority). "
        "For high priority topics, assume the user is a beginner, and for low priority, assume the user has advanced knowledge. "
        "List the subtopics as plain text, each separated by a newline. "
        "After the last subtopic, in the next line, include a title for the quiz. It should always start with 'Quiz:' "
        "Do not provide any other message or use special characters unless necessary.";
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    final subtopics = responseText.split('\n').where((subtopic) {
      return subtopic.trim().isNotEmpty && !subtopic.startsWith('Quiz:');
    }).map((subtopic) {
      return {
        'name': subtopic,
        'status': 'incomplete',
      };
    }).toList();

    return subtopics;
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizPage(),
                    ),
                  );
                },
                child: const Text('Take Initial Assessment'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Path')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _topics.length,
          itemBuilder: (context, index) {
            final topic = _topics[index];
            final subtopics = _subtopics[topic] ?? [];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text(topic),
                children: [
                  ...subtopics.map((subtopic) {
                    return ListTile(
                      title: Text(subtopic['name']),
                      tileColor: subtopic['status'] == 'complete'
                          ? Colors.grey[300]
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubtopicContentPage(
                              topic: topic,
                              subtopic: subtopic['name'],
                              userId: _auth.currentUser!.uid,
                              onSubtopicFinished: () {
                                setState(() {
                                  subtopic['status'] = 'complete';
                                });
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                  ListTile(
                    title: const Text('Quiz'),
                    tileColor: Colors.blue[50],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChapterQuiz(
                            userId: _auth.currentUser!.uid,
                            topic: topic,
                            onQuizFinished: () {
                              setState(() {
                                print('Quiz for $topic completed!');
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
