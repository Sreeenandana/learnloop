import 'package:cloud_firestore/cloud_firestore.dart';

class LearningPathService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeUserProgress(
      String userId, String topicId, List<String> subtopics) async {
    final topicRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('topics')
        .doc(topicId);
    final docSnapshot = await topicRef.get();

    if (!docSnapshot.exists) {
      Map<String, dynamic> subtopicData = {};
      for (var subtopic in subtopics) {
        subtopicData[subtopic] = {'score': 0, 'attempts': 0};
      }
      await topicRef.set({'subtopics': subtopicData, 'status': 'in_progress'});
    }
  }

  Future<String?> getNextSubtopic(String userId, String topicId) async {
    final topicRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('topics')
        .doc(topicId);
    final docSnapshot = await topicRef.get();

    if (!docSnapshot.exists) return null;
    final subtopics = docSnapshot.data()?['subtopics'] as Map<String, dynamic>;

    String? weakestSubtopic;
    int lowestScore = 101; // Assuming scores range 0-100

    subtopics.forEach((subtopic, data) {
      if (data['score'] < lowestScore) {
        lowestScore = data['score'];
        weakestSubtopic = subtopic;
      }
    });

    return weakestSubtopic;
  }

  Future<void> updateSubtopicScore(
      String userId, String topicId, String subtopic, int score) async {
    final topicRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('topics')
        .doc(topicId);
    final docSnapshot = await topicRef.get();

    if (!docSnapshot.exists) return;

    Map<String, dynamic> subtopics = docSnapshot.data()?['subtopics'];
    subtopics[subtopic]['score'] = score;
    subtopics[subtopic]['attempts'] += 1;

    await topicRef.update({'subtopics': subtopics});
  }

  Future<void> resetTopic(String userId, String topicId) async {
    final topicRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('topics')
        .doc(topicId);
    final docSnapshot = await topicRef.get();

    if (!docSnapshot.exists) return;

    Map<String, dynamic> subtopics = docSnapshot.data()?['subtopics'];
    subtopics.forEach((key, value) {
      value['score'] = 0;
      value['attempts'] = 0;
    });

    await topicRef.update({'subtopics': subtopics, 'status': 'redo'});
  }
}
