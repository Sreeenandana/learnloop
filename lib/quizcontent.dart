import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'weekly_leaderboard.dart';
import 'path.dart';
import 'dart:async';

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
  late Stopwatch _stopwatch;
  late Timer _timer;

  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
          _stopwatch.start();
          _timer = Timer.periodic(Duration(seconds: 1), (timer) {
            setState(() {});
          });
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

  void _showReviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Review Required'),
        content: Text(
          'Sorry! Your score is below 80%.\n\n'
          'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)\n\n'
          'Please review the chapter and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.pop(context); // Go back to the previous screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Congratulations!'),
        content: Text(
          'Great job! You have passed the quiz.\n\n'
          'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)\n\n'
          'Click "Continue" to proceed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.pop(context); // Go back to the previous screen
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishQuiz() async {
    _stopwatch.stop();
    _timer.cancel();

    double scorePercentage = (_score / _questions.length) * 100;

    if (scorePercentage < 80) {
      // Strictly below 80%
      _showReviewDialog();
      return; // Stop execution to prevent marking as completed
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.userId);

    try {
      await userRef.collection('chapterQuiz').doc(widget.topic).set({
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'totalTimeTakenMs': _stopwatch.elapsedMilliseconds,
        'modificationTime': DateTime.now().toIso8601String(),
        'status': 'completed'
      }, SetOptions(merge: true));

      // Update total score
      final chapterQuizSnapshot = await userRef.collection('chapterQuiz').get();
      int totalScore = 0;
      for (var doc in chapterQuizSnapshot.docs) {
        final data = doc.data();
        final dynamic score = data['score'];
        if (score is num) {
          totalScore += score.toInt();
        }
      }

      await userRef.set({
        'totalPoints': totalScore,
      }, SetOptions(merge: true));

      await updateLeaderboard(widget.userId, widget.topic, _score);

      await userRef.collection('learningPath').doc(widget.topic).update({
        'completed': true,
      });

      await _updateDailyStreak(userRef);
    } catch (e) {
      print("Error storing quiz score or updating streak: $e");
    }

    _showSuccessDialog();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LearningPathPage(),
      ),
    );
  }

  Future<void> _updateDailyStreak(DocumentReference userRef) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    try {
      final userDoc = await userRef.get();
      final data = userDoc.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey('lastActiveDate')) {
        final lastActive = DateTime.parse(data['lastActiveDate']);
        final lastDate =
            DateTime(lastActive.year, lastActive.month, lastActive.day);

        int streak = data['streak'] ?? 0;

        if (todayDate.difference(lastDate).inDays == 1) {
          streak += 1;
        } else if (todayDate.difference(lastDate).inDays > 1) {
          streak = 1;
        }

        await userRef.set({
          'streak': streak,
          'lastActiveDate': todayDate.toIso8601String(),
        }, SetOptions(merge: true));
      } else {
        await userRef.set({
          'streak': 1,
          'lastActiveDate': todayDate.toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error updating streak: $e");
    }
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
            /*           Text(
              'Total Time: ${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} seconds',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),*/
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time: ${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
                Text(
                  'Score: $_score / ${_questions.length}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
