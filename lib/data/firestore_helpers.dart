import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef Json = Map<String, dynamic>;

/// How long a write may wait for the server before it counts as queued.
const _queueAfter = Duration(seconds: 6);

/// Awaits a plain write without hanging while offline.
///
/// Firestore stores writes on the phone and sends them when it can, but the
/// returned future only completes once the server answers: awaited directly, a
/// save would spin forever with no signal. After a few seconds the write is
/// left to sync in the background. Rejections (e.g. by the rules) still throw.
Future<void> settleWrite(Future<void> write) =>
    write.timeout(_queueAfter, onTimeout: () {});

/// Transactions need the server, so give up instead of waiting forever.
Future<T> onlineOnly<T>(Future<T> work) =>
    work.timeout(const Duration(seconds: 15));

/// Parses a query, skipping (and logging) documents that don't parse, so one
/// malformed document can't take a whole screen down.
List<T> parseDocs<T>(
  QuerySnapshot<Json> snap,
  T Function(String id, Json data) parse,
) {
  final items = <T>[];
  for (final doc in snap.docs) {
    try {
      items.add(parse(doc.id, doc.data()));
    } catch (e) {
      debugPrint('Skipped malformed ${doc.reference.path}: $e');
    }
  }
  return items;
}
