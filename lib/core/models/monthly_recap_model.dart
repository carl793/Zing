import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyRecapModel {
  final String recapId; // format "yyyy-MM"
  final String aiSummary;
  final int daysTogether;
  final List<String> topActivities;
  final DateTime generatedAt;

  MonthlyRecapModel({
    required this.recapId,
    required this.aiSummary,
    required this.daysTogether,
    required this.topActivities,
    required this.generatedAt,
  });

  factory MonthlyRecapModel.fromMap(String id, Map<String, dynamic> data) => MonthlyRecapModel(
        recapId: id,
        aiSummary: data['aiSummary'] ?? '',
        daysTogether: data['daysTogether'] ?? 0,
        topActivities: List<String>.from(data['topActivities'] ?? []),
        generatedAt: (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}