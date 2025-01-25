import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyLeaderboard extends StatelessWidget {
  const WeeklyLeaderboard({Key? key}) : super(key: key); // Add const
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Leaderboard'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboard')
            .orderBy('totalScore', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No data available.'));
          }

          final leaderboardData = snapshot.data!.docs;

          return ListView.builder(
            itemCount: leaderboardData.length,
            itemBuilder: (context, index) {
              final user = leaderboardData[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  child: Text((index + 1).toString()),
                ),
                title: Text(user['name'] ?? 'Unknown User'),
                subtitle: Text('Total Score: ${user['totalScore'] ?? 0}'),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> updateLeaderboard(String userId, String chapterId, int score) async {
  final userRef = FirebaseFirestore.instance.collection('leaderboard').doc(userId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final userDoc = await transaction.get(userRef);

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final chapterScores = userData['chapterScores'] ?? {};

      // Update the score for the specific chapter
      chapterScores[chapterId] = score;

      // Calculate the total score
      final totalScore = chapterScores.values.fold(0, (sum, value) => sum + value);

      transaction.update(userRef, {
        'chapterScores': chapterScores,
        'totalScore': totalScore,
      });
    } else {
      // Create a new user entry if it doesn't exist
      transaction.set(userRef, {
        'name': 'User $userId', // Replace with actual user name
        'chapterScores': {chapterId: score},
        'totalScore': score,
      });
    }
  });
}
