import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PendingQuestionService {
  static final PendingQuestionService _instance = PendingQuestionService._();
  static PendingQuestionService get instance => _instance;
  PendingQuestionService._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = await getDatabasesPath();
    _db = await openDatabase(
      join(path, 'pending.db'),
      onCreate: (db, version) => db.execute(
        'CREATE TABLE pending (id INTEGER PRIMARY KEY, category TEXT, data TEXT, created INTEGER)'
      ),
      version: 1,
    );
    return _db!;
  }

  Future<void> save(String category, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('pending', {
      'category': category,
      'data': jsonEncode(data),
      'created': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final d = await db;
    return await d.query('pending');
  }

  Future<void> delete(int id) async {
    final d = await db;
    await d.delete('pending', where: 'id = ?', whereArgs: [id]);
  }
}