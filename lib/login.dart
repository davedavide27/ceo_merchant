import 'package:flutter/material.dart';
import 'local_database_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'loading.dart';
import 'Phone/dashboard.dart' as dashboard;

class Login extends StatefulWidget {
  final Function(Map<String, dynamic>) updateUserData;
  final String savedEmail;

  const Login({
    Key? key,
    required this.updateUserData,
    required this.savedEmail,
  }) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late WebSocketChannel? _channel;
  String _loginStatus = '';
  bool _rememberMe = false;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _showLoadingOverlay = true;

  @override
  void initState() {
    super.initState();
    // Prefill saved email if available
    if (widget.savedEmail.isNotEmpty) {
      _emailController.text = widget.savedEmail;
      _rememberMe = true;
    }
    _initializeLogin();
  }

  void _reconnectWebSocket() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    await Future.delayed(const Duration(seconds: 5));

    if (mounted) {
      setState(() {
        _isReconnecting = false;
      });
    }

    if (!_isConnected) {
      _initializeLogin();
    }
  }

  Future<void> _initializeLogin() async {
    if (!mounted) return;

    setState(() {
      _showLoadingOverlay = true;
      _loginStatus = 'Connecting to server...';
    });

    String? websocketUrl = dotenv.env['WEBSOCKET_URL'];
    if (websocketUrl == null || websocketUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _loginStatus = 'WebSocket URL is not configured.';
          _showLoadingOverlay = false;
        });
      }
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

      _channel!.stream.listen(
        (message) async {
          if (!mounted) return;

          try {
            final response = jsonDecode(message);

            if (response['type'] == 'connection_response') {
              if (response['status'] == 'connected') {
                if (mounted) {
                  setState(() {
                    _isConnected = true;
                    _showLoadingOverlay = false;
                    _loginStatus = 'Connected to server';
                  });
                }
              } else {
                if (mounted) {
                  setState(() {
                    _isConnected = false;
                    _showLoadingOverlay = true;
                    _loginStatus = 'Connection failed. Please try again.';
                  });
                }
              }
            } else if (response['type'] == 'login_response') {
              if (response['success'] == true) {
                String businessName =
                    response['user']?['business_name'] ?? 'Unknown Business';
                int userId =
                    int.tryParse(response['user']?['id']?.toString() ?? '0') ??
                    0;
                String email = response['user']?['email'] ?? '';

                if (userId > 0 && email.isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _loginStatus = 'Business Name: $businessName';
                      _isConnected = true;
                      _showLoadingOverlay = false;
                    });
                  }

                  // Create new user data
                  final newUserData = {
                    'user_id': userId.toString(),
                    'business_name': businessName,
                    'email': email,
                  };

                // Update app state
                widget.updateUserData(newUserData);
                // Set login flag true on successful login
                await LocalDatabaseHelper().setLoginFlag(true);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  // Close any open dialogs
                  if (Navigator.canPop(context)) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          dashboard.DashboardScreen(userId: userId),
                    ),
                  );
                });
              } else {
                if (mounted) {
                  setState(() {
                    _loginStatus = 'Invalid user data received from server.';
                    _showLoadingOverlay = false;
                  });
                }
              }
            } else {
              if (mounted) {
                setState(() {
                  _loginStatus =
                      response['message'] ??
                      'Login failed. Please try again.';
                  _showLoadingOverlay = false;
                });
              }
            }
          } else if (response['type'] == 'error') {
            if (mounted) {
              setState(() {
                _loginStatus = response['message'] ?? 'An error occurred.';
                _showLoadingOverlay = false;
              });
            }
          } else if (response['type'] == 'ping') {
            _channel?.sink.add(jsonEncode({'type': 'pong'}));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _loginStatus = 'Error processing server response: $e';
              _showLoadingOverlay = false;
            });
          }
        }
      },
        onError: (error) {
          print('WebSocket error: $error');
          if (!mounted) return;
          setState(() {
            _loginStatus = 'WebSocket error: $error';
            _isConnected = false;
            _showLoadingOverlay = true;
          });
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          if (mounted) {
            setState(() {
              _loginStatus = 'WebSocket connection closed. Retrying...';
              _isConnected = false;
              _showLoadingOverlay = true;
            });
          }
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      if (mounted) {
        setState(() {
          _loginStatus = 'Failed to connect to WebSocket: $e';
          _isConnected = false;
          _showLoadingOverlay = true;
        });
      }
      _reconnectWebSocket();
    }
  }

  void _handleLogin() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        setState(() {
          _loginStatus = 'Please enter both email and password.';
          _showLoadingOverlay = false;
        });
      }
      return;
    }

    if (!_isConnected) {
      if (mounted) {
        setState(() {
          _loginStatus =
              'Not connected to the server. Please check your connection.';
          _showLoadingOverlay = false;
        });
      }
      return;
    }

    print('Sending login request to server');
    _channel?.sink.add(
      jsonEncode({'type': 'login', 'email': email, 'password': password}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Logo/Image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.business,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Email Field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.lock, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Remember Me Row
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: Colors.orange,
                            ),
                            const Text(
                              'Remember Me',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Status message
                        Text(
                          _loginStatus,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
      // Loading overlay
      bottomSheet: _showLoadingOverlay
          ? Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              color: Colors.black54,
              child: Center(
                child: LoadingAnimation(
                  isVisible: true,
                  message: _isConnected
                      ? 'Authenticating...'
                      : 'Connecting to server...',
                ),
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _channel?.sink.close();
    super.dispose();
  }
}
