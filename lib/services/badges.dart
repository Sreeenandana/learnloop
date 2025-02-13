import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> awardQuizBadge(
      BuildContext context, String userId, String badgeId) async {
    final userBadgesRef =
        _firestore.collection('users').doc(userId).collection('badges');

    // Check if the badge already exists
    final doc = await userBadgesRef.doc(badgeId).get();
    if (doc.exists) return; // Avoid awarding the same badge multiple times

    // Store badge in Firestore
    await userBadgesRef.doc(badgeId).set({
      'id': badgeId,
      'earnedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    // Show popup notification
    _showBadgePopup(context, badgeId);
  }

  void _showBadgePopup(BuildContext context, String badgeId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("🎉 Badge Earned!"),
          content: Text("Congratulations! You earned the '$badgeId' badge."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
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
