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

  void _checkAuthState() async {
    try {
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
    } catch (e) {
      print("SplashScreen: Error checking auth state: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 237, 241, 239),
      body: Center(
        child: CircleAvatar(
          backgroundColor: Color.fromARGB(255, 6, 40, 2),
          radius: 48,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              "assets/images/logo.png",
              scale: 4.0,
            ),
          ),
        ),
      ),
    );
  }
}
