import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'weekly_leaderboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'pathgen.dart';
import 'reviewqstns.dart';
import 'pathdisplay.dart';

class ChapterQuiz extends StatefulWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String topic;
  final VoidCallback onQuizFinished;
  final String userId;

  ChapterQuiz({
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
  List<dynamic> _incorrectQuestions = [];
  late Stopwatch _stopwatch;
  late Timer _timer;

  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

      // Await the prompt since it's a Future<String>
      final String prompt =
          await _generatePromptForQuiz(widget.topic, widget.userId);
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

  Future<String> _generatePromptForQuiz(String topic, String userId) async {
    List<String> subtopics = await _fetchSubtopicsFromFirestore(topic);
    String subtopicsString = subtopics.join(', ');

    return "Generate 5 multiple choice questions (MCQs) about Java, on topic $topic. "
        "Focus on the following subtopics: $subtopicsString. "
        "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
        "'ans:' for the correct answer, and 'sub:' for the subtopic. do not use commas anywhere else other than to separate options. "
        "Separate each question set with a newline. Give exactly 4 options. "
        "Do not provide any other message or use any special characters unless necessary.";
  }

  Future<List<String>> _fetchSubtopicsFromFirestore(String topic) async {
    List<String> subtopics = [];
    String? userId = _auth.currentUser?.uid;
    try {
      CollectionReference userCollection =
          FirebaseFirestore.instance.collection('users');
      DocumentSnapshot<Map<String, dynamic>> topicDoc = await userCollection
          .doc(userId)
          .collection('learningPath') // Correctly referencing the collection
          .doc(topic)
          .get();

      if (topicDoc.exists && topicDoc.data() != null) {
        Map<String, dynamic> data = topicDoc.data()!;
        if (data.containsKey('subtopics') && data['subtopics'] is List) {
          subtopics = (data['subtopics'] as List)
              .map((subtopic) => subtopic['name'] as String)
              .toList();
        }
      }
    } catch (e) {
      print("Error fetching subtopics: $e");
    }

    //   print("subtopics in quiz $subtopics");
    return subtopics;
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
      } else if (line.startsWith('sub:')) {
        currentQuestion['sub'] = line.substring(4).trim();
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
      'subtopic': question['sub'] ?? '',
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

      // ✅ Store the selected answer as 'user_answer'
      question['user_answer'] = selectedAnswer;

      if (_isAnswerCorrect) {
        _score++;
      } else {
        _incorrectQuestions.add(question);
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
      // Show retry screen before re-asking
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _stopwatch.stop();
    _timer.cancel();

    String message;
    List<Widget> actions = [];
    bool streakModified = false; // Track if streak was modified

//SCORE CALCULATION
    if ((_score / _questions.length) * 100 < 80) {
      // User failed, show review message
      message = 'Sorry! Your score is below 80%.\n\n'
          'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)\n\n'
          'Please review the chapter and try again.';

      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Go back to the previous screen
          },
          child: Text('OK'),
        ),
      );
      actions.add(
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReviewScreen(incorrectQuestions: _incorrectQuestions),
              ),
            );
          },
          child: Text('Review'),
        ),
      );
    } else {
      // User passed, show review option
      message = 'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)\n\n'
          'Would you like to review incorrect answers?';

      actions.add(
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
          },
          child: Text('No'),
        ),
      );
      actions.add(
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReviewScreen(incorrectQuestions: _incorrectQuestions),
              ),
            );
          },
          child: Text('Review'),
        ),
      );
    }

//SCORE CHECK AND FIRSTORE
    double scorePercentage = (_score / _questions.length) * 100;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.userId);
    Map<String, dynamic> subtopicScores = {};
    List<String> weakSubtopics = [];

    for (var question in _questions) {
      String subtopic = question['subtopic'];
      bool isCorrect = (question['user_answer'] == question['correct_answer']);

      if (!subtopicScores.containsKey(subtopic)) {
        subtopicScores[subtopic] = {'correct': 0, 'total': 0};
      }
      subtopicScores[subtopic]['total'] += 1;
      if (isCorrect) {
        subtopicScores[subtopic]['correct'] += 1;
      }
    }

    Map<String, dynamic> finalSubtopicScores = {};
    subtopicScores.forEach((subtopic, scores) {
      double subtopicScorePercentage = (scores['total'] > 0)
          ? (scores['correct'] / scores['total']) * 100
          : 0;
      finalSubtopicScores[subtopic] = subtopicScorePercentage;
      if (subtopicScorePercentage < 80) {
        weakSubtopics.add(subtopic);
      }
    });

    try {
      await userRef.collection('chapterQuiz').doc(widget.topic).set({
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'totalTimeTakenMs': _stopwatch.elapsedMilliseconds,
        'modificationTime': DateTime.now().toIso8601String(),
        'status': 'completed',
        'subtopicScores': finalSubtopicScores,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating Firestore: $e");
    }

    int totalScore = 0;
    final chapterQuizSnapshot = await userRef.collection('chapterQuiz').get();
    for (var doc in chapterQuizSnapshot.docs) {
      final dynamic score = doc.data()['score'];
      if (score is num) totalScore += score.toInt();
    }

    await userRef.set({'totalPoints': totalScore}, SetOptions(merge: true));
    streakModified = await _updateDailyStreak(userRef);
    int failCount = 0;
    if (scorePercentage < 80) {
      await userRef.collection('learningPath').doc(widget.topic).update({
        'completed': false,
        'generateSimplerSubtopics': failCount + 1,
        'weakSubtopics': weakSubtopics.toSet().toList(),
      });

      // Run the learning path modification in the background
      Future.microtask(() async {
        final generator = LearningPathGenerator();
        await generator.generateOrModifyLearningPath(
          topic: widget.topic,
          weakSubtopics: weakSubtopics,
        );
      });
    } else {
      try {
        await updateLeaderboard(widget.userId, widget.topic, _score);
        await userRef.collection('learningPath').doc(widget.topic).update({
          'completed': true,
          'generateSimplerSubtopics': false,
          'weakSubtopics': [],
        });
      } catch (e) {
        print("Error updating Firestore: $e");
      }
    }

    if (streakModified) {
      message += "\n\n🔥 Streak Updated!";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Quiz Completed'),
        content: Text(message),
        actions: actions,
      ),
    );
  }

  Future<bool> _updateDailyStreak(DocumentReference userRef) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    bool streakUpdated = false;

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
          streakUpdated = true;
        } else if (todayDate.difference(lastDate).inDays > 1) {
          streak = 1;
          streakUpdated = true;
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
        streakUpdated = true;
      }
    } catch (e) {
      print("Error updating streak: $e");
    }
    return streakUpdated;
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
                /* Text(
                  'Time: ${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),*/
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
