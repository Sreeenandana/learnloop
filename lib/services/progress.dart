import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'badges.dart';

class ProgressService {
  final BadgeService _badgeService = BadgeService(); // Initialize BadgeService

  Future<void> updateProgress(String topicId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('tracking');

    // Fetch current progress
    DocumentSnapshot progressSnapshot = await progressRef.get();
    List<String> completedTopics =
        List<String>.from(progressSnapshot.get('completedTopics') ?? []);
    int totalTopics =
        progressSnapshot.get('totalTopics') ?? 10; // Default to 10

    if (!completedTopics.contains(topicId)) {
      completedTopics.add(topicId);
      await progressRef.set(
          {'completedTopics': completedTopics, 'totalTopics': totalTopics},
          SetOptions(merge: true));

      // ✅ **Check and award badges when progress is updated**
      //await _badgeService.checkAndAwardBadges(userId, completedTopics.length, totalTopics);
    }
  }
}
