import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyLeaderboard extends StatelessWidget {
  const WeeklyLeaderboard({super.key}); // Add const

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 230, 98, 230),
        toolbarHeight: 80.0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Adjust this value to move text more to the right
            Text(
              "LEADERBOARD",
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
            return const Center(child: Text("No data available"));
          }

// Continue with the rest of your code...

          final leaderboardData = snapshot.data!.docs;
          print("Fetched ${leaderboardData.length} leaderboard entries.");

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: leaderboardData.length,
            itemBuilder: (context, index) {
              final user =
                  leaderboardData[index].data() as Map<String, dynamic>;
              String username = user['Username'] ?? 'Unknown User';
              int totalPoints = user['totalPoints'] ?? 0;

              // Assign medal icons for top 3 users
              Widget leadingWidget;
              if (index == 0) {
                leadingWidget = const Icon(Icons.emoji_events,
                    color: Colors.amber, size: 40); // Gold
              } else if (index == 1) {
                leadingWidget = const Icon(Icons.emoji_events,
                    color: Colors.grey, size: 40); // Silver
              } else if (index == 2) {
                leadingWidget = const Icon(Icons.emoji_events,
                    color: Colors.brown, size: 40); // Bronze
              } else {
                leadingWidget = CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 183, 77, 183),
                  child: Text((index + 1).toString(),
                      style: const TextStyle(color: Colors.white)),
                );
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: leadingWidget,
                  title: Text(
                    username,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text('Total Points: $totalPoints',
                      style: const TextStyle(fontSize: 16)),
                  trailing:
                      Icon(Icons.star, color: Colors.orangeAccent.shade700),
                ),
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
