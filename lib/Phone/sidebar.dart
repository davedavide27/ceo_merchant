import 'package:flutter/material.dart';
import 'transactions.dart';
import 'cash_drawer.dart';
import 'staff.dart';
import 'items.dart';
import 'inventory.dart';
import 'reports.dart';
import 'settings.dart';
import 'dashboard.dart';

class Sidebar extends StatefulWidget {
  final int initialSelectedIndex;
  final int? userId;

  Sidebar({this.initialSelectedIndex = 0, this.userId});

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late int _selectedIndex;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = isPortrait ? screenWidth * 0.75 : screenWidth * 0.30;

    // Adjusted logo size
    final logoSize = isPortrait ? 140.0 : 120.0;

    return Drawer(
      width: drawerWidth,
      child: Container(
        color: Colors.black87,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/logo_big.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    colorBlendMode: BlendMode.clear,
                    color: null,
                  ),
                ),
                _buildDrawerItem(Icons.app_registration, "Dashboard", 0),
                _buildDrawerItem(Icons.layers, "Transactions", 2),
                _buildDrawerItem(Icons.list, "Items", 5),
                _buildDrawerItem(Icons.inventory, "Inventory", 6),
                _buildDrawerItem(Icons.settings, "Settings", 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    bool isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.lightBlue : Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.lightBlue : Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 32.0),
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);

        Widget nextScreen;
        switch (title) {
          case "Dashboard":
            nextScreen = DashboardScreen();
            break;
          case "Transactions":
            nextScreen = TransactionsScreen();
            break;
          case "Cash Drawer":
            nextScreen = CashDrawerScreen();
            break;
          case "Staff":
            nextScreen = StaffScreen();
            break;
          case "Items":
            nextScreen = ItemsScreen();
            break;
          case "Inventory":
            nextScreen = InventoryScreen();
            break;
          case "Reports":
            nextScreen = ReportsScreen();
            break;
          case "Settings":
            nextScreen = SettingsScreen();
            break;
          default:
            return;
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return child;
                },
          ),
        );
      },
    );
  }
}
