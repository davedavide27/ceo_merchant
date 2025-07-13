import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sidebar.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {

  List<Map<String, dynamic>> inventoryItems = [];
  String sortedBy = 'name';
  bool ascending = true;
  String? _userId;
  String? _businessName;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = await _dbHelper.getUser();
    if (user != null) {
      setState(() {
        _userId = user['user_id'];
        _businessName = user['business_name'];
      });
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (_userId == null || _businessName == null) return;

    _channel = WebSocketChannel.connect(
      Uri.parse(dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:3000/ws'),
    );

    _channel.stream.listen(
      _handleWebSocketMessage,
      onError: _handleWebSocketError,
      onDone: _handleWebSocketDone,
    );

    _fetchInventory();
  }

  void _fetchInventory() {
    if (_userId == null || _businessName == null) return;

    final message = {
      'type': 'get_inventory',
      'user_id': _userId!,
      'business_name': _businessName!,
    };

    _channel.sink.add(jsonEncode(message));
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final response = jsonDecode(message);
      print('WebSocket message: $response');

      switch (response['type']) {
        case 'inventory_data':
          _handleInventoryData(response);
          break;
        case 'ingredient_added':
          _handleIngredientAdded(response);
          break;
        case 'ingredient_updated':
          _handleIngredientUpdated(response);
          break;
        case 'ingredient_deleted':
          _handleIngredientDeleted(response);
          break;
        case 'error':
          _handleError(response);
          break;
        case 'update_ingredient_details':
          _handleIngredientUpdated(response);
          break;
        case 'add_purchase':
          _handleIngredientUpdated(response);
          break;
        case 'remove_purchase':
          _handleIngredientUpdated(response);
          break;
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  void _handleInventoryData(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final parsedItems = List<Map<String, dynamic>>.from(response['data'])
          .map((item) => _parseInventoryItem(item))
          .toList();
      // Deduplicate items by 'id'
      final deduplicatedItems = <String, Map<String, dynamic>>{};
      for (var item in parsedItems) {
        deduplicatedItems[item['id']] = item;
      }
      setState(() {
        inventoryItems = deduplicatedItems.values.toList();
      });
    } else {
      print('Failed to fetch inventory: ${response['message']}');
    }
  }

  Map<String, dynamic> _parseInventoryItem(Map<String, dynamic> item) {
    List<dynamic> purchases = [];
    if (item['purchases'] is String &&
        item['purchases'] != null &&
        item['purchases']!.isNotEmpty) {
      try {
        final purchaseStrings = item['purchases'].toString().split(',');
        for (var purchaseStr in purchaseStrings) {
          final cleanStr = purchaseStr.replaceAll(RegExp(r'^{|}$'), '');
          if (cleanStr.isNotEmpty) {
            final purchase = jsonDecode('{' + cleanStr + '}');
            purchases.add(purchase);
          }
        }
      } catch (e) {
        print('Error parsing purchases: $e');
      }
    } else if (item['purchases'] is List) {
      purchases = item['purchases'].cast<Map<String, dynamic>>();
    }

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

  void _handleIngredientAdded(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final newItem = _parseInventoryItem(response['data']);
      setState(() {
        if (!inventoryItems.any((item) => item['id'] == newItem['id'])) {
          inventoryItems.add(newItem);
        }
      });
    }
  }

  void _handleIngredientUpdated(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final updatedItem = _parseInventoryItem(response['data']);
      setState(() {
        final index = inventoryItems
            .indexWhere((item) => item['id'] == updatedItem['id']);
        if (index != -1) {
          inventoryItems[index] = updatedItem;
        }
      });
    }
  }

  void _handleIngredientDeleted(Map<String, dynamic> response) {
    final ingredientId = response['ingredient_id'];
    setState(() {
      inventoryItems
          .removeWhere((item) => item['id'].toString() == ingredientId);
    });
  }

  void _handleError(Map<String, dynamic> response) {
    print('Server error: ${response['message']}');
    _fetchInventory();
  }

  void _handleWebSocketError(dynamic error) {
    print('WebSocket error: $error');
  }

  void _handleWebSocketDone() {
    print('WebSocket connection closed');
  }

  void sortItems(String field) {
    setState(() {
      if (sortedBy == field) {
        ascending = !ascending;
      } else {
        sortedBy = field;
        ascending = true;
      }
      inventoryItems.sort((a, b) {
        final aVal = a[field];
        final bVal = b[field];
        if (aVal is String) {
          return ascending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
        } else if (aVal is num) {
          return ascending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
        }
        return 0;
      });
    });
  }

  Widget buildSortHeader(String field, String label, {Color? color}) {
    Icon icon = Icon(
      sortedBy == field
          ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more,
      size: 16,
      color: color ?? Colors.black,
    );
    return GestureDetector(
      onTap: () => sortItems(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
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
        title: Row(
          children: [
            Text(
              'Inventory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search ingredients...',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepOrange,
              elevation: 2,
              mini: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onPressed: () => _showAddIngredientDialog(),
              child: Icon(Icons.add, size: 24),
            ),
          ],
        ),
      ),
      drawer: Sidebar(initialSelectedIndex: 6),
      body: Column(
        children: [
          // Enhanced header with sorting options
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: buildSortHeader('name', 'INGREDIENT',
                      color: Colors.grey[700]),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: buildSortHeader('total_quantity', 'QUANTITY',
                        color: Colors.deepOrange),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: buildSortHeader('average_price', 'AVG PRICE',
                        color: Colors.grey[700]),
                  ),
                ),
                SizedBox(width: 48),
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
                        Icon(Icons.inventory_2,
                            size: 80, color: Colors.grey[300]),
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
                          'Add your first ingredient to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('Add Ingredient'),
                          onPressed: () => _showAddIngredientDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
          )
        ],
      ),
    );
  }

  // Enhanced inventory item card
  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showPurchaseDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Delete button
              Container(
                width: 40,
                alignment: Alignment.center,
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 22, color: Colors.grey[600]),
                  onPressed: () => _deleteIngredient(item['id']),
                ),
              ),

              // Ingredient name with alert indicator
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Text(
                      item['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((item['price_limit'] ?? 0) > 0 &&
                        (item['average_price'] ?? 0) >
                            (item['price_limit'] ?? 0))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.warning_amber,
                            size: 18, color: Colors.orange),
                      ),
                  ],
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // Edit button
              Container(
                width: 40,
                alignment: Alignment.center,
                child: IconButton(
                  icon: Icon(Icons.edit, size: 20, color: Colors.deepOrange),
                  onPressed: () => _showEditIngredientDialog(item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced purchase details dialog
  void _showPurchaseDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                // Header with title and buttons
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? 'Ingredient Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.speed, size: 24, color: Colors.blue),
                      onPressed: () => _showPriceLimitDialog(item),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 24),
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
                      child: _buildStatCard('Total Stock',
                          '${item['total_quantity'] ?? 0}', Icons.inventory),
                    ),
                    Container(
                      width: 120,
                      child: _buildStatCard(
                          'Avg Price',
                          '₱${(item['average_price'] ?? 0).toDouble().toStringAsFixed(2)}',
                          Icons.attach_money),
                    ),
                    if (double.tryParse(
                            item['price_limit']?.toString() ?? '0')! >
                        0)
                      Container(
                        width: 120,
                        child: _buildStatCard(
                            'Price Limit',
                            '₱${double.tryParse(item['price_limit']?.toString() ?? '0')!.toStringAsFixed(2)}',
                            Icons.warning),
                      ),
                  ],
                ),

                SizedBox(height: 24),

                // Purchases header
                Row(
                  children: [
                    Text(
                      'Purchase History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.deepOrange),
                      onPressed: () => _showAddPurchaseDialog(item),
                    ),
                  ],
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
                              Icon(Icons.history,
                                  size: 40, color: Colors.grey[300]),
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
                            return _buildPurchaseListItem(item, purchase);
                          },
                        ),
                ),

                SizedBox(height: 16),

                // Close button
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

  Widget _buildPurchaseListItem(
      Map<String, dynamic> item, Map<String, dynamic> purchase) {
    double purchasePrice = 0.0;
    if (purchase['price'] is String) {
      purchasePrice = double.tryParse(purchase['price']) ?? 0.0;
    } else if (purchase['price'] is num) {
      purchasePrice = purchase['price'].toDouble();
    }

    double priceLimit = item['price_limit']?.toDouble() ?? 0.0;
    final isOverLimit = priceLimit > 0 && purchasePrice > priceLimit;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOverLimit ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOverLimit ? Colors.red[100]! : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOverLimit ? Colors.red[100] : Colors.deepOrange[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOverLimit ? Icons.warning : Icons.shopping_bag,
            color: isOverLimit ? Colors.red : Colors.deepOrange,
            size: 20,
          ),
        ),
        title: Text(
          purchase['supplier']?.toString() ?? 'Unknown Supplier',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isOverLimit ? Colors.red[800] : Colors.grey[800],
          ),
        ),
        subtitle: Text(
          'Quantity: ${purchase['quantity'] ?? 0}',
          style: TextStyle(fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₱${purchasePrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isOverLimit ? Colors.red[800] : Colors.grey[800],
                fontSize: 16,
              ),
            ),
            if (isOverLimit)
              Text(
                'Above limit',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        onTap: () => _showEditPurchaseDialog(item, purchase),
      ),
    );
  }

  void _showAddPurchaseDialog(Map<String, dynamic> item) {
    final TextEditingController _supplierController = TextEditingController();
    final TextEditingController _priceController = TextEditingController();
    final TextEditingController _quantityController =
        TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_supplierController.text.isNotEmpty &&
                  _priceController.text.isNotEmpty &&
                  _quantityController.text.isNotEmpty) {
                _addNewPurchase(
                  item['id'],
                  _supplierController.text,
                  double.tryParse(_priceController.text) ?? 0.0,
                  int.tryParse(_quantityController.text) ?? 0,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Add Purchase'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _addNewPurchase(
      String ingredientId, String supplier, double price, int quantity) {
    if (_userId == null || _businessName == null) return;

    final message = {
      'type': 'add_purchase',
      'user_id': _userId!,
      'business_name': _businessName!,
      'ingredient_id': ingredientId,
      'supplier': supplier,
      'price': price,
      'quantity': quantity,
    };

    _channel.sink.add(jsonEncode(message));
  }

  void _showEditPurchaseDialog(
      Map<String, dynamic> item, Map<String, dynamic> purchase) {
    final TextEditingController _supplierController =
        TextEditingController(text: purchase['supplier']?.toString() ?? '');
    final TextEditingController _priceController = TextEditingController(
        text: (purchase['price'] is String
                ? purchase['price']
                : purchase['price']?.toString()) ??
            '0.0');
    final TextEditingController _quantityController = TextEditingController(
        text: (purchase['quantity'] is String
                ? purchase['quantity']
                : purchase['quantity']?.toString()) ??
            '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_supplierController.text.isNotEmpty &&
                  _priceController.text.isNotEmpty &&
                  _quantityController.text.isNotEmpty) {
                _updatePurchase(
                  item['id'],
                  purchase['supplier']?.toString() ?? '',
                  _supplierController.text,
                  double.tryParse(_priceController.text) ?? 0.0,
                  int.tryParse(_quantityController.text) ?? 0,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _updatePurchase(String ingredientId, String oldSupplier,
      String newSupplier, double newPrice, int newQuantity) {
    if (_userId == null || _businessName == null) return;

    final message = {
      'type': 'update_purchase',
      'user_id': _userId!,
      'business_name': _businessName!,
      'ingredient_id': ingredientId,
      'old_supplier': oldSupplier,
      'new_supplier': newSupplier,
      'new_price': newPrice,
      'new_quantity': newQuantity,
    };

    _channel.sink.add(jsonEncode(message));
  }

  void _showPriceLimitDialog(Map<String, dynamic> item) {
    final TextEditingController _limitController = TextEditingController(
        text: (item['price_limit'] ?? 0) > 0
            ? item['price_limit'].toStringAsFixed(2)
            : '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.price_check,
                  size: 32,
                  color: Colors.deepOrange,
                ),
              ),

              SizedBox(height: 16),

              // Title
              Text(
                'Set Price Alert',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),

              SizedBox(height: 8),

              // Subtitle
              Text(
                'Get notified when purchase prices exceed this limit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),

              SizedBox(height: 24),

              // Input field
              TextFormField(
                controller: _limitController,
                decoration: InputDecoration(
                  labelText: 'Maximum Price',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_limitController.text.isEmpty) {
                          _updatePriceLimit(item, 0);
                          Navigator.pop(context);
                          return;
                        }

                        final limit = double.tryParse(_limitController.text);
                        if (limit != null) {
                          _updatePriceLimit(item, limit);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Set Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updatePriceLimit(Map<String, dynamic> item, double limit) {
    if (_userId == null || _businessName == null) return;

    setState(() {
      item['price_limit'] = limit;
    });

    final message = {
      'type': 'update_price_limit',
      'user_id': _userId!,
      'business_name': _businessName!,
      'ingredient_id': item['id'],
      'price_limit': limit
    };

    _channel.sink.add(jsonEncode(message));
  }

  void _showAddIngredientDialog([Map<String, dynamic>? item]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: AddIngredientDialog(
          userId: _userId,
          businessName: _businessName,
          channel: _channel,
          onAdded: _fetchInventory,
          initialItem: item,
        ),
      ),
    );
  }

  void _showEditIngredientDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: EditIngredientDialog(
          userId: _userId,
          businessName: _businessName,
          channel: _channel,
          onUpdated: _fetchInventory,
          initialItem: item,
        ),
      ),
    );
  }

  void _deleteIngredient(String ingredientId) {
    if (_userId == null || _businessName == null) return;

    setState(() {
      inventoryItems.removeWhere((item) => item['id'] == ingredientId);
    });

    final message = {
      'type': 'delete_ingredient',
      'user_id': _userId!,
      'business_name': _businessName!,
      'ingredient_id': ingredientId
    };

    _channel.sink.add(jsonEncode(message));
  }

  void _removePurchase(String ingredientId, String supplier) {
    if (_userId == null || _businessName == null) return;

    final message = {
      'type': 'remove_purchase',
      'user_id': _userId!,
      'business_name': _businessName!,
      'ingredient_id': ingredientId,
      'supplier': supplier
    };

    _channel.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}

class QuantityAdjustmentField extends StatefulWidget {
  final Function(int) onAdjusted;

  const QuantityAdjustmentField({
    required this.onAdjusted,
  });

  @override
  _QuantityAdjustmentFieldState createState() =>
      _QuantityAdjustmentFieldState();
}

class _QuantityAdjustmentFieldState extends State<QuantityAdjustmentField> {
  final TextEditingController _deltaController =
      TextEditingController(text: '1');

  void _adjustQuantity(bool isAdd) {
    final delta = int.tryParse(_deltaController.text) ?? 1;
    if (delta > 0) {
      widget.onAdjusted(isAdd ? delta : -delta);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepOrange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.remove, color: Colors.deepOrange),
            onPressed: () => _adjustQuantity(false),
          ),
          Container(
            width: 60,
            child: TextField(
              controller: _deltaController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Qty',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.deepOrange),
            onPressed: () => _adjustQuantity(true),
          ),
        ],
      ),
    );
  }
}

