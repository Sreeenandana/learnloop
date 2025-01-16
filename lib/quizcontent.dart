import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizContentPage extends StatefulWidget {
  final String topic;
  const QuizContentPage({super.key, required this.topic});

  @override
  State<QuizContentPage> createState() => _QuizContentPageState();
}

class _QuizContentPageState extends State<QuizContentPage> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _hasError = false;

  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserId();
    _fetchQuestions();
  }

  Future<void> _getUserId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
      }
    } catch (_) {
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/questions?topic=${widget.topic}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _questions = data['mcqs'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
        });
      }
    } catch (_) {
      setState(() {
        _hasError = true;
      });
    }
  }

  void _submitAnswer(String selectedAnswer) {
    final correctAnswer = _questions[_currentQuestionIndex]['correct_answer'];

    if (selectedAnswer == correctAnswer) {
      setState(() {
        _score++;
      });
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitResults();
    }
  }

  Future<void> _submitResults() async {
    if (_userId == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content:
                const Text('Failed to identify user. Please log in again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('quiz_results').add({
        'userId': _userId,
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'completedAt': Timestamp.now(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quiz Completed'),
            content: Text('You scored $_score out of ${_questions.length}!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to the previous page
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to submit results. Please try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load questions. Please try again later.'),
              ElevatedButton(
                onPressed: _fetchQuestions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.topic}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              currentQuestion['question'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...currentQuestion['options'].map<Widget>((option) {
              final displayOption =
                  option.startsWith('opt:') ? option.substring(4) : option;
              return ElevatedButton(
                onPressed: () => _submitAnswer(displayOption),
                child: Text(displayOption),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
