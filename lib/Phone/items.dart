import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sidebar.dart';
import '../local_database_helper.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  _ItemsScreenState createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late WebSocketChannel _channel;
  List<Category> categories = [];
  String? _businessName;
  int? _userId;
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper();
  bool isLoading = true;

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    print("[Items] Loading user data");
    final user = await _dbHelper.getUser();
    if (user != null) {
      setState(() {
        _userId = int.tryParse(user['user_id'] ?? '');
        _businessName = user['business_name'];
      });
      print(
        "[Items] User data loaded: userId=$_userId, businessName=$_businessName",
      );
      _connectWebSocket();
    } else {
      print("[Items] ERROR: No user data found");
      setState(() => isLoading = false);
    }
  }

  void _connectWebSocket() {
    if (_userId == null || _businessName == null) {
      print("[Items] ERROR: Missing user ID or business name");
      setState(() => isLoading = false);
      return;
    }

    final websocketUrl =
        dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:3000/ws';
    print("[Items] Connecting to WebSocket: $websocketUrl");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

      _channel.stream.listen(
        _handleWebSocketMessage,
        onError: (error) => print("[Items] WebSocket error: $error"),
        onDone: () => print("[Items] WebSocket connection closed"),
      );

      _fetchCategoriesAndItems();
    } catch (e) {
      print("[Items] ERROR connecting to WebSocket: $e");
      setState(() => isLoading = false);
    }
  }

  void _fetchCategoriesAndItems() {
    print("[Items] Fetching categories and items");
    final message = {
      'type': 'get_categories_and_items',
      'user_id': _userId!,
      'business_name': _businessName!,
    };
    _channel.sink.add(jsonEncode(message));
  }

  void _handleWebSocketMessage(dynamic message) {
    print("[Items] Received WebSocket message");
    try {
      final response = jsonDecode(message);
      print(
        '[Items] Message type: ${response['type']}, success: ${response['success']}',
      );

      if (response['type'] == 'categories_and_items_data' &&
          response['success'] == true) {
        _handleCategoriesAndItemsData(response);
      } else if (response['type'] == 'error') {
        print('[Items] Server error: ${response['message']}');
        setState(() => isLoading = false);
      } else {
        print('[Items] Unhandled message type: ${response['type']}');
      }
    } catch (e) {
      print('[Items] ERROR parsing message: $e');
      print('[Items] Original message: $message');
      setState(() => isLoading = false);
    }
  }

  void _handleCategoriesAndItemsData(Map<String, dynamic> response) {
    print("[Items] Handling categories and items data");
    try {
      setState(() {
        categories = List<Map<String, dynamic>>.from(response['data'])
            .map(
              (categoryData) => Category(
                id: categoryData['id'],
                name: categoryData['name'],
                items: List<Map<String, dynamic>>.from(categoryData['items'])
                    .map(
                      (itemData) => Item(
                        id: itemData['id'],
                        name: itemData['name'],
                        price: itemData['price'].toString(),
                        cost: double.parse(itemData['cost'].toString()),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
        isLoading = false;
      });
      print("[Items] Loaded ${categories.length} categories");
    } catch (e) {
      print('[Items] ERROR processing categories: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text(
          'Menu Items',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Sidebar(initialSelectedIndex: 5),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No menu items found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items will appear once added in the system',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: CategoryColumn(
                    title: category.name,
                    items: category.items,
                  ),
                );
              },
            ),
    );
  }
}

class Category {
  final int id;
  final String name;
  final List<Item> items;

  Category({required this.id, required this.name, required this.items});
}

class Item {
  final int id;
  final String name;
  final String price;
  final double cost;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
  });
}

class CategoryColumn extends StatelessWidget {
  final String title;
  final List<Item> items;

  const CategoryColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Items List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fastfood, size: 40, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            "No items in this category",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: const Icon(
                              Icons.fastfood,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Price: ₱${item.price}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Cost: ₱${item.cost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
