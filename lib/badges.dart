import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  Future<String?> _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Your Badges")),
      body: FutureBuilder<String?>(
        future: _getCurrentUserId(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(child: Text("User not logged in"));
          }

          String userId = userSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('badges')
                .snapshots(),
            builder: (context, badgeSnapshot) {
              if (badgeSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!badgeSnapshot.hasData || badgeSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No badges earned yet!"));
              }

              var badges = badgeSnapshot.data!.docs;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Show two badges per row
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    var badge = badges[index].data() as Map<String, dynamic>;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 50, color: Colors.orange),
                          const SizedBox(height: 10),
                          Text(
                            badge['name'] ?? "Unknown Badge",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Earned on: ${badge['earnedAt']?.toDate().toString().split(' ')[0] ?? 'Unknown'}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
