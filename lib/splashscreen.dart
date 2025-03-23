import 'package:flutter/material.dart';
import 'home.dart'; // Import your HomePage
import 'login.dart'; // Import your LoginPage
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(seconds: 3),
      _checkAuthState,
    );
  }

  void _checkAuthState() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Navigate to HomePage if the user is logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // Navigate to LoginPage if the user is not logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(221, 160, 221, 1), // Background color
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures only necessary space is occupied
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // Ensures everything is center-aligned
          children: [
            CircleAvatar(
              backgroundColor: const Color.fromRGBO(221, 160, 221, 1),
              radius: 64, // Adjust size of the logo circle
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(
                  "assets/images/logo.png", // Path to your logo image
                  scale: 2.5, // Scale the logo
                ),
              ),
            ),
            Image.asset(
              "assets/images/learnloop.png", // Path to your PNG file
              width: 180,
              alignment: Alignment.center, // Ensures perfect center alignment
            ),
          ],
        ),
      ),
    );
  }
}
