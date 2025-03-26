import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learnloop/pathdisplay.dart';
import 'package:learnloop/profile.dart';
import 'package:learnloop/settings.dart';
import 'badges.dart';
import 'package:learnloop/weekly_leaderboard.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async';
import 'content.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String username = "User";
  final User? user = FirebaseAuth.instance.currentUser;
  Map<DateTime, double> progressData = {}; // Initialize as a Map
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  int _totalSubtopics = 1;
  int _completedSubtopics = 0;
  String currentTopic = "Loading...";
  String currentSubtopic = "Loading...";
  DateTime? _sessionStartTime;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUsername();
    _fetchProgressData();
    _fetchSubtopicProgress();
    _fetchCurrentTopic();
    // _fetchCurrentSubtopic();
    _startTrackingTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTrackingTime();
    super.dispose();
  }

  Future<void> _fetchUsername() async {
    if (user == null) return;
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

  Future<void> _fetchProgressData() async {
    if (user == null) return;

    final progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyProgress');

    QuerySnapshot progressSnapshot = await progressRef.get();

    Map<DateTime, double> timeSpentData = {};

    for (var doc in progressSnapshot.docs) {
      Timestamp timestamp = doc['date'];
      DateTime date = DateTime(timestamp.toDate().year,
          timestamp.toDate().month, timestamp.toDate().day);
      double timeSpent = (doc['timeSpent'] ?? 0).toDouble();

      timeSpentData[date] = timeSpent;
    }

    setState(() {
      progressData = timeSpentData;
    });
  }

  Future<void> _fetchSubtopicProgress() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    int totalSubtopics = 0;
    int completedSubtopics = 0;

    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      totalSubtopics += subtopics.length;
      completedSubtopics +=
          subtopics.where((sub) => sub['status'] == 'completed').length;
    }

    setState(() {
      _totalSubtopics = totalSubtopics > 0 ? totalSubtopics : 1;
      _completedSubtopics = completedSubtopics;
    });
  }

  Future<void> _fetchCurrentTopic() async {
    print("Fetching current topic...");
    if (user == null) return;

    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();

    String newTopic = "All topics completed!"; // Default message

    for (var doc in learningPathSnapshot.docs) {
      String topicName = doc.id;
      Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>; // Cast to Map

      bool isCompleted =
          data.containsKey('completed') ? (data['completed'] as bool) : false;

      print("Topic: $topicName, Completed: $isCompleted");

      if (!isCompleted) {
        newTopic = topicName; // Set the first topic that is not completed
        break; // Stop looking for topics
      }
    }

    setState(() {
      currentTopic = newTopic; // Update UI
    });

    print("Current Topic: $currentTopic");
  }

  /* Future<void> _fetchCurrentSubtopic() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    String subtopic = "All subtopics completed!";
    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      for (var sub in subtopics) {
        if (sub['status'] != 'completed') {
          subtopic = sub['name'] ?? "Unknown Subtopic";
          break;
        }
      }
    }
    setState(() {
      currentSubtopic = subtopic;
    });
  }*/

  void _startTrackingTime() {
    _sessionStartTime = DateTime.now();
  }

  void _stopTrackingTime() async {
    if (_sessionStartTime == null || user == null) return;
    DateTime now = DateTime.now();
    Duration sessionDuration = now.difference(_sessionStartTime!);
    double minutesSpent = sessionDuration.inMinutes.toDouble();

    String docId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    DocumentReference progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyProgress')
        .doc(docId);

    await progressRef.set({
      'date': now,
      'timeSpent': FieldValue.increment(minutesSpent),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    double progress = _completedSubtopics / _totalSubtopics;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _selectedIndex == 0
          ? AppBar(
              actions: [
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage()),
                    );
                  },
                ),
              ],
              backgroundColor: Color.fromARGB(
                  255, 230, 98, 230), // Customize the AppBar color
            )
          : null, // No AppBar for other pages
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // HomePage content: You can display the username and progress details
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Text(
                  "Welcome, $username!",
                  style: TextStyle(
                    fontSize: 32, // Larger font size for the welcome message
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 230, 98, 230),
                  ),
                ),
                SizedBox(height: 25),
                // Progress Indicator
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
                    progressColor: Colors.green,
                    backgroundColor: Colors.grey,
                  ),
                ),

                SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to the subtopic content page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LearningPathDisplay(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        // Continue Learning text outside the box
                        Text(
                          "Continue Learning",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(
                            height: 10), // Space between the text and the box

                        // Box containing the topic name
                        Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16), // Padding for the box
                          decoration: BoxDecoration(
                            color:
                                Color.fromARGB(255, 230, 98, 230), // Box color
                            borderRadius:
                                BorderRadius.circular(8), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300, // Shadow color
                                blurRadius: 6, // Blur effect for the shadow
                                offset: Offset(0, 4), // Shadow position
                              ),
                            ],
                          ),
                          child: Text(
                            "$currentTopic", // Topic name inside the box
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white, // Text color
                              fontWeight:
                                  FontWeight.bold, // Text weight for emphasis
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                TableCalendar(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2025, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      DateTime normalizedDay =
                          DateTime(day.year, day.month, day.day);
                      double timeSpent = progressData[normalizedDay] ?? 0.0;

                      double intensity = (timeSpent / 100.0)
                          .clamp(0.0, 1.0); // Normalize & clamp

                      return Container(
                        margin: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Color.lerp(Colors.white,
                              Color.fromARGB(255, 230, 98, 230), intensity),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('${day.day}')),
                      );
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                ),

                SizedBox(height: 20),
                // Other content like Learning Path, Leaderboard, etc.
                //Expanded(child: LearningPathDisplay()),
                //Expanded(child: WeeklyLeaderboard()),
                //Expanded(child: BadgesPage()),
                //Expanded(child: ProfilePage()),
              ],
            ),
          ),
          LearningPathDisplay(),
          WeeklyLeaderboard(),
          BadgesPage(),
          ProfilePage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ' '),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: ' '),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: ' '),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: ' '),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ' '),
        ],
        selectedItemColor: Color.fromARGB(255, 230, 98, 230),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learnloop/pathdisplay.dart';
