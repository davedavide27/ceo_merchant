import 'package:flutter/material.dart';
import 'sidebar.dart';

class CashDrawerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cash Drawer'),
        // No need for a leading IconButton here, Scaffold automatically adds one
        // if a Drawer is provided.
      ),
      drawer: Sidebar(initialSelectedIndex: 3), // Define the Drawer here
      body: Center(
        child: Text('This is the Cash Drawer screen.'),
      ),
    );
  }
}