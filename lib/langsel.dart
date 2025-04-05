import 'package:flutter/material.dart';
import 'initial.dart'; // Make sure this import matches your file structure

class LanguageSelectionPage extends StatefulWidget {
  @override
  _LanguageSelectionPageState createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final List<String> _languages = ["Java", "Python", "C++", "C"];
  String? _language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
        backgroundColor: Color(0xFFdda0dd),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFdda0dd), Colors.purple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose a programming language:",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            ..._languages.map((lang) => Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                  child: RadioListTile<String>(
                    title: Text(lang),
                    value: lang,
                    groupValue: _language,
                    activeColor: Color(0xFFdda0dd),
                    onChanged: (value) {
                      setState(() {
                        _language = value;
                      });
                    },
                  ),
                )),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _language == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                QuizPage(language: _language!),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFFdda0dd),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Start"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
