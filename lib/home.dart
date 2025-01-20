import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'path.dart'; // Assuming LearningPathPage is in this file
import 'login.dart'; // Import the LoginPage for redirection after logout

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, int> topicScores = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserScores();
  }

  Future<void> _loadUserScores() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Get the current logged-in user ID
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      // Handle case where user is not logged in
      print('No user is logged in.');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Fetch the initial assessment data directly from the user's document
      final initialAssessmentDocumentSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .get(); // Fetching the user document directly

      final data = initialAssessmentDocumentSnapshot.data();
      print("before if");
      print(data);
      if (data != null && data.containsKey('initialAssessment')) {
        // Process the initial assessment data
        final marks = data['initialAssessment']['marks']
            as Map<String, dynamic>?; // Retrieve 'initialAssessment' map
        print(marks);
        if (marks != null) {
          Map<String, int> scores = {};
          print("print score");
          // Convert the marks map into topicScores
          marks.forEach((topic, score) {
            if (topic.isNotEmpty && score is int) {
              scores[topic] = score;
              print(scores);
            }
          });

          print('Fetched scores: $scores'); // Debug log for fetched scores

          setState(() {
            topicScores = scores;
            isLoading = false;
          });
        } else {
          print('No initial assessment data found for the user.');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('No initial assessment field found in the user document.');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user scores: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Your Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout, // Call the logout function
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator() // Show a loading indicator while fetching data
              : topicScores.isEmpty
                  ? const Text(
                      'No scores available. Start a quiz to track your progress!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        // Pass topicScores to LearningPathPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LearningPathPage(topicScores: topicScores),
                          ),
                        );
                      },
                      child: const Text('View Learning Path'),
                    ),
        ),
      ),
    );
  }
}
