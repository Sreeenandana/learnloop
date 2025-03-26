import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ReviewScreen extends StatefulWidget {
  final List<dynamic> incorrectQuestions;

  const ReviewScreen({super.key, required this.incorrectQuestions});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  bool _isLoading = true;
  int _currentIndex = 0; // Track the current question index

  @override
  void initState() {
    super.initState();
    _fetchExplanations();
  }

  Future<void> _fetchExplanations() async {
    for (var question in widget.incorrectQuestions) {
      if (question['explanation'] == null) {
        await _fetchExplanation(question);
      }
    }
    setState(() {
      _isLoading = false; // All explanations loaded
    });
  }

  Future<void> _fetchExplanation(Map<String, dynamic> questionData) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );
      final response = await model.generateContent([
        Content.text(
            "Explain why the correct answer for '${questionData['question']}' is '${questionData['correct_answer']} in 5 to 8 sentences. Make it simple and easy to understand."
            "Do not provide any other formatting, just give plain text.")
      ]);

      questionData['explanation'] =
          response.text ?? "No explanation available.";
    } catch (e) {
      questionData['explanation'] = "Error fetching explanation.";
    }
  }

  void _nextQuestion() {
    if (_currentIndex < widget.incorrectQuestions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      Navigator.pop(context); // Exit review screen when finished
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator()), // Show loading spinner
      );
    }

    final question = widget.incorrectQuestions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Review Incorrect Answers')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Question: ${question['question']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Correct Answer: ${question['correct_answer']}",
              style: const TextStyle(
                  color: Color.fromARGB(255, 17, 40, 18), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              "Explanation: ${question['explanation'] ?? 'Fetching explanation...'}",
              style: const TextStyle(
                  color: Color.fromARGB(255, 35, 43, 50), fontSize: 14),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _nextQuestion,
              child: Text(_currentIndex < widget.incorrectQuestions.length - 1
                  ? "Next"
                  : "Finish"),
            ),
          ],
        ),
      ),
    );
  }
}
