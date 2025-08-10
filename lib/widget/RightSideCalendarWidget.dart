import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widget/notificationWidget.dart';
import '../pages/admin_notifications_page.dart';

class RightSideCalendarWidget extends StatefulWidget {
  final bool showRecentPosts;
  final bool showNotificationIcon;
  final bool scrollablePostsOnSelectedDay;
  const RightSideCalendarWidget({super.key, this.showRecentPosts = true, this.showNotificationIcon = true, this.scrollablePostsOnSelectedDay = false});

  @override
  State<RightSideCalendarWidget> createState() => _RightSideCalendarWidgetState();
}

class _RightSideCalendarWidgetState extends State<RightSideCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _eventDays = {};

  @override
  void initState() {
    super.initState();
    _loadEventDays();
  }

  Future<void> _loadEventDays() async {
    try {
      final eventSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('isEvent', isEqualTo: true)
          .get();

      final eventDays = eventSnapshot.docs.map((doc) {
        final eventDate = (doc.data()['eventDate'] as Timestamp).toDate();
        return DateTime(eventDate.year, eventDate.month, eventDate.day);
      }).toSet();

      setState(() {
        _eventDays = eventDays;
      });
    } catch (e) {
      print("⚠️ Error loading event days: $e");
    }
  }

  List<DateTime> _getEventsForDay(DateTime day) {
    return _eventDays.where((eventDay) => 
      eventDay.year == day.year && 
      eventDay.month == day.month && 
      eventDay.day == day.day
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        double containerWidth = screenWidth > 600 ? 350 : screenWidth * 0.95;
        return Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: containerWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showNotificationIcon)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, right: 0.0, bottom: 8.0),
                      child: buildNotificationIcon(context),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: Colors.white)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text("\uD83D\uDCC5 Calendar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TableCalendar(
                          firstDay: DateTime.utc(2023, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const { CalendarFormat.month: 'Month' },
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                            markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                          eventLoader: _getEventsForDay,
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isNotEmpty) {
                                return Positioned(
                                  bottom: 1,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleTextStyle: TextStyle(
                              fontSize: (screenWidth > 600 && screenWidth < 900) ? 16 : 20,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                            titleCentered: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("🧾 Posts on Selected Day", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_selectedDay == null)
                          const Text("Select a date to see posts.")
                        else
                          SizedBox(
                            height: 220,
                            child: FutureBuilder<List<DocumentSnapshot>>(
                              future: _getCombinedPostsForDay(_selectedDay!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Center(child: Text("No posts for this day."));
                                } else {
                                  final posts = snapshot.data!;
                                  return ListView.builder(
                                    itemCount: posts.length,
                                    itemBuilder: (context, index) {
                                      final data = posts[index].data() as Map<String, dynamic>;
                                      final title = data['title'] ?? 'Untitled Post';
                                      final type = data['type'] ?? 'General';
                                      final filters = (data['filters'] as List?)?.join(', ') ?? 'All';
                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("📌 $title", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                              Text("📂 Type: $type"),
                                              Text("🏷️ Filters: $filters"),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ),

                        if (widget.showRecentPosts) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text("📰 Recent Posts (Last 3 Days)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('announcements')
                                  .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))))
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Text("Loading...");
                                final posts = snapshot.data!.docs;
                                if (posts.isEmpty) {
                                  return const Text("No recent posts in the last 3 days.");
                                }
                                return ListView.builder(
                                  itemCount: posts.length,
                                  itemBuilder: (context, index) {
                                    final doc = posts[index];
                                    final title = doc['title'] ?? 'No Title';
                                    final timestamp = (doc['timestamp'] as Timestamp).toDate();
                                    final timeAgo = _getTimeAgo(timestamp);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text("• $title ($timeAgo)", style: const TextStyle(fontSize: 14)),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

Future<List<DocumentSnapshot>> _getCombinedPostsForDay(DateTime selectedDay) async {
  final start = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
  final end = start.add(const Duration(days: 1));

  try {
    // Fetch event posts
    final eventPostsSnapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .where('isEvent', isEqualTo: true)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('eventDate', isLessThan: Timestamp.fromDate(end))
        .get();

    // Fetch non-event posts
    final nonEventPostsSnapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .where('isEvent', isEqualTo: false)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    final allPosts = [...eventPostsSnapshot.docs, ...nonEventPostsSnapshot.docs];

    print("📅 Posts found for $start to $end: ${allPosts.length}");

    return allPosts;
  } catch (e) {
    print("⚠️ Error fetching posts: $e");
    return [];
  }
}

String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
  } else {
    return 'Just now';
  }
}

Widget buildNotificationIcon(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth >= 900) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          children: [
            NotificationPopup(),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  } else {
    return IconButton(
      icon: Icon(Icons.notifications, color: Colors.black),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => SafeArea(
            child: Container(
              color: Colors.white,
              height: MediaQuery.of(context).size.height * 0.7,
              child: NotificationList(
                visibleCount: 5,
                showAllButton: false,
                onShowMore: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AdminNotificationsPage()),
                  );
                },
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        );
      },
    );
  }
}

}
