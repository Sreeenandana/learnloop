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

    if (topic != null && weakSubtopics != null && weakSubtopics.isNotEmpty) {
      print("bef mod");
      await _modifyWeakSubtopics(userId, topic, weakSubtopics);
      return;
    }

    final topicScores = await _fetchTopicScores(userId);

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
    final firestore = FirebaseFirestore.instance;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('learningPath')
        .doc(topic);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists || !docSnapshot.data()!.containsKey('subtopics')) {
      print("Error: No subtopics found for $topic");
      return;
    }

    // Check failCount
    int failCount = docSnapshot.data()!.containsKey('failCount')
        ? docSnapshot.data()!['failCount'] as int
        : 0;

    if (failCount >= 3) {
      print("Fail count limit reached (3). Not modifying subtopics.");
      return;
    }

    List<Map<String, dynamic>> subtopics =
        List<Map<String, dynamic>>.from(docSnapshot.data()!['subtopics']);

    // Separate the quiz entry (if exists)
    Map<String, dynamic>? quizEntry;
    subtopics.removeWhere((subtopic) {
      if (subtopic['name'].toString().startsWith("Quiz:")) {
        quizEntry = Map<String, dynamic>.from(subtopic); // ✅ Ensure non-null
        print("Quiz removed");
        return true;
      }
      return false;
    });

    List<Map<String, dynamic>> updatedSubtopics = List.from(subtopics);

    for (String weakSubtopic in weakSubtopics) {
      int index = updatedSubtopics.indexWhere((s) => s['name'] == weakSubtopic);
      if (index == -1) continue; // If subtopic is not found, skip

      final prompt =
          "Break down the subtopic '$weakSubtopic' from the topic '$topic' in Java into simpler concepts. "
          "Only 2 or 3 new subtopics are needed. Provide only the new subtopic names, without descriptions or numbering.";

      final response = await model.generateContent([Content.text(prompt)]);
      print(response.text);
      if (response.text == null || response.text!.trim().isEmpty) {
        print("Error: AI response for $weakSubtopic is empty");
        continue; // Skip this subtopic if AI fails
      }

      final newSubtopics = _parseSubtopics(response.text!);

      // Remove the weak subtopic and insert new subtopics at the same index
      updatedSubtopics.removeAt(index);
      updatedSubtopics.insertAll(index, newSubtopics);
    }

    // Re-add the quiz entry at the end if it exists
    if (quizEntry != null) {
      print("Quiz added at the end");
      updatedSubtopics.add(quizEntry!);
    }

    // Update Firestore with the modified subtopics list
    await docRef.set({'subtopics': updatedSubtopics}, SetOptions(merge: true));
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
