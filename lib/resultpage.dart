import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection';
import 'package:firebase_auth/firebase_auth.dart';
import 'path.dart';

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

    // Filter out subtopics with a score of 0 for display
    final selectedSubtopics = Map.fromEntries(topicScores.entries
        .where((entry) => questions.any((q) => q['topic'] == entry.key)));

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        "Your Score",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "$score / $total",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Topic-wise Scores:",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedSubtopics.length,
                  itemBuilder: (context, index) {
                    String topic = selectedSubtopics.keys.elementAt(index);
                    int topicScore = selectedSubtopics[topic] ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      child: ListTile(
                        leading: Icon(Icons.book,
                            color: topicScore > 0 ? Colors.green : Colors.red),
                        title: Text(topic,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text("$topicScore",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LearningPathPage(topicScores: topicScores),
                    ),
                  );
                },
                child: const Text("Go to Learning Path",
                    style: TextStyle(color: Colors.deepPurple, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.white,
                ),
                onPressed: () => _showQuizReviewDialog(context),
                child: const Text("Review Answers",
                    style: TextStyle(color: Colors.deepPurple, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuizReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Review Answers"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final userAnswer = userAnswers[index] ?? "No Answer";
                final correctAnswer = question['correctAnswer'] ?? "N/A";

                return ListTile(
                  title: Text(question['question'] ?? "Question not found"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your Answer: $userAnswer"),
                      Text("Correct Answer: $correctAnswer",
                          style: TextStyle(
                              color: userAnswer == correctAnswer
                                  ? Colors.green
                                  : Colors.red)),
                    ],
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

      // Convert topicScores to a list to maintain order
      final orderedTopicScores = topicScores.entries.map((entry) {
        return {'topic': entry.key, 'score': entry.value};
      }).toList();

      await userDocRef.set({
        'last_score': score,
        'total_questions': total,
        'topic_scores':
            orderedTopicScores, // Now stored as a list to preserve order
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving results: $e");
    }
  }
}
