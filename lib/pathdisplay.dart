import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/content.dart';
import 'package:learnloop/quizcontent.dart';

class LearningPathDisplay extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text("User not logged in"));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Learning Path")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No learning path available"));
          }

          final topics = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topicDoc = topics[index];
                final topicName = topicDoc.id;
                final subtopics = topicDoc['subtopics'] ?? [];
                int completedCount = subtopics
                    .where((subtopic) => subtopic['status'] == 'completed')
                    .length;
                double progress =
                    subtopics.isEmpty ? 0 : completedCount / subtopics.length;

                return _buildTopicCard(
                    context, userId, topicName, subtopics, progress);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, String userId, String topicName,
      List<dynamic> subtopics, double progress) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              title: Text(
                topicName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                color: Colors.deepPurple,
              ),
              trailing: Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Column(
              children: subtopics.map((subtopic) {
                final subtopicName = subtopic['name'] ?? 'Unknown';
                final isCompleted = subtopic['status'] == 'completed';

                return ListTile(
                  title: Text(subtopicName),
                  subtitle: Text(isCompleted ? "Completed" : "Pending"),
                  trailing: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.radio_button_unchecked),
                  onTap: () => _handleSubtopicTap(
                      context, userId, topicName, subtopics, subtopicName),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubtopicTap(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, String subtopic) {
    if (subtopic.toLowerCase().startsWith("quiz")) {
      _navigateToQuiz(context, userId, topic, subtopics, subtopic);
    } else {
      _navigateToContent(context, userId, topic, subtopics, subtopic);
    }
  }

  void _navigateToQuiz(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, String subtopic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterQuiz(
          userId: userId,
          topic: topic,
          onQuizFinished: () => _markSubtopicCompleted(
              context, userId, topic, subtopics, subtopic),
        ),
      ),
    );
  }

  void _navigateToContent(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, String subtopic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubtopicContentPage(
          userId: userId,
          topic: topic,
          subtopic: subtopic,
          onSubtopicFinished: () => _markSubtopicCompleted(
              context, userId, topic, subtopics, subtopic),
        ),
      ),
    );
  }

  void _markSubtopicCompleted(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, String subtopic) async {
    final userRef = firestore.collection('users').doc(userId);
    final topicRef = userRef.collection('learningPath').doc(topic);

    int index = subtopics.indexWhere((s) => s['name'] == subtopic);
    if (index != -1) {
      subtopics[index]['status'] = 'completed';
      await topicRef.update({'subtopics': subtopics});
    }

    // Update streak
    final userSnapshot = await userRef.get();
    if (userSnapshot.exists) {
      final data = userSnapshot.data();
      int currentStreak = data?['streak'] ?? 0;
      Timestamp? lastCompletionTimestamp = data?['lastCompletion'];

      final today = DateTime.now();
      final lastCompletionDate = lastCompletionTimestamp?.toDate();

      if (lastCompletionDate != null) {
        final difference = today.difference(lastCompletionDate).inDays;
        currentStreak = (difference == 1) ? currentStreak + 1 : 1;
      } else {
        currentStreak = 1;
      }

      await userRef.update({
        'streak': currentStreak,
        'lastCompletion': Timestamp.fromDate(today),
      });
    }

    // Auto-navigate to next subtopic
    if (index != -1 && index + 1 < subtopics.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final nextSubtopic = subtopics[index + 1]['name'];
        if (nextSubtopic.toLowerCase().startsWith("quiz")) {
          _navigateToQuiz(context, userId, topic, subtopics, nextSubtopic);
        } else {
          _navigateToContent(context, userId, topic, subtopics, nextSubtopic);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All subtopics completed!")),
      );
    }
  }
}
