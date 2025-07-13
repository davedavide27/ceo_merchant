import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sidebar.dart';

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
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

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
    final user = await _dbHelper.getUser();
    if (user != null) {
      setState(() {
        _userId = int.tryParse(user['user_id'] ?? '');
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

    _fetchCategoriesAndItems();
  }

  void _fetchCategoriesAndItems() {
    if (_userId == null || _businessName == null) return;

    final message = {
      'type': 'get_categories_and_items',
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
        case 'categories_and_items_data':
          _handleCategoriesAndItemsData(response);
          break;
        case 'category_added':
          _handleCategoryAdded(response);
          break;
        case 'category_updated':
          _handleCategoryUpdated(response);
          break;
        case 'category_deleted':
          _handleCategoryDeleted(response);
          break;
        case 'item_added':
          _handleItemAdded(response);
          break;
        case 'item_updated':
          _handleItemUpdated(response);
          break;
        case 'item_deleted':
          _handleItemDeleted(response);
          break;
        case 'error':
          _handleError(response);
          break;
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  void _handleCategoriesAndItemsData(Map<String, dynamic> response) {
    if (response['success'] == true) {
      setState(() {
        categories = List<Map<String, dynamic>>.from(response['data'])
            .map((categoryData) => Category(
                  id: categoryData['id'],
                  name: categoryData['name'],
                  items: List<Map<String, dynamic>>.from(categoryData['items'])
                      .map((itemData) => Item(
                            id: itemData['id'],
                            name: itemData['name'],
                            price: itemData['price'].toString(),
                            cost: double.parse(itemData['cost'].toString()),
                          ))
                      .toList(),
                ))
            .toList();
      });
    } else {
      print('Failed to fetch categories and items: ${response['message']}');
    }
  }

  void _handleCategoryAdded(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final newCategory = Category(
          id: response['data']['id'],
          name: response['data']['name'],
          items: []);
      setState(() {
        categories.add(newCategory);
      });
    }
  }

  void _handleCategoryUpdated(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final updatedCategory = Category(
          id: response['data']['id'],
          name: response['data']['name'],
          items: response['data']['items'] != null
              ? response['data']['items']
                  .map<Item>((itemData) => Item(
                        id: itemData['id'],
                        name: itemData['name'],
                        price: itemData['price'].toString(),
                        cost: double.parse(itemData['cost'].toString()),
                      ))
                  .toList()
              : []);
      setState(() {
        final index =
            categories.indexWhere((cat) => cat.id == updatedCategory.id);
        if (index != -1) {
          categories[index] = updatedCategory;
        }
      });
    }
  }

  void _handleCategoryDeleted(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final categoryId = response['id'];
      setState(() {
        categories.removeWhere((category) => category.id == categoryId);
      });
    }
  }

  void _handleItemAdded(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final newItem = Item(
          id: response['data']['id'],
          name: response['data']['name'],
          price: response['data']['price'],
          cost: double.parse(response['data']['cost'].toString()));
      setState(() {
        final categoryIndex = categories
            .indexWhere((cat) => cat.id == response['data']['category_id']);
        if (categoryIndex != -1) {
          categories[categoryIndex].items.add(newItem);
        }
      });
    }
  }

  void _handleItemUpdated(Map<String, dynamic> response) {
    if (response['data'] != null) {
      final updatedItem = Item(
          id: response['data']['id'],
          name: response['data']['name'],
          price: response['data']['price'],
          cost: double.parse(response['data']['cost'].toString()));
      setState(() {
        final categoryIndex = categories
            .indexWhere((cat) => cat.id == response['data']['category_id']);
        if (categoryIndex != -1) {
          final itemIndex = categories[categoryIndex]
              .items
              .indexWhere((item) => item.id == updatedItem.id);
          if (itemIndex != -1) {
            categories[categoryIndex].items[itemIndex] = updatedItem;
          }
        }
      });
    }
  }

  void _handleItemDeleted(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final itemId = response['id'];
      setState(() {
        for (var category in categories) {
          category.items.removeWhere((item) => item.id == itemId);
        }
      });
    }
  }

  void _handleError(Map<String, dynamic> response) {
    print('Server error: ${response['message']}');
  }

  void _handleWebSocketError(dynamic error) {
    print('WebSocket error: $error');
  }

  void _handleWebSocketDone() {
    print('WebSocket connection closed');
  }

  void _showCategoryDialog({String? categoryName, int? categoryIndex}) {
    final dialogController = TextEditingController(text: categoryName ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryIndex == null ? 'Add Category' : 'Edit Category',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: dialogController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    prefixIcon: const Icon(Icons.category, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        final newName = dialogController.text;
                        if (newName.isEmpty) {
                          _showCategoryNameEmptyDialog();
                          return;
                        }

                        final message = {
                          'type': categoryIndex != null
                              ? 'update_category'
                              : 'add_category',
                          'user_id': _userId,
                          'business_name': _businessName,
                          'name': newName,
                        };

                        if (categoryIndex != null) {
                          message['id'] = categories[categoryIndex].id;
                        }

                        _channel.sink.add(jsonEncode(message));
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showItemDialog({
    required int categoryId,
    Item? item,
  }) {
    _itemNameController.text = item?.name ?? '';
    _priceController.text = item?.price ?? '';
    _costController.text = item?.cost.toString() ?? '0.0';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item == null ? 'Add New Item' : 'Edit Item',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextFieldWithIcon(
                  controller: _itemNameController,
                  label: 'Item Name',
                  icon: Icons.fastfood,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPesoTextField(
                        controller: _priceController,
                        label: 'Price',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPesoTextField(
                        controller: _costController,
                        label: 'Cost',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        _updateItem(categoryId, item);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Item',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildPesoTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(top: 12.0),
          child: Text('₱', style: TextStyle(fontSize: 20, color: Colors.orange)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
      keyboardType: keyboardType,
    );
  }

  void _updateItem(int categoryId, Item? item) {
    final itemName = _itemNameController.text;
    final price = _priceController.text;
    final cost = _costController.text;

    if (itemName.isEmpty || price.isEmpty || cost.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (double.tryParse(price) == null || double.tryParse(cost) == null) {
      _showErrorDialog('Price and Cost must be valid numbers');
      return;
    }

    final itemData = {
      'type': item == null ? 'add_item' : 'update_item',
      'user_id': _userId,
      'business_name': _businessName,
      'category_id': categoryId,
      'name': itemName,
      'price': price,
      'cost': cost,
    };

    if (item != null) {
      itemData['id'] = item.id;
    }

    _channel.sink.add(jsonEncode(itemData));
  }

  void _showDeleteConfirmationDialog({
    required String type,
    required String name,
    required int id,
    int? categoryId,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete $type?'),
          content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog first
                if (type == 'category') {
                  _deleteCategory(id);
                } else {
                  _deleteItem(id);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(int categoryId) {
    final message = {
      'type': 'delete_category',
      'user_id': _userId,
      'business_name': _businessName,
      'id': categoryId,
    };
    _channel.sink.add(jsonEncode(message));
  }

  void _deleteItem(int itemId) {
    final message = {
      'type': 'delete_item',
      'user_id': _userId,
      'business_name': _businessName,
      'id': itemId,
    };
    _channel.sink.add(jsonEncode(message));
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryNameEmptyDialog() {
    int secondsRemaining = 3;
    Timer? countdownTimer;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            void updateCountdown() {
              localSetState(() {
                secondsRemaining--;
                if (secondsRemaining <= 0) {
                  countdownTimer?.cancel();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              });
            }

            countdownTimer =
                Timer.periodic(const Duration(seconds: 1), (timer) {
              updateCountdown();
            });

            return AlertDialog(
              title: const Text('Validation Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Category name cannot be empty'),
                  const SizedBox(height: 16),
                  Text('Closing in $secondsRemaining seconds'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.orange,
          title: Row(
            children: [
              const Text('Items',
                  style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _categoryNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter New Category',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.category, color: Colors.orange, size: 20),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        final newCategory = {
                          'type': 'add_category',
                          'user_id': _userId,
                          'business_name': _businessName,
                          'name': value,
                        };
                        _channel.sink.add(jsonEncode(newCategory));
                        _categoryNameController.clear();
                      } else {
                        _showCategoryNameEmptyDialog();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final categoryName = _categoryNameController.text;
                    if (categoryName.isNotEmpty) {
                      final newCategory = {
                        'type': 'add_category',
                        'user_id': _userId,
                        'business_name': _businessName,
                        'name': categoryName,
                      };
                      _channel.sink.add(jsonEncode(newCategory));
                      _categoryNameController.clear();
                    } else {
                      _showCategoryNameEmptyDialog();
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  tooltip: 'Add category',
                ),
              ),
            ],
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
      ),
      drawer: Sidebar(initialSelectedIndex: 5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: categories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No categories yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first category to get started',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: CategoryColumn(
                      title: category.name,
                      items: category.items,
                      onAddItem: () => _showItemDialog(categoryId: category.id),
                      onEditCategory: () => _showCategoryDialog(
                        categoryName: category.name,
                        categoryIndex: index,
                      ),
                      onDeleteCategory: () => _showDeleteConfirmationDialog(
                        type: 'category',
                        name: category.name,
                        id: category.id,
                      ),
                      onEditItem: (itemId, item) => _showItemDialog(
                        categoryId: category.id,
                        item: item,
                      ),
                      onDeleteItem: (itemId) {
                        final item = category.items.firstWhere((i) => i.id == itemId);
                        _showDeleteConfirmationDialog(
                          type: 'item',
                          name: item.name,
                          id: item.id,
                        );
                      },
                      categoryId: category.id,
                    ),
                  );
                },
              ),
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
  final VoidCallback? onAddItem;
  final VoidCallback? onEditCategory;
  final VoidCallback? onDeleteCategory;
  final Function(int, Item)? onEditItem;
  final Function(int)? onDeleteItem;
  final int categoryId;

  const CategoryColumn({
    required this.title,
    required this.items,
    this.onAddItem,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onEditItem,
    this.onDeleteItem,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 22),
                    onPressed: onAddItem,
                    tooltip: 'Add item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 22),
                    onPressed: onEditCategory,
                    tooltip: 'Edit category',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white, size: 22),
                    onPressed: onDeleteCategory,
                    tooltip: 'Delete category',
                  ),
                ],
              ),
            ),
          ),
          
          // Items List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fastfood, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                            "No items in this category",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: onAddItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Add First Item',
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: const Icon(Icons.fastfood, color: Colors.orange),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange.shade700),
                                onPressed: () => onEditItem?.call(item.id, item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => onDeleteItem?.call(item.id),
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