import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  Future<void> set(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(value);
    await prefs.setString(key, json);
  }

  Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(key);
    if (json == null) return null;
    return jsonDecode(json);
  }

  Future<T?> getTyped<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    final data = await get(key);
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      return fromJson(data);
    }
    return null;
  }

  Future<List<T>> getList<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    final data = await get(key);
    if (data == null) return [];
    if (data is List) {
      return data.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }
}