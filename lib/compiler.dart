import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CompilerPage extends StatefulWidget {
  @override
  _CompilerPageState createState() => _CompilerPageState();
}

class _CompilerPageState extends State<CompilerPage> {
  String selectedLanguage = "java"; // Default language
  final TextEditingController _codeController = TextEditingController();
  String output = "Output will be shown here...";
  bool isLoading = false;

  // Map language names to JDoodle language identifiers
  final Map<String, String> languageMap = {
    "Python": "python3",
    "Java": "java",
    "C++": "cpp17",
    "C": "c",
  };

  // Function to send code to JDoodle API and get output
  Future<void> runCode() async {
    setState(() {
      isLoading = true;
      output = "Running...";
    });

    final response = await http.post(
      Uri.parse("https://api.jdoodle.com/v1/execute"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "script": _codeController.text,
        "language": selectedLanguage,
        "versionIndex": "0",
        "clientId":
            "d2eedf346ac96ef417edc0fb489a0aa4", // Replace with your JDoodle clientId
        "clientSecret":
            "f657da55d1953188b20ebdd356f3dbd84f8ba98fcab178c847462bda4e73daf5", // Replace with your JDoodle secret
      }),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      setState(() {
        output = result["output"];
        isLoading = false;
      });
    } else {
      setState(() {
        output = "Error: ${response.statusCode}";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 231, 91, 180),
        toolbarHeight: 80.0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
// Adjust this value to move text more to the right
            Text(
              "DO AND LEARN!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Dropdown
            DropdownButton<String>(
              value: selectedLanguage,
              onChanged: (newValue) {
                setState(() {
                  selectedLanguage = newValue!;
                });
              },
              items: languageMap.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(entry.key),
                );
              }).toList(),
            ),

            SizedBox(height: 10),

            // Code Input Box
            TextField(
              controller: _codeController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: "Write your code here...",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 10),

            // Run Button
            ElevatedButton(
              onPressed: isLoading ? null : runCode,
              child: Text("Run Code"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 231, 91, 180),
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 10),

            // Output Console
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    output,
                    style:
                        TextStyle(color: Colors.green, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
