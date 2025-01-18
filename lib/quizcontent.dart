import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizContentPage extends StatefulWidget {
  final String topic;
  final VoidCallback onQuizFinished;

  const QuizContentPage({
    super.key,
    required this.topic,
    required this.onQuizFinished,
  });

  @override
  State<QuizContentPage> createState() => _QuizContentPageState();
}

class _QuizContentPageState extends State<QuizContentPage> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isSubmitting = false;

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
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print("Error getting user ID: $e");
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
        print("Failed to load questions. Status code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print("Error fetching questions: $e");
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save quiz results to Firestore under the user's quiz_results subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('quiz_results') // Subcollection for quiz results
          .add({
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'completedAt': Timestamp.now(),
      });

      // Update subtopic status and chapter progress
      await _updateSubtopicAndChapter();

      // Notify that the quiz is finished and return to the Learning Path page
      widget.onQuizFinished();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to submit results. Please try again: $e'),
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
      print("Error submitting quiz results: $e");
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _updateSubtopicAndChapter() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Update the subtopic status to "complete"
      final subtopicDoc = firestore
          .collection('users')
          .doc(_userId)
          .collection('learningPath')
          .doc(widget.topic);

      final subtopicSnapshot = await subtopicDoc.get();
      List<Map<String, dynamic>> subtopics = [];

      if (subtopicSnapshot.exists) {
        final data = subtopicSnapshot.data();
        if (data != null) {
          subtopics = List<Map<String, dynamic>>.from(data['subtopics'] ?? []);
          for (var subtopic in subtopics) {
            if (subtopic['name'] == 'Quiz for ${widget.topic}') {
              subtopic['status'] = 'complete';
            }
          }

          // Update the subtopics in Firestore
          await subtopicDoc.update({'subtopics': subtopics});
        }
      }

      // Update the chapter progress
      final chapterDoc = firestore
          .collection('users')
          .doc(_userId)
          .collection('chapters')
          .doc(widget.topic);

      final chapterSnapshot = await chapterDoc.get();
      if (chapterSnapshot.exists) {
        final chapterData = chapterSnapshot.data();
        if (chapterData != null) {
          final totalSubtopics = chapterData['totalSubtopics'] ?? 1;
          final completedSubtopics =
              subtopics.where((s) => s['status'] == 'complete').length;

          final progressPercentage =
              (completedSubtopics / totalSubtopics) * 100;

          await chapterDoc.update({
            'completedSubtopics': completedSubtopics,
            'progressPercentage': progressPercentage,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update progress: $e'),
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
      print("Error updating subtopic and chapter progress: $e");
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
            if (_isSubmitting) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
