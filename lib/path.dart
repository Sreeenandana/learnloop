import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'initial.dart'; // Import your initial assessment page

class LearningPathPage extends StatefulWidget {
  final Map<String, int>? topicScores;
  final String? highlightedTopic;

  const LearningPathPage({super.key, this.topicScores, this.highlightedTopic});

  @override
  State<LearningPathPage> createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _priorities = [];
  final Map<String, List<Map<String, dynamic>>> _subtopics = {};
  String? _currentHighlightedTopic;

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
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
        _isLoading = false;
      });
      return;
    }

    Map<String, int> topicScores = widget.topicScores ?? {};
    print('Received topicScores: $topicScores'); // Debugging print statement

    if (topicScores.isEmpty) {
      try {
        final userDoc = await firestore.collection('users').doc(userId).get();
        final data = userDoc.data();

        if (data == null || !data.containsKey('initialAssessment')) {
          setState(() {
            _errorMessage =
                'Initial assessment data is missing. Please complete the initial assessment.';
            _isLoading = false;
          });
          return;
        }

        final initialAssessment = data['initialAssessment'];
        topicScores = Map<String, int>.from(initialAssessment['marks'] ?? {});
        final totalScore = initialAssessment['totalScore'] ?? 0;

        if (topicScores.isEmpty) {
          setState(() {
            _errorMessage = 'No topic scores found in the initial assessment.';
            _isLoading = false;
          });
          return;
        }

        final maxScore = topicScores.values.isNotEmpty
            ? topicScores.values.reduce((a, b) => a > b ? a : b)
            : 1;

        List<Map<String, dynamic>> priorities =
            topicScores.entries.map((entry) {
          final normalizedScore = entry.value / maxScore;
          final priority = 1 - normalizedScore;
          return {
            'topic': entry.key,
            'priority': priority,
            'score': entry.value,
          };
        }).toList();

        priorities.add({
          'topic': 'totalscore',
          'priority': 0.0,
          'score': totalScore,
        });

        print(
            'Priorities after assessment: $priorities'); // Debugging print statement

        for (var priority in priorities) {
          final topic = priority['topic'];
          await _generateAndLoadSubtopics(topic);
        }

        if (mounted) {
          setState(() {
            _priorities = priorities;
            _isLoading = false;
            _currentHighlightedTopic =
                widget.highlightedTopic ?? _priorities.first['topic'];
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error fetching topic scores: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateAndLoadSubtopics(String topic) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
      });
      return;
    }

    if (_subtopics.containsKey(topic) && _subtopics[topic]!.isNotEmpty) {
      return; // Subtopics already loaded
    }

    try {
      final topicPriorityEntry = _priorities.firstWhere(
        (priority) => priority['topic'] == topic,
        orElse: () => {'topic': topic, 'priority': 1.0},
      );

      final topicPriority = topicPriorityEntry['priority'];
      print(
          'Generating subtopics for topic: $topic with priority: $topicPriority'); // Debugging print statement

      final prompt = _generateSubtopicPrompt(topic, topicPriority);

      final model = GenerativeModel(
        model: 'gemini-1.5-flash', // Replace with your preferred model
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

        final quizTitle = 'Quiz for $topic';

        setState(() {
          _subtopics[topic] = subtopics;
        });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .doc(topic)
            .set({
          'priority': topicPriority,
          'subtopics': subtopics,
          'quizTitle': quizTitle,
          'totalSubtopics': subtopics.length,
          'completedSubtopics': 0,
          'progressPercentage': 0,
        });

        print(
            'Subtopics generated and saved for topic: $topic'); // Debugging print statement
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
        "List the subtopics as a plain text, each separated by a newline. "
        "After the last subtopic, in the next line, include a title for quiz. It should always start with 'Quiz:' "
        "Do not provide any other message or use special characters unless necessary.";
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    final subtopics = responseText.split('\n').where((subtopic) {
      return subtopic.trim().isNotEmpty;
    }).map((subtopic) {
      return {
        'name': subtopic,
        'status': 'incomplete',
      };
    }).toList();

    print('Parsed subtopics: $subtopics'); // Debugging print statement
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
                      builder: (context) => const QuizApp(),
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
          itemCount: _priorities.length,
          itemBuilder: (context, index) {
            final topic = _priorities[index]['topic'];
            final score = _priorities[index]['score'];
            final priority = _priorities[index]['priority'];
            final subtopics = _subtopics[topic] ?? [];

            if (subtopics.isEmpty) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text(topic),
                subtitle: Text(
                    'Score: $score, Priority: ${priority.toStringAsFixed(2)}'),
                children: subtopics.map((subtopic) {
                  return ListTile(
                    title: Text(subtopic['name']),
                    tileColor: subtopic['status'] == 'complete'
                        ? Colors.grey[300]
                        : null,
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
