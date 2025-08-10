import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../pages/admin_notifications_page.dart';

class NotificationPopup extends StatefulWidget {
  const NotificationPopup({super.key});

  @override
  State<NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<NotificationPopup> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _visibleCount = 5;
  bool _showAllButton = false;

  void _showOverlay(BuildContext context) {
    _overlayEntry = _createOverlayEntry(context);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _visibleCount = 5;
      _showAllButton = false;
    });
  }

  OverlayEntry _createOverlayEntry(BuildContext context) {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + size.height + 8,
        right: 16,
        width: 370,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(-330, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                minWidth: 320,
                maxWidth: 370,
              ),
              child: NotificationList(
                visibleCount: _visibleCount,
                showAllButton: _showAllButton,
                onShowMore: () {
                  setState(() {
                    if (_visibleCount == 5) {
                      _visibleCount += 5;
                      _showAllButton = true;
                    } else {
                      // Show all: close popup and go to notification page
                      _hideOverlay();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AdminNotificationsPage()),
                      );
                    }
                  });
                  _overlayEntry?.markNeedsBuild();
                },
                onClose: _hideOverlay,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: const Icon(Icons.notifications, color: Colors.black),
        tooltip: "Notifications",
        onPressed: () {
          if (_overlayEntry == null) {
            _showOverlay(context);
          } else {
            _hideOverlay();
          }
        },
      ),
    );
  }
}

class NotificationList extends StatelessWidget {
  final int visibleCount;
  final bool showAllButton;
  final VoidCallback onShowMore;
  final VoidCallback onClose;

  const NotificationList({
    super.key,
    required this.visibleCount,
    required this.showAllButton,
    required this.onShowMore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        var notifications = snapshot.data!.docs;
        int showCount = visibleCount.clamp(0, notifications.length);
        var visibleNotifications = notifications.take(showCount).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (visibleNotifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text("No notifications."),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: visibleNotifications.length,
                itemBuilder: (context, index) {
                  var doc = visibleNotifications[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String message = (data['message'] ?? data['comment'] ?? 'No message').toString();
                  String? replyTextRaw = data['reply'] ?? data['comment'];
                  String replyText = replyTextRaw != null ? replyTextRaw.toString() : '';
                  String time = '';
                  if (data['timestamp'] is Timestamp) {
                    try {
                      time = DateFormat('MMM dd, hh:mm a').format((data['timestamp'] as Timestamp).toDate());
                    } catch (e) {
                      time = '';
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F3060),
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (replyText.isNotEmpty && replyText != message)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                replyText,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(time, style: const TextStyle(fontSize: 12)),
                      dense: true,
                    ),
                  );
                },
              ),
            ),
            if (visibleCount < notifications.length)
              TextButton(
                onPressed: onShowMore,
                child: Text(showAllButton ? "Show all" : "Show more",style: TextStyle(color: Colors.black),),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}