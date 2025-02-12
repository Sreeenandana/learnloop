import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizPage extends StatefulWidget {
  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  final List<String> _topics = [
    'OOP Concepts',
    'Data Structures',
    'Algorithms',
    'Database Management',
    'Multithreading',
    'Networking',
    'Design Patterns'
  ];
  final Set<String> _selectedTopics = {};
  bool _quizStarted = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  Map<String, int> _topicScores = {};

  Future<void> _startQuiz() async {
    if (_selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one topic.')),
      );
      return;
    }
    setState(() {
      _quizStarted = true;
      _topicScores = {for (var topic in _selectedTopics) topic: 0};
    });
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
    List<Map<String, dynamic>> generatedQuestions = [];

    for (var topic in _selectedTopics) {
      final response = await model.generateContent([
        Content.text(
            "Generate a multiple-choice question about $topic with four options and indicate the correct answer.")
      ]);

      if (response.text != null) {
        generatedQuestions.add(_parseQuestion(response.text!, topic));
      }
    }

    setState(() {
      _questions = generatedQuestions;
    });
  }

  Map<String, dynamic> _parseQuestion(String text, String topic) {
    List<String> lines = text.split('\n');
    return {
      'topic': topic,
      'question': lines[0],
      'options': lines.sublist(1, 5),
      'answer': lines[5]
    };
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    String topic = _questions[_currentQuestionIndex]['topic'];
    if (_selectedAnswer == _questions[_currentQuestionIndex]['answer']) {
      _topicScores[topic] = (_topicScores[topic] ?? 0) + 1;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      });
    } else {
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Quiz Completed"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _topicScores.entries
              .map((entry) => Text("${entry.key}: ${entry.value}"))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _quizStarted = false;
                _selectedTopics.clear();
                _currentQuestionIndex = 0;
                _selectedAnswer = null;
              });
              Navigator.pop(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _quizStarted ? _buildQuizUI() : _buildTopicSelectionUI(),
      ),
    );
  }

  Widget _buildTopicSelectionUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose topics for the quiz:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: _topics.map((topic) {
              return CheckboxListTile(
                title: Text(topic),
                value: _selectedTopics.contains(topic),
                onChanged: (bool? selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTopics.add(topic);
                    } else {
                      _selectedTopics.remove(topic);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        Center(
          child: ElevatedButton(
            onPressed: _startQuiz,
            child: const Text('Start Quiz'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Question ${_currentQuestionIndex + 1} / ${_questions.length}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          _questions[_currentQuestionIndex]['question'],
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 10),
        ..._questions[_currentQuestionIndex]['options'].map<Widget>((option) {
          return RadioListTile<String>(
            title: Text(option),
            value: option,
            groupValue: _selectedAnswer,
            onChanged: (String? value) {
              setState(() {
                _selectedAnswer = value;
              });
            },
          );
        }).toList(),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _submitAnswer,
            child: Text(
              _currentQuestionIndex < _questions.length - 1 ? "Next" : "Finish",
            ),
          ),
        ),
      ],
    );
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
