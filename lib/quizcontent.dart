import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'weekly_leaderboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'pathgen.dart';
import 'package:lottie/lottie.dart';
import 'services/badge service.dart';
import 'main.dart';
import 'reviewqstns.dart';

class ChapterQuiz extends StatefulWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String topic;
  final VoidCallback onQuizFinished;
  final String userId;
  final String language;
  ChapterQuiz({
    super.key,
    required this.topic,
    required this.onQuizFinished,
    required this.userId,
    required this.language,
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
      final String prompt = await _generatePromptForQuiz(
          widget.topic, widget.userId, widget.language);
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

  Future<String> _generatePromptForQuiz(
      String topic, String userId, String language) async {
    List<String> subtopics =
        await _fetchSubtopicsFromFirestore(topic, language);
    String subtopicsString = subtopics.join(', ');

    return "Generate 20 multiple choice questions (MCQs) about $language, on topic $topic. "
        "Focus on the following subtopics: $subtopicsString. "
        "Each question must be structured as follows:"
        "qstn: [Question text]\n"
        "opt: [Option1]|[Option2]|[Option3]|[Option4]\n"
        "ans: [Correct Option (exact match from opt)]\n"
        "sub: [Subtopic]\n\n"
        "Ensure that:\n"
        "- Options are pipe | separated. do not change the format. \n"
        "- The correct answer appears exactly as listed in 'opt'.\n"
        "- No additional text is provided.";
  }

  Future<List<String>> _fetchSubtopicsFromFirestore(
      String topic, String language) async {
    List<String> subtopics = [];
    String? userId = _auth.currentUser?.uid;
    try {
      CollectionReference userCollection =
          FirebaseFirestore.instance.collection('users');
      DocumentSnapshot<Map<String, dynamic>> topicDoc = await userCollection
          .doc(userId)
          .collection("languages")
          .doc(language)
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
    Map<String, dynamic> currentQuestion = {};

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('qstn:')) {
        if (currentQuestion.isNotEmpty) {
          parsedQuestions.add(_buildQuestionMap(currentQuestion));
          currentQuestion.clear();
        }
        currentQuestion['qstn'] = line.substring(5).trim();
      } else if (line.startsWith('opt:')) {
        var options = line.substring(4).trim().split('|');
        options = options.map((opt) => opt.trim()).toList();
        if (options.length != 4) {
          print("⚠️ Warning: Incorrect options format - $options");
        }
        currentQuestion['opt'] = options;
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

  Map<String, dynamic> _buildQuestionMap(Map<String, dynamic> question) {
    return {
      'question': question['qstn'] ?? '',
      'options': question.containsKey('opt') ? question['opt'] : [],
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
//FINISHING THE QUIZ

  Future<void> _finishQuiz() async {
    _stopwatch.stop();
    _timer.cancel();

    String message;
    List<Widget> actions = [];
    bool streakModified = false;
    bool passed = (_score / _questions.length) * 100 >= 80;
    bool hasIncorrectAnswers = _incorrectQuestions.isNotEmpty;

// SCORE CALCULATION
    if (!passed) {
      message = 'Sorry! Your score is below 80%.\n\n'
          'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)\n\n'
          'Please review the chapter and try again.';

      actions.add(TextButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        child: Text('OK'),
      ));
      actions.add(ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReviewScreen(incorrectQuestions: _incorrectQuestions),
            ),
          );
        },
        child: Text('Review'),
      ));
    } else {
      message = 'Congratulations! You passed!\n'
          'Your Score: $_score / ${_questions.length} '
          '(${(_score / _questions.length * 100).toStringAsFixed(1)}%)';
      //final badgeService = BadgeService(widget.userId,navigatorKey);
      List<String> earnedBadges =
          await BadgeService(widget.userId, navigatorKey)
              .checkAndAwardQuizBadges(
                  _score, _questions.length, _stopwatch.elapsedMilliseconds);

      if (earnedBadges.isNotEmpty) {
        message += "\n🏅 Badge Earned:\n${earnedBadges.join('\n')}";
      }
      widget.onQuizFinished();

      // Add actions
      actions.add(TextButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        child: Text('OK'),
      ));

      if (hasIncorrectAnswers) {
        actions.add(ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReviewScreen(incorrectQuestions: _incorrectQuestions),
              ),
            );
          },
          child: Text('Review'),
        ));
      }
    }

    // Show Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Quiz Completed'),
        content: Text(message),
        actions: actions,
      ),
    );

