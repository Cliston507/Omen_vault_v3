
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../helpers/db_helper.dart';

// Represents a single mutation operation to be queued.
class Mutation {
  final int? id;
  final String model;
  final Map<String, dynamic> data;
  final String action;
  final DateTime timestamp;

  Mutation({
    this.id,
    required this.model,
    required this.data,
    required this.action,
    required this.timestamp,
  });

  // Factory constructor to create a Mutation from a map (database row).
  factory Mutation.fromMap(Map<String, dynamic> map) {
    return Mutation(
      id: map['id'],
      model: map['model'],
      data: jsonDecode(map['data']) as Map<String, dynamic>,
      action: map['action'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Method to convert a Mutation object to a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'model': model,
      'data': jsonEncode(data),
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class MutationQueueService {
  late DBHelper _dbHelper;

  MutationQueueService() {
    _dbHelper = DBHelper();
  }

  MutationQueueService.test(DBHelper dbHelper) {
    _dbHelper = dbHelper;
  }

  // Enqueues a new mutation operation into the offline queue.
  Future<void> enqueue(Mutation mutation) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'mutation_queue',
        mutation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // In a real app, you would want to log this error.
      debugPrint('Error enqueuing mutation: $e');
    }
  }

  // Fetches all un-synced mutation operations from the queue, ordered by timestamp.
  Future<List<Mutation>> getUnsyncedMutations() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'mutation_queue',
        orderBy: 'timestamp ASC',
      );
      return List.generate(maps.length, (i) {
        return Mutation.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('Error fetching unsynced mutations: $e');
      return [];
    }
  }

  // Deletes a synced transaction from the queue by its ID.
  Future<void> deleteMutation(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'mutation_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting mutation: $e');
    }
  }
}
