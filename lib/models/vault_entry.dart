class VaultEntry {
  final int? id;
  final String? firestoreId;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;

  VaultEntry({
    this.id,
    this.firestoreId,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
    };
  }

  Map<String, dynamic> toJson() {
    final map = toMap();
    map.remove('id');
    map.remove('firestoreId');
    return map;
  }

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    return VaultEntry(
      id: map['id'],
      firestoreId: map['firestoreId'],
      title: map['title'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
