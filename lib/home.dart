import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_highlight/themes/color-brewer.dart';
import 'package:learnloop/pathdisplay.dart';
import 'package:learnloop/profile.dart';
import 'package:learnloop/settings.dart';
import 'badges.dart';
import 'compiler.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:learnloop/weekly_leaderboard.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String user = "usser";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<DateTime, int> progressData = {}; // Initialize as a Map
  int _totalSubtopics = 1;
  int _completedSubtopics = 0;
  DateTime _selectedMonth = DateTime.now();
  //String currentTopic = "Loading...";
  String currentSubtopic = "Next Topic...";
  DateTime? _sessionStartTime;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchuser().then((_) {
      _fetchProgressData();
    });
    WidgetsBinding.instance.addObserver(this);
    _fetchSubtopicProgress();
    _startTrackingTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTrackingTime();
    super.dispose();
  }

  Future<void> _fetchuser() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
      String username = userDoc['Username'] ?? 'User';
      setState(() {
        user = username; // Ensure 'user' is correctly assigned
      });
    }
  }

  Future<void> _fetchProgressData() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyProgress');

    QuerySnapshot progressSnapshot = await progressRef.get();

    Map<DateTime, int> timeSpentData = {}; // Ensure int for heatmap

    for (var doc in progressSnapshot.docs) {
      Timestamp timestamp = doc['date'];
      DateTime date = DateTime(timestamp.toDate().year,
          timestamp.toDate().month, timestamp.toDate().day);
      int timeSpent = (doc['timeSpent'] ?? 0).toInt(); // Convert to int

      timeSpentData[date] = timeSpent;
    }

    setState(() {
      progressData = timeSpentData;
    });
  }

  Map<DateTime, int> _getFilteredData() {
    return Map.fromEntries(
      progressData.entries.where((entry) =>
          entry.key.year == _selectedMonth.year &&
          entry.key.month == _selectedMonth.month),
    );
  }

  Future<void> _fetchSubtopicProgress() async {
    String? user = _auth.currentUser?.uid;
    if (user == null) return;

    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();

    int totalSubtopics = 0;
    int completedSubtopics = 0;
    String? nextSubtopic;

    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];

      totalSubtopics += subtopics.length;
      completedSubtopics +=
          subtopics.where((sub) => sub['status'] == 'completed').length;

      // Find the first subtopic that is not completed
      for (var sub in subtopics) {
        if (sub['status'] != 'completed') {
          nextSubtopic = sub['name']; // Get the first uncompleted subtopic
          break; // Stop searching
        }
      }

      // Stop searching once we find the next subtopic
      if (nextSubtopic != null) break;
    }

    setState(() {
      _totalSubtopics = totalSubtopics > 0 ? totalSubtopics : 1;
      _completedSubtopics = completedSubtopics;
      currentSubtopic = nextSubtopic ?? "All subtopics completed!";
    });
  }

  void _startTrackingTime() {
    _sessionStartTime = DateTime.now();
  }

  void _stopTrackingTime() async {
    String? user = _auth.currentUser?.uid;
    if (_sessionStartTime == null || user == null) return;
    DateTime now = DateTime.now();
    Duration sessionDuration = now.difference(_sessionStartTime!);
    double minutesSpent = sessionDuration.inMinutes.toDouble();

    String docId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    DocumentReference progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user)
        .collection('dailyProgress')
        .doc(docId);

    await progressRef.set({
      'date': now,
      'timeSpent': FieldValue.increment(minutesSpent),
    }, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTrackingTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _completedSubtopics / _totalSubtopics;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Color.fromARGB(255, 230, 98, 230),
              toolbarHeight: 80.0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $user!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 248, 245, 248),
                    ),
                  ),
                ],
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            )
          : null,

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 230, 98, 230),
              ),
              child: Text(
                'Menu',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SettingsPage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ProfilePage()));
              },
            ),
            Divider(),
            ListTile(
              title: Text('Languages'),
              enabled: false, // Non-clickable title
            ),
            ListTile(
              title: Text('Java',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple)),
              onTap: () {
                print('Selected Java');
              },
            ),
            ListTile(
              title: Text('Python'),
              onTap: () {
                print('Selected Python');
              },
            ),
            ListTile(
              title: Text('C++'),
              onTap: () {
                print('Selected C++');
              },
            ),
          ],
        ),
      ),
// No AppBar for other pages
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 25),
                  Center(
                    child: CircularPercentIndicator(
                      radius: 50.0,
                      lineWidth: 7.0,
                      percent: progress,
                      center: Text(
                        "${(progress * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 230, 98, 230),
                        ),
                      ),
                      progressColor: Colors.pink,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 40),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LearningPathDisplay(),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text(
                            "Continue Learning",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 230, 98, 230),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 6,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              "$currentSubtopic",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16), // Side margin
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 247, 244, 244),
                            blurRadius: 2,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.horizontal, // Enables horizontal scrolling
                        child: HeatMap(
                          startDate: DateTime(
                              _selectedMonth.year, DateTime.february - 1, 1),
                          endDate: DateTime(
                              _selectedMonth.year, DateTime.december + 1, 0),
                          datasets:
                              _getFilteredData(), // Ensure this includes data for 3 months
                          size: 22, // Bigger boxes
                          textColor: Colors.black,
                          colorsets: {
                            1: Colors.pink[100]!,
                            5: Colors.pink[300]!,
                            10: Colors.pink[500]!,
                            15: Colors.pink[700]!,
                            20: Colors.pink[900]!,
                          },
                          showText: false, // Hide date text inside blocks
                          onClick: (date) {
                            print(
                                "Selected date: $date, Progress: ${progressData[date] ?? 0}");
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          LearningPathDisplay(),
          WeeklyLeaderboard(),
          BadgesPage(),
          CompilerPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Path'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Rank'),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Badges'),
          BottomNavigationBarItem(
              icon: Icon(Icons.computer), label: 'Practice'),
        ],
        selectedItemColor: Color.fromARGB(255, 230, 98, 230),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
