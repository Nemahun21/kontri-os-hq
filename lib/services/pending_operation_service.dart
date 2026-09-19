import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PendingOperationService {
  static final _instance = PendingOperationService._();
  factory PendingOperationService() => _instance;
  PendingOperationService._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = await getDatabasesPath();
    _db = await openDatabase(
      join(path, 'pending_operations.db'),
      version: 2,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            operation TEXT NOT NULL,
            data TEXT NOT NULL,
            media TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE pending_operations ADD COLUMN media TEXT');
        }
      },
    );
    return _db!;
  }

  Future<void> enqueue(
    String tableName,
    String operation,
    Map<String, dynamic> data, {
    Map<String, String>? media,
  }) async {
    final d = await db;
    await d.insert('pending_operations', {
      'table_name': tableName,
      'operation': operation,
      'data': jsonEncode(data),
      'media': media != null ? jsonEncode(media) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final d = await db;
    return await d.query('pending_operations', orderBy: 'created_at ASC');
  }

  Future<void> deleteOperation(int id) async {
    final d = await db;
    await d.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countPending() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) as count FROM pending_operations');
    return result.first['count'] as int;
  }

  Future<Set<String>> getPendingIdsForTable(String tableName) async {
    final ops = await getPendingOperations();
    return ops
        .where((op) => op['table_name'] == tableName)
        .map((op) {
          final data = jsonDecode(op['data']) as Map<String, dynamic>;
          return data['id'] as String?;
        })
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
  }
}