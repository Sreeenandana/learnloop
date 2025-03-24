import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'completed.dart';
import 'profile.dart';
import 'weekly_leaderboard.dart';
import 'badges.dart';
import 'pathdisplay.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    LearningPathDisplay(),
    WeeklyLeaderboard(),
    BadgesPage(),
    ProfilePage(),
    CompletedTopicsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text("Home"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    );
                  },
                ),
              ],
            )
          : null, // Show AppBar only on Home

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'Learning Path'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events), label: 'Badges'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = "User"; // Default username
  final User? user = FirebaseAuth.instance.currentUser;
  double completedProgress = 0.0;
  double inProgressProgress = 0.0;
  double pendingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _fetchProgressData();
  }

  Future<void> _fetchUsername() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          username = userDoc['Username'] ?? "User";
        });
      }
    }
  }

  Future<void> _fetchProgressData() async {
    double completed = await fetchCompletedProgress();
    double inProgress = await fetchInProgressProgress();

    setState(() {
      completedProgress = completed;
      inProgressProgress = inProgress;
      pendingProgress = 1 - (completed + inProgress);
    });
  }

  Future<double> fetchCompletedProgress() async {
    return 0.6; // 60% completed (Placeholder)
  }

  Future<double> fetchInProgressProgress() async {
    return 0.3; // 30% in progress (Placeholder)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟣 Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFdda0dd),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Welcome Back, $username!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔵 Grid View with Circular Progress Indicators
                GridView.count(
                  shrinkWrap: true, // ✅ Prevents overflow
                  physics:
                      const NeverScrollableScrollPhysics(), // ✅ Avoids nested scrolling issues
                  crossAxisCount: 2, // 3 items per row
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildProgressCard(
                      "Completed",
                      Icons.check_circle,
                      completedProgress,
                      Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CompletedTopicsPage()),
                        );
                      },
                    ),
                    _buildProgressCard(
                      "In Progress",
                      Icons.sync,
                      inProgressProgress,
                      Colors.blue,
                    ),
                    _buildProgressCard(
                      "Pending",
                      Icons.pending,
                      pendingProgress,
                      Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎯 Circular Progress Card Builder
  Widget _buildProgressCard(
      String title, IconData icon, double progress, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 70,
                  width: 70,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    color: color,
                  ),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Icon(icon, size: 30, color: color),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
