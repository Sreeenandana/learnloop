import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resultpage.dart';

class QuizPage extends StatefulWidget {
  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  List<String> _topics = [];
  final Set<String> _selectedTopics = {};
  bool _quizStarted = false;
  bool _isLoadingTopics = true;
  bool _isLoadingQuestions = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  Map<String, int> _topicScores = LinkedHashMap();
  Map<int, String> _userAnswers = {};
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _fetchTopics(); // Fetch topics when the page loads
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTopics) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Topics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_quizStarted) {
      return _buildTopicSelectionUI();
    }

    return _buildQuizUI();
  }

  Future<void> _fetchTopics() async {
    // Static list of 12 ordered topics
    setState(() {
      _topics = [
        "1. Introduction to Java",
        "2. Data Types and Variables",
        "3. Control Flow and loops",
        "4. Arrays and Strings ",
        "5. Methods and Functions",
        "6. Object-Oriented Programming (OOP)",
        "7. Inheritance and Polymorphism",
        "8. Exception Handling",
        "9. File Handling in Java"
      ];
      _isLoadingTopics = false; // Stop loading once topics are received
      print("Topics received: $_topics");
    });
  }

  Widget _buildTopicSelectionUI() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Topics'),
        backgroundColor: Color(0xFFdda0dd),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFdda0dd), Colors.purple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select topics for your quiz:",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView(
                  children: _topics.map((topic) {
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          topic,
                          style: const TextStyle(fontSize: 16),
                        ),
                        value: _selectedTopics.contains(topic),
                        activeColor: Color(0xFFdda0dd),
                        checkColor: Colors.white,
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedTopics.add(topic);
                            } else {
                              _selectedTopics.remove(topic);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Start Quiz Button
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: _selectedTopics.isNotEmpty ? _startQuiz : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFdda0dd),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Start Quiz"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startQuiz() {
/*    if (_selectedTopics.isEmpty) {
      _showError("Please select at least one topic to start the quiz.");
      return;
    }*/
    setState(() {
      _quizStarted = true;
      _isLoadingQuestions = true;
    });
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );

    List<Map<String, dynamic>> generatedQuestions = [];
    int questionsPerTopic =
        (5 / _selectedTopics.length).ceil(); // Distribute 20 questions

    for (var topic in _selectedTopics) {
      try {
        print("Fetching questions for topic: $topic");
        final response = await model.generateContent([
          Content.text(
              "Generate $questionsPerTopic beginner-level java related multiple-choice questions (MCQs) with exactly 4 options and no more. "
              "from the topic '$topic'. ignore the number before the topic name. Format each question as 'qstn:', options as 'opt:'(separated by :), 'ans:' for the correct answer, and 'top:' for the topic which should be $topic including the number at the beginning."
              " do not repeat questions. do not put unnecessary special characters or explanations or brackets.")
        ]);

        if (response.text != null) {
          List<Map<String, dynamic>> parsed = _parseQuestions(response.text!);
          print("Parsed questions for $topic: $parsed");
          generatedQuestions.addAll(parsed);
        }
      } catch (e) {
        _showError("Error fetching questions for $topic: $e");
      }
    }

    setState(() {
      _questions =
          generatedQuestions.take(20).toList(); // Limit to 20 questions
      _isLoadingQuestions = false;
    });
  }

  List<Map<String, dynamic>> _parseQuestions(String responseText) {
    List<Map<String, dynamic>> parsedQuestions = [];
    List<String> lines = responseText.split('\n');

    String? currentQuestion;
    List<String> currentOptions = [];
    String? correctAnswer;
    String? topic;

    for (String line in lines) {
      line = line.trim();
      if (line.startsWith("qstn:")) {
        if (currentQuestion != null &&
            currentOptions.isNotEmpty &&
            correctAnswer != null) {
          parsedQuestions.add({
            "question": currentQuestion,
            "options": List<String>.from(currentOptions),
            "correct_answer": correctAnswer,
            "topic": topic ?? "General",
          });
        }
        currentQuestion = line.substring(5).trim();
        currentOptions = [];
        correctAnswer = null;
        topic = null;
      } else if (line.startsWith("opt:")) {
        currentOptions =
            line.substring(4).split(':').map((s) => s.trim()).toList();
      } else if (line.startsWith("ans:")) {
        correctAnswer = line.substring(4).trim();
      } else if (line.startsWith("top:")) {
        topic = line.substring(4).trim();
      }
    }

    if (currentQuestion != null &&
        currentOptions.isNotEmpty &&
        correctAnswer != null) {
      parsedQuestions.add({
        "question": currentQuestion,
        "options": List<String>.from(currentOptions),
        "correct_answer": correctAnswer,
        "topic": topic ?? "General",
      });
    }

    return parsedQuestions;
  }

  Widget _buildQuizUI() {
    if (_isLoadingQuestions) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No questions available.')),
      );
    }

    final question = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFdda0dd)),
            ),
            const SizedBox(height: 20),

            // Question Number
            Text(
              "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Question Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  question['question'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Answer Options
            Column(
              children: (question['options'] as List<String>).map((option) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: _selectedAnswer,
                    activeColor: Color(0xFFdda0dd),
                    onChanged: (value) {
                      setState(() {
                        _selectedAnswer = value;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Next/Finish Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _selectedAnswer == null ? null : _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFdda0dd),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < _questions.length - 1
                      ? "Next"
                      : "Finish Quiz",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final question = _questions[_currentQuestionIndex];
    final correctAnswer = question['correct_answer'];
    final topic = question['topic'] ?? 'General';

    _userAnswers[_currentQuestionIndex] = _selectedAnswer!;
    if (_selectedAnswer == correctAnswer) {
      _score++;
      _topicScores[topic] = (_topicScores[topic] ?? 0) + 1;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      });
    } else {
      _goToResultPage();
    }
  }

  void _goToResultPage() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
    for (var topic in _topics) {
      _topicScores.putIfAbsent(topic, () => 0);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: _questions.length,
          topicScores: _topicScores,
          userId: userId,
          questions: _questions,
          userAnswers: _userAnswers,
        ),
      ),
    );
  }

  void _showError(String message) {
    print("ERROR: $message");
  g}
}
