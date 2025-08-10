import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../widget/ticket_preview_widget.dart';
import '../widget/notificationWidget.dart';

class AdminTicketPage extends StatefulWidget {
  final String adminUsername;
  const AdminTicketPage({super.key, required this.adminUsername});

  @override
  _AdminTicketPageState createState() => _AdminTicketPageState();
}

class _AdminTicketPageState extends State<AdminTicketPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedCategory = "All";
  String selectedStatus = "All";
  TextEditingController searchController = TextEditingController();

  Stream<List<QueryDocumentSnapshot>> getAllRequests() {
    Stream<QuerySnapshot> medicationStream = _firestore.collection("medication_requests").snapshots();
    Stream<QuerySnapshot> wheelchairStream = _firestore.collection("wheelchair_requests").snapshots();
    Stream<QuerySnapshot> serviceStream = _firestore.collection("service_requests").snapshots();

    return Rx.combineLatest3(
      medicationStream,
      wheelchairStream,
      serviceStream,
          (QuerySnapshot medication, QuerySnapshot wheelchair, QuerySnapshot service) {
        return [...medication.docs, ...wheelchair.docs, ...service.docs];
      },
    );
  }

 @override
Widget build(BuildContext context) {

  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 600;

  return Scaffold(
    backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Text(
            'MEMBER REQUESTS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 25,
            ),
          ),
          Spacer(),
          SizedBox(
            width: 250,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Request No.",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          SizedBox(width: 16),
          StreamBuilder<QuerySnapshot>(
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
          ),
        ],
      ),
      elevation: 0,
    ),
    body: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isNarrow = constraints.maxWidth < 1024;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ToggleButtons(
                              borderRadius: BorderRadius.circular(16),
                              selectedColor: Colors.white,
                              fillColor: const Color.fromARGB(255, 0, 48, 96),
                              color: Colors.black,
                              borderColor: Colors.grey.shade300,
                              selectedBorderColor: Colors.grey.shade400,
                              constraints: const BoxConstraints(minHeight: 40, minWidth: 120),
                              isSelected: [
                                selectedCategory == "All",
                                selectedCategory == "Medication",
                                selectedCategory == "Wheelchair",
                                selectedCategory == "Transportation Service",
                              ],
                              onPressed: (int index) {
                                setState(() {
                                  switch (index) {
                                    case 0:
                                      selectedCategory = "All";
                                      break;
                                    case 1:
                                      selectedCategory = "Medication";
                                      break;
                                    case 2:
                                      selectedCategory = "Wheelchair";
                                      break;
                                    case 3:
                                      selectedCategory = "Transportation Service";
                                      break;
                                  }
                                });
                              },
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('All'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Medication'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Wheelchair'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Transportation Service'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusFilters(),
                      ],
                    );
                  } else {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ToggleButtons(
                            borderRadius: BorderRadius.circular(16),
                            selectedColor: Colors.white,
                            fillColor: const Color.fromARGB(255, 0, 48, 96),
                            color: Colors.black,
                            borderColor: Colors.grey.shade300,
                            selectedBorderColor: Colors.grey.shade400,
                            constraints: const BoxConstraints(minHeight: 40, minWidth: 120),
                            isSelected: [
                              selectedCategory == "All",
                              selectedCategory == "Medication",
                              selectedCategory == "Wheelchair",
                              selectedCategory == "Transportation Service",
                            ],
                            onPressed: (int index) {
                              setState(() {
                                switch (index) {
                                  case 0:
                                    selectedCategory = "All";
                                    break;
                                  case 1:
                                    selectedCategory = "Medication";
                                    break;
                                  case 2:
                                    selectedCategory = "Wheelchair";
                                    break;
                                  case 3:
                                    selectedCategory = "Transportation Service";
                                    break;
                                }
                              });
                            },
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('All'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Medication'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Wheelchair'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Transportation Service'),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusFilters(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              if (!isSmallScreen)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color.fromARGB(217, 217, 217, 217),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Center(child: Text("Request Number", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Date Created", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 3, child: Center(child: Text("User", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: getAllRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No Requests found."));
                    }

                    var requests = snapshot.data!;
                    String searchText = searchController.text.trim();

                    if (searchText.isNotEmpty) {
                      requests = requests.where((request) {
                        var data = request.data() as Map<String, dynamic>;
                        String ticketNumber = data["requestNumber"]?.toString() ?? "";
                        return ticketNumber.contains(searchText);
                      }).toList();
                    }

                    if (selectedCategory != "All") {
                      requests = requests.where((request) {
                        var data = request.data() as Map<String, dynamic>;
                        return data["category"] == selectedCategory;
                      }).toList();
                    }

                    if (selectedStatus != "All") {
                      requests = requests.where((request) {
                        var data = request.data() as Map<String, dynamic>;
                        return data["status"] == selectedStatus;
                      }).toList();
                    }

                    requests.sort((a, b) {
                      var dataA = a.data() as Map<String, dynamic>;
                      var dataB = b.data() as Map<String, dynamic>;

                      String statusA = dataA["status"] ?? "Pending";
                      String statusB = dataB["status"] ?? "Pending";

                      int ticketNumberA = int.tryParse(dataA["requestNumber"].toString()) ?? 0;
                      int ticketNumberB = int.tryParse(dataB["requestNumber"].toString()) ?? 0;

                      if (statusA == "Closed" && statusB != "Closed") return 1;
                      if (statusA != "Closed" && statusB == "Closed") return -1;

                      return ticketNumberB.compareTo(ticketNumberA);
                    });

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var request = requests[index];
                        return TicketPreviewWidget(
                          request: request,
                          adminUsername: widget.adminUsername,
                          isSmallScreen: isSmallScreen,
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildStatusFilters() {
  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text(
        "Filter by Status:",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      _buildRadioButton("All"),
      _buildRadioButton("Open"),
      _buildRadioButton("Closed"),
    ],
  );
}


  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 45,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildRadioButton(String label) {
    return Row(
      children: [
        Radio<String>(
          value: label,
          groupValue: selectedStatus,
          onChanged: (String? value) {
            setState(() {
              selectedStatus = value!;
            });
          },
        ),
        Text(label),
      ],
    );
  }
}

class TicketDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot request;
  final String adminUsername;
  final bool enableEnterSubmit;
  const TicketDetailPage({
    super.key,
    required this.request,
    required this.adminUsername,
    this.enableEnterSubmit = false,
  });

  @override
  _TicketDetailPageState createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  late bool isOpen;
  String? _adminName;

  @override
  void initState() {
    super.initState();
    isOpen = widget.request["status"] == "Open";
    _fetchAdminName();
  }

  Future<void> _fetchAdminName() async {
    final adminDoc = await FirebaseFirestore.instance.collection('admins').where('username', isEqualTo: widget.adminUsername).get();
    if (adminDoc.docs.isNotEmpty) {
      setState(() {
        _adminName = adminDoc.docs.first['name'] ?? widget.adminUsername;
      });
    } else {
      setState(() {
        _adminName = widget.adminUsername;
      });
    }
  }

  void addComment() async {
    if (!isOpen) return;

    if (_commentController.text.isNotEmpty) {
      // Add the comment
      await FirebaseFirestore.instance
          .collection(widget.request.reference.parent.id)
          .doc(widget.request.id)
          .collection("comments")
          .add({
        "text": _commentController.text,
        "timestamp": FieldValue.serverTimestamp(),
        "role": "admin",
        "username": _adminName ?? widget.adminUsername,
      });

      // Check if commenter is an admin
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: widget.adminUsername)
          .get();
      final isAdmin = adminDoc.docs.isNotEmpty;

      // Only send notification if the commenter is NOT an admin
      if (!isAdmin) {
        // Fetch all admins
        final adminsSnapshot = await FirebaseFirestore.instance.collection('admins').get();
        // Fetch user profile to get first name
        final userProfileSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: widget.adminUsername)
            .get();
        String userFirstName = widget.adminUsername;
        if (userProfileSnapshot.docs.isNotEmpty) {
          userFirstName = userProfileSnapshot.docs.first['firstName'] ?? widget.adminUsername;
        }
        for (var admin in adminsSnapshot.docs) {
          final adminUsername = admin['username'] ?? '';
          await FirebaseFirestore.instance.collection('notifications').add({
            'type': 'comment',
            'role': 'user',
            'to': adminUsername,
            'from': widget.adminUsername,
            'ticketId': widget.request.id,
            'message': '$userFirstName commented on this ticket',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }

      _commentController.clear();
    }
  }

  void updateTicketStatus(String newStatus) {
    FirebaseFirestore.instance
        .collection(widget.request.reference.parent.id)
        .doc(widget.request.id)
        .update({"status": newStatus});

    setState(() {
      isOpen = newStatus == "Open";
    });
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            TextSpan(text: value ?? "N/A",style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = widget.request.data() as Map<String, dynamic>;
    double screenWidth = MediaQuery.of(context).size.width;
    double imageWidth = screenWidth > 600 ? 200 : screenWidth * 0.4;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: 700,
        ),
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double commentBarWidth = constraints.maxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Request No. #${data["requestNumber"] ?? "N/A"}",
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text("Name: " + (data["name"] ?? "N/A"), style: const TextStyle(fontSize: 18)),
                              Text("(${data["user"] ?? "N/A"})", style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text("Category: " + (data["category"] ?? "N/A"), style: const TextStyle(fontSize: 20)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  data["status"] ?? "Pending",
                                  style: TextStyle(
                                    color: isOpen ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data["category"] == "Medication") ...[
                                    _buildDetailRow("Medicine", data["medicineName"]),
                                    _buildDetailRow("Service", data["pickupOrDelivery"]),
                                    _buildDetailRow("Address", data["address"]),
                                    _buildDetailRow("Date Needed", data["date"]),
                                    _buildDetailRow("Time", data["requestedTime"]),
                                  ]
                                  else if (data["category"] == "Wheelchair") ...[
                                    _buildDetailRow("Reason", data["reason"]),
                                    _buildDetailRow("Location", data["location"]),
                                    _buildDetailRow("Delivery Date", data["dateToDeliver"]),
                                    _buildDetailRow("Delivery Time", data["deliveryTime"]),
                                    _buildDetailRow("Pickup Date", data["dateToPickUp"]),
                                    _buildDetailRow("Pickup Time", data["pickupTime"]),
                                  ]
                                  else if (data["category"] == "Transportation Service") ...[
                                      _buildDetailRow("Needs Wheelchair", data["needsWheelchair"] == true ? "Yes" : "No"),
                                      _buildDetailRow("Reason", data["reason"]),
                                      _buildDetailRow("Pickup Location", data["pickup_location"]),
                                      _buildDetailRow("Pickup Date", data["pickup_date"]),
                                      _buildDetailRow("Pickup Time", data["pickup_time"]),
                                      _buildDetailRow("Destination", data["destination"]),
                                      _buildDetailRow("Trip Type", data["tripType"]),
                                    ]
                                ],
                              ),
                            ),
                            if (data.containsKey("medicine_image") && data["medicine_image"] != null)
                              ...[
                                const SizedBox(width: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    data["medicine_image"],
                                    width: imageWidth,
                                    height: imageWidth,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                  ),
                                ),
                              ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          thickness: 1.5,
                          color: Colors.grey.shade300,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                            child: Text(
                              "Comments",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection(widget.request.reference.parent.id)
                              .doc(widget.request.id)
                              .collection("comments")
                              .orderBy("timestamp", descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            var comments = snapshot.data!.docs;
                            return Column(
                              children: List.generate(comments.length, (index) {
                                var comment = comments[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: SizedBox(
                                    width: commentBarWidth,
                                    child: Card(
                                      color: Color.fromARGB(255, 250, 250, 250),
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                comment.data().containsKey("role") && comment["role"] == "admin"
                                                    ? (comment.data().containsKey("username") && (comment["username"] as String).isNotEmpty
                                                        ? comment["username"]
                                                        : "Admin")
                                                    : (comment.data().containsKey("userFullName") && (comment["userFullName"] as String).isNotEmpty
                                                        ? comment["userFullName"]
                                                        : "User"),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (comment.data().containsKey("timestamp") && comment["timestamp"] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Text(
                                                  comment["timestamp"] is Timestamp
                                                      ? DateFormat('MMM dd, hh:mm a').format(comment["timestamp"].toDate())
                                                      : '',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Text(comment["text"] ?? "No content"),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Fixed comment bar at the bottom
                // Fixed comment bar at the bottom
                SizedBox(
                  width: commentBarWidth,
                  child: isOpen
                      ? TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) {
                      addComment();
                      FocusScope.of(context).unfocus();
                    },
                  )
                      : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "This request is closed. You cannot comment anymore.",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}