import 'package:firebase/pages/admin_settings_page.dart';
import 'package:firebase/widget/FullCommentDialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_dashboard_page.dart';
import 'admin_ticket_page.dart';
import 'AdminCreatePostDialog.dart';
import 'admin_user_full_list_page.dart';
import 'create_admin_page.dart';
import 'login_page.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'admin_voice_messages_page.dart';
import '../widget/RightSideCalendarWidget.dart';
import 'admin_notifications_page.dart';
import '../widget/notificationWidget.dart';


class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});


  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'General', 'Seminar', 'Job Offering'];
  final bool _isSidebarExpanded = false;
  Map<String, dynamic>? userDetails;
  String? adminEmail;
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AdminUserFullListPageState> membersListKey = GlobalKey<AdminUserFullListPageState>();
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  List<GlobalKey> _postKeys = [];
  bool isSuperAdmin = false;
  bool isBarangayAccount = false;


final ScrollController _localScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    _checkSuperAdmin();
  }

  String formatContactNumber(String number) {
    if (number.startsWith('+63')) {
      return '0${number.substring(3)}';
    } else if (number.startsWith('63')) {
      return '0${number.substring(2)}';
    }
    return number;
  }

  Future<void> _checkSuperAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(currentUser.email)
          .get();

      if (adminDoc.exists) {
        final data = adminDoc.data();
        if (data != null) {
          if (data['superAdmin'] == true) {
            setState(() {
              isSuperAdmin = true;
            });
          }
          if (data['role'] == 'barangay') {
            setState(() {
              isBarangayAccount = true;
            });
          }
        }
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  void _updateIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection("admins").doc(user.email).get();
      if (userDoc.exists) {
        setState(() {
          userDetails = userDoc.data() as Map<String, dynamic>?;
          adminEmail = user.email;
          isLoading = false;
        });
      } else {
        setState(() {
          adminEmail = null;
          isLoading = false;
        });
      }
    } else {
      setState(() => isLoading = false);
    }
  }
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void signOut(BuildContext context) async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",style: TextStyle(color: Colors.black),),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(user.email)
                    .update({'isOnline': false});
              }
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Clear the navigation stack and navigate directly to LoginPage
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage(onTap: null)),
                      (route) => false, // This ensures the entire stack is cleared
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      // No need to call signOut here, it's already handled inside the dialog's action.
    }
  }
  final Map<String, bool> _replyVisibilityMap = {};

