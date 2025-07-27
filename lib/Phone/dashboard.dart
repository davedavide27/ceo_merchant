import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sidebar.dart';
import '../notifications/notif_modal.dart';
import '../notifications/user_modal.dart';
import '../local_database_helper.dart';
import '../login.dart';

class DashboardScreen extends StatefulWidget {
  final int? userId;

  const DashboardScreen({super.key, this.userId});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showNotifications = false;
  bool _showUserModal = false; // Add this
  late GlobalKey<AnimatedListState> _animatedListKey; // Add this
  late List<Map<String, dynamic>> _notifications;
  late GlobalKey<NotificationModalState> _notificationModalKey;
  bool _isFabVisible = true;
  Map<String, dynamic> _userData = {
    'businessName': 'Loading...',
    'email': 'loading@example.com',
  };

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    _animatedListKey = GlobalKey<AnimatedListState>(); // Initialize
    _notificationModalKey = GlobalKey<NotificationModalState>();
    super.initState();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          // iOS and other platform settings can be added here if needed
        );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        setState(() {
          _showNotifications = true;
          _isFabVisible = false;
        });
      },
      onDidReceiveBackgroundNotificationResponse: null,
    );

    _requestPermissions();

    _notifications = [];
    _loadNotifications();
    _loadUserData();
    timeago.setLocaleMessages('en', timeago.EnMessages());
  }

  void _requestPermissions() async {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // For Android 13+ (API 33+), request notification permission explicitly using permission_handler
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // Add this function to load user data
  Future<void> _loadUserData() async {
    final user = await LocalDatabaseHelper().getUser();
    if (user != null && mounted) {
      setState(() {
        _userData = {
          'businessName': user['business_name'] ?? 'My Business',
          'email': user['email'] ?? 'user@example.com',
        };
      });
    }
  }

  // In dashboard.dart
  // Update the logout function
  Future<void> _logout() async {
    // Clear user session
    await LocalDatabaseHelper().clearUserSession();

    // Navigate to login screen using root navigator
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Login(
          updateUserData: (newUserData) {}, // Dummy callback
          savedEmail: '', // Empty email
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString('notifications');

    if (notificationsJson != null) {
      final List<dynamic> decoded = json.decode(notificationsJson);
      if (mounted) {
        setState(() {
          _notifications = decoded.map<Map<String, dynamic>>((item) {
            return {
              'title': item['title'],
              'message': item['message'],
              'time': DateTime.parse(item['time']),
              'read': item['read'],
            };
          }).toList();
        });
      }
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = json.encode(
      _notifications.map((n) {
        return {
          'title': n['title'],
          'message': n['message'],
          'time': n['time'].toIso8601String(),
          'read': n['read'],
        };
      }).toList(),
    );
    prefs.setString('notifications', notificationsJson);
  }

  int _notificationIdCounter = 0;

  void _addRandomNotification() async {
    final random = Random();
    final titles = [
      'New Order',
      'Payment Received',
      'Low Stock Alert',
      'Special Offer',
      'System Update',
    ];
    final messages = [
      'Table ${random.nextInt(20)} placed a new order',
      'Order #${random.nextInt(2000)} payment received',
      '${['Chicken', 'Beef', 'Pork', 'Rice', 'Coke'][random.nextInt(5)]} is running low',
      'Weekend special: ${random.nextInt(30)}% off on all drinks!',
      'New version of the app is available',
    ];

    final title = titles[random.nextInt(titles.length)];
    final message = messages[random.nextInt(messages.length)];

    setState(() {
      _notifications.insert(0, {
        'title': title,
        'message': message,
        'time': DateTime.now(),
        'read': false,
      });
    });
    _saveNotifications();

    // Show device notification using flutter_local_notifications
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'ceo_merchant_channel',
          'Ceo Merchant Notifications',
          channelDescription: 'Notification channel for Ceo Merchant app',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      _notificationIdCounter++,
      title,
      message,
      platformChannelSpecifics,
      payload: jsonEncode({'title': title, 'message': message}),
    );
  }

  Future<void> _clearReadNotifications() async {
    final readIndices = <int>[];
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i]['read']) {
        readIndices.add(i);
      }
    }

    readIndices.sort((a, b) => b.compareTo(a));

    for (final index in readIndices) {
      final removedItem = _notifications.removeAt(index);
      _animatedListKey.currentState?.removeItem(
        index,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          child: _buildRemovedItem(removedItem),
        ),
        duration: const Duration(milliseconds: 300),
      );
    }

    await _saveNotifications();

    // Trigger modal close animation after clearing items
    if (readIndices.isNotEmpty && _showNotifications) {
      await NotificationModal.close(context);
    }
  }

  Widget _buildRemovedItem(Map<String, dynamic> notification) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications, color: Colors.grey),
      ),
      title: Text(notification['title'], style: TextStyle(color: Colors.grey)),
      subtitle: Text(notification['message']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Sidebar(userId: widget.userId),
      backgroundColor: Colors.grey[100],
      floatingActionButton: _isFabVisible
          ? FloatingActionButton(
              onPressed: _addRandomNotification,
              backgroundColor: Colors.teal,
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: Icon(Icons.menu, color: Colors.teal, size: 28),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info, color: Colors.teal, size: 20),
                      ),
                      Spacer(),
                      // Notification icon with badge
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: Colors.teal,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNotifications = !_showNotifications;
                                _isFabVisible = !_showNotifications;
                              });
                            },
                          ),
                          if (_notifications.any((n) => !n['read']))
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${_notifications.where((n) => !n['read']).length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showUserModal = true;
                              _isFabVisible = false;
                            });
                          },
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.teal,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Last synced info
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Text(
                    'Last synced at ${DateTime.now().toString().split('.')[0]}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),

                // Dashboard Cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        // First Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Net Sales',
                                value: '₱0.00',
                                icon: Icons.bar_chart,
                                color: Color(0xFFFF8A80), // Light red/coral
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Discounts',
                                value: '₱0.00',
                                icon: Icons.percent,
                                color: Color(0xFF80CBC4), // Light teal
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Second Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'No. of Transactions',
                                value: '0',
                                icon: Icons.receipt_long,
                                color: Color(0xFFA5D6A7), // Light green
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Cost of Goods',
                                value: '0',
                                icon: Icons.local_offer,
                                color: Color(0xFFFFCC80), // Light orange
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Third Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'No. of Items',
                                value: '0',
                                icon: Icons.inventory_2,
                                color: Color(0xFF80CBC4), // Light teal
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Profit',
                                value: '₱0.00',
                                icon: Icons.account_balance_wallet,
                                color: Color(0xFFFF8A80), // Light red/coral
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Fourth Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Refunds',
                                value: '₱0.00',
                                icon: Icons.keyboard_return,
                                color: Color(0xFFFFCC80), // Light orange
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Online Orders',
                                value: '₱0.00',
                                icon: Icons.shopping_bag,
                                color: Color(0xFFA5D6A7), // Light green
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Fifth Row (Single card)
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'No. of Online Orders',
                                value: '0',
                                icon: Icons.shopping_cart,
                                color: Color(0xFFFF8A80), // Light red/coral
                                height: 120,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Greeting
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Good morning, Bba!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[300],
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Date Filter
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Jul 12, 12:00am – Jul 12, 11:59pm',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: Colors.grey[700],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Payment Types Section
                        _buildSectionTitle(
                          'Payment Types',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildNoDataRow(Icons.credit_card, 'No Data', '₱0.00'),

                        SizedBox(height: 24),

                        // Sales by Date Section
                        _buildSectionTitle(
                          'Sales by Date',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildSalesByDate(),

                        SizedBox(height: 24),

                        // Sales by Category Section
                        _buildSectionTitle(
                          'Sales by Category',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildNoDataRow(Icons.category, 'No Data'),

                        SizedBox(height: 24),

                        // Sales by Item Section
                        _buildSectionTitle(
                          'Sales by Item',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildNoDataRow(Icons.list, 'No Data'),

                        SizedBox(height: 24),

                        // Sales by Cashier Section
                        _buildSectionTitle(
                          'Sales by Cashier',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildNoDataRow(Icons.person, 'No Data'),

                        SizedBox(height: 24),

                        // Sales by Payment Section
                        _buildSectionTitle(
                          'Sales by Payment',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildNoDataRow(Icons.payment, 'No Data'),

                        SizedBox(height: 24),

                        // List of Items Section
                        _buildSectionTitle(
                          'List of Items',
                          'Jul 12, 12:00am – Jul 12, 11:59pm',
                        ),
                        _buildEmptyItemList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Notification panel
            // In the build method where NotificationModal is used:
            if (_showNotifications)
              NotificationModal(
                key: _notificationModalKey,
                notifications: _notifications,
                animatedListKey: _animatedListKey,
                onDeleteIndices: (List<int> indices) {
                  // delete the items from your list
                  indices.sort((a, b) => b.compareTo(a)); // descending
                  for (final i in indices) {
                    _notifications.removeAt(i);
                  }
                  setState(() {});
                  _saveNotifications();
                },
                onClose: () {
                  setState(() {
                    _showNotifications = false;
                    _isFabVisible = true;
                  });
                },
                onMarkAsRead: (index) {
                  setState(() {
                    _notifications[index]['read'] = true;
                  });
                  _saveNotifications();
                },
                onMarkAllAsRead: () {
                  setState(() {
                    for (var n in _notifications) {
                      n['read'] = true;
                    }
                  });
                  _saveNotifications();
                },
                onClearReadNotifications: () async {
                  // Clear read notifications first
                  await _clearReadNotifications();

                  // Then close the modal with animation
                  if (mounted) {
                    setState(() {
                      _showNotifications = false;
                      _isFabVisible = true;
                    });
                  }
                },
              ),
            // User modal
            // User modal - now covers entire screen
            if (_showUserModal)
              Positioned.fill(
                child: UserModal(
                  businessName: _userData['businessName'],
                  email: _userData['email'],
                  onLogout: _logout,
                  onClose: () {
                    setState(() {
                      _showUserModal = false;
                      _isFabVisible = true;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double height = 120,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background circles for design
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.teal[300],
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildNoDataRow(IconData icon, String label, [String? value]) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400]),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
          ),
          if (value != null)
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesByDate() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hourly',
                style: TextStyle(
                  color: Colors.teal[300],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Daily',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              SizedBox(width: 16),
              Text(
                'Monthly',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            height: 120,
            alignment: Alignment.center,
            child: Text(
              'No Data',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemList() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Table(
            columnWidths: {0: FlexColumnWidth(3)},
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Item',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No Data',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<int>(
                value: 10,
                items: [10, 20, 50]
                    .map(
                      (e) => DropdownMenuItem<int>(value: e, child: Text('$e')),
                    )
                    .toList(),
                onChanged: (value) {},
              ),
              Text('0-0 of 0'),
              IconButton(icon: Icon(Icons.chevron_left), onPressed: () {}),
              IconButton(icon: Icon(Icons.chevron_right), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
