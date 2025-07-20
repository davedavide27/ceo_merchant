import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'local_database_helper.dart';
import 'Phone/dashboard.dart' as dashboard;

Future<void> loadEnv() async {
  await dotenv.load();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnv();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Map<String, dynamic>? _userData;
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserDataAndLoginFlag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadUserDataAndLoginFlag() async {
    final user = await _dbHelper.getUser();
    final isLoggedIn = await _dbHelper.getLoginFlag();
    setState(() {
      _userData = user;
      _isLoading = false;
      _isLoggedIn = isLoggedIn;
    });
  }

  bool _isLoggedIn = false;

  void _updateUserData(Map<String, dynamic> newUserData) async {
    // Update local DB
    await _dbHelper.clearUser();
    await _dbHelper.saveUser(
      newUserData['user_id'].toString(),
      newUserData['business_name'],
      newUserData['email'],
    );
    // Set login flag true on login
    await _dbHelper.setLoginFlag(true);
    
    // Update app state
    setState(() {
      _userData = newUserData;
      _isLoggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final userId = _userData != null
        ? int.tryParse(_userData!['user_id'].toString()) ?? 0
        : 0;
    final email = _userData?['email'] ?? '';
    final businessName = _userData?['business_name'] ?? '';

    return MaterialApp(
      title: 'Ceo Merchant App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: (userId > 0 && _isLoggedIn)
          ? dashboard.DashboardScreen(userId: userId)
          : Login(
              updateUserData: _updateUserData,
              savedEmail: email,
            ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      // App is closing or going to background, set login flag to false (force logout)
      _dbHelper.setLoginFlag(false);
      setState(() {
        _isLoggedIn = false;
      });
    }
  }
}
