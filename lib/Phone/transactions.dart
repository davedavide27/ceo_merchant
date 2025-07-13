import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sidebar.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  Map<String, List<Map<String, dynamic>>> groupedTransactions = {};
  Map<String, dynamic>? selectedTransaction;
  bool isLoading = false;
  String? businessName;
  bool showDetails = false;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() async {
    setState(() => isLoading = true);

    businessName = await _fetchBusinessNameFromDB();
    if (businessName == null || businessName!.isEmpty) {
      print('Error: Business name not found in local database');
      setState(() => isLoading = false);
      return;
    }

    String? websocketUrl = dotenv.env['WEBSOCKET_URL'];
    if (websocketUrl == null || websocketUrl.isEmpty) {
      print('Error: WEBSOCKET_URL is not configured');
      setState(() => isLoading = false);
      return;
    }

  }

  Future<String?> _fetchBusinessNameFromDB() async {
    // Simulate fetching business name from local database
    // Replace this with actual database query logic
    await Future.delayed(const Duration(seconds: 1));
    return 'My Business'; // Example business name
  }

  void _fetchTransactions() {
    if (businessName == null || businessName!.isEmpty) {
      print('Error: Business name is not available');
      return;
    }


  }

  void _fetchReceiptDetails(int receiptNumber) {
    if (businessName == null || businessName!.isEmpty) {
      print('Error: Business name is not available');
      return;
    }

  }

  void _handleServerMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      if (data['type'] == 'transactions_response' && data['success']) {
        final List receipts = data['receipts'];
        Map<String, List<Map<String, dynamic>>> tempGroupedTransactions = {};

        for (var receipt in receipts) {
          String dateString = receipt['time'].toString().split(' ')[0];
          if (!tempGroupedTransactions.containsKey(dateString)) {
            tempGroupedTransactions[dateString] = [];
          }
          tempGroupedTransactions[dateString]!.add(receipt);
        }

        setState(() {
          groupedTransactions = tempGroupedTransactions;
          isLoading = false;
        });
      } else if (data['type'] == 'receipt_response' && data['success']) {
        setState(() {
          selectedTransaction = data['receipt'];
          if (data['items'] != null) {
            selectedTransaction!['items'] = data['items'];
          }
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error parsing server message: $error');
      setState(() => isLoading = false);
    }
  }

  void _handleTransactionSelection(Map<String, dynamic> transaction) {
    setState(() {
      isLoading = true;
      showDetails = true;
    });
    _fetchReceiptDetails(transaction['receipt_number']);
  }

  void _closeDetails() {
    setState(() {
      selectedTransaction = null;
      showDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[800],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          showDetails && isPortrait 
            ? selectedTransaction != null
              ? 'Receipt #${selectedTransaction!['receipt_number']}'
              : 'Receipt Details'
            : 'Transactions',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: showDetails && isPortrait
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeDetails,
            )
          : null,
        elevation: 4,
      ),
      drawer: !isPortrait || !showDetails ? Sidebar(initialSelectedIndex: 2) : null,
      body: isPortrait
        ? _buildPortraitLayout()
        : _buildLandscapeLayout(),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left Panel - Transaction List
        Expanded(
          flex: 2,
          child: _buildTransactionList(),
        ),
        
        // Right Panel - Transaction Details
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTransactionDetail(),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return showDetails
      ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildTransactionDetail(),
        )
      : _buildTransactionList();
  }

  Widget _buildTransactionList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: !showDetails
            ? Border(right: BorderSide(color: Colors.grey[300]!))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(Icons.search, color: Colors.orange[800]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.orange,
                    ),
                  )
                : groupedTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: groupedTransactions.length,
                        itemBuilder: (context, index) {
                          final dateKey = groupedTransactions.keys.elementAt(index);
                          final transactions = groupedTransactions[dateKey]!;
                          return _buildDateGroup(dateKey, transactions);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: selectedTransaction == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt,
                      size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'Select a transaction to view details',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click on any transaction in the list',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '${selectedTransaction!['payment_type']} Receipt',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#${selectedTransaction!['receipt_number']}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedTransaction!['time'].toString().split(' ')[0],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Info Section
                      _buildDetailRow(
                        icon: Icons.payment,
                        label: 'Payment Type',
                        value: selectedTransaction!['payment_type'],
                      ),
                      _buildDetailRow(
                        icon: Icons.table_restaurant,
                        label: 'Table Number',
                        value: selectedTransaction!['table_number'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        icon: Icons.confirmation_number,
                        label: 'Reference Number',
                        value: selectedTransaction!['reference_number'] ?? 'N/A',
                      ),
                      const SizedBox(height: 16),
                      
                      // Items Section
                      Text(
                        'ITEMS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      
                      if (selectedTransaction!['items'] != null &&
                          (selectedTransaction!['items'] as List).isNotEmpty)
                        ...(selectedTransaction!['items'] as List).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['quantity']}x ${item['item_name']}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Text(
                                  '₱${item['price']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      
                      const SizedBox(height: 24),
                      
                      // Totals Section
                      _buildAmountRow('Subtotal', selectedTransaction!['subtotal']),
                      _buildAmountRow('Discount', selectedTransaction!['discount']),
                      if (selectedTransaction!['payment_type'] != 'Maya')
                        ...[
                          _buildAmountRow('Cash Received', selectedTransaction!['cash_received']),
                          _buildAmountRow('Change', selectedTransaction!['change']),
                        ],
                      const Divider(height: 32, thickness: 1.5),
                      _buildAmountRow(
                        'TOTAL',
                        selectedTransaction!['total'],
                        isTotal: true,
                      ),
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.print, size: 20),
                              label: const Text('REPRINT RECEIPT'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.undo, size: 20),
                              label: const Text('REFUND'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                foregroundColor: Colors.grey[800],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateGroup(String date, List<Map<String, dynamic>> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange[50],
          child: Row(
            children: [
              Text(
                date,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transactions.length.toString(),
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...transactions.map((transaction) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selectedTransaction?['receipt_number'] ==
                        transaction['receipt_number']
                    ? Colors.orange[300]!
                    : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction['payment_type'] == 'Maya'
                      ? Icons.credit_card
                      : Icons.money,
                  color: Colors.orange[800],
                  size: 20,
                ),
              ),
              title: Text(
                transaction['time'].toString().split(' ')[1],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: Text(
                'Table ${transaction['table_number'] ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Text(
                '₱${transaction['total']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () => _handleTransactionSelection(transaction),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange[700], size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, dynamic amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.orange[800] : Colors.grey[700],
            ),
          ),
          Text(
            '₱$amount',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.orange[800] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Close the WebSocket connection if it exists
    // _channel?.sink.close();
    super.dispose();
  }
}