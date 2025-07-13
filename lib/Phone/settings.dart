import 'package:flutter/material.dart';
import 'dart:io';
import 'sidebar.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ipAddress = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getIpAddress();
  }

  Future<void> _getIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() {
              _ipAddress = addr.address;
            });
            return;
          }
        }
      }
      setState(() {
        _ipAddress = 'IP not found';
      });
    } catch (e) {
      setState(() {
        _ipAddress = 'Error getting IP';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 800;

    return Scaffold(
      drawer: Sidebar(initialSelectedIndex: 8),
      appBar: AppBar(
        backgroundColor: Color(0xFFF57C00),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (isSmallScreen) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(size),
                        SizedBox(height: 24),
                        _buildActionButtons(isSmallScreen),
                        SizedBox(height: 24),
                        _buildFormSection(),
                        SizedBox(height: 24),
                        _buildGeneralSettingsCard(),
                        SizedBox(height: 16),
                        _buildPrinterSettingsCard(),
                        SizedBox(height: 16),
                        _buildConnectionInfo(size),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          physics: ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderSection(size),
                              SizedBox(height: 24),
                              _buildActionButtons(isSmallScreen),
                              SizedBox(height: 24),
                              _buildFormSection(),
                              SizedBox(height: 24),
                              _buildConnectionInfo(size),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          physics: ClampingScrollPhysics(),
                          child: Column(
                            children: [
                              _buildGeneralSettingsCard(),
                              SizedBox(height: 16),
                              _buildPrinterSettingsCard(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CEO APP',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Version 1.0.0.0, Build: 1.0.0',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(label: 'Update App', icon: Icons.update),
        _ActionButton(label: 'Reload App', icon: Icons.refresh),
        _ActionButton(label: 'Logout', icon: Icons.exit_to_app),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField('Business Name'),
        SizedBox(height: 20),
        _buildLabeledField('Email Reports To'),
        SizedBox(height: 20),
        _buildLabeledField('Business Address'),
        SizedBox(height: 24),
        Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        _buildSelectButton('Select Payment Methods'),
        SizedBox(height: 24),
        Text(
          'Device Modes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        _buildSelectButton('Customer Screen'),
        SizedBox(height: 8),
        _buildSelectButton('Kitchen Screen'),
      ],
    );
  }

  Widget _buildGeneralSettingsCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            _buildToggleRow('Park Orders'),
            _buildDivider(),
            _buildToggleRow('Customer Database'),
            _buildDivider(),
            _buildDropdownRow('Customer Display', ['Off', 'On']),
            _buildDivider(),
            _buildToggleRow('Kitchen Display'),
            _buildDivider(),
            _buildDropdownRow('View Override', ['Off', 'On']),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSettingsCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printer Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            _buildToggleRow('Print Stickers'),
            _buildDivider(),
            _buildToggleRow('Print Order Slip'),
            _buildDivider(),
            _buildToggleRow('Extra Order Printer'),
            _buildDivider(),
            _buildToggleRow('Auto Print', active: true),
            _buildDivider(),
            _buildToggleRow('58mm Mini Printer', active: true),
            _buildDivider(),
            _buildToggleRow('Cash Drawer'),
            _buildDivider(),
            _buildDropdownRow('Receipt Printer', ['USB Printer', 'Network Printer']),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Text(
          'Connection: $_ipAddress',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Device Height: ${size.height.toStringAsFixed(0)}, Width: ${size.width.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectButton(String label) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white54, width: 1.5),
        padding: EdgeInsets.symmetric(vertical: 16),
        minimumSize: Size(double.infinity, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {},
      child: Text(
        label,
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildToggleRow(String label, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            )
          ),
          Switch.adaptive(
            value: active, 
            onChanged: (v) {},
            activeColor: Color(0xFFF57C00),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, List<String> options) {
    String current = options.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            )
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: current,
              underline: SizedBox(),
              icon: Icon(Icons.arrow_drop_down),
              items: options
                  .map((o) => DropdownMenuItem(
                        child: Text(
                          o, 
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 15
                          )
                        ),
                        value: o,
                      ))
                  .toList(),
              onChanged: (v) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 20,
      thickness: 1,
      color: Colors.grey[300],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ActionButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.15),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.white),
        ),
      ),
      onPressed: () {},
    );
  }
}