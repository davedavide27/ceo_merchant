import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationModal extends StatefulWidget {
  const NotificationModal({
    Key? key,
    required this.notifications,
    required this.onClose,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
    required this.onClearReadNotifications, // Updated type
    required this.animatedListKey,
    required this.onDeleteIndices,
  }) : super(key: key);

  final GlobalKey<AnimatedListState> animatedListKey;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function() onClearReadNotifications; // Updated to Future
  final VoidCallback onClose;
  final void Function(List<int>) onDeleteIndices; // <- NEW
  final VoidCallback onMarkAllAsRead;
  final void Function(int) onMarkAsRead;

  @override
  NotificationModalState createState() => NotificationModalState();

  static Future<void> close(BuildContext context) async {
    final state = context.findAncestorStateOfType<NotificationModalState>();
    if (state != null) {
      await state._closeModal();
    }
  }
}

class NotificationModalState extends State<NotificationModal>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const double _maxHeight = 400;
  static const double _minHeight = 0;

  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

    _controller.forward();
  }

  Future<void> _closeModal() async {
    await _controller.reverse();
    widget.onClose();
  }

  Future<void> _handleClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Clear'),
        content: const Text(
          'Are you sure you want to clear all read notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final listState = widget.animatedListKey.currentState;
    if (listState == null) return;

    // Indices of *read* notifications (iterate backwards)
    final readIndices = List<int>.generate(
      widget.notifications.length,
      (i) => i,
    ).reversed.where((i) => widget.notifications[i]['read'] as bool).toList();

    if (readIndices.isEmpty) return;

    // Animate them out
    for (final idx in readIndices) {
      final removed = widget.notifications[idx];
      listState.removeItem(
        idx,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          child: _buildNotificationItem(removed, idx),
        ),
        duration: const Duration(milliseconds: 200),
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Tell parent to delete exactly these indices
    widget.onDeleteIndices(readIndices);

    // Wait one frame so the modal rebuilds with the new (possibly empty) list
    await WidgetsBinding.instance.endOfFrame;

    // Now close if nothing is left
    if (widget.notifications.isEmpty) {
      await _closeModal();
    }
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
              : AnimatedList(
                  key: widget.animatedListKey,
                  initialItemCount: widget.notifications.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index, animation) {
                    final notification = widget.notifications[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      child: _buildNotificationItem(notification, index),
                    );
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
              const SizedBox(width: 8),
              TextButton(
                onPressed: _handleClear, // Use new handler
                child: const Text(
                  'Clear all',
                  style: TextStyle(color: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.notifications.where((n) => !n['read']).length;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final borderRadius = 20 * (_heightAnimation.value / _maxHeight);

          Widget container = Container(
            height: isLandscape
                ? _heightAnimation.value * 0.9
                : _heightAnimation.value,
            width: double.infinity,
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

          return container;
        },
        child: _buildContent(unreadCount),
      ),
    );
  }
}
