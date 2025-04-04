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
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 230, 98, 230),
        toolbarHeight: 80.0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Adjust this value to move text more to the right
            Text(
              "YOUR BADGES",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
                return const Center(
                    child: Text("START EARNING YOUR BADGES NOW!!"));
              }

              // Group badges by base name (excluding levels)
              Map<String, DocumentSnapshot> latestBadges = {};

              for (var doc in badgeSnapshot.data!.docs) {
                var badge = doc.data() as Map<String, dynamic>;
                String badgeName = doc.id;
                String baseName =
                    badgeName.replaceAll(RegExp(r' Level \d+$'), '');

                if (!latestBadges.containsKey(baseName)) {
                  latestBadges[baseName] = doc;
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Show two badges per row
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: latestBadges.length,
                  itemBuilder: (context, index) {
                    var badgeDoc = latestBadges.values.elementAt(index);
                    var badge = badgeDoc.data() as Map<String, dynamic>;
                    String criteria =
                        badge['criteria'] ?? 'No criteria available';

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 50, color: Colors.orange),
                            const SizedBox(height: 10),
                            Text(
                              badgeDoc.id, // Display badge name
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              criteria,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
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
