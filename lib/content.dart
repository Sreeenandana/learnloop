import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:learnloop/services/badges.dart';

class SubtopicContentPage extends StatelessWidget {
  final String topic;
  final String subtopic;
  final VoidCallback onSubtopicFinished;
  final String userId;
  final BadgeService _badgeService = BadgeService();

  SubtopicContentPage({
    super.key,
    required this.topic,
    required this.subtopic,
    required this.onSubtopicFinished,
    required this.userId,
  });

  // Secure your API key instead of hardcoding it
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  Future<String> _fetchSubtopicContent(String subtopic) async {
    try {
      //print("📚 Fetching content for subtopic: $subtopic");
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt =
          "Generate detailed content for the subtopic: $subtopic in context of Java";
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        // print("✅ Successfully fetched content for subtopic: $subtopic");
        return response.text!;
      } else {
        //print("⚠️ Failed to load content: Unable to generate response.");
        return 'Failed to load content: Unable to generate response.';
      }
    } catch (e) {
      //print("⚠️ Error fetching content: $e");
      return 'Error fetching content: $e';
    }
  }

  Future<void> _updateSubtopicStatus(BuildContext context) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final learningPathRef = userRef.collection('learningPath');
      final badgesRef = userRef.collection('badges');
      final docRef = learningPathRef.doc(topic);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);

        if (docSnapshot.exists) {
          List<dynamic> subtopicsDynamic =
              docSnapshot.data()?['subtopics'] ?? [];
          List<Map<String, dynamic>> subtopics = subtopicsDynamic.map((s) {
            return Map<String, dynamic>.from(s);
          }).toList();

          int currentSubtopicIndex = -1;
          bool isSubtopicUpdated = false;

          for (int i = 0; i < subtopics.length; i++) {
            var sub = subtopics[i];

            if (sub['name'] == subtopic) {
              if (sub['status'] != 'completed') {
                sub['status'] = 'completed';
                sub['finishedAt'] = DateTime.now().toIso8601String();
                isSubtopicUpdated = true;
              }
              currentSubtopicIndex = i;
            }
          }

          if (isSubtopicUpdated) {
            transaction.update(docRef, {'subtopics': subtopics});
          }

          // Update user's current position
          await userRef.update({
            'currentPosition': {
              'topic': topic,
              'subtopicIndex': currentSubtopicIndex
            }
          });

          // Unlock and navigate to the next subtopic
          if (currentSubtopicIndex + 1 < subtopics.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Subtopic completed! Unlocking next...")),
            );

            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SubtopicContentPage(
                    topic: topic,
                    subtopic: subtopics[currentSubtopicIndex + 1]['name'],
                    userId: userId,
                    onSubtopicFinished: onSubtopicFinished,
                  ),
                ),
              );
            });
          } else {
            // Last subtopic completed, return to the previous screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("All subtopics completed!")),
            );

            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pop(context);
            });
          }

          // Award badge if this is the first completed subtopic
          if (currentSubtopicIndex == 0) {
            final badgeDoc =
                await badgesRef.doc("first_subtopic_completion").get();
            if (!badgeDoc.exists) {
              await _badgeService.awardBadge(
                context,
                userId,
                "first_subtopic_completion",
                () {
                  // Move to next subtopic after awarding the badge
                  if (currentSubtopicIndex + 1 < subtopics.length) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubtopicContentPage(
                          topic: topic,
                          subtopic: subtopics[currentSubtopicIndex + 1]['name'],
                          userId: userId,
                          onSubtopicFinished: onSubtopicFinished,
                        ),
                      ),
                    );
                  }
                },
              );
            }
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating subtopic status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subtopic)),
      body: FutureBuilder<String>(
        future: _fetchSubtopicContent(subtopic),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                snapshot.error?.toString() ?? 'Error loading content',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          String content = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content, style: const TextStyle(color: Colors.black)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // print("🔘 Marking subtopic as finished...");
                        await _updateSubtopicStatus(context);
                      } catch (e) {
                        //print("⚠️ Error marking subtopic as finished: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                          ),
                        );
                      }
                    },
                    child: const Text('Mark as Finished'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
