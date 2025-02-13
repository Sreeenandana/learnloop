import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize the badge for first subtopic completion
  Future<void> createBadge() async {
    final badge = {
      "id": "first_subtopic_completion",
      "name": "First Subtopic Master",
      "description": "Completed the first subtopic in the first chapter"
    };

    await _firestore
        .collection('badges')
        .doc("first_subtopic_completion")
        .set(badge);
    print("✅ First Subtopic Completion badge initialized!");
  }

  // Check and award the badge when any subtopic is completed first
  Future<void> checkAndAwardBadge(
      BuildContext context, String userId, VoidCallback onContinue) async {
    try {
      print("🔍 Checking badge for user: $userId");
      final userRef = _firestore.collection('users').doc(userId);
      final learningPathRef = userRef.collection('learningPath');
      final badgesRef = userRef.collection('badges');

      // Force Firestore to get the latest data
      final learningPathSnapshot =
          await learningPathRef.get(const GetOptions(source: Source.server));

      // Check if the user already has the badge
      final badgeDoc = await badgesRef.doc("first_subtopic_completion").get();
      if (badgeDoc.exists) {
        print("🔹 Badge already earned.");
        return;
      }

      bool isFirstSubtopicCompleted = false;
      String completedSubtopic = "";

      print("📂 Checking user's learning path...");
      for (var chapter in learningPathSnapshot.docs) {
        List<dynamic> chapterSubtopics = chapter.data()['subtopics'] ?? [];
        print(
            "📖 Checking chapter: ${chapter.id}, Subtopics: ${chapterSubtopics.length}");
        for (var sub in chapterSubtopics) {
          print(
              "🔍 Subtopic: ${sub['name']}, Status: ${sub['status'] ?? 'null'}");
          if (sub.containsKey('status') && sub['status'] == 'completed') {
            isFirstSubtopicCompleted = true;
            completedSubtopic = sub['name'];
            break;
          }
        }
        if (isFirstSubtopicCompleted) break;
      }

      if (isFirstSubtopicCompleted) {
        print("🏆 First completed subtopic detected: $completedSubtopic");
        await badgesRef.doc("first_subtopic_completion").set({
          "id": "first_subtopic_completion",
          "name": "Beginner Learner",
          "earnedAt": FieldValue.serverTimestamp(),
        });
        _showCongratulations(context, onContinue);
        print("🏅 First Subtopic Completion badge awarded!");
      } else {
        print("❌ No subtopics completed yet.");
      }
    } catch (e) {
      print("⚠️ Error checking badge: $e");
    }
  }

  Future<void> awardBadge(BuildContext context, String userId, String badgeId,
      VoidCallback onContinue) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final badgesRef = userRef.collection('badges');

      await badgesRef.doc(badgeId).set({
        "id": badgeId,
        "earnedAt": FieldValue.serverTimestamp(),
      });

      _showCongratulations(context, onContinue);
    } catch (e) {
      print("⚠️ Error awarding badge: $e");
    }
  }

  void _showCongratulations(BuildContext context, VoidCallback onContinue) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents dialog from closing by tapping outside
      builder: (context) => AlertDialog(
        title: const Text("🎉 Congratulations!"),
        content: const Text(
            "You've earned the First Subtopic Master badge! Keep up the great work!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              onContinue(); // Proceed to the next subtopic
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  // Directly award badge after subtopic completion
  Future<void> awardBadgeOnSubtopicCompletion(BuildContext context,
      String userId, String subtopic, VoidCallback onContinue) async {
    try {
      print("🏆 Awarding badge for completed subtopic: $subtopic");
      final userRef = _firestore.collection('users').doc(userId);
      final badgesRef = userRef.collection('badges');

      final badgeDoc = await badgesRef.doc("first_subtopic_completion").get();
      if (badgeDoc.exists) {
        print("🔹 Badge already earned.");
        return;
      }

      await badgesRef.doc("first_subtopic_completion").set({
        "id": "first_subtopic_completion",
        "earnedAt": FieldValue.serverTimestamp(),
      });

      _showCongratulations(context, onContinue);
      print(
          "🏅 First Subtopic Completion badge awarded immediately after completion!");
    } catch (e) {
      print("⚠️ Error awarding badge: $e");
    }
  }
}
