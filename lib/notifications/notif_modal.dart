import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationModal extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onClose;
  final void Function(int) onMarkAsRead;
  final VoidCallback onMarkAllAsRead;

  const NotificationModal({
    Key? key,
    required this.notifications,
    required this.onClose,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
  }) : super(key: key);

  @override
  _NotificationModalState createState() => _NotificationModalState();
}

class _NotificationModalState extends State<NotificationModal>
    with SingleTickerProviderStateMixin {
  static const double _maxHeight = 400;
  static const double _minHeight = 0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _heightAnimation = Tween<double>(
      begin: _minHeight,
      end: _maxHeight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    // Start the open animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeModal() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.notifications.where((n) => !n['read']).length;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final borderRadius = 20 * (_heightAnimation.value / _maxHeight);

          return Container(
            height: _heightAnimation.value,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: _heightAnimation.value > 10
                  ? [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(borderRadius),
                bottomRight: Radius.circular(borderRadius),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          );
        },
        child: _buildContent(unreadCount),
      ),
    );
  }

  Widget _buildContent(int unreadCount) {
    return Column(
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _closeModal,
              ),
            ],
          ),
        ),

        // Notification list
        Expanded(
          child: widget.notifications.isEmpty
              ? Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: widget.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = widget.notifications[index];
                    return _buildNotificationItem(notification, index);
                  },
                ),
        ),

        // Footer with clear button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Text(
                '${widget.notifications.length} notifications',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onMarkAllAsRead,
                child: Text(
                  'Mark all as read',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: notification['read']
              ? Colors.grey[200]
              : Colors.teal.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.notifications,
          color: notification['read'] ? Colors.grey : Colors.teal,
        ),
      ),
      title: Text(
        notification['title'],
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: notification['read'] ? Colors.grey[700] : Colors.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const SizedBox(height: 4), Text(notification['message'])],
      ),
      trailing: Text(
        timeago.format(notification['time']),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () {
        widget.onMarkAsRead(index);
      },
    );
  }
}
