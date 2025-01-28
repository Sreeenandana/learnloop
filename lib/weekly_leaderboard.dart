import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyLeaderboard extends StatelessWidget {
  const WeeklyLeaderboard({super.key}); // Add const

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Leaderboard'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboard')
            .orderBy('totalPoints', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("No data available in the leaderboard collection.");
            return const Center(child: Text('No data available.'));
          }

          final leaderboardData = snapshot.data!.docs;
          print("Fetched ${leaderboardData.length} leaderboard entries.");

          return ListView.builder(
            itemCount: leaderboardData.length,
            itemBuilder: (context, index) {
              final user =
                  leaderboardData[index].data() as Map<String, dynamic>;
              print(
                  "Rendering leaderboard entry: ${user['Username']} with ${user['totalPoints']} points.");

              return ListTile(
                leading: CircleAvatar(
                  child: Text((index + 1).toString()),
                ),
                title: Text(user['Username'] ?? 'Unknown User'),
                subtitle: Text('Total Points: ${user['totalPoints'] ?? 0}'),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> updateLeaderboard(
    String userId, String chapterId, int points) async {
  final userRef =
      FirebaseFirestore.instance.collection('leaderboard').doc(userId);

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final userDocData = await transaction
          .get(userDocRef); // Fetch user name from the 'users' collection

      String userName = userDocData.exists
          ? userDocData['Username']
          : 'Unknown User'; // Default name if not found

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        //print("User $userId exists. Current data: $userData");

        final chapterScores = userData['chapterScores'] ?? {};
        //print("Current chapter scores: $chapterScores");

        // Update the score for the specific chapter
        chapterScores[chapterId] = points;

        // Calculate the total score
        final totalPoints =
            chapterScores.values.fold(0, (sums, value) => sums + value);
        // print("Updated total points: $totalPoints");

        transaction.update(userRef, {
          'Username': userName, // Store the user's name
          'chapterScores': chapterScores,
          'totalPoints': totalPoints,
        });
        //print("Updated user $userId data successfully.");
      } else {
        // Create a new user entry if it doesn't exist
        //print("User $userId does not exist. Creating new entry.");
        transaction.set(userRef, {
          'Username': userName, // Use the name from 'users' collection
          'chapterScores': {chapterId: points},
          'totalPoints': points,
        });
        //print("Created new entry for user $userId.");
      }
    });
  } catch (e, stackTrace) {
    print("Error updating leaderboard for user $userId: $e");
    print(stackTrace);
  }
}
