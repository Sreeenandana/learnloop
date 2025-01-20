import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart'; // Import your HomePage
import 'login.dart'; // Import your LoginPage

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    // Automatically navigate after the last page
    Future.delayed(const Duration(seconds: 12), _checkAuthState);
  }

  void _checkAuthState() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // If the user is logged in, navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // If the user is not logged in, navigate to LoginPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(
          76, 175, 80, 1), // Customize the background color
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              // Slide 1
              buildPage(
                title: 'Welcome to LearnLoop',
                subtitle: 'The best platform to start your learning journey!',
                icon: Icons.book_online,
              ),
              // Slide 2
              buildPage(
                title: 'Learn from the Best',
                subtitle: 'Courses tailored to your needs and interests.',
                icon: Icons.school,
              ),
              // Slide 3
              buildPage(
                title: 'Achieve Your Goals',
                subtitle:
                    'Track your progress and celebrate your achievements.',
                icon: Icons.emoji_events,
              ),
            ],
          ),
          // Indicator dots
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3, // Number of pages
                (index) => buildDot(index, _currentPage),
              ),
            ),
          ),
          // Skip button
          if (_currentPage < 2)
            Positioned(
              top: 40,
              right: 20,
              child: TextButton(
                onPressed: _checkAuthState,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildPage(
      {required String title,
      required String subtitle,
      required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 120,
            color: Colors.white,
          ),
          const SizedBox(height: 30),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildDot(int index, int currentPage) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: currentPage == index ? 20 : 10,
      decoration: BoxDecoration(
        color: currentPage == index ? Colors.black : Colors.grey,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
