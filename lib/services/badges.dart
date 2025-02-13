import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize badges in Firestore (Run this once)
  Future<void> createBadges() async {
    final badges = {
      "beginner_explorer": {
        "id": "beginner_explorer",
        "name": "Beginner Explorer",
        "description": "Completed the first topic",
        "requiredTopics": 1
      },
      "intermediate_learner": {
        "id": "intermediate_learner",
        "name": "Intermediate Learner",
        "description": "Completed 50% of topics",
        "requiredTopics": 3  // Adjust based on total topics
      },
      "mastery_achiever": {
        "id": "mastery_achiever",
        "name": "Mastery Achiever",
        "description": "Completed all topics",
        "requiredTopics": 6  // Adjust based on total topics
      }
    };

    final badgeRef = _firestore.collection('badges');

    for (var entry in badges.entries) {
      await badgeRef.doc(entry.key).set(entry.value);
    }

    print("Badges collection initialized!");
  }

  // Check and award badges based on user progress
  Future<void> checkAndAwardBadges(String userId, int completedTopics, int totalTopics) async {
    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');

    // Get all predefined badges
    final badgeSnapshot = await _firestore.collection('badges').get();

    for (var doc in badgeSnapshot.docs) {
      final badgeData = doc.data();
      final badgeId = badgeData['id'];
      final requiredTopics = badgeData['requiredTopics'];

      // Check if user already has this badge
      final userBadgeDoc = await badgeRef.doc(badgeId).get();
      if (!userBadgeDoc.exists && completedTopics >= requiredTopics) {
        await badgeRef.doc(badgeId).set({
          "id": badgeId,
          "name": badgeData['name'],
          "description": badgeData['description'],
          "earnedAt": FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
