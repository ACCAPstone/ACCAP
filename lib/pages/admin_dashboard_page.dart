import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../widget/notificationWidget.dart';
import 'admin_voice_messages_page.dart';
import 'admin_notifications_page.dart';
import 'admin_ticket_page.dart';
import 'package:firebase/widget/RightSideCalendarWidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase/widget/FullCommentDialog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:async/async.dart';

const kSidebarColor = Color(0xFF0B2E4E);
const kSidebarIconColor = Color(0xFF4A90A4);
const kAlertBgColor = Color(0xFFF8D7DA);
const kAlertTextColor = Color(0xFF721C24);
const kAlertButtonColor = Color(0xFFE74C3C);
const kMemberCardColor = Color(0xFFE6F7FF);
const kTotalMemberCardColor = Color(0xFFFFF7E6);
const kRequestOpenColor = Color(0xFFE9F9EE);
const kRequestClosedColor = Color(0xFFF8D7DA);
const kRequestOpenButton = Color(0xFF27AE60);
const kRequestClosedButton = Color(0xFFE74C3C);

const kTransportationColor = Color(0xFFE74C3C);
const kMedicationColor = Color(0xFFF1C40F);
const kWheelchairColor = Color(0xFF3498DB);

class AdminDashboardPage extends StatefulWidget {
  final Function(int) updateIndex;
  final ScrollController scrollController;
  final void Function(List<String> filter) onImpairmentCardTap;
  const AdminDashboardPage({
    super.key,
    required this.updateIndex,
    required this.scrollController,
    required this.onImpairmentCardTap,
  });

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
  String _selectedChartRange = 'Last 7 days';
  String? _highlightedLine; // 'transportation', 'medication', 'wheelchair'
  
  // Add request chart data
  List<FlSpot> _transportationData = [];
  List<FlSpot> _medicationData = [];
  List<FlSpot> _wheelchairData = [];
  int _transportationCount = 0;
  int _medicationCount = 0;
  int _wheelchairCount = 0;
  
