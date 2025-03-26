import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _darkMode = true; // Toggle for dark mode
  bool _notifications = true; // Toggle for notifications

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _darkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: const Color.fromARGB(255, 9, 28, 44),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Account Section
            const ListTile(
              title: Text('Account'),
              subtitle: Text('Manage your account settings'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              subtitle: const Text('View and edit your profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileSettings()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              subtitle: const Text('Update your password'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage()),
                );
              },
            ),
            const Divider(),

            // Preferences Section
            const ListTile(
              title: Text('Preferences'),
              subtitle: Text('Customize your experience'),
            ),
            SwitchListTile(
              value: _darkMode,
              onChanged: (bool value) {
                setState(() {
                  _darkMode = value;
                });
                _updatePreference('darkMode', value);
              },
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              secondary: const Icon(Icons.dark_mode),
            ),
            SwitchListTile(
              value: _notifications,
              onChanged: (bool value) {
                setState(() {
                  _notifications = value;
                });
                _updatePreference('notifications', value);
              },
              title: const Text('Notifications'),
              subtitle: const Text('Enable app notifications'),
              secondary: const Icon(Icons.notifications),
            ),
            const Divider(),

            // Other Section
            const ListTile(
              title: Text('Other'),
              subtitle: Text('Additional options'),
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              subtitle: const Text('Get assistance'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              subtitle: const Text('Learn more about the app'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Profile Page Implementation

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfileSettings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _usernameController = TextEditingController();
  File? _profileImage;
  bool _isLoading = false;

  String? _username;
  String? _email;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      setState(() {
        _email = userDoc['email'];
        _username = userDoc['Username'];
        _profileImageUrl = userDoc['profileImageUrl'];
        _usernameController.text = _username ?? '';
      });
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'Username': _usernameController.text});

          setState(() {
            _username = _usernameController.text;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated successfully!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update username.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _profileImage = File(pickedImage.path);
      });

      _uploadProfileImage();
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}.jpg');
        await storageRef.putFile(_profileImage!);

        final imageUrl = await storageRef.getDownloadURL();

        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'profileImageUrl': imageUrl});

        setState(() {
          _profileImageUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile picture.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context)
          .pushReplacementNamed('/login'); // Navigate to Login Page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign out.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/default_profile.png')
                              as ImageProvider,
                      child: const Icon(Icons.edit, size: 24),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email Display
                  Text(
                    _email ?? 'Email not available',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Username Input
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _updateUsername,
                    child: const Text('Update Username'),
                  ),
                  const Spacer(),

                  // Sign Out Button
                  ElevatedButton(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
    );
  }
}

// Change Password Page Implementation

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get current user
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-logged-in',
            message: 'User is not logged in.',
          );
        }

        // Re-authenticate the user with their old password
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(_newPasswordController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!')),
        );

        // Clear the fields
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'An error occurred. Please try again.';
        if (e.code == 'wrong-password') {
          errorMessage = 'The old password is incorrect.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The new password is too weak.';
        } else if (e.code == 'user-not-logged-in') {
          errorMessage = 'No user is logged in.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Old Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your old password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _changePassword,
                      child: const Text('Update Password'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// Help Page Implementation
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@yourapp.com',
      queryParameters: {'subject': 'Help & Support Inquiry'},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  // Function to open a link
  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            _buildSectionTitle("Frequently Asked Questions"),
            ExpansionTile(
              title: const Text("How does the app work?"),
              children: [Padding(padding: const EdgeInsets.all(10.0), child: Text("The app provides AI-powered tutoring based on your learning path."))],
            ),
            ExpansionTile(
              title: const Text("How do I reset my password?"),
              children: [Padding(padding: const EdgeInsets.all(10.0), child: Text("Go to Settings > Account > Reset Password."))],
            ),
            ExpansionTile(
              title: const Text("How can I track my progress?"),
              children: [Padding(padding: const EdgeInsets.all(10.0), child: Text("You can track progress under the 'Path' section."))],
            ),

            const SizedBox(height: 20),

            // Contact Support Section
            _buildSectionTitle("Contact Support"),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text("Email Us"),
              subtitle: const Text("learnloop3@gmail.com"),
              onTap: _sendEmail,
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text("Live Chat (Coming Soon)"),
              subtitle: const Text("Chat with our support team"),
            ),

            const SizedBox(height: 20),

            // Tutorials Section
            _buildSectionTitle("Tutorials & Guides"),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.red),
              title: const Text("Watch Video Tutorial"),
              subtitle: const Text("Learn how to use the app"),
              onTap: () => _launchURL("https://www.youtube.com"),
            ),

            const SizedBox(height: 20),

            // Troubleshooting Section
            _buildSectionTitle("Troubleshooting & Common Issues"),
            ListTile(
              leading: const Icon(Icons.error, color: Colors.orange),
              title: const Text("Login Issues"),
              subtitle: const Text("Reset your password if you have trouble logging in."),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.purple),
              title: const Text("Quiz Not Loading"),
              subtitle: const Text("Check your internet connection and try again."),
            ),

            const SizedBox(height: 20),

            // Report a Bug
            _buildSectionTitle("Report a Bug"),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text("Submit a Bug Report"),
              subtitle: const Text("Help us improve by reporting issues."),
              onTap: () => _launchURL("https://forms.google.com"), // Replace with actual form link
            ),

            const SizedBox(height: 20),

            // Community & Forums
            _buildSectionTitle("Community & Forums"),
            ListTile(
              leading: const Icon(Icons.forum, color: Colors.blue),
              title: const Text("Join the Community"),
              subtitle: const Text("Discuss and learn with others"),
              onTap: () => _launchURL("https://discord.com"), // Replace with actual community link
            ),
          ],
        ),
      ),
    );
  }

  // Function to create a section title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// About Page Implementation
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "About This App",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Welcome to Learnloop, AI-powered personal tutor designed to provide an adaptive and personalized learning experience. Our goal is to help you master subjects at your own pace with dynamically generated content, quizzes, and feedback tailored to your performance.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                "Key Features:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildFeatureItem("✅ AI-Generated Content & Quizzes – Get dynamically generated lessons and questions based on your progress."),
              _buildFeatureItem("✅ Personalized Learning Path – Adaptive topics and subtopics that evolve based on your quiz results."),
              _buildFeatureItem("✅ Progress Tracking – Monitor your improvement with topic-wise scores and badges."),
              _buildFeatureItem("✅ Interactive Quizzes – Reinforce learning with quizzes that unlock the next topics."),
              _buildFeatureItem("✅ Smart Recommendations – Weak areas are reinforced with simpler, AI-curated content."),
              _buildFeatureItem("✅ Leaderboard & Achievements – Compete with peers and earn badges as you progress."),
              SizedBox(height: 20),
              Text(
                "Our Mission",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "We believe in making education accessible, engaging, and tailored to each learner's needs. Using AI, we aim to revolutionize the way students learn by ensuring they receive the right content at the right time.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                "Need Help?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text("📧 learnloop3.com", style: TextStyle(fontSize: 16)),
              Text("🌐 [Your Website URL]", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
    Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Text(text, style: TextStyle(fontSize: 16)),
    );
  }
}
