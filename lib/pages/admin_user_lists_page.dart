import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserListScreen extends StatelessWidget {
  final String category;
  const UserListScreen({super.key, required this.category});

  int _calculateAge(DateTime birthdate) {
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  Future<List<Map<String, String>>> _getUsersForCategory(String category) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('disabilityType', isEqualTo: category)
        .get();

    return snapshot.docs.map((doc) {
      String firstName = doc['firstName'] ?? '';
      String middleName = doc['middleName'] ?? '';
      String lastName = doc['lastName'] ?? '';
      String contactNumber = doc['contactNumber'] ?? 'N/A';
      String email = doc['email'] ?? 'N/A';
      String address = doc['address'] ?? 'N/A';
      String birthdateString = doc['birthdate'] ?? '';
      DateTime birthdate = DateTime.parse(birthdateString);
      String fullName = '$firstName $middleName $lastName'.trim();
      int age = _calculateAge(birthdate);
      String birthdateFormatted = DateFormat('yyyy-MM-dd').format(birthdate);

      return {
        'fullName': fullName,
        'birthdate': birthdateFormatted,
        'age': age.toString(),
        'address': address,
        'contactNumber': contactNumber,
        'email': email,
      };
    }).toList();
  }

  Future<Map<String, int>> _getTotalUsersPerCategory() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('users').get();

    Map<String, int> categoryCounts = {};

    for (var doc in snapshot.docs) {
      String disabilityType = doc['disabilityType'] ?? 'Unknown';
      categoryCounts[disabilityType] = (categoryCounts[disabilityType] ?? 0) + 1;
    }

    return categoryCounts;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 30, 136, 229),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "ACCAP",
          style: TextStyle(
            letterSpacing: 2.0,
            fontSize: 50,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          _getUsersForCategory(category),
          _getTotalUsersPerCategory(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }

          List<Map<String, String>> users = snapshot.data![0];
          Map<String, int> totalPerCategory = snapshot.data![1];
          int totalUsers = users.length;

          return SingleChildScrollView(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 8.0 : 16.0,
                    isSmallScreen ? 8.0 : 16.0,
                    isSmallScreen ? 8.0 : 16.0,
                    isSmallScreen ? 24.0 : 32.0, // Extra bottom padding
                  ),
                  child: Column(
                    children: [
                      // Total user count for current category
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          'Total Users in "$category": $totalUsers',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Display total users for all categories
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: totalPerCategory.entries.map((entry) {
                            return Text(
                              '• \\${entry.key}: \\${entry.value}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Responsive user data
                      if (isSmallScreen)
                        // Show as cards on small screens
                        Column(
                          children: users.map((user) {
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
                                    Text('Birthdate: \\${user['birthdate'] ?? 'N/A'}'),
                                    Text('Age: \\${user['age'] ?? 'N/A'}'),
                                    Text('Address: \\${user['address'] ?? 'N/A'}'),
                                    Text('Contact: \\${user['contactNumber'] ?? 'N/A'}'),
                                    Text('Email: \\${user['email'] ?? 'N/A'}'),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        // Show as table on larger screens
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            border: TableBorder.all(color: Colors.black, width: 1),
                            columnWidths: const {
                              0: FixedColumnWidth(250),
                              1: FixedColumnWidth(150),
                              2: FixedColumnWidth(80),
                              3: FixedColumnWidth(250),
                              4: FixedColumnWidth(200),
                              5: FixedColumnWidth(250),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey[300]),
                                children: const [
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Birthdate', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Age', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              ...users.map((user) {
                                return TableRow(
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['fullName'] ?? 'N/A'),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['birthdate'] ?? 'N/A'),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['age'] ?? 'N/A'),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['address'] ?? 'N/A'),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['contactNumber'] ?? 'N/A'),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(user['email'] ?? 'N/A'),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}