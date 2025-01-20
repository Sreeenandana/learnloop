import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'path.dart'; // Assuming you have a learning path class in 'path.dart'
import 'home.dart'; // Assuming you have a home page in 'home.dart'

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Python Quiz',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false, // Remove debug banner
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
      appBar: AppBar(title: const Text('Select Difficulty Level')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center the buttons vertically
          crossAxisAlignment:
              CrossAxisAlignment.center, // Center the buttons horizontally
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
        print('API Response: ${response.text}'); // Log the raw response
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
            "'ans:' for the correct answer, and 'top:' for the topic. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      case 'intermediate':
        return "Generate 20 intermediate-level Java multiple choice questions (MCQs) about functions, classes, and data structures. "
            "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
            "'ans:' for the correct answer, and 'top:' for the topic. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      case 'advanced':
        return "Generate 20 advanced-level Java multiple choice questions (MCQs) about algorithms, data science, and optimization. "
            "For each question, start with 'qstn:' for the question, 'opt:' for the options (separate them with commas), "
            "'ans:' for the correct answer, and 'top:' for the topic. Separate each question set with a newline. "
            "Do not provide any other message or use any special characters unless necessary.";

      default:
        return '';
    }
  }

  List<dynamic> _parseQuestions(String responseText) {
    final List<dynamic> parsedQuestions = [];
    final lines = responseText.split('\n'); // Split the response into lines
    print('Response lines: $lines'); // Log the lines for debugging
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

    print(
        'Parsed ${parsedQuestions.length} questions'); // Log number of parsed questions
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

    if (correctAnswer == null) {
      _showError('Error: Missing data for correct_answer.');
      return;
    }

    // Ensure the topic exists in the scores map
    if (!_topicScores.containsKey(topic)) {
      _topicScores[topic] = 0;
    }

    // Update scores based on the selected answer
    if (selectedAnswer == correctAnswer) {
      _topicScores[topic] =
          _topicScores[topic]! + 1; // Increment the score for the topic
      _score++;
    }

    // Move to the next question or show results if it’s the last question
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
        builder: (context) => HomePage(
            //topicScores: _topicScores,  // Pass topicScores to HomePage
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
