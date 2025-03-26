import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BadgeService {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<NavigatorState> navigatorKey;

  BadgeService(this.userId, this.navigatorKey);

  /// **Check and Award Quiz-Related Badges**
  Future<List<String>> checkAndAwardQuizBadges(
      int score, int totalQuestions, int elapsedTime) async {
    final List<String> earnedBadges = [];
    final userBadgeRef =
        _firestore.collection('users').doc(userId).collection('badges');

    // Fetch existing badges
    final badgeDocs = await userBadgeRef.get();
    final Map<String, int> earnedBadgeLevels = {
      for (var doc in badgeDocs.docs) doc.id: doc.data()['level'] ?? 0
    };

    // **High Achiever Badge (Single)**
    if (score == totalQuestions) {
      await _checkAndAwardSingleBadge(
        userBadgeRef,
        "High Achiever",
        earnedBadges,
        "Scored full marks ($score/$totalQuestions)",
      );
    }

    // **Speed Master Badge (Sequential)**
    await _checkAndAwardSequentialBadge(
      userBadgeRef,
      "Speed Master",
      earnedBadgeLevels,
      earnedBadges,
      criteriaPrefix:
          "Fastest quiz completion in ${elapsedTime ~/ 1000} sec - Level",
    );

    // **Streak Ninja Badge (Milestone-Based)**
    final int streakDays = await _getUserStreak();
    await _checkAndAwardStreakBadge(
      userBadgeRef,
      earnedBadgeLevels,
      earnedBadges,
      streakDays,
    );

    return earnedBadges;
  }

  /// **Helper Function to Award a Single Badge**
  Future<void> _checkAndAwardSingleBadge(
    CollectionReference userBadgeRef,
    String badgeName,
    List<String> earnedBadges,
    String criteria,
  ) async {
    final badgeDoc = await userBadgeRef.doc(badgeName).get();
    if (!badgeDoc.exists) {
      await userBadgeRef.doc(badgeName).set({
        "timestamp": FieldValue.serverTimestamp(),
        "criteria": criteria,
      });

      earnedBadges.add(badgeName);
    }
  }

  /// **Helper Function to Award Speed Master Sequentially**
  Future<void> _checkAndAwardSequentialBadge(
    CollectionReference userBadgeRef,
    String badgeName,
    Map<String, int> earnedBadgeLevels,
    List<String> earnedBadges, {
    required String criteriaPrefix,
  }) async {
    int currentLevel = earnedBadgeLevels[badgeName] ?? 0;
    int nextLevel = currentLevel + 1;

    await userBadgeRef.doc(badgeName).set({
      "level": nextLevel,
      "timestamp": FieldValue.serverTimestamp(),
      "criteria": "$criteriaPrefix $nextLevel",
    }, SetOptions(merge: true));

    earnedBadges.add("$badgeName (Level $nextLevel)");
  }

  /// **Helper Function to Award Streak Ninja at Specific Milestones**
  Future<void> _checkAndAwardStreakBadge(
    CollectionReference userBadgeRef,
    Map<String, int> earnedBadgeLevels,
    List<String> earnedBadges,
    int streakDays,
  ) async {
    const Map<int, int> streakMilestones = {
      7: 1, // Level 1 at 7 days
      30: 2, // Level 2 at 30 days
      60: 3, // Level 3 at 60 days
    };

    for (var milestone in streakMilestones.keys) {
      if (streakDays == milestone) {
        int newLevel = streakMilestones[milestone]!;
        int currentLevel = earnedBadgeLevels["Streak Ninja"] ?? 0;

        if (newLevel > currentLevel) {
          await userBadgeRef.doc("Streak Ninja").set({
            "level": newLevel,
            "timestamp": FieldValue.serverTimestamp(),
            "criteria":
                "Maintained a learning streak of $streakDays days - Level $newLevel",
          }, SetOptions(merge: true));

          earnedBadges.add("Streak Ninja (Level $newLevel)");
        }
      }
    }
  }

  /// **Check and Award First Subtopic Badge**
  Future<void> checkAndAwardSubtopicBadges(String subtopic) async {
    List<String> earnedBadges =
        await _checkAndAwardFirstSubtopicBadge(subtopic);
    if (earnedBadges.isNotEmpty) {
      _showBadgeDialog(earnedBadges);
    }
  }

  /// **Helper Function to Check and Award First Subtopic Badge**
  Future<List<String>> _checkAndAwardFirstSubtopicBadge(String subtopic) async {
    List<String> earnedBadges = [];

    try {
      QuerySnapshot topicSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningPath')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '1.')
          .where(FieldPath.documentId, isLessThan: '2')
          .limit(1)
          .get();

      if (topicSnapshot.docs.isEmpty) return [];

      DocumentSnapshot firstTopicDoc = topicSnapshot.docs.first;
      List<dynamic> subtopics = firstTopicDoc['subtopics'];

      if (subtopics.isEmpty) return [];

      String firstSubtopicName = subtopics.first['name'];

      if (subtopic.trim().toLowerCase() ==
          firstSubtopicName.trim().toLowerCase()) {
        DocumentSnapshot badgeDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc('First Subtopic')
            .get();

        if (!badgeDoc.exists) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('badges')
              .doc('First Subtopic')
              .set({
            'timestamp': Timestamp.now(),
            "criteria": "Completed first subtopic"
          });

          earnedBadges.add("First Subtopic Completed");
        }
      }
    } catch (e) {
      print("❌ Error awarding first subtopic badge: $e");
    }

    return earnedBadges;
  }

  /// **Helper Function to Get User Streak**
  Future<int> _getUserStreak() async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['streak'] ?? 0;
    }
    return 0;
  }

  /// **Helper Function to Show Badge Earned Dialog**
  void _showBadgeDialog(List<String> earnedBadges) {
    if (earnedBadges.isEmpty) return;

    String message = "🎉 Congratulations! You've earned:\n\n" +
        earnedBadges.map((badge) => "🏅 $badge").join("\n");

    Future.delayed(Duration.zero, () {
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text("🏆 Badge Earned!"),
              content: Text(message),
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
