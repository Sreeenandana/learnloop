import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
<<<<<<< Updated upstream
import 'content.dart'; // Ensure these files exist
=======
import 'content.dart'; // Ensure this exists
>>>>>>> Stashed changes
import 'quizcontent.dart';
import 'resultpage.dart';

class LearningPathPage extends StatefulWidget {
  final Map<String, int>? topicScores;

  const LearningPathPage({Key? key, this.topicScores}) : super(key: key);

  @override
  _LearningPathPageState createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  final Map<String, List<Map<String, dynamic>>> _subtopics = {};

  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';

  @override
  void initState() {
    super.initState();
    _fetchLearningPath();
  }

<<<<<<< Updated upstream
  Future<void> _generateLearningPath() async {
    setState(() => _isLoading = true);
=======
  Future<void> _fetchLearningPath() async {
    setState(() {
      _isLoading = true;
    });
>>>>>>> Stashed changes

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _errorMessage = 'No user is logged in.';
          _isLoading = false;
        });
        return;
      }

      Map<String, int> topicScores = widget.topicScores ?? {};
      if (topicScores.isEmpty) {
        final learningPathSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .get();

        if (learningPathSnapshot.docs.isNotEmpty) {
          for (var doc in learningPathSnapshot.docs) {
            topicScores[doc.id.replaceAll('_', ' ')] = 0;
          }
        } else {
          setState(() {
            _errorMessage =
                'No topic scores available to generate a learning path.';
            _isLoading = false;
          });
          return;
        }
      }

<<<<<<< Updated upstream
=======
      // Fetch existing learning path from Firestore
>>>>>>> Stashed changes
      for (var topic in topicScores.keys) {
        await _loadSubtopicsFromFirestore(topic, topicScores[topic]!);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching learning path: $e';
        _isLoading = false;
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

    if (docSnapshot.exists && docSnapshot.data()!.containsKey('subtopics')) {
      setState(() {
        _subtopics[topic] = List<Map<String, dynamic>>.from(
            docSnapshot.data()!['subtopics'] ?? []);
      });
    } else {
      await _generateAndStoreSubtopics(topic, score);
    }
  }

  Future<void> _generateAndStoreSubtopics(String topic, int score) async {
    final userId = _auth.currentUser?.uid;
<<<<<<< Updated upstream
    if (userId == null ||
        (_subtopics.containsKey(topic) && _subtopics[topic]!.isNotEmpty))
      return;
=======
    if (userId == null) return;
>>>>>>> Stashed changes

    try {
      int subtopicCount = score < 40 ? 7 : (score < 70 ? 5 : 3);
      final prompt = "Generate $subtopicCount subtopics for the topic $topic. "
          "Give only subtopic names, no descriptions, no numbering."
<<<<<<< Updated upstream
          "Lastly also give a quiz title for the given topic as 'quiz:$topic'.";
=======
          "Lastly, also provide a quiz title in the format 'Quiz: $topic'.";
>>>>>>> Stashed changes

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        final subtopics = _parseSubtopics(response.text!);

        if (subtopics.isEmpty) {
          setState(() =>
              _errorMessage = 'Generated subtopics for $topic are empty.');
          return;
        }

<<<<<<< Updated upstream
        setState(() => _subtopics[topic] = subtopics);
=======
        for (var subtopic in subtopics) {
          subtopic['status'] = 'pending'; // Default status
        }

        setState(() {
          _subtopics[topic] = subtopics;
        });
>>>>>>> Stashed changes

        await firestore
            .collection('users')
            .doc(userId)
            .collection('learningPath')
            .doc(topic)
            .set({'subtopics': subtopics}, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error generating subtopics: $e');
    }
  }

  List<Map<String, dynamic>> _parseSubtopics(String responseText) {
    return responseText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
<<<<<<< Updated upstream
        .map((subtopic) => {'name': subtopic, 'status': 'pending'})
=======
        .map((subtopic) => {'name': subtopic.trim(), 'status': 'pending'})
>>>>>>> Stashed changes
        .toList();
  }

  void _navigateToContent(String topic, String subtopic) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _errorMessage = 'User not logged in.');
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
<<<<<<< Updated upstream
            onQuizFinished: () => Navigator.pop(context),
=======
            onQuizFinished: () {
              Navigator.pop(context);
            },
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
            onSubtopicFinished: () {
              setState(() => subtopics[currentIndex]['status'] = 'complete');
=======
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

>>>>>>> Stashed changes
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
    return Scaffold(
<<<<<<< Updated upstream
      appBar: AppBar(
        title: const Text('Learning Path'),
        backgroundColor: const Color(0xFFdda0dd),
        elevation: 0,
=======
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
>>>>>>> Stashed changes
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: const Color(0xFFdda0dd)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Color(0xFFF8F8F8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: _subtopics.keys.map((topic) {
                      bool isCompleted = _subtopics[topic]!
                          .every((sub) => sub['status'] == 'complete');

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            topic,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          leading: Icon(
                              isCompleted ? Icons.check_circle : Icons.book,
                              color: isCompleted
                                  ? Colors.green
                                  : Colors.purpleAccent),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: const Color(0xFFdda0dd)),
                          onTap: () => _navigateToContent(
                              topic, _subtopics[topic]!.first['name']),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
