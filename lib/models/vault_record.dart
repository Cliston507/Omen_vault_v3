import 'dart:convert';

class VaultRecord {
  final String? id;
  final String? firestoreId;
  final String encryptedData;
  final DateTime timestamp;

  VaultRecord({
    this.id,
    this.firestoreId,
    required this.encryptedData,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'encryptedData': encryptedData,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory VaultRecord.fromMap(Map<String, dynamic> map) {
    return VaultRecord(
      id: map['id'],
      firestoreId: map['firestoreId'],
      encryptedData: map['encryptedData'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