class AddIngredientDialog extends StatefulWidget {
  final String? userId;
  final String? businessName;
  final WebSocketChannel channel;
  final VoidCallback onAdded;
  final Map<String, dynamic>? initialItem;

  const AddIngredientDialog({
    required this.userId,
    required this.businessName,
    required this.channel,
    required this.onAdded,
    this.initialItem,
  });

  @override
  _AddIngredientDialogState createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<AddIngredientDialog> {
  late final TextEditingController _nameController;
  List<Map<String, TextEditingController>> _purchaseEntries = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialItem?['name'] ?? '',
    );

    if (widget.initialItem != null) {
      for (var purchase in widget.initialItem!['purchases']) {
        _addPurchaseEntry(
          supplier: purchase['supplier'] ?? '',
          price: purchase['price'] is String
              ? purchase['price']
              : purchase['price']?.toString() ?? '0.0',
          quantity: purchase['quantity'] is String
              ? purchase['quantity']
              : purchase['quantity']?.toString() ?? '0',
        );
      }
    } else {
      _addPurchaseEntry();
    }
  }

  void _addPurchaseEntry(
      {String supplier = '', String price = '0.0', String quantity = '0'}) {
    setState(() {
      _purchaseEntries.add({
        'supplier': TextEditingController(text: supplier),
        'price': TextEditingController(text: price),
        'quantity': TextEditingController(text: quantity),
      });
    });
  }

  Widget _buildPurchaseEntry(int index) {
    return Column(
      children: [
        SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _purchaseEntries[index]['supplier'],
                decoration: InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.remove_circle,
                  size: 28,
                  color: _purchaseEntries.length > 1
                      ? Colors.red[400]
                      : Colors.grey[400]),
              onPressed: () {
                if (_purchaseEntries.length > 1) {
                  _removePurchaseEntry(index);
                }
              },
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _purchaseEntries[index]['price'],
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!isNumeric(value)) return 'Invalid price';
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _purchaseEntries[index]['quantity'],
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!isNumeric(value)) return 'Invalid quantity';
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  bool isNumeric(String s) {
    return double.tryParse(s) != null;
  }

  void _removePurchaseEntry(int index) {
    setState(() {
      _purchaseEntries.removeAt(index);
    });
  }

  void _submitIngredient() {
    if (_formKey.currentState!.validate() &&
        widget.userId != null &&
        widget.businessName != null) {
      List<Map<String, dynamic>> purchases = [];

      for (var entry in _purchaseEntries) {
        purchases.add({
          'supplier': entry['supplier']!.text,
          'price': double.tryParse(entry['price']!.text) ?? 0.0,
          'quantity': int.tryParse(entry['quantity']!.text) ?? 0,
        });
      }

      final message = {
        'type': widget.initialItem != null
            ? 'update_ingredient_details'
            : 'add_ingredient',
        'user_id': widget.userId!,
        'business_name': widget.businessName!,
        'name': _nameController.text,
        'purchases': purchases,
      };

      if (widget.initialItem != null) {
        message['ingredient_id'] = widget.initialItem!['id'];
      }

      widget.channel.sink.add(jsonEncode(message));
      Navigator.pop(context);
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.initialItem != null ? Icons.edit : Icons.add_circle,
                size: 28,
                color: Colors.deepOrange,
              ),
              SizedBox(width: 12),
              Text(
                widget.initialItem != null
                    ? 'Edit Ingredient'
                    : 'Add New Ingredient',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Ingredient Name',
                    prefixIcon: Icon(Icons.kitchen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.deepOrange, width: 1.5),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(fontSize: 16),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),

                SizedBox(height: 24),

                // Purchases header
                Row(
                  children: [
                    Text(
                      'Purchases',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Purchase entries
                ...List.generate(_purchaseEntries.length,
                    (index) => _buildPurchaseEntry(index)),

                // Add purchase button
                Center(
                  child: TextButton.icon(
                    onPressed: () => _addPurchaseEntry(),
                    icon: Icon(Icons.add_circle_outline,
                        color: Colors.deepOrange),
                    label: Text(
                      'Add Purchase',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: Navigator.of(context).pop,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.initialItem != null ? 'Update' : 'Add',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditIngredientDialog extends StatefulWidget {
  final String? userId;
  final String? businessName;
  final WebSocketChannel channel;
  final VoidCallback onUpdated;
  final Map<String, dynamic> initialItem;

  const EditIngredientDialog({
    required this.userId,
    required this.businessName,
    required this.channel,
    required this.onUpdated,
    required this.initialItem,
  });

  @override
  _EditIngredientDialogState createState() => _EditIngredientDialogState();
}

class _EditIngredientDialogState extends State<EditIngredientDialog> {
  late final TextEditingController _nameController;
  List<Map<String, TextEditingController>> _purchaseEntries = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialItem['name'] ?? '',
    );

    for (var purchase in widget.initialItem['purchases']) {
      _addPurchaseEntry(
        supplier: purchase['supplier'] ?? '',
        price: purchase['price'] is String
            ? purchase['price']
            : purchase['price']?.toString() ?? '0.0',
        quantity: purchase['quantity'] is String
            ? purchase['quantity']
            : purchase['quantity']?.toString() ?? '0',
      );
    }
  }

  void _addPurchaseEntry(
      {String supplier = '', String price = '0.0', String quantity = '0'}) {
    setState(() {
      _purchaseEntries.add({
        'supplier': TextEditingController(text: supplier),
        'price': TextEditingController(text: price),
        'quantity': TextEditingController(text: quantity),
      });
    });
  }

  Widget _buildPurchaseEntry(int index) {
    return Column(
      children: [
        SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _purchaseEntries[index]['supplier'],
                decoration: InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.remove_circle,
                  size: 28,
                  color: _purchaseEntries.length > 1
                      ? Colors.red[400]
                      : Colors.grey[400]),
              onPressed: () {
                if (_purchaseEntries.length > 1) {
                  _removePurchaseEntry(index);
                }
              },
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _purchaseEntries[index]['price'],
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!isNumeric(value)) return 'Invalid price';
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _purchaseEntries[index]['quantity'],
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!isNumeric(value)) return 'Invalid quantity';
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  bool isNumeric(String s) {
    return double.tryParse(s) != null;
  }

  void _removePurchaseEntry(int index) {
    setState(() {
      _purchaseEntries.removeAt(index);
    });
  }

  void _submitIngredient() {
    if (_formKey.currentState!.validate() &&
        widget.userId != null &&
        widget.businessName != null) {
      List<Map<String, dynamic>> purchases = [];

      for (var entry in _purchaseEntries) {
        purchases.add({
          'supplier': entry['supplier']!.text,
          'price': double.tryParse(entry['price']!.text) ?? 0.0,
          'quantity': int.tryParse(entry['quantity']!.text) ?? 0,
        });
      }

      final message = {
        'type': 'update_ingredient_details',
        'user_id': widget.userId!,
        'business_name': widget.businessName!,
        'ingredient_id': widget.initialItem['id'],
        'name': _nameController.text,
        'purchases': purchases,
      };

      widget.channel.sink.add(jsonEncode(message));
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.edit,
                  size: 28,
                  color: Colors.deepOrange,
                ),
                SizedBox(width: 12),
                Text(
                  'Edit Ingredient',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Ingredient Name',
                      prefixIcon: Icon(Icons.kitchen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.deepOrange, width: 1.5),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: TextStyle(fontSize: 16),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),

                  SizedBox(height: 24),

                  // Purchases header
                  Row(
                    children: [
                      Text(
                        'Purchases',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Purchase entries
                  ...List.generate(_purchaseEntries.length,
                      (index) => _buildPurchaseEntry(index)),

                  // Add purchase button
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _addPurchaseEntry(),
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.deepOrange),
                      label: Text(
                        'Add Purchase',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Navigator.of(context).pop,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitIngredient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
