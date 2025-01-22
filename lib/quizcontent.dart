import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'path.dart';

class ChapterQuiz extends StatefulWidget {
  final String topic;
  final VoidCallback onQuizFinished;
  final String userId; // Pass userId to the constructor

  const ChapterQuiz({
    super.key,
    required this.topic,
    required this.onQuizFinished,
    required this.userId, // Receive userId as parameter
  });

  @override
  State<ChapterQuiz> createState() => _ChapterQuizState();
}

class _ChapterQuizState extends State<ChapterQuiz> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  final Map<String, int> _topicScores = {};
  final String _apiKey =
      'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = _generatePromptForQuiz(widget.topic);
      final content = [Content.text(prompt)];

      final response = await model.generateContent(content);

      if (response.text != null) {
        setState(() {
          _questions = _parseQuestions(response.text!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _questions = [];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _questions = [];
      });
      _showError('Error fetching questions: $e');
    }
  }

  String _generatePromptForQuiz(String topic) {
    return "Generate 10 multiple choice questions (MCQs) about Java, on topic $topic. "
        "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
        "'ans:' for the correct answer, and 'top:' for the topic. Separate each question set with a newline. give only 4 options."
        "Do not provide any other message or use any special characters unless necessary.";
  }

  List<dynamic> _parseQuestions(String responseText) {
    final List<dynamic> parsedQuestions = [];
    final lines = responseText.split('\n');
    Map<String, String> currentQuestion = {};

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('qstn:')) {
        if (currentQuestion.isNotEmpty) {
          if (_isValidQuestion(currentQuestion)) {
            parsedQuestions.add(_buildQuestionMap(currentQuestion));
          }
          currentQuestion.clear();
        }
        currentQuestion['qstn'] = line.substring(5).trim();
      } else if (line.startsWith('opt:')) {
        currentQuestion['opt'] = line.substring(4).trim();
      } else if (line.startsWith('ans:')) {
        currentQuestion['ans'] = line.substring(4).trim();
      } else if (line.startsWith('top:')) {
        currentQuestion['top'] = line.substring(4).trim();
      }
    }

    if (_isValidQuestion(currentQuestion)) {
      parsedQuestions.add(_buildQuestionMap(currentQuestion));
    }

    return parsedQuestions;
  }

  bool _isValidQuestion(Map<String, String> question) {
    return question.containsKey('qstn') &&
        question.containsKey('opt') &&
        question.containsKey('ans') &&
        question.containsKey('top');
  }

  Map<String, dynamic> _buildQuestionMap(Map<String, String> question) {
    return {
      'question': question['qstn'] ?? '',
      'options':
          (question['opt'] ?? '').split(',').map((opt) => opt.trim()).toList(),
      'correct_answer': question['ans'] ?? '',
      'topic': question['top'] ?? '',
    };
  }

  void _showError(String message) {
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
    final topic = question['topic'] ?? 'General';

    if (correctAnswer == null) {
      _showError('Error: Missing data for correct_answer.');
      return;
    }

    if (!_topicScores.containsKey(topic)) {
      _topicScores[topic] = 0;
    }

    if (selectedAnswer == correctAnswer) {
      _topicScores[topic] = _topicScores[topic]! + 1;
      _score++;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    widget.onQuizFinished();

    final userId = widget.userId; // Use the passed userId
    final firestore = FirebaseFirestore.instance;

    try {
      // Store the score in Firestore under the user's document for the specific topic
      await firestore
          .collection('users')
          .doc(userId)
          .collection('chapterQuiz')
          .doc(widget.topic) // Use the topic as the document ID
          .set(
              {
            'topic': widget.topic,
            'score': _score,
            'totalQuestions': _questions.length,
            'modificationTime':
                FieldValue.serverTimestamp(), // Save modification time
          },
              SetOptions(
                  merge:
                      true)); // Use merge to update the document if it already exists

      // Mark the quiz as completed in learningPath document
      await firestore
          .collection('users')
          .doc(userId)
          .collection('learningPath')
          .doc(widget.topic)
          .update({
        'completed': true, // Mark as completed
        //'timestamp': FieldValue.serverTimestamp(),
      });

      print("Quiz score stored and marked as completed.");
    } catch (e) {
      print("Error storing quiz score: $e");
    }

    // Optionally, navigate back to the LearningPathPage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              const LearningPathPage()), // Pass userId back to the LearningPathPage
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
