import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Python Quiz',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LevelSelectionPage(),
    );
  }
}

class LevelSelectionPage extends StatefulWidget {
  const LevelSelectionPage({super.key});

  @override
  LevelSelectionPageState createState() => LevelSelectionPageState();
}

class LevelSelectionPageState extends State<LevelSelectionPage> {
  final TextEditingController _nameController = TextEditingController();

  void _startQuiz(BuildContext context, String level) {
    if (_nameController.text.isEmpty) {
      // Show an error if the name is not entered
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Please enter your name.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String userName = _nameController.text;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(level: level, userName: userName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Difficulty Level')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter your name:',
              style: TextStyle(fontSize: 18),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _startQuiz(context, 'beginner'),
              child: const Text('Beginner'),
            ),
            ElevatedButton(
              onPressed: () => _startQuiz(context, 'intermediate'),
              child: const Text('Intermediate'),
            ),
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
  final String userName; // Accept userName as a parameter

  const QuizPage({super.key, required this.level, required this.userName});

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

    if (selectedAnswer == correctAnswer) {
      // Increment the score for the topic
      if (!_topicScores.containsKey(topic)) {
        _topicScores[topic] = 0;
      }
      _topicScores[topic] = _topicScores[topic]! + 1;
      _score++;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: _questions.length,
          topicScores: _topicScores,
          userId: "user123", // You can use a dynamic userId here
          userName: widget.userName, // Pass userName to ResultPage
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
                return ElevatedButton(
                  onPressed: () => _submitAnswer(option),
                  child: Text(option),
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
  final Map<String, int> topicScores; // Pass topic-wise scores
  final String userId; // Dynamic user ID
  final String userName; // Dynamic user name

  // Constructor to accept dynamic userId and userName
  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.topicScores,
    required this.userId, // Accept userId dynamically
    required this.userName, // Accept userName dynamically
  });

  Future<void> _saveResultsToFirestore() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      await firestore.collection('users').doc(userId).set({
        'name': userName,
        'marks': topicScores, // Store topic-wise scores
        'totalScore': score,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("Results saved successfully!");
    } catch (e) {
      print("Error saving results: $e");
    }
  }

  List<String> _getWeakTopics() {
    List<String> weakTopics = [];
    topicScores.forEach((topic, score) {
      // You can set your own threshold for weak topics, here it's 3
      if (score < 3) {
        weakTopics.add(topic);
      }
    });
    return weakTopics;
  }

  @override
  Widget build(BuildContext context) {
    // Save results when the result page is loaded
    _saveResultsToFirestore();

    List<String> weakTopics = _getWeakTopics();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your Score: $score / $total',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (weakTopics.isNotEmpty)
              Text(
                'Focus on these weak topics: ${weakTopics.join(', ')}',
                style: const TextStyle(fontSize: 18, color: Colors.red),
              )
            else
              const Text(
                'Great job! You are strong in all topics!',
                style: TextStyle(fontSize: 18, color: Colors.green),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LevelSelectionPage()),
                );
              },
              child: const Text('Retry Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
