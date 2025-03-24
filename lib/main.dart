import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'home.dart';
import 'login.dart';
import 'splashscreen.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    showReminderNotification();
    return Future.value(true);
  });
}

// Background message handler
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void showReminderNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'subtopic_reminder_channel',
    'Subtopic Reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    1,
    "Don't Stop Learning!",
    "You haven't selected a new subtopic. Keep going!",
    notificationDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  tz.initializeTimeZones();

  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: androidInitializationSettings);

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Firebase Messaging instance
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("User granted permission for notifications");
  } else {
    print("User declined or has not granted permission");
  }

  // Get the device token for push notifications
  String? token = await messaging.getToken();
  print("FCM Token: $token");

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Received a foreground message: ${message.notification?.title}");

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: false,
          ),
        ),
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Notifications',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
