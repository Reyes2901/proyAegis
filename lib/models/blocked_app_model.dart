import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedApp {
  const BlockedApp({
    required this.packageName,
    required this.blocked,
    this.blockedAt,
    this.source,
  });

  factory BlockedApp.fromJson(Map<String, dynamic> data) {
    final blockedAt = data['blockedAt'];
    return BlockedApp(
      packageName: data['packageName'] as String? ?? '',
      blocked: data['blocked'] as bool? ?? false,
      blockedAt: blockedAt is Timestamp ? blockedAt.toDate() : null,
      source: data['source'] as String?,
    );
  }

  final String packageName;
  final bool blocked;
  final DateTime? blockedAt;
  final String? source;
}
