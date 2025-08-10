import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../pages/admin_ticket_page.dart';

class TicketPreviewWidget extends StatelessWidget {
  final QueryDocumentSnapshot request;
  final String adminUsername;
  final bool isSmallScreen;

  const TicketPreviewWidget({
    super.key,
    required this.request,
    required this.adminUsername,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = request.data() as Map<String, dynamic>;
    String ticketNumber = data["requestNumber"]?.toString() ?? "N/A";
    String created = data['timestamp'] is Timestamp
        ? DateFormat('MMM dd, yyyy hh:mm a').format(data['timestamp'].toDate())
        : "Unknown Time";
    String user = data["name"] ?? "N/A";
    String category = data["category"] ?? "Unknown";
    String status = data["status"] ?? "Pending";

    Color statusColor;
    if (status == "Open") {
      statusColor = Colors.green;
    } else if (status == "Closed") {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return isSmallScreen
        ? Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: ListTile(
              title: Text(
                "Request No. #$ticketNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Created: $created"),
                  Text("User: $user"),
                  Text("Category: $category"),
                  Row(
                    children: [
                      const Text("Status: "),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTicketDetails(context),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: InkWell(
              onTap: () => _showTicketDetails(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Center(child: Text("Request No. #$ticketNumber"))),
                    _buildVerticalDivider(),
                    Expanded(flex: 2, child: Center(child: Text(created))),
                    _buildVerticalDivider(),
                    Expanded(flex: 3, child: Center(child: Text(user))),
                    _buildVerticalDivider(),
                    Expanded(flex: 2, child: Center(child: Text(category))),
                    _buildVerticalDivider(),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
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

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  void _showTicketDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 750,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
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
                    request: request,
                    adminUsername: adminUsername,
                    enableEnterSubmit: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 