// FIRESTORE UPDATES AND STREAK LOGIC
    await _updateFirestore(passed);
    streakModified = await _updateDailyStreak(
        FirebaseFirestore.instance.collection('users').doc(widget.userId));

    if (streakModified) {
      print("🔥 Streak Updated!");
    }
  }

// FIRESTORE UPDATES
  Future<void> _updateFirestore(bool passed) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.userId);
    final quizRef = userRef
        .collection('languages')
        .doc(widget.language)
        .collection('chapterQuiz')
        .doc(widget.topic);
    Map<String, dynamic> subtopicScores = {};
    List<String> weakSubtopics = [];

    // Fetch current quiz status (to check if it's a first attempt)
    final quizSnapshot = await quizRef.get();
    bool isFirstAttempt =
        !quizSnapshot.exists || quizSnapshot.data()?['status'] == 'pending';

    // Calculate subtopic scores
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

    // Compute final subtopic scores and identify weak subtopics
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
      print("updating quiz");
      // Update quiz record
      await quizRef.set({
        'topic': widget.topic,
        'score': _score,
        'totalQuestions': _questions.length,
        'totalTimeTakenMs': _stopwatch.elapsedMilliseconds,
        'modificationTime': DateTime.now().toIso8601String(),
        'status': 'completed',
        'attempts': FieldValue.increment(1),
        'subtopicScores': finalSubtopicScores,
      }, SetOptions(merge: true));

      if (!passed) {
        // User failed, update learning path
        await userRef
            .collection('languages')
            .doc(widget.language)
            .collection('learningPath')
            .doc(widget.topic)
            .update({
          'completed': false,
          'weakSubtopics': weakSubtopics.toSet().toList(),
        });

        final generator = LearningPathGenerator();
        await generator.generateOrModifyLearningPath(
          language: widget.language,
          topic: widget.topic,
          weakSubtopics: weakSubtopics,
        );
      } else {
        // User passed, update leaderboard
        await updateLeaderboard(widget.userId, widget.topic, _score);

        // Update learning path
        await userRef
            .collection('languages')
            .doc(widget.language)
            .collection('learningPath')
            .doc(widget.topic)
            .update({
          'completed': true,
          'weakSubtopics': [],
        });

        // **If first attempt and passed, add score to total points**
        if (isFirstAttempt) {
          await userRef.update({
            'totalPoints': FieldValue.increment(_score),
          });
        }
      }
    } catch (e) {
      print("Error updating Firestore: $e");
    }
  }

// ROLLING STREAK LOGIC
  Future<bool> _updateDailyStreak(DocumentReference userRef) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // Store only date
    bool streakUpdated = false;

    try {
      final userDoc = await userRef.get();
      final data = userDoc.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey('lastActiveTimestamp')) {
        final lastActive = DateTime.parse(data['lastActiveTimestamp']);
        final lastActiveDate =
            DateTime(lastActive.year, lastActive.month, lastActive.day);
        int streak = data['streak'] ?? 0;
        int daysDifference = today.difference(lastActiveDate).inDays;

        if (daysDifference == 0) {
          print("✅ User already active today. Streak remains: $streak");
          return false; // No update needed
        } else if (daysDifference == 1) {
          print("🔥 Streak continued! Increasing streak.");
          streak += 1;
          streakUpdated = true;
        } else {
          print("❌ Streak reset. More than 1 day gap.");
          streak = 1;
          streakUpdated = true;
        }

        await userRef.set({
          'streak': streak,
          'lastActiveTimestamp': today.toIso8601String(), // Store only the date
        }, SetOptions(merge: true));
      } else {
        print("🎉 First-time activity, starting new streak.");
        await userRef.set({
          'streak': 1,
          'lastActiveTimestamp': today.toIso8601String(),
        }, SetOptions(merge: true));
        streakUpdated = true;
      }
    } catch (e) {
      print("❌ Error updating streak: $e");
    }

    return streakUpdated;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Topics')),
        body: Container(
          color: Color.fromARGB(255, 231, 91, 180),
          child: Center(
            child: Lottie.asset(
              'assets/lottie/loading.json',
              width: 200,
              height: 200,
            ),
          ),
        ),
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
              'Total Time: ${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} seconds',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
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
