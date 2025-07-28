import 'dart:convert';
import 'package:ceo_merchant/notifications/notif_modal.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar.dart';
import '../local_database_helper.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late WebSocketChannel _channel;
  List<Map<String, dynamic>> inventoryItems = [];
  bool isLoading = true;
  String? _userId;
  String? _businessName;
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper();

  // Notifications state
  List<Map<String, dynamic>> _notifications = [];
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  bool _showNotificationModal = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationsFromPrefs();
  }

  void _loadUserData() async {
    print("[Inventory] Loading user data");
    final user = await _dbHelper.getUser();
    if (user != null) {
      setState(() {
        _userId = user['user_id'];
        _businessName = user['business_name'];
      });
      print(
        "[Inventory] User data loaded: userId=$_userId, businessName=$_businessName",
      );
      _connectWebSocket();
    } else {
      print("[Inventory] ERROR: No user data found");
      setState(() => isLoading = false);
    }
  }

  Widget _buildInventoryListItem(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Expanded(
            flex: 3,
            child: Text(
              item['name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${item['total_quantity'] ?? 0}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '₱${(item['average_price'] ?? 0).toDouble().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotificationsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notifications');
    if (notificationsJson != null) {
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      setState(() {
        _notifications = decoded
            .map((e) => {
                  'title': e['title'],
                  'message': e['message'],
                  'time': DateTime.parse(e['time']),
                  'read': e['read'],
                })
            .toList()
            .cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _saveNotificationsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_notifications
        .map((e) => {
              'title': e['title'],
              'message': e['message'],
              'time': (e['time'] as DateTime).toIso8601String(),
              'read': e['read'],
            })
        .toList());
    await prefs.setString('notifications', encoded);
  }

  void _handleNotification(Map<String, dynamic> notification) {
    print('[Inventory] Handling notification: $notification');
    final newNotification = {
      'title': notification['title'] ?? 'Notification',
      'message': notification['message'] ?? '',
      'time':
          DateTime.tryParse(notification['timestamp'] ?? '') ?? DateTime.now(),
      'read': false,
    };
    setState(() {
      _notifications.insert(0, newNotification);
      _animatedListKey.currentState?.insertItem(0);
    });
    _saveNotificationsToPrefs();
  }

  void _connectWebSocket() {
    if (_userId == null || _businessName == null) {
      print("[Inventory] ERROR: Missing user ID or business name");
      setState(() => isLoading = false);
      return;
    }

    final websocketUrl =
        dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:3000/ws';
    print("[Inventory] Connecting to WebSocket: $websocketUrl");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

      _channel.stream.listen(
        _handleWebSocketMessage,
        onError: (error) => print("[Inventory] WebSocket error: $error"),
        onDone: () => print("[Inventory] WebSocket connection closed"),
      );

      _fetchInventory();
    } catch (e) {
      print("[Inventory] ERROR connecting to WebSocket: $e");
      setState(() => isLoading = false);
    }
  }

  void _fetchInventory() {
    print("[Inventory] Fetching inventory data");
    final message = {
      'type': 'get_inventory',
      'user_id': _userId!,
      'business_name': _businessName!,
    };
    _channel.sink.add(jsonEncode(message));
  }

  void _handleWebSocketMessage(dynamic message) {
    print("[Inventory] Received WebSocket message");
    try {
      final response = jsonDecode(message);
      print(
        '[Inventory] Message type: ${response['type']}, success: ${response['success']}',
      );

      if (response['type'] == 'inventory_data' && response['success'] == true) {
        _handleInventoryData(response);
      } else if (response['type'] == 'notification') {
        _handleNotification(response);
      } else if (response['type'] == 'error') {
        print('[Inventory] Server error: ${response['message']}');
        setState(() => isLoading = false);
      } else {
        print('[Inventory] Unhandled message type: ${response['type']}');
      }
    } catch (e) {
      print('[Inventory] ERROR parsing message: $e');
      print('[Inventory] Original message: $message');
      setState(() => isLoading = false);
    }
  }

  void _handleInventoryData(Map<String, dynamic> response) {
    print("[Inventory] Handling inventory data");
    try {
      final parsedItems = List<Map<String, dynamic>>.from(
        response['data'],
      ).map((item) => _parseInventoryItem(item)).toList();

      // Deduplicate items by 'id'
      final deduplicatedItems = <String, Map<String, dynamic>>{};
      for (var item in parsedItems) {
        deduplicatedItems[item['id']] = item;
      }

      setState(() {
        inventoryItems = deduplicatedItems.values.toList();
        isLoading = false;
      });
      print("[Inventory] Loaded ${inventoryItems.length} inventory items");
    } catch (e) {
      print('[Inventory] ERROR processing inventory data: $e');
      setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _parseInventoryItem(Map<String, dynamic> item) {
    List<dynamic> purchases = [];

    // Parse purchases data
    if (item['purchases'] is String && item['purchases']!.isNotEmpty) {
      try {
        purchases = jsonDecode(item['purchases']);
      } catch (e) {
        print('[Inventory] ERROR parsing purchases string: $e');
      }
    } else if (item['purchases'] is List) {
      purchases = item['purchases'];
    }

    // Calculate totals
    int totalQuantity = 0;
    double totalCost = 0.0;

    for (var purchase in purchases) {
      double price = purchase['price'] is String
          ? double.tryParse(purchase['price']) ?? 0.0
          : purchase['price']?.toDouble() ?? 0.0;

      int quantity = purchase['quantity'] is String
          ? int.tryParse(purchase['quantity']) ?? 0
          : purchase['quantity'] ?? 0;

      totalQuantity += quantity;
      totalCost += price * quantity;
    }

    double averagePrice = totalQuantity > 0 ? totalCost / totalQuantity : 0.0;

    // Parse price limit
    double priceLimit = 0.0;
    if (item['price_limit'] is String) {
      priceLimit = double.tryParse(item['price_limit']) ?? 0.0;
    } else if (item['price_limit'] is num) {
      priceLimit = item['price_limit'].toDouble();
    }

    return {
      'id': item['id']?.toString() ?? '',
      'name': item['name']?.toString() ?? 'Unknown',
      'purchases': purchases,
      'total_quantity': totalQuantity,
      'average_price': averagePrice,
      'price_limit': priceLimit,
    };
  }

  // Display-only details dialog with X button at top
  void _showPurchaseDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['name'] ?? 'Ingredient Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Stats row
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Container(
                      width: 120,
                      child: _buildStatCard(
                        'Total Stock',
                        '${item['total_quantity'] ?? 0}',
                        Icons.inventory,
                      ),
                    ),
                    Container(
                      width: 120,
                      child: _buildStatCard(
                        'Avg Price',
                        '₱${(item['average_price'] ?? 0).toDouble().toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),
                    ),
                    if (double.tryParse(
                          item['price_limit']?.toString() ?? '0',
                        )! >
                        0)
                      Container(
                        width: 120,
                        child: _buildStatCard(
                          'Price Limit',
                          '₱${double.tryParse(item['price_limit']?.toString() ?? '0')!.toStringAsFixed(2)}',
                          Icons.warning,
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 24),

                // Purchases header
                Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Divider(thickness: 1),

                // Purchase list
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: (item['purchases'] as List).isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 40,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 10),
                              Text('No purchases recorded'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: (item['purchases'] as List).length,
                          itemBuilder: (context, index) {
                            final purchase = (item['purchases'] as List)[index];
                            return _buildPurchaseListItem(purchase);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseListItem(Map<String, dynamic> purchase) {
    double purchasePrice = 0.0;
    if (purchase['price'] is String) {
      purchasePrice = double.tryParse(purchase['price']) ?? 0.0;
    } else if (purchase['price'] is num) {
      purchasePrice = purchase['price'].toDouble();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepOrange[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shopping_bag, color: Colors.deepOrange, size: 20),
        ),
        title: Text(
          purchase['supplier']?.toString() ?? 'Unknown Supplier',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Quantity: ${purchase['quantity'] ?? 0}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        trailing: Text(
          '₱${purchasePrice.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrangeAccent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Inventory',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications, color: Colors.white),
                if (_notifications.any((n) => !n['read']))
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${_notifications.where((n) => !n['read']).length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              setState(() {
                _showNotificationModal = true;
              });
            },
          ),
        ],
      ),
      drawer: Sidebar(initialSelectedIndex: 6),
      body: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange),
                )
              : Column(
                  children: [
                    // Enhanced header
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'INGREDIENT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'QUANTITY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'AVG PRICE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Inventory list
                    Expanded(
                      child: inventoryItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 80,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'No Ingredients Found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Inventory items will appear once added in the system',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: inventoryItems.length,
                              itemBuilder: (context, index) =>
                                  _buildInventoryListItem(inventoryItems[index]),
                            ),
                    ),
                  ],
                ),
          if (_showNotificationModal)
            NotificationModal(
              notifications: _notifications,
              animatedListKey: _animatedListKey,
              onClose: () {
                setState(() {
                  _showNotificationModal = false;
                });
              },
              onMarkAsRead: (index) {
                setState(() {
                  _notifications[index]['read'] = true;
                });
              },
              onMarkAllAsRead: () {
                setState(() {
                  for (var n in _notifications) {
                    n['read'] = true;
                  }
                });
              },
              onClearReadNotifications: () async {
                setState(() {
                  _notifications.removeWhere((n) => n['read']);
                });
              },
              onDeleteIndices: (indices) {
                setState(() {
                  indices.sort((a, b) => b.compareTo(a));
                  for (var idx in indices) {
                    _notifications.removeAt(idx);
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}
