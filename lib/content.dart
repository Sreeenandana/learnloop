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

  final RegExp regexBold = RegExp(r'\*(.*?)\*');
  final RegExp regexItalics = RegExp(r'#(.*?)#');
  final RegExp regexCode = RegExp(r'```(.*?)```', dotAll: true);
  final RegExp regexBullet = RegExp(r'^\$(.*)', multiLine: true);

  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  Future<String> _fetchSubtopicContent(String subtopic) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt =
          "Generate detailed content for the subtopic: $subtopic in context of Java";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      } else {
        return 'Failed to load content: Unable to generate response.';
      }
    } catch (e) {
      return 'Error fetching content: $e';
    }
  }

  TextSpan _formatContent(String content) {
    List<TextSpan> textSpans = [];
    int lastEnd = 0;

    final codeMatches = regexCode.allMatches(content);
    for (var match in codeMatches) {
      if (match.start > lastEnd) {
        textSpans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      textSpans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Color.fromARGB(255, 230, 230, 230),
          color: Colors.black,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      textSpans.add(TextSpan(text: content.substring(lastEnd)));
    }

    List<TextSpan> finalTextSpans = [];
    for (var span in textSpans) {
      finalTextSpans.addAll(_processTextStyles(span.text ?? ''));
    }

    return TextSpan(
      children: finalTextSpans,
      style: const TextStyle(color: Colors.black),
    );
  }

  List<TextSpan> _processTextStyles(String content) {
    List<TextSpan> resultSpans = [];
    int lastEnd = 0;

    final matches = [
      ...regexBold.allMatches(content),
      ...regexItalics.allMatches(content),
      ...regexBullet.allMatches(content)
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (var match in matches) {
      if (match.start > lastEnd) {
        resultSpans
            .add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      if (regexBold.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ));
      } else if (regexItalics.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black,
          ),
        ));
      } else if (regexBullet.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: "\u2022 ${match.group(1)?.trim()}\n",
          style: const TextStyle(color: Colors.black),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      resultSpans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return resultSpans;
  }

  Future<void> _updateSubtopicStatus(BuildContext context) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learningPath')
          .doc(topic.replaceAll(' ', '_'));

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);

        if (docSnapshot.exists) {
          List<dynamic> subtopicsDynamic =
              docSnapshot.data()?['subtopics'] ?? [];

          // Convert list to mutable List<Map<String, dynamic>>
          List<Map<String, dynamic>> subtopics = subtopicsDynamic.map((s) {
            return Map<String, dynamic>.from(s);
          }).toList();

          int completedSubtopics = 0;
          // Find the subtopic and update status
          for (var sub in subtopics) {
            if (sub['name'] == subtopic) {
              sub['status'] = 'completed';
              sub['finishedAt'] =
                  DateTime.now().toIso8601String(); // Use timestamp as string
            }
            if (sub['status'] == 'completed') {
              completedSubtopics++;
            }
          }

          // Update only the modified array
          transaction.update(docRef, {'subtopics': subtopics});

          int totalSubtopics = subtopics.length;
          int halfSubtopics = (totalSubtopics / 2).ceil();

          // Check for progress-based badges
          if (completedSubtopics == halfSubtopics) {
            await _badgeService.checkAndAwardBadges(userId, completedSubtopics, totalSubtopics);
            _showBadgeEarnedDialog(context, "Halfway Explorer", "You've completed half of the subtopics!");
          } else if (completedSubtopics == totalSubtopics) {
            await _badgeService.checkAndAwardBadges(userId, completedSubtopics, totalSubtopics);
            _showBadgeEarnedDialog(context, "Topic Mastery", "You've completed all subtopics in this topic!");
          }
        }
      });
      print("Subtopic '$subtopic' marked as completed in Firestore.");
    } catch (e) {
      print("Error updating subtopic status: $e");
    }
  }
  void _showBadgeEarnedDialog(BuildContext context, String badgeName, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🎉 Badge Earned!"),
        content: Text("$badgeName: $message"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
                  RichText(
                    text: _formatContent(content),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _updateSubtopicStatus(context);
                        onSubtopicFinished();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Subtopic "$subtopic" marked as finished.')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Error marking subtopic as finished: $e')),
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
