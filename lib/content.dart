import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class SubtopicContentPage extends StatelessWidget {
  final String topic;
  final String subtopic;
  final VoidCallback onSubtopicFinished;
  final String userId;

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

  Future<void> _updateSubtopicStatus(String topic, String subtopic) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('topics')
          .doc(topic)
          .collection('subtopics')
          .doc(subtopic);

      await docRef.update({
        'status': 'finished',
        'finishedAt': FieldValue.serverTimestamp(),
      });

      print("Subtopic status updated to 'finished'");
    } catch (e) {
      print("Error updating subtopic status: $e");
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
                  RichText(
                    text: _formatContent(content),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _updateSubtopicStatus(topic, subtopic);
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
