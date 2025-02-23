import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> awardBadgeOnSubtopicCompletion(
    BuildContext context,
    String userId,
    String subtopic,
    String topic,
    int currentSubtopicIndex,
    List<Map<String, dynamic>> subtopics,
    VoidCallback onContinue,
  ) async {
    try {
      // Check if it's the first or last subtopic of the first chapter
      if (topic.startsWith("1")) {
        // Check if this is the first subtopic
        if (currentSubtopicIndex == 0) {
          await _awardFirstSubtopicBadge(context, userId, onContinue);
        }
        // Check if this is the last subtopic
        else if (currentSubtopicIndex == subtopics.length - 2) {
          print("nowwww");
          await _awardLastSubtopicBadge(context, userId, onContinue);
        }
      }
    } catch (e) {
      print("⚠️ Error awarding badge: $e");
    }
  }

  Future<void> _awardFirstSubtopicBadge(
    BuildContext context,
    String userId,
    VoidCallback onContinue,
  ) async {
    final badgesRef =
        _firestore.collection('users').doc(userId).collection('badges');
    final badgeDoc = await badgesRef.doc("first_subtopic_completion").get();
    if (!badgeDoc.exists) {
      await badgesRef.doc("first_subtopic_completion").set({
        "id": "first_subtopic_completion",
        "name": "Beginner Explorer",
        "earnedAt": FieldValue.serverTimestamp(),
      });
      _showBadgePopup(context, "first_subtopic_completion");
      onContinue();
    }
  }

  Future<void> _awardLastSubtopicBadge(
    BuildContext context,
    String userId,
    VoidCallback onContinue,
  ) async {
    final badgesRef =
        _firestore.collection('users').doc(userId).collection('badges');
    final badgeDoc = await badgesRef.doc("last_subtopic_completion").get();
    if (!badgeDoc.exists) {
      await badgesRef.doc("last_subtopic_completion").set({
        "id": "last_subtopic_completion",
        "name": "Flawless Finisher",
        "earnedAt": FieldValue.serverTimestamp(),
      });
      _showBadgePopup(context, "last_subtopic_completion");
      onContinue();
    }
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
}
