import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class SubtopicContentPage extends StatelessWidget {
  final String subtopic;
  final Function(String)
      onSubtopicFinished; // Callback for when the subtopic is finished

  SubtopicContentPage({
    super.key,
    required this.subtopic,
    required this.onSubtopicFinished, // Accept the callback function
  });

  // Regex patterns for bold, italic, code blocks, and bullet points
  final RegExp regexBold =
      RegExp(r'\*(.*?)\*'); // Bold text (starts and stops at immediate *)
  final RegExp regexItalics = RegExp(r'#(.*?)#'); // Italic text (enclosed by #)
  final RegExp regexCode =
      RegExp(r'```(.*?)```', dotAll: true); // Code blocks (enclosed by ```)
  final RegExp regexBullet = RegExp(r'^\$(.*)',
      multiLine: true); // Bullet points (lines starting with $)

  // Google Generative AI API Key
  final String _apiKey =
      'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'; // Replace with your actual API key

  // Fetch content for subtopic using Google Generative AI
  Future<String> _fetchSubtopicContent(String subtopic) async {
    try {
      print("in cp");
      // Initialize the Generative Model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', // Replace with your preferred model
        apiKey: _apiKey,
      );

      // Create a prompt to generate content for the subtopic
      final prompt = "Generate detailed content for the subtopic: $subtopic.";

      // Generate content using the AI model
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

  // Format content to handle bold text, italics, code blocks, and bullet points
  TextSpan _formatContent(String content) {
    List<TextSpan> textSpans = [];
    int lastEnd = 0;

    // Process code blocks
    final codeMatches = regexCode.allMatches(content);
    for (var match in codeMatches) {
      if (match.start > lastEnd) {
        textSpans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      textSpans.add(TextSpan(
        text: match.group(1), // Code content inside triple backticks
        style: const TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Color.fromARGB(
              255, 139, 114, 114), // Light background for code block
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining plain text
    if (lastEnd < content.length) {
      textSpans.add(TextSpan(text: content.substring(lastEnd)));
    }

    // Now, handle bold, italic text, and bullet points
    List<TextSpan> finalTextSpans = [];
    for (var span in textSpans) {
      finalTextSpans.addAll(_processTextStyles(span.text ?? ''));
    }

    return TextSpan(children: finalTextSpans);
  }

  // Function to process bold, italic text, and bullet points
  List<TextSpan> _processTextStyles(String content) {
    print("in pts of cp");
    List<TextSpan> resultSpans = [];
    int lastEnd = 0;

    // Combine matches for bold, italic, and bullet points
    final matches = [
      ...regexBold.allMatches(content),
      ...regexItalics.allMatches(content),
      ...regexBullet.allMatches(content)
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (var match in matches) {
      if (match.start > lastEnd) {
        // Add the text before the styled section
        resultSpans
            .add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      // Determine style based on the match
      if (regexBold.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (regexItalics.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (regexBullet.hasMatch(match.group(0)!)) {
        resultSpans.add(TextSpan(
          text: "\u2022 ${match.group(1)?.trim()}\n",
          style: const TextStyle(),
        ));
      }

      lastEnd = match.end;
    }

    // Add any remaining plain text after the last match
    if (lastEnd < content.length) {
      resultSpans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return resultSpans;
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

          // Apply formatting and return the formatted text
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
                    onPressed: () {
                      // Mark the subtopic as finished and call the callback to move to the next subtopic
                      onSubtopicFinished(subtopic);
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
