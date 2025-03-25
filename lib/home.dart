import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'completed.dart';
import 'profile.dart';
import 'weekly_leaderboard.dart';
import 'badges.dart';
import 'pathdisplay.dart';
import 'settings.dart';
import 'package:intl/intl.dart';

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
          : null,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learning Path'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Badges'),
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
  String username = "User";
  final User? user = FirebaseAuth.instance.currentUser;
  List<FlSpot> progressData1 = [FlSpot(0, 0)];
  List<FlSpot> progressData2 = [FlSpot(0, 0)];
  Map<double, String> xAxisLabels = {};
  String selectedYear = "2025";
  
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
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    List<FlSpot> data1 = [];
    List<FlSpot> data2 = [];
    Map<double, String> xLabels = {
      1: "Jan", 2: "Feb", 3: "Mar", 4: "Apr", 5: "May", 6: "Jun",
      7: "Jul", 8: "Aug", 9: "Sep", 10: "Oct", 11: "Nov", 12: "Dec",
    };

    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      for (var sub in subtopics) {
        if (sub['status'] == 'completed') {
          Timestamp? timestamp = sub['completedAt'];
          if (timestamp != null) {
            DateTime date = timestamp.toDate();
            if (date.year.toString() == selectedYear) {
              double month = date.month.toDouble();
              double progress = (data1.length % 20) * 1000 + 5000;
              data1.add(FlSpot(month, progress));
              data2.add(FlSpot(month, progress - 2000));
            }
          }
        }
      }
    }

    setState(() {
      progressData1 = data1.isNotEmpty ? data1 : [FlSpot(1, 5000)];
      progressData2 = data2.isNotEmpty ? data2 : [FlSpot(1, 3000)];
      xAxisLabels = xLabels;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome, $username", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12), // Reduced padding for smaller screens
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15), // Slightly smaller for mobile
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: 12,
                      minY: 0,
                      maxY: 20000,
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                xAxisLabels[value.toInt()] ?? "",
                                style: TextStyle(fontSize: 10), // Reduced font size
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, 
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              return Text(
                              "${value ~/ 1000}K",
                              style: TextStyle(fontSize: 10), // Smaller text
                            );
                          },
                        ),
                      ),
                      ),
                      lineBarsData: [
                        LineChartBarData(spots: progressData1, isCurved: true, color: Colors.blue, barWidth: 2),
                        LineChartBarData(spots: progressData2, isCurved: true, color: Colors.green, barWidth: 2),
                      ],
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