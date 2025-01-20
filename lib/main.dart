import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'home.dart'; // Import your HomePage
import 'login.dart'; // Import your LoginPage
import 'splashscreen.dart'; // Import your sliding splash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Login',
      debugShowCheckedModeBanner: false, // Disable the debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue, // Set the primary color theme
      ),
      home: const SplashScreen(), // Use the sliding splash screen
    );
  }
}
