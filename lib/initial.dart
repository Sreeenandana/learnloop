import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Map<String, int> _topicScores = {};
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
    print("Fetching topics...");
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );

    try {
      final response = await model.generateContent([
        Content.text(
            "Generate a list of 7 unique java topics in order of learning. Only give topics, no description and no serial number.the topic names should have no special characters in it ")
      ]);

      if (response.text != null) {
        setState(() {
          _topics =
              response.text!.split('\n').where((t) => t.isNotEmpty).toList();
          _isLoadingTopics = false; // Stop loading once topics are received
          print("Topics received: $_topics");
        });
      }
    } catch (e) {
      _showError("Error fetching topics: $e");
    }
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
    if (_selectedTopics.isEmpty) {
      _showError("Please select at least one topic to start the quiz.");
      return;
    }
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
        (10 / _selectedTopics.length).ceil(); // Distribute 20 questions

    for (var topic in _selectedTopics) {
      try {
        print("Fetching questions for topic: $topic");
        final response = await model.generateContent([
          Content.text(
              "Generate $questionsPerTopic beginner-level multiple-choice questions (MCQs) with exactly 4 options. "
              "from the topic '$topic'. Format each question as 'qstn:', options as 'opt:'(comma-separated), 'ans:' for the correct answer, and 'top:' for the topic. do not repeat questions. do not put unnecessary special characters")
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
            line.substring(4).split(',').map((s) => s.trim()).toList();
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
      body: Padding(
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
  }
}





/*
class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Initial Assessment',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 6, 186, 12),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
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
      appBar: AppBar(title: const Text('Difficulty Level')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
  final String _apiKey =
      'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    _fetchQuestions(); // Fetch questions when the page is initialized
  }

  Future<void> _fetchQuestions() async {
    try {
      // Initialize the Google Generative AI SDK with the API key and model name
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', // Replace with your preferred model
        apiKey: _apiKey,
      );

      // Generate the prompt based on the selected level
      final prompt = _generatePromptForLevel(widget.level);
      final content = [Content.text(prompt)];

      // Generate content using the AI model
      final response = await model.generateContent(content);

      if (response.text != null) {
        // print('API Response: ${response.text}'); // Log the raw response
        setState(() {
          _questions =
              _parseQuestions(response.text!); // Parse questions from response
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _questions = [];
        });
        _showError('No content generated from API.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _questions = [];
      });
      _showError('Error fetching questions: $e');
    }
  }

  String _generatePromptForLevel(String level) {
    switch (level) {
      case 'beginner':
        return "Generate 20 beginner-level Java multiple choice questions (MCQs) about variables, loops, and basic syntax. "
            "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
            "'ans:' for the correct answer, and 'top:' for the topic. give only 4 options. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      case 'intermediate':
        return "Generate 20 intermediate-level Java multiple choice questions (MCQs) about functions, classes, and data structures. "
            "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
            "'ans:' for the correct answer, and 'top:' for the topic. give only 4 options. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      case 'advanced':
        return "Generate 20 advanced-level Java multiple choice questions (MCQs) about algorithms, data science, and optimization. "
            "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
            "'ans:' for the correct answer, and 'top:' for the topic. give only 4 options. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      default:
        return '';
    }
  }

  List<dynamic> _parseQuestions(String responseText) {
    final List<dynamic> parsedQuestions = [];
    final lines = responseText.split('\n'); // Split the response into lines
    // print('Response lines: $lines'); // Log the lines for debugging
    Map<String, String> currentQuestion =
        {}; // Temporary storage for a question's parts

    for (var line in lines) {
      line = line.trim(); // Remove extra whitespace
      if (line.startsWith('qstn:')) {
        // Start of a new question; process the previous question if it's complete
        if (currentQuestion.isNotEmpty) {
          if (_isValidQuestion(currentQuestion)) {
            parsedQuestions.add(_buildQuestionMap(currentQuestion));
          }
          currentQuestion.clear(); // Clear for the next question
        }
        currentQuestion['qstn'] =
            line.substring(5).trim(); // Extract question text
      } else if (line.startsWith('opt:')) {
        currentQuestion['opt'] = line.substring(4).trim(); // Extract options
      } else if (line.startsWith('ans:')) {
        currentQuestion['ans'] = line.substring(4).trim(); // Extract answer
      } else if (line.startsWith('top:')) {
        currentQuestion['top'] = line.substring(4).trim(); // Extract topic
      }
    }

    // Process the last question in the response
    if (_isValidQuestion(currentQuestion)) {
      parsedQuestions.add(_buildQuestionMap(currentQuestion));
    }

    // print('Parsed ${parsedQuestions.length} questions'); // Log number of parsed questions
    return parsedQuestions;
  }

  bool _isValidQuestion(Map<String, String> question) {
    print('Validating question: $question'); // Log the question being validated
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
    final topic = question['topic'] ??
        'General'; // Default to 'General' if topic is missing

    if (correctAnswer == null || topic == null) {
      _showError('Error: Missing data for question.');
      return;
    }

    // Ensure the topic exists in the scores map
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
      _goToHomePage(); // Redirect to home page after quiz
    }
  }

  void _goToHomePage() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

    // Pass topicScores to the learning path and go to home page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: _questions.length,
          topicScores: _topicScores,
          userId: userId,
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
      await firestore.collection('users').doc(userId).set(
        {
          'marks': topicScores,
          'totalScore': score,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print("Error saving results: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
}*/
