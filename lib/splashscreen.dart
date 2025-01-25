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
  int _currentPage = 0;
  bool _isLoggedIn = false;
  final int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in
      setState(() {
        _isLoggedIn = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    }
  }

  void _navigateToNextPage() {
    if (_currentPage < (_isLoggedIn ? 0 : _totalPages - 1)) {
      setState(() {
        _currentPage++;
      });
    } else {
      // Navigate to appropriate page after the last slide
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
      body: Stack(
        children: [
          PageView.builder(
            itemCount: _isLoggedIn ? 1 : _totalPages,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            controller: PageController(initialPage: _currentPage),
            itemBuilder: (context, index) {
              return buildPage(
                title: index == 0
                    ? 'Welcome to LearnLoop'
                    : index == 1
                        ? 'Learn from the Best'
                        : 'Achieve Your Goals',
                subtitle: index == 0
                    ? 'The best platform to start your learning journey!'
                    : index == 1
                        ? 'Courses tailored to your needs and interests.'
                        : 'Track your progress and celebrate your achievements.',
                icon: index == 0
                    ? Icons.book_online
                    : index == 1
                        ? Icons.school
                        : Icons.emoji_events,
              );
            },
          ),
          // Indicator dots
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _isLoggedIn ? 1 : _totalPages,
                (index) => buildDot(index),
              ),
            ),
          ),
          // Next button
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _navigateToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_currentPage == (_isLoggedIn ? 0 : _totalPages - 1)
                  ? 'Finish'
                  : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPage({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
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

  Widget buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: _currentPage == index ? 20 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.black : Colors.grey,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
