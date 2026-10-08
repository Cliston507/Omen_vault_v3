
/// A single vault entry: the unit of content a user stores in Omen Vault.
class VaultEntry {
  final String id;
  String title;
  String body;
  final String ownerId;
  final DateTime updatedAt;

  VaultEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'ownerId': ownerId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultEntry.fromMap(Map<String, dynamic> map) => VaultEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        ownerId: map['ownerId'] as String,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  /// Payload sent to the remote store; the queue stamps ownership on dispatch.
  Map<String, dynamic> toRemoteData() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
