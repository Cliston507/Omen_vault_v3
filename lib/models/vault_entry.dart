class VaultEntry {
  final int? id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;

  VaultEntry({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
    };
  }

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    return VaultEntry(
      id: map['id'],
      title: map['title'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
