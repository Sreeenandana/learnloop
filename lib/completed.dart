import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompletedTopicsPage extends StatefulWidget {
  @override
  _CompletedTopicsPageState createState() => _CompletedTopicsPageState();
}

class _CompletedTopicsPageState extends State<CompletedTopicsPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Completed Topics")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('learningPath')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No completed topics yet."));
          }

          List<Widget> completedItems = [];

          for (var doc in snapshot.data!.docs) {
            List<dynamic> subtopics = doc['subtopics'] ?? [];
            for (var subtopic in subtopics) {
              if (subtopic['status'] == 'completed') {
                completedItems.add(
                  ListTile(
                    title: Text(subtopic['name']),
                    subtitle: Text("Topic: ${doc.id}"),
                    leading: Icon(Icons.check_circle, color: Colors.green),
                  ),
                );
              }
            }
          }

          if (completedItems.isEmpty) {
            return Center(child: Text("No completed topics yet."));
          }

          return ListView(children: completedItems);
        },
      ),
    );
  }
}
