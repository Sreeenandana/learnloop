import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:learnloop/services/badges.dart';

class SubtopicContentPage extends StatefulWidget {
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

  @override
  _SubtopicContentPageState createState() => _SubtopicContentPageState();
}

class _SubtopicContentPageState extends State<SubtopicContentPage> {
  final BadgeService _badgeService = BadgeService();
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  Map<String, dynamic>? subtopicData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSubtopicContent();
  }

  Future<void> _fetchSubtopicContent() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = """
Generate structured and interactive content for the subtopic: "${widget.subtopic}" in Java.it should be fun and interesting tone.

**Content Format:**  
1. **Explanation:** Provide a clear explanation of the concept.  
2. **Example:** Include a code example.   
3. **Questions:** Include multiple-choice questions and code snippet fill-in-the-blanks.

**MCQ Format:**  
- Start the question with `qstn:`  
- Provide answer choices prefixed with `opt:` (comma-separated)  
- Indicate the correct answer using `ans:`    
 

**Fill-in-the-Blanks Format:**  
- Start the question with `fqstn:`  
- Represent the missing part with `blank`  
- Provide the correct answer using `fans:`  


Now, generate content using this format.
""";

      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text != null && response.text!.trim().isNotEmpty) {
        print(response.text);
        setState(() {
          subtopicData = _parseGeneratedContent(response.text!);
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

  Map<String, dynamic> _parseGeneratedContent(String response) {
    Map<String, dynamic> parsedContent = {
      'explanation': '',
      'example': '',
      'questions': [],
    };

    // Extract explanation
    RegExp expExplanation =
        RegExp(r'\*\*1\. Explanation:\*\*\n\n(.*?)\n\n', dotAll: true);
    parsedContent['explanation'] =
        expExplanation.firstMatch(response)?.group(1)?.trim() ?? '';

    // Extract example code
    RegExp expExample =
        RegExp(r'\*\*2\. Example:\*\*\n\n```java\n(.*?)\n```', dotAll: true);
    parsedContent['example'] =
        expExample.firstMatch(response)?.group(1)?.trim() ?? '';

    // Extract MCQ questions
    RegExp expMCQ = RegExp(
        r'`qstn:`\s*(.*?)\n`opt:`\s*(.*?)\n`ans:`\s*(.*?)\n`sub:`\s*(.*?)\n',
        dotAll: true);
    var mcqMatches = expMCQ.allMatches(response);
    for (var match in mcqMatches) {
      parsedContent['questions'].add({
        'type': 'mcq',
        'question': match.group(1)?.trim() ?? '',
        'options': match.group(2)?.trim().split(', '),
        'answer': match.group(3)?.trim() ?? '',
      });
    }

    // Extract Fill-in-the-Blanks questions
    RegExp expFillBlanks = RegExp(
        r'`fqstn:`\s*(.*?)\n`fans:`\s*(.*?)\n`sub:`\s*(.*?)\n',
        dotAll: true);
    var fillMatches = expFillBlanks.allMatches(response);
    for (var match in fillMatches) {
      parsedContent['questions'].add({
        'type': 'fill-in-the-blank',
        'question': match.group(1)?.trim() ?? '',
        'answer': match.group(2)?.trim() ?? '',
      });
    }

    return parsedContent;
  }

  Future<void> _markSubtopicAsFinished() async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final learningPathRef = userRef.collection('learningPath');
      final docRef = learningPathRef.doc(widget.topic);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        if (docSnapshot.exists) {
          List<dynamic> subtopicsDynamic =
              docSnapshot.data()?['subtopics'] ?? [];
          List<Map<String, dynamic>> subtopics = subtopicsDynamic
              .map((s) => Map<String, dynamic>.from(s))
              .toList();

          for (var sub in subtopics) {
            if (sub['name'] == widget.subtopic) {
              sub['status'] = 'completed';
              sub['finishedAt'] = DateTime.now().toIso8601String();
            }
          }
          transaction.update(docRef, {'subtopics': subtopics});
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subtopic completed!")),
      );
      widget.onSubtopicFinished();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subtopic)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // **Explanation**
                        Text(
                          "Explanation:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 5),
                        Text(subtopicData!['explanation'],
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 20),

                        // **Example Code**
                        Text(
                          "Example:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subtopicData!['example'],
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // **MCQs Section**
                        if (subtopicData!['questions']
                            .where((q) => q['type'] == 'mcq')
                            .isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Multiple Choice Questions:",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              ...subtopicData!['questions']
                                  .where((q) => q['type'] == 'mcq')
                                  .map<Widget>((q) => _buildMCQ(q)),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // **Fill-in-the-Blanks Section**
                        if (subtopicData!['questions']
                            .where((q) => q['type'] == 'fill-in-the-blank')
                            .isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Fill in the Blanks:",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              ...subtopicData!['questions']
                                  .where(
                                      (q) => q['type'] == 'fill-in-the-blank')
                                  .map<Widget>((q) => _buildFillInTheBlank(q)),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // **Mark as Finished Button**
                        ElevatedButton(
                          onPressed: _markSubtopicAsFinished,
                          child: const Text('Mark as Finished'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

// MCQ Widget
  Widget _buildMCQ(Map<String, dynamic> mcq) {
    String? selectedOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mcq['question'], style: TextStyle(fontSize: 16)),
        ...mcq['options'].map<Widget>((option) {
          return RadioListTile<String>(
            title: Text(option),
            value: option,
            groupValue: selectedOption,
            onChanged: (value) {
              setState(() {
                selectedOption = value;
              });
            },
          );
        }).toList(),
        const SizedBox(height: 10),
      ],
    );
  }

// Fill-in-the-Blank Widget
  Widget _buildFillInTheBlank(Map<String, dynamic> fitb) {
    TextEditingController _controller = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fitb['question'].replaceAll("blank", "____"),
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 5),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Your answer here...",
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
