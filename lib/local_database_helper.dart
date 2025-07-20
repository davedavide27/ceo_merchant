import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

//local_database_helper.dart
class LocalDatabaseHelper {
  static final LocalDatabaseHelper _instance = LocalDatabaseHelper._internal();
  factory LocalDatabaseHelper() => _instance;

  static Database? _database;
  static const int _databaseVersion = 1; // Updated version

  LocalDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_data.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        user_id TEXT PRIMARY KEY,
        business_name TEXT,
        email TEXT
      )
    ''');
  }

  Future<void> saveUser(
    String userId,
    String businessName,
    String email,
  ) async {
    final db = await database;
    try {
      await db.insert('users', {
        'user_id': userId,
        'business_name': businessName,
        'email': email,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      log('User saved successfully.');
    } catch (e) {
      log('Error saving user: $e');
    }
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> users = await db.query('users');
      if (users.isNotEmpty) {
        log('User retrieved: ${users.first}');
        return users.first;
      }
    } catch (e) {
      log('Error retrieving user: $e');
    }
    return null;
  }

  Future<void> clearUser() async {
    final db = await database;
    try {
      await db.delete('users');
      log('User cleared successfully.');
    } catch (e) {
      log('Error clearing user: $e');
    }
  }

  // Add this to your local_database_helper.dart
  Future<void> clearUserSession() async {
    await clearUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
  }

  // New methods to set and get login flag
  Future<void> setLoginFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
  }

  Future<bool> getLoginFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}
