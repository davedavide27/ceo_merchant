import 'package:flutter/material.dart';
import 'sidebar.dart';

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        // No need for a leading IconButton here, Scaffold automatically adds one
        // if a Drawer is provided.
      ),
      drawer: Sidebar(initialSelectedIndex: 7),
      body: Center(
        child: Text('This is the Reports screen.'),
      ),
    );
  }
}