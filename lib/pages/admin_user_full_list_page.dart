import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:typed_data';
import 'dart:html' as html;
import 'admin_notifications_page.dart';
import '../widget/notificationWidget.dart';

class AdminUserFullListPage extends StatefulWidget {
  final List<String> initialSelectedCategories;
  const AdminUserFullListPage({super.key, this.initialSelectedCategories = const []});
  void setFilter(List<String> categories) {
  }
  @override
  State<AdminUserFullListPage> createState() => AdminUserFullListPageState();
}

class AdminUserFullListPageState extends State<AdminUserFullListPage> {
  final List<String> categories = [
    "Visual Impairment",
    "Hearing Impairment",
    "Speech Impairment",
    "Mobility Impairment"
  ];
  void setFilter(List<String> categories) {
    setState(() {
      if (categories.isEmpty) {
        allSelected = true;
        selectedCategories = [false, false, false, false];
      } else {
        allSelected = false;
        for (int i = 0; i < this.categories.length; i++) {
          selectedCategories[i] = categories.contains(this.categories[i]);
        }
      }
      currentPage = 0;
    });
  }

  List<bool> selectedCategories = [false, false, false, false];
  bool allSelected = true;
  String _formatContactNumber(String number) {
    if (number.startsWith('+63') && number.length > 3) {
      return '0${number.substring(3)}';
    }
    return number;
  }
  int entriesPerPage = 10;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedCategories.isEmpty) {
      allSelected = true;
      selectedCategories = [false, false, false, false];
    } else {
      allSelected = false;
      for (int i = 0; i < categories.length; i++) {
        selectedCategories[i] = widget.initialSelectedCategories.contains(categories[i]);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getAllUsers() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();

    int userId = 1;
    return snapshot.docs.map((doc) {
      String firstName = doc['firstName'] ?? '';
      String middleName = doc['middleName'] ?? '';
      String lastName = doc['lastName'] ?? '';
      String contactNumber = doc['contactNumber'] ?? 'N/A';
      String email = doc['email'] ?? 'N/A';
      String address = doc['address'] ?? 'N/A';
      String birthdateString = doc['birthdate'] ?? '';
      DateTime birthdate = DateTime.tryParse(birthdateString) ?? DateTime(2000, 1, 1);
      String fullName = '$firstName $middleName $lastName'.trim();
      String birthdateFormatted = DateFormat('yyyy-MM-dd').format(birthdate);
      String disabilityType = (doc['disabilityType'] ?? 'Unknown').toString();

      Map<String, dynamic> user = {
        'userId': userId++,
        'fullName': fullName,
        'birthdate': birthdateFormatted,
        'address': address,
        'contactNumber': contactNumber,
        'email': email,
        'disabilityType': disabilityType,
      };
      return user;
    }).toList();
  }

  void _downloadExcel(List<Map<String, dynamic>> users, int total, List<String> selected) async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheetObject = excel['Sheet1'];

    String title;
    String fileName;
    if (selected.isEmpty) {
      title = "Total Users for All Disability Types: $total";
      fileName = "Members List for All.xlsx";
    } else {
      String cats = selected.join(', ');
      title = "Total Members for $cats: $total";
      fileName = "Members List for $cats.xlsx";
    }

    // Title row with style
    var titleCell = sheetObject.cell(ex.CellIndex.indexByString("A1"));
    titleCell.value = title;
    titleCell.cellStyle = ex.CellStyle(
      backgroundColorHex: "#003060",
      fontColorHex: "#FFFFFF",
      bold: true,
      fontSize: 14,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
    );
    sheetObject.merge(
      ex.CellIndex.indexByString("A1"),
      ex.CellIndex.indexByString("G1"),
    );

    // Header row
    List<String> headers = [
      "Member ID", "Name", "Email", "Disability", "Birthdate", "Contact", "Address"
    ];
    sheetObject.appendRow(headers);

    // Set header style
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.cellStyle = ex.CellStyle(
        bold: true,
        fontSize: 12,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
      );
    }

    // Set column widths
    sheetObject.setColWidth(0, 20);  // Member ID
    sheetObject.setColWidth(1, 35);  // Name
    sheetObject.setColWidth(2, 30);  // Email
    sheetObject.setColWidth(3, 30);  // Disability
    sheetObject.setColWidth(4, 30);  // Birthdate
    sheetObject.setColWidth(5, 30);  // Contact
    sheetObject.setColWidth(6, 70);  // Address

    // Add data rows and set style for each cell
    for (int rowIdx = 0; rowIdx < users.length; rowIdx++) {
      var user = users[rowIdx];
      List<dynamic> row = [
        user['userId'].toString(),
        user['fullName'] ?? '',
        user['email'] ?? '',
        user['disabilityType'] ?? '',
        user['birthdate'] ?? '',
        _formatContactNumber(user['contactNumber'] ?? ''),
        user['address'] ?? '',
      ];
      sheetObject.appendRow(row);

      // Set style for each cell in this row (rowIndex: +2 because title is row 0, header is row 1)
      for (int colIdx = 0; colIdx < row.length; colIdx++) {
        var cell = sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx + 2));
        cell.cellStyle = ex.CellStyle(
          fontSize: 12,
          horizontalAlign: ex.HorizontalAlign.Center,
          verticalAlign: ex.VerticalAlign.Center,
        );
      }
    }

    final excelBytes = excel.encode();
    if (excelBytes != null) {
      final content = Uint8List.fromList(excelBytes);
      final blob = html.Blob([content]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<Map<String, int>> _getTotalUsersPerCategory() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();

    Map<String, int> categoryCounts = {
      "Visual Impairment": 0,
      "Hearing Impairment": 0,
      "Speech Impairment": 0,
      "Mobility Impairment": 0,
      "Unknown": 0,
    };

    for (var doc in snapshot.docs) {
      String disabilityType = doc['disabilityType'] ?? 'Unknown';
      if (!categoryCounts.containsKey(disabilityType)) {
        categoryCounts[disabilityType] = 0;
      }
      categoryCounts[disabilityType] = (categoryCounts[disabilityType] ?? 0) + 1;
    }

    return categoryCounts;
  }

  List<String> getSelectedCategories() {
    if (allSelected) return [];
    List<String> selected = [];
    for (int i = 0; i < categories.length; i++) {
      if (selectedCategories[i]) selected.add(categories[i]);
    }
    return selected;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'MEMBERS LIST',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 25,
          ),
        ),
        elevation: 0,
        actions: [
          buildNotificationIcon(context),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          _getAllUsers(),
          _getTotalUsersPerCategory(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<Map<String, dynamic>> users = snapshot.data![0];
          Map<String, int> totalPerCategory = snapshot.data![1];

          // --- FILTER LOGIC ---
          List<String> selected = getSelectedCategories();
          List<Map<String, dynamic>> filteredUsers;
          Map<String, int> filteredCategoryCounts = {};

          if (allSelected || selected.isEmpty) {
            filteredUsers = users;
            filteredCategoryCounts = totalPerCategory;
          } else {
            filteredUsers = users.where((user) => selected.contains(user['disabilityType'])).toList();
            for (var cat in selected) {
              filteredCategoryCounts[cat] = users.where((user) => user['disabilityType'] == cat).length;
            }
          }
          int filteredTotalUsers = filteredUsers.length;

          // --- PAGINATION LOGIC ---
          int pageCount = (filteredTotalUsers / entriesPerPage).ceil();
          int start = currentPage * entriesPerPage;
          int end = ((start + entriesPerPage) > filteredTotalUsers
              ? filteredTotalUsers
              : (start + entriesPerPage));
          List<Map<String, dynamic>> pagedUsers =
          filteredUsers.sublist(start, end);

          return Padding(
            padding: EdgeInsets.all(isSmallScreen ? 4.0 : 12.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 16.0),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isNarrow = constraints.maxWidth < 900;
                        final filterColor = const Color.fromARGB(255, 0, 48, 96);

                        final summaryWidget = Text(
                          'Total Users: $filteredTotalUsers',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        );

                        final filterWidget = Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text("All"),
                              selected: allSelected,
                              selectedColor: filterColor,
                              labelStyle: TextStyle(
                                color: allSelected ? Colors.white : filterColor,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: filterColor),
                              onSelected: (selected) {
                                setState(() {
                                  allSelected = true;
                                  selectedCategories = [false, false, false, false];
                                  currentPage = 0;
                                });
                              },
                            ),
                            ...List.generate(categories.length, (i) {
                              return FilterChip(
                                label: Text(categories[i]),
                                selected: selectedCategories[i],
                                selectedColor: filterColor,
                                labelStyle: TextStyle(
                                  color: selectedCategories[i] ? Colors.white : filterColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: filterColor),
                                onSelected: (selected) {
                                  setState(() {
                                    selectedCategories[i] = selected;
                                    allSelected = false;
                                    // If all are selected, switch to "All"
                                    if (selectedCategories.where((e) => e).length == 4) {
                                      allSelected = true;
                                      selectedCategories = [false, false, false, false];
                                    }
                                    // If none are selected, switch to "All"
                                    if (selectedCategories.where((e) => e).isEmpty) {
                                      allSelected = true;
                                    }
                                    currentPage = 0;
                                  });
                                },
                              );
                            }),
                          ],
                        );

                        if (isSmallScreen || isNarrow) {
                          // Stack vertically for small screens
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              filterWidget,
                              const SizedBox(height: 12),
                              summaryWidget,
                            ],
                          );
                        } else {
                          // Row for wide screens
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: filterWidget),
                              const SizedBox(width: 32),
                              summaryWidget,
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.table_chart),
                          label: const Text("Download Excel"),
                          onPressed: () => _downloadExcel(filteredUsers, filteredTotalUsers, selected),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Responsive user data
                    if (isSmallScreen)
                      // Show as cards on small screens
                      Expanded(
                        child: pagedUsers.isEmpty
                            ? const Center(child: Text("No users found for this category."))
                            : ListView.builder(
                                itemCount: pagedUsers.length,
                                itemBuilder: (context, index) {
                                  final user = pagedUsers[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(user['fullName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text('Email: ${user['email'] ?? 'N/A'}'),
                                          Text('Disability: ${user['disabilityType'] ?? 'N/A'}'),
                                          Text('Birthdate: ${user['birthdate'] ?? 'N/A'}'),
                                          Text('Contact: ${_formatContactNumber(user['contactNumber'] ?? 'N/A')}'),
                                          Text('Address: ${user['address'] ?? 'N/A'}'),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      )
                    else
                      // Show as table on larger screens
                      Expanded(
                        child: pagedUsers.isEmpty
                            ? const Center(child: Text("No users found for this category."))
                            : SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Column(
                                  children: [
                                    // Table header
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      color: const Color.fromARGB(217, 217, 217, 217),
                                      child: Row(
                                        children: const [
                                          Expanded(flex: 1, child: Center(child: Text("Member ID", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 2, child: Center(child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 3, child: Center(child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 2, child: Center(child: Text("Disability", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 2, child: Center(child: Text("Birthdate", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 2, child: Center(child: Text("Contact", style: TextStyle(fontWeight: FontWeight.bold)))),
                                          Expanded(flex: 3, child: Center(child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold)))),
                                        ],
                                      ),
                                    ),
                                    ...pagedUsers.map((user) {
                                      return Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 1, child: Center(child: Text('${user['userId']}'))),
                                            Expanded(flex: 2, child: Center(child: Text(user['fullName'] ?? 'N/A'))),
                                            Expanded(flex: 3, child: Center(child: Text(user['email'] ?? 'N/A'))),
                                            Expanded(flex: 2, child: Center(child: Text(user['disabilityType'] ?? 'N/A'))),
                                            Expanded(flex: 2, child: Center(child: Text(user['birthdate'] ?? 'N/A'))),
                                            Expanded(
                                              flex: 2,
                                              child: Center(
                                                child: Text(
                                                  _formatContactNumber(user['contactNumber'] ?? 'N/A'),
                                                ),
                                              ),
                                            ),
                                            Expanded(flex: 3, child: Center(child: Text(user['address'] ?? 'N/A'))),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                      ),
                    const SizedBox(height: 16),
                    if (pageCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade200,
                                disabledForegroundColor: Colors.grey,
                              ),
                              onPressed: currentPage > 0
                                  ? () {
                                setState(() {
                                  currentPage--;
                                });
                              }
                                  : null,
                              child: const Text("Previous"),
                            ),
                            Text("Page ${currentPage + 1} of $pageCount"),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade200,
                                disabledForegroundColor: Colors.grey,
                              ),
                              onPressed: currentPage < pageCount - 1
                                  ? () {
                                setState(() {
                                  currentPage++;
                                });
                              }
                                  : null,
                              child: const Text("Next"),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}