import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/pathgen.dart';
import 'pathgen.dart';
import 'pathdisplay.dart';
//mport 'path.dart'; // Ensure this file contains LearningPathPage

class ReviewPage extends StatefulWidget {
  final String userId;
  final String topic;
  final List<String> weakSubtopics;
  final int score;
  final int totalQuestions;

  const ReviewPage({
    Key? key,
    required this.userId,
    required this.topic,
    required this.weakSubtopics,
    required this.score,
    required this.totalQuestions,
  }) : super(key: key);

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  String _message = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _evaluatePerformance();
  }

  void _evaluatePerformance() {
    double percentage = (widget.score / widget.totalQuestions) * 100;
    if (percentage >= 80) {
      _message = "🎉 Congratulations! You Passed! 🎉";
    } else {
      _message = "❌ You didn't pass. Review and try again! ❌";
    }
  }

  Future<void> _modifyPath() async {
    setState(() {
      _isLoading = true;
    });

    final generator = LearningPathGenerator();
    await generator.generateOrModifyLearningPath(
      topic: widget.topic,
      weakSubtopics: widget.weakSubtopics,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Review Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _message,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              "Your Score: ${widget.score} / ${widget.totalQuestions}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 30),
            if (widget.weakSubtopics.isNotEmpty) ...[
              Text(
                "Weak Subtopics to Review:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (String subtopic in widget.weakSubtopics)
                Text("- $subtopic", style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
            ],
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _modifyPath,
                    child: Text("Modify Learning Path"),
                  ),
          ],
        ),
      ),
    );
  }
}
