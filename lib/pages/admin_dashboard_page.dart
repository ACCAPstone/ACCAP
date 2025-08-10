import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widget/notificationWidget.dart';
import 'admin_notifications_page.dart';
import 'admin_ticket_page.dart';
import 'package:firebase/widget/RightSideCalendarWidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase/widget/FullCommentDialog.dart';

class AdminDashboardPage extends StatefulWidget {
  final Function(int) updateIndex;
  final ScrollController scrollController;
  final void Function(List<String> filter) onImpairmentCardTap;
  const AdminDashboardPage({super.key,required this.updateIndex,required this.scrollController,required this.onImpairmentCardTap, });

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _recentTickets = [];
  List<GlobalKey> _postKeys = [];
  Map<String, int> _disabilityCounts = {
    'Hearing Impairment': 0,
    'Visual Impairment': 0,
    'Speech Impairment': 0,
    'Mobility Impairment': 0,
  };
  bool _isSidebarCollapsed = false;
  String? adminUsername;
  bool showUserList = false;
  List<String> selectedUserCategories = [];
  
  // Add separate scroll controllers
  final ScrollController _announcementsController = ScrollController();
  final ScrollController _requestsController = ScrollController();
  final ScrollController _calendarController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _loadUserCounts();
    _loadRecentTickets();
    _postKeys = List.generate(_announcements.length, (index) => GlobalKey());
    _fetchAdminUsername();
  }

  @override
  void dispose() {
    _announcementsController.dispose();
    _requestsController.dispose();
    _calendarController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(user.email).get();
      if (doc.exists) {
        setState(() {
          adminUsername = doc['username'] ?? 'Admin';
        });
      }
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _navigateToTicket(BuildContext context, String ticketNumber) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    List<String> collections = ["medication_requests", "wheelchair_requests", "service_requests"];

    for (String collection in collections) {
      var querySnapshot = await firestore
          .collection(collection)
          .where("ticketNumber", isEqualTo: ticketNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var ticketDoc = querySnapshot.docs.first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailPage(request: ticketDoc, adminUsername: adminUsername ?? 'Admin'),
          ),
        );
        return;
      }
    }
  }

  void _loadAnnouncements() {
    FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _announcements = snapshot.docs.map((doc) {
          var data = doc.data();
          var rawDate = data['timestamp'];

          DateTime parsedDate = (rawDate is Timestamp)
              ? rawDate.toDate()
              : DateTime.parse(rawDate);

          String formattedDate = DateFormat('MMMM dd, yyyy hh:mm a').format(parsedDate);

          return {
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'type': data ['type'] ?? 'No Type',
            'content': data['content'] ?? 'No Details',
            'timestamp': formattedDate,
          };
        }).toList();
        _postKeys = List.generate(_announcements.length, (index) => GlobalKey());
      });
    });
  }

  void _loadUserCounts() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      Map<String, int> tempCounts = {
        'Hearing Impairment': 0,
        'Visual Impairment': 0,
        'Speech Impairment': 0,
        'Mobility Impairment': 0,
      };

      for (var doc in snapshot.docs) {
        String? disabilityType = doc.data()['disabilityType'];
        if (disabilityType != null) {
          // Normalize the disability type to match our keys
          String normalizedType = disabilityType.trim();
          if (tempCounts.containsKey(normalizedType)) {
            tempCounts[normalizedType] = (tempCounts[normalizedType] ?? 0) + 1;
          }
        }
      }

      setState(() {
        _disabilityCounts = tempCounts;
      });
    });
  }

  void _loadRecentTickets() async {
    List<String> collections = ['medication_requests', 'wheelchair_requests', 'service_requests'];
    List<Map<String, dynamic>> allTickets = [];

    for (String collection in collections) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String formattedTime = 'No Date Available';
        if (data['timestamp'] is Timestamp) {
          formattedTime = DateFormat('MMMM dd, yyyy hh:mm a').format(data['timestamp'].toDate());
        }

        allTickets.add({
          'ticket#': data['requestNumber'] ?? 'No Ticket Number',
          'user': data['name'] ?? 'Unknown User',
          'message': data['reason'] ?? data['medicineName'] ?? 'No Message',
          'timestamp': formattedTime,
          'type': collection.replaceAll('_', ' '),
          'status': data['status'] ?? 'Pending',
        });
      }
    }

    allTickets.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    setState(() {
      _recentTickets = allTickets;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final double leftColWidth = screenWidth >= 1200 ? 320 : (screenWidth >= 768 ? 280 : 260);
    final double calendarCardHeight = screenWidth >= 1200 ? 500 : (screenWidth >= 768 ? 450 : 400);
    final double totalUsersBoxHeight = screenWidth >= 768 ? 120 : 100;
    final double rightColHeight = screenWidth >= 1200 ? 650 : (screenWidth >= 768 ? 600 : 550);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          fontSize: screenWidth >= 768 ? 25 : 20,
        ),
        title: Text(
          'DASHBOARD',
        ),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
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
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.all(screenWidth >= 768 ? 16.0 : 8.0),
        children: [
          isMobile
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Impairment Cards
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildImpairmentCard(context, "Visual Impairment", _disabilityCounts['Visual Impairment'] ?? 0, Icons.visibility, useExpanded: false),
                            const SizedBox(width: 12),
                            _buildImpairmentCard(context, "Hearing Impairment", _disabilityCounts['Hearing Impairment'] ?? 0, Icons.hearing, useExpanded: false),
                            const SizedBox(width: 12),
                            _buildImpairmentCard(context, "Speech Impairment", _disabilityCounts['Speech Impairment'] ?? 0, Icons.record_voice_over, useExpanded: false),
                            const SizedBox(width: 12),
                            _buildImpairmentCard(context, "Mobility Impairment", _disabilityCounts['Mobility Impairment'] ?? 0, Icons.accessible, useExpanded: false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Total Users + Calendar
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(minHeight: totalUsersBoxHeight),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: _buildTotalUsersBox(_disabilityCounts.values.fold(0, (sum, value) => sum + value)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: calendarCardHeight,
                              child: SingleChildScrollView(
                                child: Card(
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: EdgeInsets.zero,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: screenWidth >= 768 ? 280 : 260,
                                      maxWidth: screenWidth >= 768 ? 340 : 320,
                                    ),
                                    child: RightSideCalendarWidget(
                                      showRecentPosts: false,
                                      showNotificationIcon: false,
                                      scrollablePostsOnSelectedDay: true
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Announcements + Requests stacked
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Announcements",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 20 : 18,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                                SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _announcements.length,
                                  itemBuilder: (context, index) {
                                    final announcement = _announcements[index];
                                    return _buildAnnouncementCard(announcement);
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Recent Requests",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 20 : 18,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                                SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _recentTickets.length,
                                  itemBuilder: (context, index) {
                                    final ticket = _recentTickets[index];
                                    return _buildRequestCard(ticket);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Impairment Cards
                  Row(
                    children: [
                      Expanded(child: _buildImpairmentCard(context, "Visual Impairment", _disabilityCounts['Visual Impairment'] ?? 0, Icons.visibility)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildImpairmentCard(context, "Hearing Impairment", _disabilityCounts['Hearing Impairment'] ?? 0, Icons.hearing)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildImpairmentCard(context, "Speech Impairment", _disabilityCounts['Speech Impairment'] ?? 0, Icons.record_voice_over)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildImpairmentCard(context, "Mobility Impairment", _disabilityCounts['Mobility Impairment'] ?? 0, Icons.accessible)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: leftColWidth,
                          maxWidth: leftColWidth,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(minHeight: totalUsersBoxHeight),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: _buildTotalUsersBox(_disabilityCounts.values.fold(0, (sum, value) => sum + value)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: calendarCardHeight,
                              child: SingleChildScrollView(
                                controller: _calendarController,
                                child: Card(
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: EdgeInsets.zero,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: screenWidth >= 768 ? 280 : 260,
                                      maxWidth: screenWidth >= 768 ? 340 : 320,
                                    ),
                                    child: RightSideCalendarWidget(
                                      showRecentPosts: false,
                                      showNotificationIcon: false,
                                      scrollablePostsOnSelectedDay: true
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      // Right columns: Announcements and Member Requests
                      Expanded(
                        child: SizedBox(
                          height: rightColHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEAF6FB),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(screenWidth >= 768 ? 20 : 16),
                                  margin: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Announcements",
                                        style: TextStyle(
                                          fontSize: screenWidth >= 768 ? 20 : 18,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Expanded(
                                        child: Scrollbar(
                                          controller: _announcementsController,
                                          thumbVisibility: true,
                                          child: ListView.builder(
                                            controller: _announcementsController,
                                            itemCount: _announcements.length,
                                            itemBuilder: (context, index) {
                                              final announcement = _announcements[index];
                                              return _buildAnnouncementCard(announcement);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEAF6FB),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(screenWidth >= 768 ? 20 : 16),
                                  margin: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Member Requests",
                                        style: TextStyle(
                                          fontSize: screenWidth >= 768 ? 20 : 18,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Expanded(
                                        child: Scrollbar(
                                          controller: _requestsController,
                                          thumbVisibility: true,
                                          child: ListView.builder(
                                            controller: _requestsController,
                                            itemCount: _recentTickets.length,
                                            itemBuilder: (context, index) {
                                              final ticket = _recentTickets[index];
                                              return _buildRequestCard(ticket);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildImpairmentCard(BuildContext context, String label, int count, IconData icon, {bool useExpanded = true}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;
    final iconSize = isSmall ? 22.0 : 36.0;
    final labelFontSize = isSmall ? 11.0 : 16.0;
    final countFontSize = isSmall ? 14.0 : 24.0;
    final cardPadding = isSmall ? 10.0 : 24.0;
    final card = InkWell(
      onTap: () {
        widget.onImpairmentCardTap([label]);
      },
      child: Card(
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFFEAF6FB),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black87, size: iconSize),
              SizedBox(height: isSmall ? 6 : 12),
              Text(
                label,
                style: TextStyle(fontSize: labelFontSize, color: Colors.black54),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmall ? 6 : 12),
              Text(
                "$count Members",
                style: TextStyle(fontSize: countFontSize, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
    if (useExpanded) {
      return Expanded(child: card);
    } else {
      return SizedBox(width: 180, child: card);
    }
  }

  Widget _buildTotalUsersBox(int totalUserCount) {
    return InkWell(
      onTap: () {
        widget.onImpairmentCardTap([]);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Color(0xFFEAF6FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Total Members",
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              "$totalUserCount Members",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dialogWidth = constraints.maxWidth < 640 ? constraints.maxWidth : 600.0;
                  return SizedBox(
                    width: dialogWidth,
                    child: FullCommentDialog(
                      postId: announcement['id'],
                      adminUsername: adminUsername ?? 'Admin',
                    ),
                  );
                },
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // subtle shadow
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement['title'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${announcement['type']} • ${announcement['timestamp']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> ticket) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: GestureDetector(
        onTap: () async {
          List<String> collections = ["medication_requests", "wheelchair_requests", "service_requests"];
          for (String collection in collections) {
            var querySnapshot = await FirebaseFirestore.instance
                .collection(collection)
                .where("requestNumber", isEqualTo: ticket['ticket#'])
                .limit(1)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              var ticketDoc = querySnapshot.docs.first;
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: const Color.fromARGB(255, 250, 250, 250),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.height * 0.8,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 250, 250, 250),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.black),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Expanded(
                            child: TicketDetailPage(
                              request: ticketDoc,
                              adminUsername: adminUsername ?? 'Admin',
                              enableEnterSubmit: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return;
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // subtle shadow
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request No. #${ticket['ticket#'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'User: ${ticket['user'] ?? 'Unknown'} | Category: ${ticket['type'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Message: ${ticket['message'] ?? 'No Message'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final status = ticket['status'] ?? 'Pending';
                  Color statusColor;
                  if (status == 'Open') {
                    statusColor = Colors.green;
                  } else if (status == 'Closed') {
                    statusColor = Colors.red;
                  } else {
                    statusColor = Colors.orange;
                  }
                  return Container(
                    margin: EdgeInsets.only(left: 8, top: 2),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}