  // Add donut chart data
  int _totalRequests = 0;
  int _openRequests = 0;
  int _closedRequests = 0;

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
    _loadRequestData(); // Load initial request data
    _loadDonutChartData(); // Load initial donut chart data
    _postKeys = List.generate(_announcements.length, (index) => GlobalKey());
    _fetchAdminUsername();
  }

  Future<void> _markSosViewed(String docId) async {
    final adminId = FirebaseAuth.instance.currentUser?.email ??
        adminUsername ??
        'unknown_admin';
    try {
      await FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc(docId)
          .update({
        'viewedBy': FieldValue.arrayUnion([adminId])
      });
    } catch (e) {
      // ignore errors - best effort
    }
  }

  // Fetch the latest file Reference from Firebase Storage path 'emergency_locations'
  Future<Reference?> _fetchLatestStorageReference() async {
    try {
      final storage = FirebaseStorage.instance;
      final result = await storage.ref('emergency_locations').listAll();
      final items = result.items;
      if (items.isEmpty) return null;

      final List<MapEntry<Reference, DateTime?>> filesWithDate =
      await Future.wait(
        items.map((ref) async {
          try {
            final meta = await ref.getMetadata();
            return MapEntry(ref, meta.updated ?? meta.timeCreated);
          } catch (e) {
            return MapEntry(ref, null);
          }
        }),
      );

      filesWithDate.sort((a, b) {
        final aDate = a.value;
        final bDate = b.value;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return filesWithDate.first.key;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchJsonFromUrl(String url) async {
    try {
      final response = await html.HttpRequest.request(url);
      return jsonDecode(response.responseText!);
    } catch (e) {
      return null;
    }
  }

  // Clean a storage filename for display: remove extension, strip numeric sequences, and replace underscores with spaces
  String _cleanFileName(String fileName) {
    // Remove extension like .json
    String name = fileName.replaceAll(RegExp(r"\.[^\.]+"), '');
    // Replace underscores, dashes, dots with spaces
    name = name.replaceAll(RegExp(r'[_\-\.]'), ' ');
    // Remove standalone numeric sequences
    name = name.replaceAll(RegExp(r"\b\d+\b"), '');
    // Collapse multiple spaces and trim
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? fileName : name;
  }

  Widget _buildSosBanner() {
    final adminId = FirebaseAuth.instance.currentUser?.email ??
        adminUsername ??
        'unknown_admin';

    // Poll storage every 5 seconds for newest file
    final Stream<Reference?> storageStream =
    Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _fetchLatestStorageReference())
        .asBroadcastStream();

    return StreamBuilder<Reference?>(
      stream: storageStream,
      builder: (context, storageSnapshot) {
        if (!storageSnapshot.hasData || storageSnapshot.data == null)
          return const SizedBox.shrink();
        final ref = storageSnapshot.data!;
        final fileName = ref.name;

        // Listen to Firestore doc that tracks views for this storage file
        final docStream = FirebaseFirestore.instance
            .collection('sos_views')
            .doc(fileName)
            .snapshots();

        return StreamBuilder<DocumentSnapshot>(
          stream: docStream,
          builder: (context, viewSnapshot) {
            final docExists = viewSnapshot.hasData && viewSnapshot.data!.exists;
            final Map<String, dynamic>? viewData = docExists
                ? (viewSnapshot.data!.data() as Map<String, dynamic>?)
                : null;
            final viewedBy = viewData != null
                ? List<String>.from(
                (viewData['viewedBy'] ?? []) as List<dynamic>)
                : <String>[];
            final seenByMe = viewedBy.contains(adminId);

            return FutureBuilder<String>(
              future: ref.getDownloadURL(),
              builder: (context, urlSnap) {
                String locationText = _cleanFileName(fileName);
                String timeText = '';
                if (urlSnap.hasData) {
                  // attempt to parse JSON for nicer display
                  // ignore errors
                  _fetchJsonFromUrl(urlSnap.data!).then((json) {
                    // no setState here; we only use parsed json synchronously below when available
                  });
                }

                // use metadata timestamp if available
                return FutureBuilder<FullMetadata?>(
                  future: ref.getMetadata(),
                  builder: (context, metaSnap) {
                    if (metaSnap.hasData) {
                      final ts =
                          metaSnap.data!.updated ?? metaSnap.data!.timeCreated;
                      if (ts != null) {
                        try {
                          timeText =
                              DateFormat('MMMM dd, yyyy hh:mm a').format(ts);
                        } catch (_) {}
                      }
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SOS ALERT',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700)),
                                const SizedBox(height: 4),
                                Text(locationText,
                                    style: const TextStyle(fontSize: 14)),
                                if (timeText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(timeText,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700),
                            onPressed: () async {
                              // mark this SOS as viewed for this admin then open the specific emergency
                              try {
                                await FirebaseFirestore.instance
                                    .collection('sos_views')
                                    .doc(fileName)
                                    .set({
                                  'viewedBy': FieldValue.arrayUnion([adminId]),
                                  'timestamp': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              } catch (e) {}
                              if (context.mounted) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => AdminVoiceMessagesPage(
                                        initialFileName: fileName)));
                              }
                            },
                            child: const Text('View'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: seenByMe ? 'Seen' : 'Mark as seen for me',
                            onPressed: seenByMe
                                ? null
                                : () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('sos_views')
                                    .doc(fileName)
                                    .set({
                                  'viewedBy':
                                  FieldValue.arrayUnion([adminId]),
                                  'timestamp':
                                  FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              } catch (e) {}
                            },
                            icon: Icon(
                                seenByMe
                                    ? Icons.check_circle
                                    : Icons.visibility,
                                color:
                                seenByMe ? Colors.green : Colors.black54),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
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
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.email)
          .get();
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

    List<String> collections = [
      "medication_requests",
      "wheelchair_requests",
      "service_requests"
    ];

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
            builder: (context) => TicketDetailPage(
                request: ticketDoc, adminUsername: adminUsername ?? 'Admin'),
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

          String formattedDate =
          DateFormat('MMMM dd, yyyy hh:mm a').format(parsedDate);

          return {
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'type': data['type'] ?? 'No Type',
            'content': data['content'] ?? 'No Details',
            'timestamp': formattedDate,
          };
        }).toList();
        _postKeys =
            List.generate(_announcements.length, (index) => GlobalKey());
      });
    });
  }

  void _loadUserCounts() {
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
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
    List<String> collections = [
      'medication_requests',
      'wheelchair_requests',
      'service_requests'
    ];
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
          formattedTime = DateFormat('MMMM dd, yyyy hh:mm a')
              .format(data['timestamp'].toDate());
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

  void _loadRequestData() async {
    DateTime now = DateTime.now();
    DateTime startTime;
    
    switch (_selectedChartRange) {
      case 'Last hour':
        startTime = now.subtract(const Duration(hours: 1));
        break;
      case 'Last 7 days':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case 'Last 30 days':
        startTime = now.subtract(const Duration(days: 30));
        break;
      default:
        startTime = now.subtract(const Duration(days: 7));
    }

    // Load data from Firebase collections
    await _loadCollectionData('service_requests', startTime, now, _transportationData, (count) {
      _transportationCount = count;
    });
    
    await _loadCollectionData('medication_requests', startTime, now, _medicationData, (count) {
      _medicationCount = count;
    });
    
    await _loadCollectionData('wheelchair_requests', startTime, now, _wheelchairData, (count) {
      _wheelchairCount = count;
    });

    setState(() {});
  }

  Future<void> _loadCollectionData(String collection, DateTime startTime, DateTime endTime, 
      List<FlSpot> dataList, Function(int) setCount) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      setCount(snapshot.docs.length);
      
      // Group data by time intervals
      Map<String, int> timeGroups = {};
      
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] is Timestamp) {
          DateTime timestamp = data['timestamp'].toDate();
          String timeKey;
          
          if (_selectedChartRange == 'Last hour') {
            timeKey = DateFormat('HH:mm').format(timestamp);
          } else {
            timeKey = DateFormat('MMM dd').format(timestamp);
          }
          
          timeGroups[timeKey] = (timeGroups[timeKey] ?? 0) + 1;
        }
      }

      // Convert to chart data
      dataList.clear();
      List<String> sortedKeys = timeGroups.keys.toList()..sort();
      
      for (int i = 0; i < sortedKeys.length; i++) {
        dataList.add(FlSpot(i.toDouble(), timeGroups[sortedKeys[i]]!.toDouble()));
      }
    } catch (e) {
      print('Error loading $collection data: $e');
      setCount(0);
      dataList.clear();
    }
  }

  void _loadDonutChartData() async {
    List<String> collections = [
      'service_requests',
      'medication_requests',
      'wheelchair_requests'
    ];
    
    int totalRequests = 0;
    int openRequests = 0;
    int closedRequests = 0;

    for (String collection in collections) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .get();

        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          totalRequests++;
          
          // Check status - handle different possible status values
          String status = (data['status'] ?? 'pending').toString().toLowerCase();
          
          if (status == 'open' || status == 'pending' || status == 'in progress') {
            openRequests++;
          } else if (status == 'closed' || status == 'completed' || status == 'resolved') {
            closedRequests++;
          } else {
            // If status is unclear, count as open
            openRequests++;
          }
        }
      } catch (e) {
        print('Error loading $collection data for donut chart: $e');
      }
    }

    setState(() {
      _totalRequests = totalRequests;
      _openRequests = openRequests;
      _closedRequests = closedRequests;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final double leftColWidth =
    screenWidth >= 1200 ? 320 : (screenWidth >= 768 ? 280 : 260);
    final double calendarCardHeight =
    screenWidth >= 1200 ? 500 : (screenWidth >= 768 ? 450 : 400);
    final double totalUsersBoxHeight = screenWidth >= 768 ? 120 : 100;
    final double rightColHeight =
    screenWidth >= 1200 ? 650 : (screenWidth >= 768 ? 600 : 550);

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
                    bool hasUnread =
                        snapshot.hasData && snapshot.data!.docs.isNotEmpty;
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
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const AdminNotificationsPage()),
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
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.all(screenWidth >= 768 ? 16.0 : 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS banner (shows latest SOS; per-admin view tracked in 'sos_alerts' collection)
            _buildSosBanner(),
            const SizedBox(height: 24),
            isMobile
                ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Impairment Cards in 2x2 grid
                  Container(
                    height: 260, // Increased height for mobile to prevent overflow
                    child: Column(
                      children: [
                        // First row of impairment cards
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildImpairmentCard(
                                  context,
                                  "Visual Impairment",
                                  _disabilityCounts['Visual Impairment'] ?? 0,
                                  Icons.visibility,
                                  useExpanded: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildImpairmentCard(
                                  context,
                                  "Hearing Impairment",
                                  _disabilityCounts['Hearing Impairment'] ?? 0,
                                  Icons.hearing,
                                  useExpanded: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Second row of impairment cards
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildImpairmentCard(
                                  context,
                                  "Speech Impairment",
                                  _disabilityCounts['Speech Impairment'] ?? 0,
                                  Icons.record_voice_over,
                                  useExpanded: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildImpairmentCard(
                                  context,
                                  "Mobility Impairment",
                                  _disabilityCounts['Mobility Impairment'] ?? 0,
                                  Icons.accessible,
                                  useExpanded: false,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          height: 200, // Increased height for total users card to prevent overflow
                          child: _buildTotalUsersBox(_disabilityCounts
                              .values
                              .fold(0, (sum, value) => sum + value)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: calendarCardHeight,
                          child: SingleChildScrollView(
                            child: Card(
                              elevation: 2,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                              margin: EdgeInsets.zero,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth:
                                  screenWidth >= 768 ? 280 : 260,
                                  maxWidth:
                                  screenWidth >= 768 ? 340 : 320,
                                ),
                                child: RightSideCalendarWidget(
                                    showRecentPosts: false,
                                    showNotificationIcon: false,
                                    scrollablePostsOnSelectedDay: true),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Increased spacing between calendar and announcements
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
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _announcements.length,
                              itemBuilder: (context, index) {
                                final announcement =
                                _announcements[index];
                                return _buildAnnouncementCard(
                                    announcement);
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
                                  fontWeight: FontWeight.bold),
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
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Impairment Cards in 2x2 grid on left + Total Members on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: 2x2 grid of impairment cards (2/3 width)
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 320, // Increased height to fix overflow issue
                        child: Column(
                          children: [
                            // First row of impairment cards
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildImpairmentCard(
                                      context,
                                      "Visual Impairment",
                                      _disabilityCounts['Visual Impairment'] ?? 0,
                                      Icons.visibility,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildImpairmentCard(
                                      context,
                                      "Hearing Impairment",
                                      _disabilityCounts['Hearing Impairment'] ?? 0,
                                      Icons.hearing,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Second row of impairment cards
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildImpairmentCard(
                                      context,
                                      "Speech Impairment",
                                      _disabilityCounts['Speech Impairment'] ?? 0,
                                      Icons.record_voice_over,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildImpairmentCard(
                                      context,
                                      "Mobility Impairment",
                                      _disabilityCounts['Mobility Impairment'] ?? 0,
                                      Icons.accessible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right side: Total Members card (1/3 width)
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 320, // Same height as impairment cards container
                        child: _buildTotalUsersBox(_disabilityCounts
                            .values
                            .fold(0, (sum, value) => sum + value)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32), // Increased spacing
                // Requests Chart Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and filter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Number of Requests",
                            style: TextStyle(
                              fontSize: screenWidth >= 768 ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          // Filter dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedChartRange,
                              underline: const SizedBox(),
                              items: [
                                'Last hour',
                                'Last 7 days',
                                'Last 30 days',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedChartRange = newValue;
                                  });
                                  _loadRequestData();
                                  _loadDonutChartData(); // Load donut chart data when filter changes
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Request counts
                      Row(
                        children: [
                          Expanded(
                            child: _buildRequestCountItem(
                              "Transportation Request",
                              _transportationCount,
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRequestCountItem(
                              "Medication Request",
                              _medicationCount,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRequestCountItem(
                              "Wheelchair Request",
                              _wheelchairCount,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Chart title
                      Text(
                        "Requests Over Time",
                        style: TextStyle(
                          fontSize: screenWidth >= 768 ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Line chart
                      SizedBox(
                        height: 300,
                        child: _buildRequestsChart(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Donut Chart Section
                Row(
                  children: [
                    // First Donut Chart Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with title and total count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Member Request Status",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "Total: $_totalRequests",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Textual breakdown
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Open: $_openRequests",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Closed: $_closedRequests",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Donut Chart
                            Center(
                              child: SizedBox(
                                height: 120,
                                child: _buildDonutChart(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendItem("Open requests", const Color(0xFF2E86AB)),
                                _buildLegendItem("Closed requests", const Color(0xFF3F464F)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Second Donut Chart Card (identical)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with title and total count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Member Request Status",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "Total: $_totalRequests",
                                  style: TextStyle(
                                    fontSize: screenWidth >= 768 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Textual breakdown
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Open: $_openRequests",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Closed: $_closedRequests",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Donut Chart
                            Center(
                              child: SizedBox(
                                height: 120,
                                child: _buildDonutChart(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendItem("Open requests", const Color(0xFF2E86AB)),
                                _buildLegendItem("Closed requests", const Color(0xFF3F464F)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32), // Increased spacing
                // Requests Section - Full Width
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Requests",
                        style: TextStyle(
                          fontSize: screenWidth >= 768 ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 400, // Fixed height for scrollable area
                        child: ListView.builder(
                          itemCount: _recentTickets.length > 5 ? 5 : _recentTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _recentTickets[index];
                            return _buildRequestCard(ticket);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32), // Increased spacing
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
                          SizedBox(
                            height: calendarCardHeight,
                            child: SingleChildScrollView(
                              controller: _calendarController,
                              child: Card(
                                elevation: 2,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                                margin: EdgeInsets.zero,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                    screenWidth >= 768 ? 280 : 260,
                                    maxWidth:
                                    screenWidth >= 768 ? 340 : 320,
                                  ),
                                  child: RightSideCalendarWidget(
                                      showRecentPosts: false,
                                      showNotificationIcon: false,
                                      scrollablePostsOnSelectedDay: true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right columns: Announcements only
                    Expanded(
                      child: Container(
                        height: rightColHeight,
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
                        padding: EdgeInsets.all(
                            screenWidth >= 768 ? 20 : 16),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Announcements",
                              style: TextStyle(
                                  fontSize:
                                  screenWidth >= 768 ? 20 : 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12),
                            Expanded(
                              child: Scrollbar(
                                controller:
                                _announcementsController,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller:
                                  _announcementsController,
                                  itemCount: _announcements.length,
                                  itemBuilder: (context, index) {
                                    final announcement =
                                    _announcements[index];
                                    return _buildAnnouncementCard(
                                        announcement);
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
                const SizedBox(height: 40), // Increased bottom padding for scrolling
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpairmentCard(
      BuildContext context, String label, int count, IconData icon,
      {bool useExpanded = true}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;
    final iconSize = isSmall ? 24.0 : 36.0; // Slightly reduced icon size for better fit
    final labelFontSize = isSmall ? 11.0 : 16.0; // Optimized label font size
    final countFontSize = isSmall ? 13.0 : 20.0; // Optimized count font size
    final cardPadding = isSmall ? 10.0 : 18.0; // Optimized padding
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
              SizedBox(height: isSmall ? 6 : 12), // Optimized spacing
              Text(
                label,
                style:
                TextStyle(fontSize: labelFontSize, color: Colors.black54),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmall ? 6 : 12), // Optimized spacing
              Text(
                "$count Members",
                style: TextStyle(
                    fontSize: countFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
    if (useExpanded) {
      return Expanded(child: card);
    } else {
      return SizedBox(width: 170, child: card); // Slightly reduced width for mobile
    }
  }

  Widget _buildTotalUsersBox(int totalUserCount) {
    return InkWell(
      onTap: () {
        widget.onImpairmentCardTap([]);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity, // Fill the container height
        padding: const EdgeInsets.all(24.0), // Increased padding
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6), // Light beige/cream background
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Group icon with people including wheelchair user
            Container(
              padding: const EdgeInsets.all(16), // Increased padding
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups,
                size: 48, // Increased icon size
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16), // Increased spacing
            const Text(
              "Total Members:",
              style: TextStyle(
                fontSize: 18, // Increased font size
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8), // Increased spacing
            Text(
              "$totalUserCount Members",
              style: const TextStyle(
                fontSize: 32, // Increased font size
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
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
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dialogWidth =
                  constraints.maxWidth < 640 ? constraints.maxWidth : 600.0;
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
          List<String> collections = [
            "medication_requests",
            "wheelchair_requests",
            "service_requests"
          ];
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
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
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
                              icon:
                              const Icon(Icons.close, color: Colors.black),
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
            color: _getRequestCardColor(ticket['status'] ?? 'Pending'),
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
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.white,
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

  Color _getRequestCardColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
      case 'pending':
      case 'in progress':
        return Colors.green.shade50; // Light green background for open requests
      case 'closed':
      case 'completed':
      case 'resolved':
        return Colors.red.shade50; // Light red background for closed requests
      default:
        return Colors.green.shade50; // Default to light green for unknown status
    }
  }

  Widget _buildRequestCountItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: _getMaxX(),
        minY: 0,
        maxY: _getMaxY(),
        lineBarsData: [
          // Transportation Request (Red)
          LineChartBarData(
            spots: _transportationData,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red.shade600,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade400.withOpacity(0.3),
                  Colors.red.shade600.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Medication Request (Orange)
          LineChartBarData(
            spots: _medicationData,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.orange.shade600,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade400.withOpacity(0.3),
                  Colors.orange.shade600.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Wheelchair Request (Blue)
          LineChartBarData(
            spots: _wheelchairData,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue.shade600,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400.withOpacity(0.3),
                  Colors.blue.shade600.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                String label = '';
                if (barSpot.barIndex == 0) {
                  label = 'Transportation';
                } else if (barSpot.barIndex == 1) {
                  label = 'Medication';
                } else if (barSpot.barIndex == 2) {
                  label = 'Wheelchair';
                }
                return LineTooltipItem(
                  '$label: ${barSpot.y.toInt()}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _getMaxX() {
    int maxLength = 0;
    if (_transportationData.isNotEmpty) maxLength = _transportationData.length;
    if (_medicationData.isNotEmpty && _medicationData.length > maxLength) {
      maxLength = _medicationData.length;
    }
    if (_wheelchairData.isNotEmpty && _wheelchairData.length > maxLength) {
      maxLength = _wheelchairData.length;
    }
    return maxLength > 0 ? (maxLength - 1).toDouble() : 10.0;
  }

  double _getMaxY() {
    double maxY = 0;
    for (var spot in _transportationData) {
      if (spot.y > maxY) maxY = spot.y;
    }
    for (var spot in _medicationData) {
      if (spot.y > maxY) maxY = spot.y;
    }
    for (var spot in _wheelchairData) {
      if (spot.y > maxY) maxY = spot.y;
    }
    return maxY > 0 ? maxY + 1 : 10.0;
  }

  Widget _buildDonutChart() {
    if (_totalRequests == 0) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 30,
        pieTouchData: PieTouchData(enabled: false),
        sections: [
          // Open Requests (blue)
          if (_openRequests > 0)
            PieChartSectionData(
              color: const Color(0xFF2E86AB), // Updated blue color
              value: _openRequests.toDouble(),
              title: '',
              radius: 50,
            ),
          // Closed Requests (dark grey)
          if (_closedRequests > 0)
            PieChartSectionData(
              color: const Color(0xFF3F464F), // Updated dark grey color
              value: _closedRequests.toDouble(),
              title: '',
              radius: 50,
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
