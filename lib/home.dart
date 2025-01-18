import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'path.dart'; // Import your LearningPathPage here
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
      // Fetch initial assessment scores from the 'initialAssessment' subcollection
      final initialAssessmentQuerySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('initialAssessment')
          .get();

      if (initialAssessmentQuerySnapshot.docs.isNotEmpty) {
        // Process the initial assessment scores here
        Map<String, int> scores = {};
        for (var doc in initialAssessmentQuerySnapshot.docs) {
          final data = doc.data();
          final topic = data['topic'] ?? '';
          final score = data['score'] ?? 0;
          if (topic.isNotEmpty) {
            scores[topic] = score;
          }
        }

        setState(() {
          topicScores = scores;
          isLoading = false;
        });
        print('User initial assessment scores: $topicScores');
      } else {
        print('No initial assessment data found for the user.');
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
