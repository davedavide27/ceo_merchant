import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'login.dart';
import 'local_database_helper.dart';
import 'Phone/dashboard.dart' as dashboard;

Future<void> loadEnv() async {
  await dotenv.load();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
  await loadEnv();

  // Comment out background service initialization to test if it causes build hang
  // bool hasPermissions = await AndroidBackgroundService.initialize();
  // if (hasPermissions) {
  //   await AndroidBackgroundService.enableBackgroundExecution();
  // }

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

  Timer? _inactivityTimer;
  static const inactivityDuration = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserDataAndLoginFlag();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityDuration, _handleLogout);
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  Future<void> _handleLogout() async {
    await _dbHelper.setLoginFlag(false);
    setState(() {
      _isLoggedIn = false;
      _userData = null;
    });
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
    _resetInactivityTimer();
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: MaterialApp(
        title: 'Ceo Merchant App',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: (userId > 0 && _isLoggedIn)
            ? dashboard.DashboardScreen(userId: userId)
            : Login(updateUserData: _updateUserData, savedEmail: email),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is closing, logout immediately
      _handleLogout();
    }
  }
}
