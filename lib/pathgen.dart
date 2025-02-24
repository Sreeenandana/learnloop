import 'dart:async';
import 'dart:math'; // For random quote selection
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class LearningPathGenerator {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  final List<String> motivationalQuotes = [
    "Learning never exhausts the mind. – Leonardo da Vinci",
    "The beautiful thing about learning is that nobody can take it away from you. – B.B. King",
    "Live as if you were to die tomorrow. Learn as if you were to live forever. – Mahatma Gandhi",
    "The more I read, the more I acquire, the more certain I am that I know nothing. – Voltaire",
    "The capacity to learn is a gift; the ability to learn is a skill; the willingness to learn is a choice. – Brian Herbert",
    "Success is not the key to happiness. Happiness is the key to success. If you love what you are doing, you will be successful. – Albert Schweitzer",
  ];

  Future<void> generateOrModifyLearningPath(
      {BuildContext? context,
      String? topic,
      List<String>? weakSubtopics}) async {
    print("in genormod");
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Show loading dialog only if context is available
    if (context != null) _showLoadingDialog(context);

    final topicScores = await _fetchTopicScores(userId);

    if (topic != null && weakSubtopics != null && weakSubtopics.isNotEmpty) {
      print("bef mod");
      await _modifyWeakSubtopics(userId, topic, weakSubtopics);
    }

    for (var topic in topicScores.keys) {
      await _generateAndStoreSubtopics(userId, topic, topicScores[topic]!);
    }

    // Close the loading dialog if it was shown
    if (context != null) Navigator.pop(context);
  }

  Future<Map<String, int>> _fetchTopicScores(String userId) async {
    final snapshot = await firestore.collection('users').doc(userId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return {};
    }

    final data = snapshot.data();
    final topicScoresList = data?['topic_scores'];

    if (topicScoresList is List) {
      return {
        for (var entry in topicScoresList)
          if (entry is Map<String, dynamic> &&
              entry.containsKey('topic') &&
              entry.containsKey('score'))
            entry['topic'] as String: entry['score'] as int
      };
    } else {
      print("Error: topic_scores is not a List of Maps");
      return {};
    }
  }

  Future<void> _generateAndStoreSubtopics(
      String userId, String topic, int score) async {
    print("in genandstore");
    int subtopicCount = score < 3 ? 7 : (score < 7 ? 5 : 3);

    final prompt =
        "Generate $subtopicCount subtopics for the topic $topic in the context of Java in learning order. "
        "Give only subtopic names, no descriptions, no numbering. "
        "Lastly, also provide a quiz title in the format 'Quiz: $topic'.";

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );

    final response = await model.generateContent([Content.text(prompt)]);

    if (response.text == null || response.text!.trim().isEmpty) {
      print("Error: AI response is empty");
      return;
    }

    final subtopics = _parseSubtopics(response.text!);
    await firestore
        .collection('users')
        .doc(userId)
        .collection('learningPath')
        .doc(topic)
        .set({'subtopics': subtopics}, SetOptions(merge: true));
  }

  Future<void> _modifyWeakSubtopics(
      String userId, String topic, List<String> weakSubtopics) async {
    final prompt =
        "Modify weak subtopics of $topic in Java by breaking them into simpler concepts. "
        "Weak subtopics: ${weakSubtopics.join(', ')}. "
        "Provide only subtopic names, no descriptions, no numbering. "
        "Lastly, provide a quiz title as 'Quiz: $topic'.";

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    final response = await model.generateContent([Content.text(prompt)]);

    if (response.text == null || response.text!.trim().isEmpty) {
      print("Error: AI response is empty");
      return;
    }

    final newSubtopics = _parseSubtopics(response.text!);
    await firestore
        .collection('users')
        .doc(userId)
        .collection('learningPath')
        .doc(topic)
        .set({'subtopics': newSubtopics}, SetOptions(merge: true));
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    return responseText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((subtopic) => {'name': subtopic.trim(), 'status': 'pending'})
        .toList();
  }

  // Show loading dialog with a random motivational quote
  void _showLoadingDialog(BuildContext context) {
    final random = Random();
    String quote =
        motivationalQuotes[random.nextInt(motivationalQuotes.length)];

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing until loading completes
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                quote,
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }
}
