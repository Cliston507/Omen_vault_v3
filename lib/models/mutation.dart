import 'dart:convert';

class Mutation {
  final int id;
  final String type;
  final Map<String, dynamic> data;

  Mutation({required this.id, required this.type, required this.data});

  factory Mutation.fromJson(Map<String, dynamic> json) {
    return Mutation(
      id: json['id'],
      type: json['type'],
      data: jsonDecode(json['data']),
    );
  }

  String get sql {
    switch (type) {
      case 'add':
        return 'INSERT INTO vault_entries (id, name, username, password, url, notes, folder_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
      case 'update':
        return 'UPDATE vault_entries SET name = ?, username = ?, password = ?, url = ?, notes = ?, folder_id = ?, updated_at = ? WHERE id = ?';
      case 'delete':
        return 'DELETE FROM vault_entries WHERE id = ?';
      default:
        throw Exception('Unknown mutation type: $type');
    }
  }

  List<dynamic> get params {
    switch (type) {
      case 'add':
        return [
          data['id'],
          data['name'],
          data['username'],
          data['password'],
          data['url'],
          data['notes'],
          data['folder_id'],
          data['created_at'],
          data['updated_at'],
        ];
      case 'update':
        return [
          data['name'],
          data['username'],
          data['password'],
          data['url'],
          data['notes'],
          data['folder_id'],
          data['updated_at'],
          data['id'],
        ];
      case 'delete':
        return [data['id']];
      default:
        throw Exception('Unknown mutation type: $type');
    }
  }
}