Widget _buildCommentSection(String postId, String commentId, Map<String, dynamic> commentData) {
  TextEditingController replyController = TextEditingController();

  // Initialize if not already
  _replyVisibilityMap.putIfAbsent(commentId, () => false);

  return StatefulBuilder(
    builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${commentData['user'] ?? 'Anonymous'}: ${commentData['comment']}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(commentData['timestamp']),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Delete Comment"),
                              content: const Text("Are you sure you want to delete this comment?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await FirebaseFirestore.instance
                                .collection('announcements')
                                .doc(postId)
                                .collection('comments')
                                .doc(commentId)
                                .delete();
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _replyVisibilityMap[commentId] = !_replyVisibilityMap[commentId]!;
                });
              },
              child: const Text("Reply", style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 4),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .collection('replies')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!.docs.map((replyDoc) {
                    var reply = replyDoc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "↳ ${reply['author'] ?? 'Anonymous'}: ${reply['text']}",
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTimestamp(reply['timestamp']),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Delete Reply"),
                                        content: const Text("Are you sure you want to delete this reply?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await FirebaseFirestore.instance
                                          .collection('announcements')
                                          .doc(postId)
                                          .collection('comments')
                                          .doc(commentId)
                                          .collection('replies')
                                          .doc(replyDoc.id)
                                          .delete();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (_replyVisibilityMap[commentId] == true)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      decoration: const InputDecoration(hintText: "Write a reply..."),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (replyController.text.trim().isNotEmpty) {
                        FirebaseFirestore.instance
                            .collection('announcements')
                            .doc(postId)
                            .collection('comments')
                            .doc(commentId)
                            .collection('replies')
                            .add({
                          'text': replyController.text.trim(),
                          'timestamp': Timestamp.now(),
                          'author': userDetails?['name'] ?? 'Admin',
                        });
                        replyController.clear();
                        setState(() {
                          _replyVisibilityMap[commentId] = false;
                        });
                      }
                    },
                  )
                ],
              ),
          ],
        ),
      );
    },
  );
}


  void _showAcknowledgedDialog(String postId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection("notifications")
        .where("postId", isEqualTo: postId)
        .where("action", isEqualTo: "received")
        .get();

    List<List<String>> acknowledgedData = [
      ['User', 'Action']
    ];

    for (var doc in snapshot.docs) {
      var data = doc.data();
      acknowledgedData.add([
        data['user'] ?? 'Unknown',
        data['action'] ?? 'N/A',
      ]);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recipients'),
          backgroundColor: const Color(0xFFFAFAFA),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                return ListTile(
                  title: Text(data['user'] ?? 'Unknown'),
                  subtitle: Text(data['action'] ?? 'No action'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAttendeesDialog(BuildContext context, String postId) async {
    var seminarDoc = await FirebaseFirestore.instance
        .collection("announcements")
        .doc(postId)
        .get();

    String seminarTitle = "Seminar";
    if (seminarDoc.exists) {
      var data = seminarDoc.data()!;
      if ((data['type'] ?? '').toString().toLowerCase().contains('seminar')) {
        seminarTitle = data['title'] ?? "Seminar";
      }
    }

    var snapshot = await FirebaseFirestore.instance
        .collection("notifications")
        .where("postId", isEqualTo: postId)
        .where("action", isEqualTo: "attended")
        .get();

    List<List<String>> attendeesData = [
      ['Member Number', 'Name', 'Contact Number', 'Signature']
    ];

    int memberNumber = 1;
    for (var doc in snapshot.docs) {
      var data = doc.data();
      String name = 'Unknown';
      String contactNumber = '';
      String userEmail = data['user'] ?? '';
      if (userEmail.isNotEmpty) {
        var userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          var userData = userQuery.docs.first.data();
          name = [
            userData['firstName'] ?? '',
            userData['middleName'] ?? '',
            userData['lastName'] ?? ''
          ].where((s) => s.isNotEmpty).join(' ');
          contactNumber = formatContactNumber(userData['contactNumber'] ?? '');
        }
      }

      attendeesData.add([
        memberNumber.toString(),
        name,
        contactNumber,
        '',
      ]);
      memberNumber++;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Attendees'),
          backgroundColor: const Color(0xFFFAFAFA),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                return ListTile(
                  title: Text(data['user'] ?? 'Unknown'),
                  subtitle: Text(data['action'] ?? 'No email'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                var excel = ex.Excel.createExcel();
                var sheet = excel['Sheet1'];

                var title = 'Attendees of $seminarTitle';
                var titleCell = sheet.cell(ex.CellIndex.indexByString("A1"));
                titleCell.value = title;
                titleCell.cellStyle = ex.CellStyle(
                  backgroundColorHex: "#003060",
                  fontColorHex: "#FFFFFF",
                  bold: true,
                  fontSize: 14,
                  horizontalAlign: ex.HorizontalAlign.Center,
                  verticalAlign: ex.VerticalAlign.Center,
                );
                sheet.merge(
                  ex.CellIndex.indexByString("A1"),
                  ex.CellIndex.indexByString("D1"),
                );

                sheet.appendRow(attendeesData[0]);

                for (int i = 1; i < attendeesData.length; i++) {
                  sheet.appendRow(attendeesData[i]);
                }

                for (int i = 0; i < attendeesData[0].length; i++) {
                  var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
                  cell.cellStyle = ex.CellStyle(
                    bold: true,
                    fontSize: 12,
                    horizontalAlign: ex.HorizontalAlign.Center,
                    verticalAlign: ex.VerticalAlign.Center,
                  );
                }

                for (int rowIdx = 1; rowIdx < attendeesData.length; rowIdx++) {
                  for (int colIdx = 0; colIdx < attendeesData[rowIdx].length; colIdx++) {
                    var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx + 1));
                    cell.cellStyle = ex.CellStyle(
                      fontSize: 12,
                      horizontalAlign: ex.HorizontalAlign.Center,
                      verticalAlign: ex.VerticalAlign.Center,
                    );
                  }
                }
                sheet.setColWidth(0, 20); // Member Number
                sheet.setColWidth(1, 45); // Name (wider)
                sheet.setColWidth(2, 45); // Contact Number (wider)
                sheet.setColWidth(3, 50); // Signature (widest)

                final bytes = excel.encode();
                if (bytes == null) return;

                final blob = html.Blob([Uint8List.fromList(bytes)]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute("download", "Attendees of $seminarTitle.xlsx")
                  ..click();
                html.Url.revokeObjectUrl(url);
              },
              child: const Text('Download Excel'),
            ),
          ],
        );
      },
    );
  }

  void _showApplicantsDialog(String postId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('jobApplications')
        .where('postId', isEqualTo: postId)
        .get();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Job Applicants'),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                String userEmail = data['user'] ?? 'Unknown';
                String action = data['action'] ?? 'Applied';
                String resumeUrl = data['resumeUrl'] ?? '';

                return ListTile(
                  title: Text(userEmail),
                  subtitle: Text(action),
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () {
                      _openResumeInNewTab(resumeUrl);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close',style: TextStyle(color: Colors.black),)),
            TextButton(
              onPressed: () async {
                // 1. Get the announcement post to fetch the title
                var postDoc = await FirebaseFirestore.instance
                    .collection('announcements')
                    .doc(postId)
                    .get();
                String postTitle = postDoc.exists ? (postDoc.data()?['title'] ?? 'Job Post') : 'Job Post';

                // 2. Prepare Excel
                var excel = ex.Excel.createExcel();
                var sheet = excel['Sheet1'];

                // 3. Set the title in the first row and merge cells
                var title = 'Job Applicants';
                var titleCell = sheet.cell(ex.CellIndex.indexByString("A1"));
                titleCell.value = title;
                titleCell.cellStyle = ex.CellStyle(
                  backgroundColorHex: "#003060",
                  fontColorHex: "#FFFFFF",
                  bold: true,
                  fontSize: 14,
                  horizontalAlign: ex.HorizontalAlign.Center,
                  verticalAlign: ex.VerticalAlign.Center,
                );
                sheet.merge(
                  ex.CellIndex.indexByString("A1"),
                  ex.CellIndex.indexByString("C1"),
                );

                double titleWidth = (title.length * 1.2).clamp(30, 80).toDouble();
                sheet.setColWidth(0, titleWidth);
                sheet.setColWidth(1, titleWidth);
                sheet.setColWidth(2, titleWidth);

                // 4. Add header row
                sheet.appendRow(['Name', 'Contact Number', 'Email']);

                // 5. Add applicant data
                for (var doc in snapshot.docs) {
                  var data = doc.data();
                  String userEmail = data['user'] ?? '';
                  String name = 'Unknown';
                  String contactNumber = '';

                  if (userEmail.isNotEmpty) {
                    var userQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: userEmail)
                        .limit(1)
                        .get();
                    if (userQuery.docs.isNotEmpty) {
                      var userData = userQuery.docs.first.data();
                      name = [
                        userData['firstName'] ?? '',
                        userData['middleName'] ?? '',
                        userData['lastName'] ?? ''
                      ].where((s) => s.isNotEmpty).join(' ');
                      contactNumber = formatContactNumber(userData['contactNumber'] ?? '');
                    }
                  }

                  sheet.appendRow([name, contactNumber, userEmail]);
                }

                // 6. Style header row
                for (int i = 0; i < 3; i++) {
                  var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
                  cell.cellStyle = ex.CellStyle(
                    bold: true,
                    fontSize: 12,
                    horizontalAlign: ex.HorizontalAlign.Center,
                    verticalAlign: ex.VerticalAlign.Center,
                  );
                }

                // 7. Adjust column widths
                sheet.setColWidth(0, 30); // Name
                sheet.setColWidth(1, 25); // Contact Number
                sheet.setColWidth(2, 35); // Email

                // 8. Download the file
                final bytes = excel.encode();
                if (bytes == null) return;

                final blob = html.Blob([Uint8List.fromList(bytes)]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute("download", "Job Applicants for $postTitle.xlsx")
                  ..click();
                html.Url.revokeObjectUrl(url);
              },
              child: const Text('Download Excel',style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _openResumeInNewTab(String resumeUrl) async {
    if (await canLaunch(resumeUrl)) {
      await launch(resumeUrl);
    } else {
      print('Could not open resume URL: $resumeUrl');
    }
  }

 @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 426;
  final isVerySmallScreen = screenWidth <= 425;
  final sidebarWidth = isSmallScreen ? 0.0 : (screenWidth > 1200 ? 300.0 : 220.0);

  return Scaffold(
    key: _scaffoldKey,
    drawer: isSmallScreen ? Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 0, 48, 96),
            ),
            child: Center(
              child: Image.asset(
                'assets/ACCAP_LOGO.png',
                height: 60,
              ),
            ),
          ),
          _buildNavItem(Icons.dashboard, "Dashboard", 0, isSmallScreen),
          _buildNavItem(Icons.report, "Emergency Alerts", 5, isSmallScreen),
          if (!isBarangayAccount) ...[
            _buildNavItem(Icons.confirmation_num, "Requests", 2, isSmallScreen),
            _buildNavItem(Icons.post_add, "Announcements", 3, isSmallScreen),
            const Padding(
              padding: EdgeInsets.only(left: 10.0, top: 16.0, bottom: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "User Management",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black54,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0.0),
              child: _buildNavItem(Icons.people, "Members List", 6, isSmallScreen),
            ),
          ],
          if (isSuperAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 0.0),
              child: _buildNavItem(
                Icons.admin_panel_settings,
                "Admin Management",
                4,
                isSmallScreen,
              ),
            ),
          const Divider(),
          _buildNavItem(Icons.settings, "Account Settings", 7, isSmallScreen),
          _buildNavItem(Icons.logout, "Logout", -1, isSmallScreen),
        ],
      ),
    ) : null,
    appBar: isSmallScreen ? AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.black),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: null,
      elevation: 0,
    ) : null,
    body: SafeArea(
      child: Stack(
        children: [
          Container(
            color: Colors.white,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isSmallScreen)
                        Container(
                          width: sidebarWidth,
                          color: Colors.white,
                          child: Column(
                            children: [
                              Container(
                                color: Color.fromARGB(255, 0, 48, 96),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/ACCAP_LOGO.png',
                                      height: 48,
                                      fit: BoxFit.contain,
                                    ),
                                    if (MediaQuery.of(context).size.width >= 768) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            "ACCAP",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              _buildNavItem(Icons.dashboard, "Dashboard", 0, isSmallScreen),
                              _buildNavItem(Icons.report, "Emergency Alerts", 5, isSmallScreen),
                              if (!isBarangayAccount) ...[
                                _buildNavItem(Icons.confirmation_num, "Requests", 2, isSmallScreen),
                                _buildNavItem(Icons.post_add, "Announcements", 3, isSmallScreen),
                                const Padding(
                                  padding: EdgeInsets.only(left: 10.0, top: 16.0, bottom: 4.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "User Management",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black54,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 0.0),
                                  child: _buildNavItem(Icons.people, "Members List", 6, isSmallScreen),
                                ),
                              ],
                              if (isSuperAdmin)
                                Padding(
                                  padding: const EdgeInsets.only(left: 0.0),
                                  child: _buildNavItem(
                                    Icons.admin_panel_settings,
                                    "Admin Management",
                                    4,
                                    isSmallScreen,
                                  ),
                                ),
                              const Spacer(),
                              _buildNavItem(Icons.settings, "Account Settings", 7, isSmallScreen),
                              _buildNavItem(Icons.logout, "Logout", -1, isSmallScreen),
                            ],
                          ),
                        ),
                      if (!isSmallScreen)
                        Container(
                          width: 3,
                          color: Colors.grey.shade300,
                        ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Content
                            Expanded(
                              flex: 4,
                              child: Stack(
                                children: [
                                  IndexedStack(
                                    index: _currentIndex,
                                    children: [
                                      AdminDashboardPage(
                                        updateIndex: (int idx) {
                                          setState(() {
                                            _currentIndex = idx;
                                          });
                                        },
                                        scrollController: _scrollController,
                                        onImpairmentCardTap: (List<String> filter) {
                                          setState(() {
                                            _currentIndex = 1;
                                          });
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            membersListKey.currentState?.setFilter(filter);
                                          });
                                        },
                                      ),
                                      // For barangay accounts, show restricted access message for restricted pages
                                      isBarangayAccount && _currentIndex == 1 
                                          ? _buildRestrictedAccessPage()
                                          : AdminUserFullListPage(
                                              key: membersListKey,
                                              initialSelectedCategories: [],
                                            ),
                                      isBarangayAccount && _currentIndex == 2 
                                          ? _buildRestrictedAccessPage()
                                          : AdminTicketPage(adminUsername: userDetails?['username'] ?? 'Admin'),
                                      isBarangayAccount && _currentIndex == 3 
                                          ? _buildRestrictedAccessPage()
                                          : _buildHomePage(),
                                      isBarangayAccount && _currentIndex == 4 
                                          ? _buildRestrictedAccessPage()
                                          : CreateAdminPage(),
                                      AdminVoiceMessagesPage(),
                                      isBarangayAccount && _currentIndex == 6 
                                          ? _buildRestrictedAccessPage()
                                          : AdminUserFullListPage(),
                                      AdminSettingsPage(),
                                    ],
                                  ),
                                  // Floating Filter & Calendar Buttons for Post Page (Announcements) only
                                  if (_currentIndex == 3 && screenWidth <= 768)
                                    Positioned(
                                      bottom: 16,
                                      right: 16,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Calendar Button (now purple and on the left)
                                          FloatingActionButton.extended(
                                            heroTag: 'calendar_fab',
                                            backgroundColor: const Color(0xFFB39DDB),
                                            icon: const Icon(Icons.calendar_month),
                                            label: const Text('Calendar'),
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                shape: const RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                                ),
                                                builder: (context) => SafeArea(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 24),
                                                    child: SizedBox(
                                                      height: MediaQuery.of(context).size.height * 0.85,
                                                      child: RightSideCalendarWidget(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          // Filter Button (now purple and on the right)
                                          FloatingActionButton.extended(
                                            heroTag: 'filter_fab',
                                            backgroundColor: const Color(0xFFB39DDB),
                                            icon: const Icon(Icons.filter_list),
                                            label: const Text('Filter'),
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                shape: const RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                                ),
                                                builder: (context) => Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      const Text(
                                                        "Filter by Type",
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F3060),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      ...['All', 'General', 'Seminar', 'Job Offering'].map((filter) {
                                                        final isSelected = _selectedFilter == filter;
                                                        return Center(
                                                          child: ListTile(
                                                            selected: isSelected,
                                                            selectedTileColor: const Color(0xFF0F3060).withOpacity(0.1),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                            leading: Icon(
                                                              Icons.label,
                                                              color: isSelected ? const Color.fromARGB(255, 250, 250, 250) : Colors.black,
                                                            ),
                                                            title: Text(
                                                              filter,
                                                              style: TextStyle(
                                                                color: isSelected ? const Color.fromARGB(255, 250, 250, 250) : Colors.black,
                                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(context);
                                                              setState(() {
                                                                _selectedFilter = filter;
                                                              });
                                                            },
                                                          ),
                                                        );
                                                      }),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Calendar Sidebar for Large Screens
                            if (_currentIndex == 3 && screenWidth > 1000)
                              Container(
                                width: 3,
                                color: Colors.grey.shade300,
                              ),
                            if (_currentIndex == 3 && screenWidth > 1000)
                              Container(
                                width: 370,
                                color: Colors.transparent,
                                child: RightSideCalendarWidget(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildRestrictedAccessPage() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 24),
            Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Barangay accounts can only access Dashboard and Emergency Alerts.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0; // Go back to dashboard
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                foregroundColor: Colors.white,
              ),
              child: Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon,
      String label,
      int index,
      bool isSmallScreen, {
        VoidCallback? customOnTap,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.black,
        size: isSmallScreen ? 18 : 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 16,
          color: Colors.black,
        ),
      ),
      selected: _currentIndex == index,
      onTap: customOnTap ??
              () {
            if (index == -1) {
              signOut(context);
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
      horizontalTitleGap: isSmallScreen ? 4 : 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
Widget _buildHomePage() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 600;

  return Container(
    color: const Color.fromARGB(255, 255, 255, 255),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The rest of the content (small and large screen layouts)
            if (isSmallScreen)
              ...[
                // Create Post Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false, // 🔒 Prevent closing on outside tap
                        barrierColor: Colors.black.withOpacity(0.5),
                        builder: (BuildContext context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.white,
                            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: SizedBox(
                              width: 600,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        height: 32,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            minimumSize: Size(0, 32),
                                            padding: EdgeInsets.symmetric(horizontal: 10),
                                            foregroundColor: Colors.green[800],
                                            backgroundColor: Colors.green[50],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(Icons.image, color: Colors.green, size: 18),
                                          label: Text("Photo", style: TextStyle(fontSize: 13)),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              barrierColor: Colors.black.withOpacity(0.5),
                                              builder: (BuildContext context) {
                                                return Dialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  backgroundColor: Colors.white,
                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                  child: SizedBox(
                                                    width: 600,
                                                    child: AdminPostDialogContent(autoPickImage: true),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 140,
                                        height: 32,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            minimumSize: Size(0, 32),
                                            padding: EdgeInsets.symmetric(horizontal: 10),
                                            foregroundColor: Colors.orange[800],
                                            backgroundColor: Colors.orange[50],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(Icons.event, color: Colors.orange, size: 18),
                                          label: Text("Event", style: TextStyle(fontSize: 13)),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              barrierColor: Colors.black.withOpacity(0.5),
                                              builder: (BuildContext context) {
                                                return Dialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  backgroundColor: Colors.white,
                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                  child: SizedBox(
                                                    width: 600,
                                                    child: AdminPostDialogContent(autoEvent: true),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.edit, color: Colors.grey),
                              SizedBox(width: 10),
                              Text("Create post", style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(
                                width: 160,
                                height: 40,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.green[800],
                                    backgroundColor: Colors.green[50],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: Icon(Icons.image, color: Colors.green, size: 24),
                                  label: Text("Photo", style: TextStyle(fontSize: 15)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      barrierColor: Colors.black.withOpacity(0.5),
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          backgroundColor: Colors.white,
                                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                          child: SizedBox(
                                            width: 600,
                                            child: AdminPostDialogContent(autoPickImage: true),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 32),
                              SizedBox(
                                width: 160,
                                height: 40,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange[800],
                                    backgroundColor: Colors.orange[50],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: Icon(Icons.event, color: Colors.orange, size: 24),
                                  label: Text("Event", style: TextStyle(fontSize: 15)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      barrierColor: Colors.black.withOpacity(0.5),
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          backgroundColor: Colors.white,
                                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                          child: SizedBox(
                                            width: 600,
                                            child: AdminPostDialogContent(autoEvent: true),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Posts List
                Expanded(
                  child: StreamBuilder(
                    stream: _firestore
                        .collection('announcements')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: \\${snapshot.error}"));
                      }

                      var posts = snapshot.data?.docs ?? [];
                      if (_selectedFilter != 'All') {
                        posts = posts.where((post) {
                          final data = post.data();
                          return data['type'] == _selectedFilter;
                        }).toList();
                      }

                      if (posts.isEmpty) {
                        return const Center(child: Text("No announcements posted yet."));
                      }

                      _postKeys = List.generate(posts.length, (index) => GlobalKey());

                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          var post = posts[index];
                          var data = post.data();
                          return _buildPostCard(data, post.id, _postKeys[index], screenWidth);
                        },
                      );
                    },
                  ),
                ),
                // Filters Below on Small Screens
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center, // ✅ Changed from start to center
                              children: [
                                const Text(
                                  "Filter by Type",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F3060),
                                  ),
                                ),
                                const SizedBox(height: 8), // Optional spacing
                                ...['All', 'General', 'Seminar', 'Job Offering'].map((filter) {
                                  final isSelected = _selectedFilter == filter;
                                  return Center( // ✅ Wrap ListTile with Center
                                    child: ListTile(
                                      selected: isSelected,
                                      selectedTileColor: const Color(0xFF0F3060).withOpacity(0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      leading: Icon(
                                        Icons.label,
                                        color: isSelected ? const Color.fromARGB(255, 250, 250, 250) : Colors.black,
                                      ),
                                      title: Text(
                                        filter,
                                        style: TextStyle(
                                          color: isSelected ? const Color.fromARGB(255, 250, 250, 250) : Colors.black,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _selectedFilter = filter;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.filter_list),
                      label: const Text("Filter"),
                    ),
                  ),
                ),
              ]
            else
              // Large screen layout
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;
                          final maxContentWidth = screenWidth > 600 ? ((screenWidth * 0.98).clamp(0, 1400.0) as double) : screenWidth.toDouble();
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxContentWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 24, left: 8),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: ToggleButtons(
                                      borderRadius: BorderRadius.circular(12),
                                      selectedColor: Colors.white,
                                      fillColor: const Color(0xFF0F3060),
                                      color: Colors.black,
                                      direction: Axis.horizontal,
                                      isSelected: [
                                        _selectedFilter == 'All',
                                        _selectedFilter == 'General',
                                        _selectedFilter == 'Seminar',
                                        _selectedFilter == 'Job Offering',
                                      ],
                                      onPressed: (int index) {
                                        setState(() {
                                          switch (index) {
                                            case 0:
                                              _selectedFilter = 'All';
                                              break;
                                            case 1:
                                              _selectedFilter = 'General';
                                              break;
                                            case 2:
                                              _selectedFilter = 'Seminar';
                                              break;
                                            case 3:
                                              _selectedFilter = 'Job Offering';
                                              break;
                                          }
                                        });
                                      },
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          child: Text('All'),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          child: Text('General'),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          child: Text('Seminar'),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          child: Text('Job Offering'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // CREATE POST BUTTON (Facebook-style unified card)
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 20),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Make input row clickable
                                        InkWell(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (BuildContext context) {
                                                return Dialog(
                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  backgroundColor: Colors.white,
                                                  child: LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      double dialogWidth = constraints.maxWidth < 640
                                                          ? constraints.maxWidth
                                                          : 600;
                                                      return SizedBox(
                                                        width: dialogWidth,
                                                        child: AdminPostDialogContent(),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit, color: Colors.grey),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    "Create post",
                                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              SizedBox(
                                                width: 160,
                                                height: 40,
                                                child: TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.green[800],
                                                    backgroundColor: Colors.green[50],
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: Icon(Icons.image, color: Colors.green, size: 24),
                                                  label: Text("Photo", style: TextStyle(fontSize: 15)),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      barrierColor: Colors.black.withOpacity(0.5),
                                                      builder: (BuildContext context) {
                                                        return Dialog(
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                          backgroundColor: Colors.white,
                                                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                          child: SizedBox(
                                                            width: 600,
                                                            child: AdminPostDialogContent(autoPickImage: true),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              SizedBox(width: 32),
                                              SizedBox(
                                                width: 160,
                                                height: 40,
                                                child: TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.orange[800],
                                                    backgroundColor: Colors.orange[50],
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: Icon(Icons.event, color: Colors.orange, size: 24),
                                                  label: Text("Event", style: TextStyle(fontSize: 15)),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      barrierColor: Colors.black.withOpacity(0.5),
                                                      builder: (BuildContext context) {
                                                        return Dialog(
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                          backgroundColor: Colors.white,
                                                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                          child: SizedBox(
                                                            width: 600,
                                                            child: AdminPostDialogContent(autoEvent: true),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // POSTS STREAM
                                StreamBuilder(
                                  stream: _firestore
                                      .collection('announcements')
                                      .orderBy('timestamp', descending: true)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(child: Text("Error: \\${snapshot.error}"));
                                    }

                                    var posts = snapshot.data?.docs ?? [];
                                    if (_selectedFilter != 'All') {
                                      posts = posts.where((post) {
                                        final data = post.data();
                                        return data['type'] == _selectedFilter;
                                      }).toList();
                                    }

                                    if (posts.isEmpty) {
                                      return const Center(child: Text("No announcements posted yet."));
                                    }

                                    _postKeys = List.generate(posts.length, (index) => GlobalKey());

                                    return ListView.builder(
                                      itemCount: posts.length,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        var post = posts[index];
                                        var data = post.data();
                                        return _buildPostCard(data, post.id, _postKeys[index], screenWidth);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildPostCard(Map<String, dynamic> data, String postId, Key key, double screenWidth) {
  final isSmallScreen = screenWidth <= 400;

  return Card(
    key: key,
    elevation: 2,
    margin: EdgeInsets.symmetric(
      horizontal: screenWidth * 0.04,
      vertical: 8,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF0F3060),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Admin',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatTimestamp(data['timestamp']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color.fromARGB(255, 250, 250, 250),
                onSelected: (value) async {
                  if (value == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Colors.white,
                        child: SizedBox(
                          width: screenWidth * 0.9,
                          child: AdminPostDialogContent(postId: postId, initialData: data),
                        ),
                      ),
                    );
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.white, // Set background color
                        title: const Text(
                          "Delete Post",
                          style: TextStyle(color: Colors.black), // Title text color
                        ),
                        content: const Text(
                          "Are you sure you want to delete this post?",
                          style: TextStyle(color: Colors.black), // Content text color
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel", style: TextStyle(color: Colors.black)), // Button text color
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete", style: TextStyle(color: Colors.red)), // "Delete" in red for emphasis
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('announcements').doc(postId).delete();
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(value: 'delete', child: Text("Delete")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Content
          if ((data['title'] ?? '').isNotEmpty)
            Text(
              data['title'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F3060)),
              softWrap: true,
            ),
          if ((data['title'] ?? '').isNotEmpty) const SizedBox(height: 8),
          if ((data['content'] ?? '').isNotEmpty)
            Text(
              data['content'],
              style: const TextStyle(fontSize: 15),
              softWrap: true,
            ),
          const SizedBox(height: 12),

          // Images Grid
          if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildImageGrid(data['imageUrl'], postId),
            ),

          const SizedBox(height: 12),

          // Buttons (Scroll horizontally if needed)
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 8,
              radius: const Radius.circular(4),
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.white,
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final dialogWidth = (constraints.maxWidth < 900 ? constraints.maxWidth : 900).toDouble();
                                  return ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: dialogWidth,
                                    ),
                                    child: SingleChildScrollView(
                                      child: FullCommentDialog(postId: postId, adminUsername: userDetails?['username'] ?? 'Admin'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.comment, color: Color.fromARGB(255, 0, 48, 96)),
                        label: Text("View Comments", style: TextStyle(color: Color.fromARGB(255, 0, 48, 96))),
                      ),
                      if (data['type'] == 'Job Offering')
                        TextButton.icon(
                          onPressed: () => _showApplicantsDialog(postId),
                          icon: Icon(Icons.work, color: Color.fromARGB(255, 0, 48, 96)),
                          label: Text("View Applicants", style: TextStyle(color: Color.fromARGB(255, 0, 48, 96))),
                        ),
                      if (data['type'] == 'Seminar')
                        TextButton.icon(
                          onPressed: () => _showAttendeesDialog(context, postId),
                          icon: Icon(Icons.people, color: Color.fromARGB(255, 0, 48, 96)),
                          label: Text("View Attendees", style: TextStyle(color: Color.fromARGB(255, 0, 48, 96))),
                        ),
                      if (data['type'] == 'General')
                        TextButton.icon(
                          onPressed: () => _showAcknowledgedDialog(postId),
                          icon: Icon(Icons.check_circle, color: Color.fromARGB(255, 0, 48, 96)),
                          label: Text("View Recipients", style: TextStyle(color: Color.fromARGB(255, 0, 48, 96))),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildImageGrid(dynamic imageData, String postId) {
  List<String> imageUrls = [];
  if (imageData is String) {
    imageUrls = [imageData];
  } else if (imageData is List) {
    imageUrls = List<String>.from(imageData);
  }

  if (imageUrls.isEmpty) return const SizedBox();

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width * 0.75; // Maintain aspect ratio

      if (imageUrls.length == 1) {
        return SizedBox(
          height: height,
          child: GestureDetector(
            onTap: () => _showImageDialog(context, imageUrls[0], postId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[0],
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }

      if (imageUrls.length == 2) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[0], postId),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[0],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[1], postId),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[1],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (imageUrls.length == 3) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[0], postId),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[0],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, imageUrls[1], postId),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                          child: Image.network(
                            imageUrls[1],
                            fit: BoxFit.cover,
                            height: height / 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, imageUrls[2], postId),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                          child: Image.network(
                            imageUrls[2],
                            fit: BoxFit.cover,
                            height: height / 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // For 4 or more images
      return SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[0], postId),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[0],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[1], postId),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[1],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[2], postId),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrls[2],
                              fit: BoxFit.cover,
                              height: height / 2,
                            ),
                            if (imageUrls.length > 4)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Text(
                                    '+${imageUrls.length - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[3], postId),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[3],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showImageDialog(BuildContext context, String imageUrl, String postId) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = (constraints.maxWidth < 900 ? constraints.maxWidth : 900).toDouble();
          return SizedBox(
            width: dialogWidth,
            child: FullCommentDialog(postId: postId, adminUsername: userDetails?['username'] ?? 'Admin'),
          );
        },
      ),
    ),
  );
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