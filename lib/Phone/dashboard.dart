import 'package:flutter/material.dart';
import 'sidebar.dart';

class DashboardScreen extends StatefulWidget {
  final int? userId;

  const DashboardScreen({Key? key, this.userId}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Sidebar(userId: widget.userId),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
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
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.teal,
                      size: 24,
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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            
            // Dashboard Cards
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
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
                            height: 100,
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
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          Icon(Icons.calendar_today, color: Colors.grey[700]),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Payment Types Section
                    _buildSectionTitle('Payment Types', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildNoDataRow(Icons.credit_card, 'No Data', '₱0.00'),

                    SizedBox(height: 24),

                    // Sales by Date Section
                    _buildSectionTitle('Sales by Date', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildSalesByDate(),

                    SizedBox(height: 24),

                    // Sales by Category Section
                    _buildSectionTitle('Sales by Category', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildNoDataRow(Icons.category, 'No Data'),

                    SizedBox(height: 24),

                    // Sales by Item Section
                    _buildSectionTitle('Sales by Item', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildNoDataRow(Icons.list, 'No Data'),

                    SizedBox(height: 24),

                    // Sales by Cashier Section
                    _buildSectionTitle('Sales by Cashier', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildNoDataRow(Icons.person, 'No Data'),

                    SizedBox(height: 24),

                    // Sales by Payment Section
                    _buildSectionTitle('Sales by Payment', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildNoDataRow(Icons.payment, 'No Data'),

                    SizedBox(height: 24),

                    // List of Items Section
                    _buildSectionTitle('List of Items', 'Jul 12, 12:00am – Jul 12, 11:59pm'),
                    _buildEmptyItemList(),
                  ],
                ),
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
          colors: [
            color,
            color.withOpacity(0.8),
          ],
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
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
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
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
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
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Monthly',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
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
            columnWidths: {
              0: FlexColumnWidth(3),
            },
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
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
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
                    .map((e) => DropdownMenuItem<int>(
                          value: e,
                          child: Text('$e'),
                        ))
                    .toList(),
                onChanged: (value) {},
              ),
              Text('0-0 of 0'),
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