import 'package:learnloop/profile.dart';
import 'package:learnloop/settings.dart';
import 'badges.dart';
import 'package:learnloop/weekly_leaderboard.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String username = "User";
  final User? user = FirebaseAuth.instance.currentUser;
  Map<DateTime, double> progressData = {};
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  int _totalSubtopics = 1;
  int _completedSubtopics = 0;
  String currentTopic = "Loading...";
  String currentSubtopic = "Loading...";
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUsername();
    _fetchProgressData();
    _fetchSubtopicProgress();
    _fetchCurrentTopic();
    _fetchCurrentSubtopic();
    _startTrackingTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTrackingTime();
    super.dispose();
  }

  Future<void> _fetchUsername() async {
    if (user == null) return;
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

  Future<void> _fetchProgressData() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    Map<DateTime, double> dailyMinutes = {};

    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      for (var sub in subtopics) {
        if (sub['status'] == 'completed' && sub.containsKey('completedAt')) {
          Timestamp? timestamp = sub['completedAt'];
          double timeSpent = (sub['timeSpent'] ?? 0).toDouble();

          if (timestamp != null) {
            DateTime date = timestamp.toDate();
            DateTime dayKey = DateTime(date.year, date.month, date.day);
            dailyMinutes[dayKey] = (dailyMinutes[dayKey] ?? 0) + timeSpent;
          }
        }
      }
    }

    setState(() {
      progressData = dailyMinutes;
    });
  }

  Future<void> _fetchSubtopicProgress() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    int totalSubtopics = 0;
    int completedSubtopics = 0;

    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      totalSubtopics += subtopics.length;
      completedSubtopics +=
          subtopics.where((sub) => sub['status'] == 'completed').length;
    }

    setState(() {
      _totalSubtopics = totalSubtopics > 0 ? totalSubtopics : 1;
      _completedSubtopics = completedSubtopics;
    });
  }

  Future<void> _fetchCurrentTopic() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    String topic = "All topics completed!";
    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      if (subtopics.any((sub) => sub['status'] != 'completed')) {
        topic = doc.id;
        break;
      }
    }
    setState(() {
      currentTopic = topic;
    });
  }

  Future<void> _fetchCurrentSubtopic() async {
    if (user == null) return;
    final learningPathRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('learningPath');

    QuerySnapshot learningPathSnapshot = await learningPathRef.get();
    String subtopic = "All subtopics completed!";
    for (var doc in learningPathSnapshot.docs) {
      List<dynamic> subtopics = doc['subtopics'] ?? [];
      for (var sub in subtopics) {
        if (sub['status'] != 'completed') {
          subtopic = sub['name'] ?? "Unknown Subtopic";
          break;
        }
      }
    }
    setState(() {
      currentSubtopic = subtopic;
    });
  }

  void _startTrackingTime() {
    _sessionStartTime = DateTime.now();
  }

  void _stopTrackingTime() async {
    if (_sessionStartTime == null || user == null) return;
    DateTime now = DateTime.now();
    Duration sessionDuration = now.difference(_sessionStartTime!);
    double minutesSpent = sessionDuration.inMinutes.toDouble();

    String docId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    DocumentReference progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('dailyProgress')
        .doc(docId);

    await progressRef.set({
      'date': now,
      'timeSpent': FieldValue.increment(minutesSpent),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    double progress = _completedSubtopics / _totalSubtopics;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingsPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Welcome, $username",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              CircularPercentIndicator(
                  radius: 120.0,
                  lineWidth: 13.0,
                  animation: true,
                  percent: progress,
                  center: Text(
                      "${(_completedSubtopics / _totalSubtopics * 100).toInt()}%"),
                  progressColor: Colors.blue),
              SizedBox(height: 20),
              Text("Current Subtopic: $currentSubtopic",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              SizedBox(height: 30),
              Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade300, blurRadius: 6)
                    ]),
                child: TableCalendar(
                    firstDay: DateTime.utc(2025, 1, 1),
                    lastDay: DateTime.utc(2025, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Set this dynamically based on the selected tab
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => LearningPathDisplay()));
          } else if (index == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => WeeklyLeaderboard()));
          } else if (index == 3) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => BadgesPage()));
          } else if (index == 4) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => ProfilePage()));
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Path'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Badge'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 
*/
}
