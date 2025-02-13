import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'path.dart'; // Import your LearningPathPage

class ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final Map<String, int> topicScores;
  final String userId;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> userAnswers;

  const ResultPage({
    Key? key,
    required this.score,
    required this.total,
    required this.topicScores,
    required this.userId,
    required this.questions,
    required this.userAnswers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _saveResultsToFirestore();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Your Score: $score / $total",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "Topic-wise Scores:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: topicScores.length,
                itemBuilder: (context, index) {
                  String topic = topicScores.keys.elementAt(index);
                  int topicScore = topicScores[topic] ?? 0;
                  return ListTile(
                    title: Text(topic),
                    trailing: Text("$topicScore"),
                  );
                },
              ),
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
              child: const Text("Go to Learning Path"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _showQuizReviewDialog(context),
              child: const Text("Review Answers"),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuizReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Quiz Review"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Adjust height as needed
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final String correctAnswer = question['correct_answer'];
                final String userAnswer = userAnswers[index] ?? "Not Answered";
                final bool isCorrect = userAnswer == correctAnswer;

                return Card(
                  color: isCorrect ? Colors.green[100] : Colors.red[100],
                  child: ListTile(
                    title: Text(
                      question['question'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Your Answer: $userAnswer",
                            style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold)),
                        Text("Correct Answer: $correctAnswer",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(
                          isCorrect
                              ? "✔ Well done!"
                              : "❌ Try reviewing this topic.",
                          style: TextStyle(
                              color: isCorrect ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _saveResultsToFirestore() async {
    try {
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDocRef.set({
        'last_score': score,
        'total_questions': total,
        'topic_scores': topicScores,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Results saved successfully!");
    } catch (e) {
      print("Error saving results: $e");
    }
  }
}
