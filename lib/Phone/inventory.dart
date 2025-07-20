import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      ),
      drawer: Sidebar(initialSelectedIndex: 6),
      body: isLoading
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
                              _buildInventoryItem(inventoryItems[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final isOverLimit =
        (item['price_limit'] ?? 0) > 0 &&
        (item['average_price'] ?? 0) > (item['price_limit'] ?? 0);

    return InkWell(
      onTap: () => _showPurchaseDetails(item),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Ingredient name with alert indicator
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isOverLimit)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.warning_amber,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Quantity display
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item['total_quantity'] ?? 0}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                ),
              ),

              // Average price display
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '₱${item['average_price']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}

// Helper method to safely parse double values
double _parseDouble(dynamic value) {
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  } else if (value is num) {
    return value.toDouble();
  }
  return 0.0;
}

// Helper method to safely parse int values
int _parseInt(dynamic value) {
  if (value is String) {
    return int.tryParse(value) ?? 0;
  } else if (value is num) {
    return value.toInt();
  }
  return 0;
}
