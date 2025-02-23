import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/content.dart';
import 'package:learnloop/quizcontent.dart'; // Import Quiz Page

class LearningPathDisplay extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Center(child: Text("User not logged in"));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Learning Path")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No learning path available"));
          }

          final topics = snapshot.data!.docs;

          return ListView.builder(
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topicDoc = topics[index];
              final topicName = topicDoc.id;
              final subtopics = topicDoc['subtopics'] ?? [];

              return ExpansionTile(
                title: Text(topicName,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                children: subtopics.map<Widget>((subtopic) {
                  final subtopicName = subtopic['name'] ?? 'Unknown Subtopic';

                  return ListTile(
                    title: Text(subtopicName),
                    subtitle:
                        Text("Status: ${subtopic['status'] ?? 'pending'}"),
                    trailing: subtopic['status'] == 'completed'
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      if (subtopicName.toLowerCase().startsWith("quiz")) {
                        // Navigate to Quiz Page if subtopic is a quiz
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChapterQuiz(
                              userId: userId,
                              topic: topicName,
                              onQuizFinished: () {
                                _markSubtopicCompleted(
                                    context, userId, topicName, subtopicName);
                              },
                            ),
                          ),
                        );
                      } else {
                        // Navigate to Content Page for regular subtopics
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubtopicContentPage(
                              userId: userId,
                              topic: topicName,
                              subtopic: subtopicName,
                              onSubtopicFinished: () {
                                _markSubtopicCompleted(
                                    context, userId, topicName, subtopicName);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  void _markSubtopicCompleted(BuildContext context, String userId, String topic,
      String subtopic) async {
    final userRef = firestore.collection('users').doc(userId);
    final topicRef = userRef.collection('learningPath').doc(topic);

    final snapshot = await topicRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      List<dynamic> subtopics = snapshot.data()!['subtopics'] ?? [];

      int currentIndex = subtopics.indexWhere((s) => s['name'] == subtopic);
      if (currentIndex != -1) {
        subtopics[currentIndex]['status'] = 'completed';
        await topicRef.update({'subtopics': subtopics});
      }

      // Update streak in Firestore
      final userSnapshot = await userRef.get();
      if (userSnapshot.exists && userSnapshot.data() != null) {
        final data = userSnapshot.data();
        int currentStreak = data?['streak'] ?? 0;
        Timestamp? lastCompletionTimestamp = data?['lastCompletion'];

        final today = DateTime.now();
        final lastCompletionDate = lastCompletionTimestamp?.toDate();

        if (lastCompletionDate != null) {
          final difference = today.difference(lastCompletionDate).inDays;
          if (difference == 1) {
            currentStreak++; // Continue streak
          } else if (difference > 1) {
            currentStreak = 1; // Reset streak
          }
        } else {
          currentStreak = 1; // First-time streak update
        }

        await userRef.update({
          'streak': currentStreak,
          'lastCompletion': Timestamp.fromDate(today),
        });
      }

      // Navigate to the next subtopic automatically
      if (currentIndex != -1 && currentIndex + 1 < subtopics.length) {
        final nextSubtopic = subtopics[currentIndex + 1]['name'];
        final current = subtopics[currentIndex]['name'];
        if (current.toLowerCase().startsWith("quiz")) {
          Navigator.pop(context);
        }

        Future.delayed(Duration(milliseconds: 500), () {
          if (nextSubtopic.toLowerCase().startsWith("quiz")) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChapterQuiz(
                  userId: userId,
                  topic: topic,
                  onQuizFinished: () {
                    _markSubtopicCompleted(
                        context, userId, topic, nextSubtopic);
                  },
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SubtopicContentPage(
                  userId: userId,
                  topic: topic,
                  subtopic: nextSubtopic,
                  onSubtopicFinished: () {
                    _markSubtopicCompleted(
                        context, userId, topic, nextSubtopic);
                  },
                ),
              ),
            );
          }
        });
      }
    }
  }
}
