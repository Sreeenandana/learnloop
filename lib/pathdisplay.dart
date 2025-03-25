//has the subtopic badge
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/content.dart';
import 'main.dart';
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
    print("in nav to contnt");
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
    print("✅ Marking subtopic as completed: $subtopic");

    final userRef = firestore.collection('users').doc(userId);
    final topicRef = userRef.collection('learningPath').doc(topic);

    int index = subtopics.indexWhere((s) => s['name'] == subtopic);
    if (index != -1) {
      subtopics[index]['status'] = 'completed';
      await topicRef.update({'subtopics': subtopics});
      print("✅ Firestore updated for subtopic completion.");
    }

    // **Update Streak**
    final userSnapshot = await userRef.get();
    if (userSnapshot.exists) {
      final data = userSnapshot.data();
      int currentStreak = data?['streak'] ?? 0;
      Timestamp? lastCompletionTimestamp = data?['lastCompletion'];

      final today = DateTime.now();
      final lastCompletionDate = lastCompletionTimestamp?.toDate();

      if (lastCompletionDate != null) {
        final difference = today.difference(lastCompletionDate).inDays;
        currentStreak = (difference <= 1) ? currentStreak + 1 : 1;
      } else {
        currentStreak = 1;
      }

      await userRef.update({
        'streak': currentStreak,
        'lastCompletion': Timestamp.fromDate(today),
      });

      print("✅ Streak updated: $currentStreak days");
    }

    // **Check and Award First Subtopic Badge**
    // **Check and Award First Subtopic Badge**
    try {
      print("🔍 Checking for first subtopic badge...");

      // Fetch first topic that STARTS with "1."
      QuerySnapshot topicSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('learningPath')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '1.')
          .where(FieldPath.documentId,
              isLessThan: '2') // Ensures only "1.x" topics are considered
          .limit(1)
          .get();

      if (topicSnapshot.docs.isEmpty) {
        print("❌ No topics found starting with '1.'");
        return;
      }

      DocumentSnapshot firstTopicDoc = topicSnapshot.docs.first;
      String firstTopicId = firstTopicDoc.id;
      List<dynamic> subtopics = firstTopicDoc['subtopics'];

      if (subtopics.isEmpty) {
        print("❌ No subtopics found for topic $firstTopicId");
        return;
      }

      String firstSubtopicName = subtopics.first['name'];
      print("🎯 First subtopic: $firstSubtopicName");

      // Normalize and compare subtopic names
      if (subtopic.trim().toLowerCase() ==
          firstSubtopicName.trim().toLowerCase()) {
        DocumentSnapshot badgeDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc('first subtopic')
            .get();

        if (!badgeDoc.exists) {
          await firestore
              .collection('users')
              .doc(userId)
              .collection('badges')
              .doc('first subtopic')
              .set({
            'timestamp': Timestamp.now() // User can mark it as read later
          });
          print("📩 badges saved in Firestore.");
          Future.delayed(Duration.zero, () {
            if (navigatorKey.currentContext != null) {
              showDialog(
                context: navigatorKey.currentContext!,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: Text("🏅 Badge Earned!"),
                    content: Text(
                        "🎉 Congratulations! You've earned the 'First Subtopic Completed' badge!"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text("OK"),
                      ),
                    ],
                  );
                },
              );
            }
          });
        }
      }
    } catch (e) {
      print("❌ Error awarding badge: $e");
    }
  }
}
