//has the subtopic badge
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnloop/content.dart';
import 'main.dart';
import 'initial.dart';
import 'package:lottie/lottie.dart';
import 'services/badge service.dart';
import 'package:learnloop/quizcontent.dart';

class LearningPathDisplay extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String language; // Add at the top of the class

  LearningPathDisplay({Key? key, required this.language}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text("User not logged in"));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 231, 91, 180),
        toolbarHeight: 80.0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "LEARNING PATH",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .doc(userId)
            .collection('languages')
            .doc(language)
            .collection('learningPath')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Color.fromARGB(255, 231, 91,
                  180), // 🎨 Change this to any background color you want
              child: Center(
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  width: 200,
                  height: 200,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Start Learning Now!!"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizPage(language: language),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Take Initial Assessment",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
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

                return _buildTopicCard(context, userId, topicName, subtopics,
                    progress, index, topics);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicCard(
      BuildContext context,
      String userId,
      String topicName,
      List<dynamic> subtopics,
      double progress,
      int topicIndex,
      List<QueryDocumentSnapshot> allTopics) {
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
              children: List.generate(subtopics.length, (i) {
                final subtopic = subtopics[i];
                final subtopicName = subtopic['name'] ?? 'Unknown';
                final isCompleted = subtopic['status'] == 'completed';
                final subtopicIndex = subtopics.indexOf(subtopic);
                final isQuiz =
                    subtopic['name'].toLowerCase().startsWith('quiz');
                bool isLocked = false;

// Lock only non-quiz subtopics unless previous one is completed
                if (!isQuiz) {
                  if (subtopicIndex > 0) {
                    final prevSubtopic = subtopics[subtopicIndex - 1];
                    isLocked = prevSubtopic['status'] != 'completed';
                  }
                }

                bool isEnabled = false;

                // ✅ Case 1: Subtopic is completed
                if (isCompleted) {
                  isEnabled = true;
                }
                // ✅ Case 2: It's the first subtopic in topic
                else if (i == 0) {
                  // 🔐 Check if it's the first topic
                  if (topicIndex == 0) {
                    isEnabled = true; // allow first subtopic of first topic
                  } else {
                    // Get previous topic's last subtopic
                    final prevTopic = allTopics[topicIndex - 1];
                    final prevSubtopics = prevTopic['subtopics'] ?? [];
                    final lastPrevSub =
                        prevSubtopics.isNotEmpty ? prevSubtopics.last : null;

                    // Allow only if previous topic's last subtopic (quiz) is completed
                    if (lastPrevSub != null &&
                        lastPrevSub['status'] == 'completed') {
                      isEnabled = true;
                    }
                  }
                }
                // ✅ Case 3: It's the next one after a completed subtopic
                else if (i > 0 && subtopics[i - 1]['status'] == 'completed') {
                  isEnabled = true;
                }

                return ListTile(
                  title: Text(
                    subtopicName,
                    style: TextStyle(
                        color: isEnabled ? Colors.black : Colors.grey),
                  ),
                  subtitle: Text(
                    isCompleted
                        ? "Completed"
                        : isEnabled
                            ? "Available"
                            : "Locked",
                  ),
                  trailing: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : isEnabled
                          ? const Icon(Icons.radio_button_unchecked)
                          : const Icon(Icons.lock, color: Colors.grey),
                  onTap: isLocked
                      ? null
                      : () => _handleSubtopicTap(
                          context, userId, topicName, subtopics, subtopic),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubtopicTap(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, Map<String, dynamic> subtopic) {
    final subtopicName = subtopic['name']?.toString().toLowerCase() ?? '';

    if (subtopicName.startsWith("quiz")) {
      _navigateToQuiz(context, userId, topic, subtopics, subtopic['name']);
    } else {
      _navigateToContent(context, userId, topic, subtopics, subtopic['name']);
    }
  }

  void _navigateToQuiz(BuildContext context, String userId, String topic,
      List<dynamic> subtopics, Map<String, dynamic> subtopic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterQuiz(
          userId: userId,
          topic: topic,
          language: language,
          onQuizFinished: () {
            _markSubtopicCompleted(
                context, userId, topic, subtopics, subtopic['name']);
          },
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
          language: language,
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
    final topicRef = userRef
        .collection('languages')
        .doc(language)
        .collection('learningPath')
        .doc(topic);

    Future<bool> _updateDailyStreak(DocumentReference userRef) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day); // Store only date
      bool streakUpdated = false;

      try {
        final userDoc = await userRef.get();
        final data = userDoc.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey('lastActiveTimestamp')) {
          final lastActiveDate =
              DateTime.tryParse(data['lastActiveTimestamp'])?.toLocal();

          if (lastActiveDate != null) {
            final lastDateOnly = DateTime(
                lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);
            int streak = data['streak'] ?? 0;
            int daysDifference = today.difference(lastDateOnly).inDays;

            if (daysDifference == 0) {
              print("✅ User already active today. Streak remains: $streak");
              return false; // No update needed
            } else if (daysDifference == 1) {
              print("🔥 Streak continued! Increasing streak.");
              streak += 1;
              streakUpdated = true;
            } else {
              print("❌ Streak reset. More than 1 day gap.");
              streak = 1;
              streakUpdated = true;
            }

            await userRef.set({
              'streak': streak,
              'lastActiveTimestamp':
                  today.toIso8601String(), // Store only the date
            }, SetOptions(merge: true));
          }
        } else {
          print("🎉 First-time activity, starting new streak.");
          await userRef.set({
            'streak': 1,
            'lastActiveTimestamp': today.toIso8601String(),
          }, SetOptions(merge: true));
          streakUpdated = true;
        }
      } catch (e) {
        print("❌ Error updating streak: $e");
      }

      return streakUpdated;
    }

    int index = subtopics.indexWhere((s) => s['name'] == subtopic);
    if (index != -1) {
      subtopics[index]['status'] = 'completed';
      _updateDailyStreak(userRef);
      await topicRef.update({'subtopics': subtopics});
      print("✅ Firestore updated for subtopic completion.");
    }

    // **Check and Award First Subtopic Badge**
    await BadgeService(userId, navigatorKey)
        .checkAndAwardSubtopicBadges(subtopic, language);
  }
}
