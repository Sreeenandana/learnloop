import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/path.dart';
import 'package:learnloop/home.dart';

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Python Quiz',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: const LevelSelectionPage(),
    );
  }
}

class LevelSelectionPage extends StatelessWidget {
  const LevelSelectionPage({super.key});

  void _startQuiz(BuildContext context, String level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Difficulty Level')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center the buttons vertically
          crossAxisAlignment:
              CrossAxisAlignment.center, // Center the buttons horizontally
          children: [
            const Text(
              'Select a difficulty level:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _startQuiz(context, 'beginner'),
              child: const Text('Beginner'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _startQuiz(context, 'intermediate'),
              child: const Text('Intermediate'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _startQuiz(context, 'advanced'),
              child: const Text('Advanced'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizPage extends StatefulWidget {
  final String level;

  const QuizPage({super.key, required this.level});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  final Map<String, int> _topicScores = {};

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url = Uri.parse(
        'http://127.0.0.1:5000/generate?level=${widget.level}'); // Replace with your Flask server URL
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _questions = data['mcqs'];
          _isLoading = false;
        });
      } else {
        _showError('Failed to load questions: ${response.body}');
      }
    } catch (e) {
      _showError('Error fetching questions: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitAnswer(String selectedAnswer) {
    final question = _questions[_currentQuestionIndex];
    final correctAnswer = question['correct_answer'];
    final topic = question['topic'];

    // Check if correctAnswer or topic is null
    if (correctAnswer == null) {
      _showError('Error: Missing data for correct_answer.');
      return;
    }
    if (topic == null) {
      _showError('Error: Missing data for topic.');
      return;
    }

    if (!_topicScores.containsKey(topic)) {
      _topicScores[topic] = 0; // Initialize score for this topic
      //_showError("initialised for $topic");
    }

    // Check if the answer is correct
    if (selectedAnswer == correctAnswer) {
      // Check if topic is missing and initialize

      // Increment score for this topic
      _topicScores[topic] = _topicScores[topic]! + 1;
      // _showError("score is $_topicScores[topic] for $topic");
      //print("score is $_topicScores[topic] for $topic");

      // Increment total score
      _score++;
    }
    // Move to the next question or show results if last question
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    // Get userId from FirebaseAuth
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: _questions.length,
          topicScores: _topicScores,
          userId: userId, // Pass userId to ResultPage
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final question = _questions[_currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(title: Text('Question ${_currentQuestionIndex + 1}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question['question'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              question['options'].length,
              (index) {
                final option = question['options'][index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: ElevatedButton(
                    onPressed: () => _submitAnswer(option),
                    child: Text(option),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final Map<String, int> topicScores;
  final String userId;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.topicScores,
    required this.userId,
  });

  Future<void> _saveResultsToFirestore() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Store topic scores and total score using userId as the document ID
      await firestore.collection('users').doc(userId).set({
        'marks': topicScores, // Save the topic scores as a map
        'totalScore': score, // Save the total score
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print("Results saved successfully!");
    } catch (e) {
      print("Error saving results: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Save results to Firestore
    _saveResultsToFirestore();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your Score: $score / $total',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LearningPathPage(topicScores: topicScores),
                  ),
                );
              },
              child: const Text('View Learning Path'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
