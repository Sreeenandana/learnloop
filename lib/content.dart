import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:learnloop/services/badges.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
  final BadgeService _badgeService = BadgeService();
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
    _initializeFCM();
  }
  @override
  void dispose() {
    _inactivityTimer?.cancel();  // Cancel timer if the user leaves
    super.dispose();
  }


  Future<void> _fetchSubtopicContent() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final response = await model.generateContent([Content.text(widget.subtopic)]);

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

  Future<void> _initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ Notifications permission granted");

      // Listen for foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showNotificationDialog(message.notification!.title, message.notification!.body);
        }
      });

      scheduleSubtopicReminder();
    } else {
      print("❌ Notifications permission denied");
    }
  }
  void _scheduleReminder() {
    if (!_isReminderScheduled) {
      _isReminderScheduled = true;
      Future.delayed(Duration(minutes: 1), () {
        if (mounted && _isReminderScheduled) {
          showReminderNotification();
        }
      });

      print("⏳ Inactivity Timer Started - Notification in 1 minute.");
    }
  }

  void _scheduleBackgroundReminder() {
    Workmanager().registerOneOffTask(
      "subtopic_reminder_task",
      "showReminderNotification",
      initialDelay: Duration(minutes: 1),  
    );

    print("⏳ Background task scheduled - Notification in 1 minute.");
  }

  void _startInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer?.cancel();  // Cancel any existing timer
    _inactivityTimer = Timer(Duration(minutes: 1), () {
      scheduleSubtopicReminder();
    });
    print("⏳ Inactivity timer started - user must select a new subtopic within 1 minute.");
  }
  void _cancelInactivityTimer() {
    if (_inactivityTimer != null && _inactivityTimer!.isActive) {
      _inactivityTimer!.cancel();
      print("❌ Inactivity timer canceled - user selected a new subtopic.");
    }
  }

  void scheduleSubtopicReminder() async {
    print("📢 Sending inactivity reminder notification...");
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'subtopic_reminder_channel',
      'Subtopic Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      1,  // Unique notification ID
      "Don't Stop Learning!",
      "You haven't selected a new subtopic. Keep going!",
      notificationDetails,
    );
  }

  void _showNotificationDialog(String? title, String? body) {
    if (title == null || body == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _parseGeneratedContent(String response) {
    return {
      'explanation': response.replaceAll('*', '').replaceAll('#', ''),
      'example': '',
      'questions': [],
    };
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
                                  style: TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                                SizedBox(height: 20),
                                Image.asset('assets/${widget.subtopic.replaceAll(' ', '_').toLowerCase()}.png', height: 200, errorBuilder: (context, error, stackTrace) => Container()),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            widget.onSubtopicFinished();  // Mark as finished
                            Navigator.pop(context);  // ✅ Return to Subtopic List instead of moving to next subtopic
                            _scheduleReminder(); // ✅ Start Reminder for Foreground
                            _scheduleBackgroundReminder();
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
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
