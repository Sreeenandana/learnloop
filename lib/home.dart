import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'path.dart';
import 'login.dart';
import 'settings.dart'; // Import the SettingsPage
import 'weekly_leaderboard.dart'; // Import the WeeklyLeaderboard

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = false;

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
            onPressed: _logout, // Logout function
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator() // Show loading indicator
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome! Ready to learn and improve?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to LearningPathPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LearningPathPage(),
                          ),
                        );
                      },
                      child: const Text('View Learning Path'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to SettingsPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      child: const Text('Go to Settings'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to WeeklyLeaderboard
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WeeklyLeaderboard(),
                          ),
                        );
                      },
                      child: const Text('View Leaderboard'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
