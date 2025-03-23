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

      final response = await model.generateContent([Content.text(widget.subtopic)]);

      if (response.text != null && response.text!.trim().isNotEmpty) {
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
    return {
      'explanation': response.replaceAll('*', '').replaceAll('#', ''),
      'example': '',
      'questions': [],
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
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 16),
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
                                Text(
                                  "Explanation:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  subtopicData!['explanation'],
                                  style: TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                                SizedBox(height: 20),
                                Image.asset('assets/${widget.subtopic.replaceAll(' ', '_').toLowerCase()}.png', height: 200, errorBuilder: (context, error, stackTrace) => Container()),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: widget.onSubtopicFinished,
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
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
