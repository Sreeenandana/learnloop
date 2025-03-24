import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:learnloop/main.dart';
import 'dart:async';
import 'package:workmanager/workmanager.dart';

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
  // final BadgeService _badgeService = BadgeService();
  final String _apiKey = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44';
  Map<String, dynamic>? subtopicData;
  bool _isReminderScheduled = false;
  bool isLoading = true;
  String? errorMessage;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _fetchSubtopicContent();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSubtopicContent() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      if (widget.subtopic.trim().isEmpty) {
        throw Exception('Subtopic is null or empty');
      }

      final response = await model.generateContent([
        Content.text(
            "Generate some explanation about ${widget.subtopic} in the context of Java programming. "
            "Make it interesting and catchy. Imagine you are teaching a 13-year-old. "
            "Also, include examples and very simple questions. "
            "Start the explanation with 'eexplanation:', examples with 'eexamples:', and questions with 'qquestions:'.")
      ]);

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
    String explanation = '';
    String example = '';
    List<String> questions = [];

    // Use regex to extract sections based on the AI prompt structure
    final expMatch = RegExp(r'eexplanation:(.*?)eexamples:', dotAll: true)
        .firstMatch(response);
    final exMatch = RegExp(r'eexamples:(.*?)qquestions:', dotAll: true)
        .firstMatch(response);
    final qMatch =
        RegExp(r'qquestions:(.*)', dotAll: true).firstMatch(response);

    if (expMatch != null) {
      explanation = expMatch.group(1)!.trim();
    }
    if (exMatch != null) {
      example = exMatch.group(1)!.trim();
    }
    if (qMatch != null) {
      questions = qMatch
          .group(1)!
          .trim()
          .split('\n')
          .where((q) => q.trim().isNotEmpty)
          .toList();
    }

    return {
      'explanation': explanation,
      'example': example,
      'questions': questions,
    };
  }

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

//bool _isReminderScheduled = false;

  void initNotifications() async {
    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize WorkManager
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  void scheduleInactivityReminder() {
    if (!_isReminderScheduled) {
      _isReminderScheduled = true;
      Future.delayed(Duration(minutes: 1), () {
        if (_isReminderScheduled) {
          showNotification(
            "📢 Keep Learning!",
            "You haven't interacted with Java topics. Continue your progress!",
          );
        }
      });

      print("⏳ Inactivity Reminder Scheduled for 1 minute.");
    }
  }

  void scheduleStreakReminder() {
    Workmanager().registerOneOffTask(
      "streak_reminder_task",
      "showStreakReminder",
      initialDelay: Duration(hours: 20),
    );

    print("🔥 Streak Reminder Scheduled for 20 hours.");
  }

  void showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'reminder_channel',
      'Learning Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Unique ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

// Background execution
  void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) {
      if (task == "streak_reminder_task") {
        showNotification(
          "⚠️ Streak Warning!",
          "Your learning streak is about to be lost. Open the app now!",
        );
      }
      return Future.value(true);
    });
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
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black87),
                                ),
                                SizedBox(height: 20),
                                Image.asset(
                                    'assets/${widget.subtopic.replaceAll(' ', '_').toLowerCase()}.png',
                                    height: 200,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container()),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            widget.onSubtopicFinished();
                            // Mark as finished
                            Navigator.pop(
                                context); // ✅ Return to Subtopic List instead of moving to next subtopic
                            scheduleInactivityReminder(); // ✅ Start Reminder for Foreground
                            scheduleStreakReminder();
                          },
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
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
