import 'package:cloud_firestore/cloud_firestore.dart';

enum MemoryEntryType { memory, plan }

class LocationPin {
  final String name;
  final double lat;
  final double lng;
  LocationPin({required this.name, required this.lat, required this.lng});

  factory LocationPin.fromMap(Map<String, dynamic>? data) =>
      LocationPin(name: data?['name'] ?? '', lat: (data?['lat'] ?? 0).toDouble(), lng: (data?['lng'] ?? 0).toDouble());

  Map<String, dynamic> toMap() => {'name': name, 'lat': lat, 'lng': lng};
}

class MemoryModel {
  final String memoryId;
  final String authorUid;
  final DateTime date;
  final MemoryEntryType entryType;
  final String title;
  final String story;
  final String tagCategory;
  final LocationPin? locationPin;
  final List<String> photoUrls;
  final String? voiceNoteUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MemoryModel({
    required this.memoryId,
    required this.authorUid,
    required this.date,
    this.entryType = MemoryEntryType.memory,
    required this.title,
    this.story = '',
    this.tagCategory = '',
    this.locationPin,
    this.photoUrls = const [],
    this.voiceNoteUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory MemoryModel.fromMap(String id, Map<String, dynamic> data) => MemoryModel(
        memoryId: id,
        authorUid: data['authorUid'] ?? '',
        date: (data['date'] as Timestamp).toDate(),
        entryType: MemoryEntryType.values.firstWhere(
          (t) => t.name == (data['entryType'] ?? 'memory'),
          orElse: () => MemoryEntryType.memory,
        ),
        title: data['title'] ?? '',
        story: data['story'] ?? '',
        tagCategory: data['tagCategory'] ?? '',
        locationPin: data['locationPin'] != null ? LocationPin.fromMap(data['locationPin']) : null,
        photoUrls: List<String>.from(data['photoUrls'] ?? []),
        voiceNoteUrl: data['voiceNoteUrl'],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'date': Timestamp.fromDate(date),
        'entryType': entryType.name,
        'title': title,
        'story': story,
        'tagCategory': tagCategory,
        if (locationPin != null) 'locationPin': locationPin!.toMap(),
        'photoUrls': photoUrls,
        'voiceNoteUrl': voiceNoteUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}