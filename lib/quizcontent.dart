import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'weekly_leaderboard.dart';
import 'path.dart';

class ChapterQuiz extends StatefulWidget {
  final String topic;
  final VoidCallback onQuizFinished;
  final String userId;

  const ChapterQuiz({
    super.key,
    required this.topic,
    required this.onQuizFinished,
    required this.userId,
  });

  @override
  State<ChapterQuiz> createState() => _ChapterQuizState();
}

class _ChapterQuizState extends State<ChapterQuiz> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  String? _feedbackMessage;
  bool _isAnswerCorrect = false;
  bool _hasAnswered = false;

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
    }
  }

  String _generatePromptForQuiz(String topic) {
    return "Generate 10 multiple choice questions (MCQs) about Java, on topic $topic. "
        "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
        "'ans:' for the correct answer, and 'top:' for the topic. Separate each question set with a newline. Give only 4 options."
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
          parsedQuestions.add(_buildQuestionMap(currentQuestion));
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

    if (currentQuestion.isNotEmpty) {
      parsedQuestions.add(_buildQuestionMap(currentQuestion));
    }

    return parsedQuestions;
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

  void _submitAnswer(String selectedAnswer) {
    final question = _questions[_currentQuestionIndex];
    final correctAnswer = question['correct_answer'];

    setState(() {
      _hasAnswered = true;
      _isAnswerCorrect = (selectedAnswer == correctAnswer);
      _feedbackMessage = _isAnswerCorrect
          ? 'Correct!'
          : 'Incorrect. The correct answer is "$correctAnswer".';

      if (_isAnswerCorrect) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _hasAnswered = false;
        _feedbackMessage = null;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    widget.onQuizFinished();

    final firestore = FirebaseFirestore.instance;

    try {
      // Update chapter quiz data
      await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('chapterQuiz')
          .doc(widget.topic)
          .set({
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'modificationTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Fetch all chapter scores to calculate total score
      final chapterQuizSnapshot = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('chapterQuiz')
          .get();

      int totalScore = 0;
      for (var doc in chapterQuizSnapshot.docs) {
        final data = doc.data();
        final dynamic score = data['score']; // Use dynamic to avoid type issues
        if (score is num) {
          // Ensure it's a number
          totalScore += score.toInt(); // Safely cast to int
        }
      }

      // Update totalScore in the user's document
      await firestore.collection('users').doc(widget.userId).set({
        'totalPoints': totalScore,
      }, SetOptions(merge: true));

      // Update leaderboard after finishing the quiz
      await updateLeaderboard(widget.userId, widget.topic, _score);

      // Mark the topic as completed in the learning path
      await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('learningPath')
          .doc(widget.topic)
          .update({
        'completed': true,
      });
    } catch (e) {
      print("Error storing quiz score or updating totalPoints: $e");
    }

    // Navigate to the learning path page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LearningPathPage(),
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
                    onPressed:
                        _hasAnswered ? null : () => _submitAnswer(option),
                    child: Text(option),
                  ),
                );
              },
            ),
            if (_hasAnswered)
              Column(
                children: [
                  Text(
                    _feedbackMessage ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isAnswerCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _nextQuestion,
                    child: Text(
                      _currentQuestionIndex < _questions.length - 1
                          ? 'Next Question'
                          : 'Finish Quiz',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
