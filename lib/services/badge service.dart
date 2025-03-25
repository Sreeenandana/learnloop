import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeService {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BadgeService(this.userId);

  Future<List<String>> checkAndAwardBadges(
      int score, int totalQuestions, int elapsedTime) async {
    final List<String> earnedBadges = [];

    final userBadgeRef =
        _firestore.collection('users').doc(userId).collection('badges');

    // Fetch already earned badges
    final badgeDocs = await userBadgeRef.get();
    final earnedBadgeNames = badgeDocs.docs.map((doc) => doc.id).toSet();

    // Speed Master Badge Levels
    if (elapsedTime <= 120000 &&
        !earnedBadgeNames.contains("Speed Master Level 1")) {
      await _awardBadge(userBadgeRef, "Speed Master Level 1");
      earnedBadges.add("Speed Master Level 1");
    }

    if (elapsedTime <= 60000 &&
        earnedBadgeNames.contains("Speed Master Level 1") &&
        !earnedBadgeNames.contains("Speed Master Level 2")) {
      await _awardBadge(userBadgeRef, "Speed Master Level 2");
      earnedBadges.add("Speed Master Level 2");
    }

    if (elapsedTime <= 30000 &&
        earnedBadgeNames.contains("Speed Master Level 2") &&
        !earnedBadgeNames.contains("Speed Master Level 3")) {
      await _awardBadge(userBadgeRef, "Speed Master Level 3");
      earnedBadges.add("Speed Master Level 3");
    }

    // High Achiever Badge (Score 90% or more)
    if ((score / totalQuestions) >= 0.9 &&
        !earnedBadgeNames.contains("High Achiever")) {
      await _awardBadge(userBadgeRef, "High Achiever");
      earnedBadges.add("High Achiever");
    }

    // Fetch user's streak from Firestore
    final int streakDays = await _getUserStreak();

    // Streak Badge Levels
    if (streakDays >= 7 && !earnedBadgeNames.contains("Streak Level 1")) {
      await _awardBadge(userBadgeRef, "Streak Level 1");
      earnedBadges.add("Streak Level 1");
    }

    if (streakDays >= 30 &&
        earnedBadgeNames.contains("Streak Level 1") &&
        !earnedBadgeNames.contains("Streak Level 2")) {
      await _awardBadge(userBadgeRef, "Streak Level 2");
      earnedBadges.add("Streak Level 2");
    }

    if (streakDays >= 60 &&
        earnedBadgeNames.contains("Streak Level 2") &&
        !earnedBadgeNames.contains("Streak Level 3")) {
      await _awardBadge(userBadgeRef, "Streak Level 3");
      earnedBadges.add("Streak Level 3");
    }

    return earnedBadges;
  }

  Future<void> _awardBadge(
      CollectionReference userBadgeRef, String badgeName) async {
    await userBadgeRef.doc(badgeName).set({'timestamp': Timestamp.now()});
  }

  Future<int> _getUserStreak() async {
    final userDoc = await _firestore.collection('users').doc(userId).get();

    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['streak'] ?? 0; // Use existing 'streak' field
    }

    return 0; // Default if streak is not set
  }
}
