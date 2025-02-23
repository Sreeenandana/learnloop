//modify cheyyumbo just firestore modify aakkeet pinne path motham load aakkam. otherwise orderingil mattam ind.
//also do the same for first time loading. athilum ordering is bad.
//i have changed question count to 5.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'content.dart'; // Ensure this exists
import 'quizcontent.dart';
import 'resultpage.dart';

class LearningPathPage extends StatefulWidget {
  final Map<String, int>? topicScores;
  final String? topic;
  final List<String>? weakSubtopics;
  LearningPathPage({Key? key, this.topicScores, this.topic, this.weakSubtopics})
      : super(key: key) {
    //print("Constructor: topic = $topic, weakSubtopics = $weakSubtopics");
  }
  @override
  _LearningPathPageState createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage> {
  String _statusMessage = "";
  String _errorMessage = '';
  final Map<String, List<Map<String, dynamic>>> _subtopics = {};
  bool generated = false;
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  @override
  void initState() {
    super.initState();
    _fetchLearningPath();
  }

  Future<void> _fetchLearningPath() async {
    setState(() {
      _statusMessage = 'Curating Your Personalised Learning Path';
    });

//checks if user is logged in
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _errorMessage = 'No user is logged in.';
          _statusMessage = "";
        });
        return;
      }

// weaksubtopic indengil modify cheyyanam
      String? topic = widget.topic;
      List<String>? weakSubtopics = widget.weakSubtopics;
      if ((topic ?? '').isNotEmpty && (weakSubtopics?.isNotEmpty ?? false)) {
        await _modifyWeakSubtopics(topic!, weakSubtopics!);
      }

//topic score empty aanengil databaseil indonn nokkua
      Map<String, int> topicScores = widget.topicScores ?? {};
      if (topicScores.isEmpty) {
        print("topsc mt");
        final learningPathSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .get();
        if (learningPathSnapshot.docs.isNotEmpty) {
          for (var doc in learningPathSnapshot.docs) {
            topicScores[doc.id] = 0;
          }
        } else {
          print("lpsnap mt");
          setState(() {
            _errorMessage =
                'No topic scores available to generate a learning path.';
            _statusMessage = "";
          });
          return;
        }
      }
      for (var topic in topicScores.keys) {
        await _loadSubtopicsFromFirestore(topic, topicScores[topic]!);
      }
      setState(() {
        _statusMessage = "Let's Start Learning!!";
      });
      if ((context.mounted) && (generated)) {
        Navigator.pushReplacementNamed(
            context, '/home'); // Navigate to Home Page
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching learning path: $e';
        _statusMessage = "";
      });
    }
  }

  Future<void> _loadSubtopicsFromFirestore(String topic, int score) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('learningPath')
        .doc(topic);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data.containsKey('subtopics')) {
        final subtopics =
            List<Map<String, dynamic>>.from(data['subtopics'] ?? []);
        setState(() {
          _subtopics[topic] = subtopics;
        });
        generated = false;
      } else {
        await _generateAndStoreSubtopics(topic, score);
        generated = true;
      }
    } else {
      await _generateAndStoreSubtopics(topic, score);
      generated = true;
    }
  }

  Future<void> _generateAndStoreSubtopics(String topic, int score) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      int subtopicCount = score < 3 ? 7 : (score < 7 ? 5 : 3);

      final prompt =
          "Generate $subtopicCount subtopics for the topic $topic in the context of java in the learning order. "
          "Give only subtopic names, no descriptions, no numbering."
          "Lastly, also provide a quiz title in the format 'Quiz: $topic'.";

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        final subtopics = _parseSubtopics(response.text!);

        if (subtopics.isEmpty) {
          setState(() {
            _errorMessage = 'Generated subtopics for $topic are empty.';
          });
          return;
        }

        for (var subtopic in subtopics) {
          subtopic['status'] = 'pending'; // Default status
        }

        await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .doc(topic)
            .set({'subtopics': subtopics}, SetOptions(merge: true));

        _loadSubtopicsFromFirestore(topic, score);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating subtopics: $e';
      });
    }
  }

//unexpected null value vann. ini ellam print cheyth nokkanam.
  Future<void> _modifyWeakSubtopics(
      String topic, List<String> weakSubtopics) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || weakSubtopics.isEmpty) return;

    try {
      print("isnisde mod");
      String prompt =
          "Generate subtopics for the topic $topic in the context of java in the learning order."
          "I have little knowledge in the following subtopics of $topic: ${weakSubtopics.join(', ')}."
          "Modify these subtopics by breaking them down into simpler subtopics for better understanding. "
          "Give only subtopic names, no descriptions, no numbering."
          "Lastly, also provide a quiz title in the format 'Quiz: $topic'.";

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.trim().isNotEmpty) {
        final newSubtopics = _parseSubtopics(response.text!);

        if (newSubtopics.isEmpty) {
          setState(() {
            _errorMessage = 'No modified subtopics generated for $topic.';
          });
          return;
        }

        for (var subtopic in newSubtopics) {
          subtopic['status'] = 'pending'; // Default status
        }

        setState(() {
          // Ensure _subtopics[topic] exists
          if (!_subtopics.containsKey(topic)) {
            _subtopics[topic] = [];
          }

          // Remove weak subtopics
          _subtopics[topic] = _subtopics[topic]!
              .where((s) => !weakSubtopics.contains(s['name']))
              .toList();

          // Add new subtopics
          _subtopics[topic]!.addAll(newSubtopics);
        });
        print("just bef storing mod");
        await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .doc(topic)
            .set({'subtopics': _subtopics[topic]}, SetOptions(merge: true));
      } else {
        setState(() {
          _errorMessage = 'AI did not return any text for topic $topic.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error modifying weak subtopics: $e';
      });
    }
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    return responseText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((subtopic) => {'name': subtopic.trim(), 'status': 'pending'})
        .toList();
  }

  void _navigateToContent(String topic, String subtopic) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _errorMessage = 'User not logged in.';
      });
      return;
    }

    final subtopics = _subtopics[topic];
    if (subtopics == null) return;

    int currentIndex = subtopics.indexWhere((item) => item['name'] == subtopic);

    if (subtopic.toLowerCase().startsWith("quiz:")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterQuiz(
            topic: topic,
            userId: userId,
            onQuizFinished: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubtopicContentPage(
            topic: topic,
            subtopic: subtopic,
            userId: userId,
            onSubtopicFinished: () async {
              setState(() {
                subtopics[currentIndex]['status'] = 'complete';
              });

              await firestore
                  .collection('users')
                  .doc(userId)
                  .collection('learningPath')
                  .doc(topic)
                  .update({'subtopics': subtopics});

              if (currentIndex + 1 < subtopics.length) {
                _navigateToContent(topic, subtopics[currentIndex + 1]['name']);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_statusMessage.isNotEmpty) {
      Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          _statusMessage,
          style: TextStyle(fontSize: 16, color: Colors.blue),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning Path')),
        body: Center(
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Path')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: _subtopics.keys.map((topic) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                title: Text(topic,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                children: _subtopics[topic]!.map((subtopic) {
                  return ListTile(
                    title: Text(subtopic['name']),
                    trailing: subtopic['status'] == 'complete'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => _navigateToContent(topic, subtopic['name']),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
