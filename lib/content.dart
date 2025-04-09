import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:workmanager/workmanager.dart';

class SubtopicContentPage extends StatefulWidget {
  final String topic;
  final String subtopic;
  final VoidCallback onSubtopicFinished;
  final String userId;
  final String language;

  SubtopicContentPage({
    super.key,
    required this.topic,
    required this.subtopic,
    required this.onSubtopicFinished,
    required this.language,
    required this.userId,
  });

  @override
  _SubtopicContentPageState createState() => _SubtopicContentPageState();
}

class _SubtopicContentPageState extends State<SubtopicContentPage> {
  // final BadgeService _badgeService = BadgeService();
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  Map<String, dynamic>? subtopicData;
  List<Map<String, dynamic>>? practiceData;
  bool isLoading = true;
  String? errorMessage;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _fetchSubtopicContent();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Widget _buildMCQ(Map<String, dynamic> q) {
    String? selected;
    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['question'], style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                ...q['options'].map<Widget>((opt) {
                  return RadioListTile<String>(
                    title: Text(opt),
                    value: opt[0], // Use A, B, C, D as value
                    groupValue: selected,
                    onChanged: (val) {
                      setState(() => selected = val);
                    },
                  );
                }).toList(),
                if (selected != null)
                  Text(
                    selected == q['answer']
                        ? 'Correct!'
                        : 'Wrong! Answer: ${q['answer']}',
                    style: TextStyle(
                      color:
                          selected == q['answer'] ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatch(Map<String, dynamic> q) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Match the following:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 6),
            Text(q['pairs'], style: TextStyle(fontFamily: 'monospace')),
            SizedBox(height: 6),
            Text('Answer: ${q['answer']}',
                style: TextStyle(color: Colors.grey[700]))
          ],
        ),
      ),
    );
  }

  Widget _buildFill(Map<String, dynamic> q) {
    final controller = TextEditingController();
    bool submitted = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['question'], style: TextStyle(fontSize: 16)),
                TextField(controller: controller),
                SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () => setState(() => submitted = true),
                  child: Text('Check'),
                ),
                if (submitted)
                  Text(
                    controller.text.trim().toLowerCase() ==
                            q['answer'].toString().toLowerCase()
                        ? 'Correct!'
                        : 'Wrong! Answer: ${q['answer']}',
                    style: TextStyle(
                      color: controller.text.trim().toLowerCase() ==
                              q['answer'].toString().toLowerCase()
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchSubtopicContent() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      if (widget.subtopic.trim().isEmpty) {
        throw Exception('Subtopic is null or empty');
      }

      final response = await model.generateContent([
        Content.text(
            "Generate some detailed explanation about ${widget.subtopic} in the context of ${widget.language} programming language . "
            "Make it interesting and catchy, but do not make it overly casual. Imagine you are teaching a 13-year-old. you can sound like a textbook, just a bit more simpler. "
            "Also, include code pieces as examples if needed only. Do not include any formatting like bold or italian. always finish explanation before you give the example."
            "only put the code piece as example.Do not put any explanation after code piece. no need to use ``` at the start or end of code piece."
            "when you first start the explanation, begin with 'pl:', examples with 'eex:'. do not use these headers more than once.")
      ]);

      final practiceResponse = await model.generateContent([
        Content.text(
            "Generate a practice session with 3 diverse questions for the subtopic '${widget.subtopic}' in ${widget.language}. "
            "The format should be strictly as follows:\n"
            " mcq: What does X mean?\nA. Option1\nB. Option2\nC. Option3\nD. Option4\nAnswer: B\n"
            " fill: A variable that holds multiple values is called a ______.\nAnswer: list\n"
            "Do not include any explanation. Do not include any labels or headers.")
      ]);

      // print(response.text);
      if (response.text != null && response.text!.trim().isNotEmpty) {
        setState(() {
          subtopicData = _parseGeneratedContent(response.text!);
          practiceData = _parsePracticeQuestions(practiceResponse.text!)
              .cast<Map<String, dynamic>>();
          print("subbbb");
          print(subtopicData);
          isLoading = false;
        });
      } else {
        throw Exception('No content generated or empty response');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching content: $e';
        isLoading = false;
      });
    }
  }

  List<Map> _parsePracticeQuestions(String practiceText) {
    final questions = practiceText.split(RegExp(r'\n(?=\d\.)'));

    return questions.map((q) {
      if (q.contains("mcq:")) {
        final parts = q.split('\n');
        final question =
            parts[0].replaceFirst(RegExp(r'\d\.\s*mcq:'), '').trim();
        final options = parts.sublist(1, 5).map((o) => o.trim()).toList();
        final answer = parts
            .firstWhere((line) => line.startsWith('Answer:'))
            .split(':')[1]
            .trim();

        return {
          'type': 'mcq',
          'question': question,
          'options': options,
          'answer': answer,
        };
      } else if (q.contains("fill:")) {
        final fillParts = q.split('Answer:');
        final question =
            fillParts[0].replaceFirst(RegExp(r'\d\.\s*fill:'), '').trim();
        final answer = fillParts[1].trim();

        return {
          'type': 'fill',
          'question': question,
          'answer': answer,
        };
      } else {
        return {};
      }
    }).toList();
  }

  Map<String, dynamic> _parseGeneratedContent(String response) {
    String explanation = '';
    String example = '';
    List<String> questions = [];

    final expMatch =
        RegExp(r'pl:(.*?)(eex:|$)', dotAll: true).firstMatch(response);
    final exMatch =
        RegExp(r'eex:(.*?)(qquestions:|$)', dotAll: true).firstMatch(response);
    final qMatch =
        RegExp(r'qquestions:(.*)', dotAll: true).firstMatch(response);

    if (expMatch != null) {
      explanation = expMatch.group(1)!.trim();
      print("plplpl");
      print(explanation);
    }
    if (exMatch != null) {
      example = exMatch.group(1)!.trim();
      print("xxxxxxx");
      print(example);
    }
    if (qMatch != null) {
      questions = qMatch
          .group(1)!
          .trim()
          .split('\n')
          .where((q) => q.trim().isNotEmpty)
          .toList();
    }

    return {
      'explanation': explanation,
      'example': example,
      'questions': questions,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.subtopic.trim(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        backgroundColor: Color(0xFFdda0dd),
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Container(
              color: Color.fromARGB(
                  255, 231, 91, 180), // Set any background color here
              child: Center(
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  width: 200,
                  height: 200,
                ),
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            Text(
                              subtopicData!['explanation'],
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black87),
                            ),
                            SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                subtopicData!['example'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (practiceData != null && practiceData!.isNotEmpty) ...[
                      Text(
                        'Practice Session',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      ...practiceData!.map<Widget>((q) {
                        switch (q['type']) {
                          case 'mcq':
                            return _buildMCQ(q);
                          case 'fill':
                            return _buildFill(q);
                          default:
                            return SizedBox();
                        }
                      }).toList(),
                    ],
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        widget.onSubtopicFinished();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Center(
                        child: Text(
                          'Mark as Finished',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
