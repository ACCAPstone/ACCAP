import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_notifications_page.dart';
import '../widget/notificationWidget.dart';

class AdminVoiceMessagesPage extends StatefulWidget {
  const AdminVoiceMessagesPage({super.key});

  @override
  State<AdminVoiceMessagesPage> createState() => _AdminVoiceMessagesPageState();
}

class _AdminVoiceMessagesPageState extends State<AdminVoiceMessagesPage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late Future<List<Reference>> _jsonFilesFuture;

  @override
  void initState() {
    super.initState();
    _jsonFilesFuture = _fetchJsonFiles();
  }

  Future<List<Reference>> _fetchJsonFiles() async {
    final ListResult result = await _storage.ref('emergency_locations').listAll();
    final items = result.items;

    // Fetch metadata for all files
    final List<MapEntry<Reference, DateTime?>> filesWithDate = await Future.wait(
      items.map((ref) async {
        try {
          final meta = await ref.getMetadata();
          // Use updated if available, else timeCreated
          return MapEntry(ref, meta.updated ?? meta.timeCreated);
        } catch (e) {
          return MapEntry(ref, null);
        }
      }),
    );

    // Sort by date descending (most recent first)
    filesWithDate.sort((a, b) {
      final aDate = a.value;
      final bDate = b.value;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate); // Descending
    });

    // Return only the sorted references
    return filesWithDate.map((e) => e.key).toList();
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown date';
    return "${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<Map<String, dynamic>?> _fetchJsonContent(String url) async {
    try {
      final response = await html.HttpRequest.request(url);
      return jsonDecode(response.responseText!);
    } catch (e) {
      return null;
    }
  }

  Future<void> _makeEmergencyCall() async {
    const String emergencyNumber = 'tel:911';
    if (await canLaunchUrl(Uri.parse(emergencyNumber))) {
      await launchUrl(Uri.parse(emergencyNumber));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make emergency call.')),
        );
      }
    }
  }
  String _parseUserName(String fileName) {
    final parts = fileName.split('_');
    if (parts.length > 1) {

      parts.removeLast();
    }
    final name = parts.join(' ');
    return name.replaceAll(RegExp(r'\.[^\.]+'), '');
  }

  String _getFormattedAddress(Map<String, dynamic> jsonData) {
    // Prioritize 'locationName' as the address
    if (jsonData['locationName'] != null && jsonData['locationName'].toString().trim().isNotEmpty) {
      return jsonData['locationName'];
    }
    if (jsonData['address'] != null && jsonData['address'].toString().trim().isNotEmpty) {
      return jsonData['address'];
    }
    if (jsonData['plus_code'] != null && jsonData['plus_code'].toString().trim().isNotEmpty) {
      return jsonData['plus_code'];
    }
    if (jsonData['formatted_address'] != null && jsonData['formatted_address'].toString().trim().isNotEmpty) {
      return jsonData['formatted_address'];
    }
    // Fallback: show lat/lng if available
    final lat = jsonData['latitude'] ?? jsonData['lat'];
    final lng = jsonData['longitude'] ?? jsonData['lng'] ?? jsonData['lon'];
    if (lat != null && lng != null) {
      return 'Lat: $lat, Lng: $lng';
    }
    return 'Unknown location';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'EMERGENCY ALERTS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: screenWidth < 400 ? 18 : (screenWidth < 600 ? 20 : 25),
          ),
        ),
        elevation: 0,
        actions: [
          buildNotificationIcon(context),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(screenWidth < 400 ? 6.0 : (screenWidth < 600 ? 10.0 : 16.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenWidth < 400 ? 8 : (screenWidth < 600 ? 12 : 20)),
            Expanded(
              child: FutureBuilder<List<Reference>>(
                future: _jsonFilesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                     return Center(child: Text("Error loading files: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        "No emergency locations found.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  final files = snapshot.data!;
                  return ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final fileRef = files[index];
                      return FutureBuilder<String>(
                        future: fileRef.getDownloadURL(),
                        builder: (context, urlSnapshot) {
                          if (urlSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(title: Text("Loading URL..."));
                          }
                           if (urlSnapshot.hasError) {
                            return ListTile(title: Text("Error getting URL: ${urlSnapshot.error}"));
                          }
                          final url = urlSnapshot.data;
                          if (url == null) return const ListTile(title: Text("URL not available"));

                          return FutureBuilder<FullMetadata>(
                            future: fileRef.getMetadata(),
                            builder: (context, metaSnapshot) {
                              if (metaSnapshot.connectionState == ConnectionState.waiting) {
                                return const ListTile(title: Text("Loading metadata..."));
                              }
                              if (metaSnapshot.hasError) {
                                return ListTile(title: Text("Error loading metadata: ${metaSnapshot.error}"));
                              }
                              final metadata = metaSnapshot.data;
                              final fileName = fileRef.name;
                              final userName = _parseUserName(fileName);
                              final dateTime = metadata?.updated ?? metadata?.timeCreated;

                              return FutureBuilder<Map<String, dynamic>?>(
                                future: _fetchJsonContent(url),
                                builder: (context, jsonSnapshot) {
                                  String address = '';
                                  if (jsonSnapshot.hasData && jsonSnapshot.data != null) {
                                    address = _getFormattedAddress(jsonSnapshot.data!);
                                  }
                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: screenWidth < 400 ? 4 : 8),
                                    color: Colors.white,
                                    child: InkWell(
                                      onTap: () async {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return FutureBuilder<Map<String, dynamic>?>(
                                              future: _fetchJsonContent(url),
                                              builder: (context, jsonSnapshot) {
                                                if (jsonSnapshot.connectionState == ConnectionState.waiting) {
                                                  return AlertDialog(
                                                    backgroundColor: Colors.white,
                                                    title: Text("Loading Location Data...", style: TextStyle(fontSize: screenWidth < 400 ? 16 : 20)),
                                                    content: SizedBox(
                                                      width: screenWidth < 400 ? 200 : (screenWidth < 600 ? 250 : 350),
                                                      height: screenWidth < 400 ? 180 : (screenWidth < 600 ? 220 : 300),
                                                      child:  Center(child: CircularProgressIndicator()),
                                                    ),
                                                  );
                                                }
                                                if (jsonSnapshot.hasError || jsonSnapshot.data == null) {
                                                  return AlertDialog(
                                                    title: Text(fileName, style: TextStyle(fontSize: screenWidth < 400 ? 16 : 20)),
                                                    backgroundColor: Colors.white,
                                                    content: SizedBox(
                                                      width: screenWidth < 400 ? 200 : (screenWidth < 600 ? 250 : 350),
                                                      height: screenWidth < 400 ? 180 : (screenWidth < 600 ? 220 : 300),
                                                      child: Center(
                                                        child: Text("Failed to load location data.", style: TextStyle(fontSize: screenWidth < 400 ? 12 : 16)),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text("Close"),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                final jsonData = jsonSnapshot.data!;
                                                LatLng? latLng;
                                                final lat = jsonData['latitude'] ?? jsonData['lat'];
                                                final lng = jsonData['longitude'] ?? jsonData['lng'] ?? jsonData['lon'];

                                                if (lat != null && lng != null) {
                                                    final parsedLat = lat is String ? double.tryParse(lat) : (lat as num).toDouble();
                                                    final parsedLng = lng is String ? double.tryParse(lng) : (lng as num).toDouble();
                                                    if (parsedLat != null && parsedLng != null) {
                                                        latLng = LatLng(parsedLat, parsedLng);
                                                    }
                                                }

                                                return AlertDialog(
                                                  title: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(userName, style: TextStyle(fontSize: 22)),
                                                      if (address.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4.0),
                                                          child: Text(
                                                            address,
                                                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                                          ),
                                                        ),
                                                      if (jsonData['emergencyType'] != null && jsonData['emergencyType'].toString().trim().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4.0),
                                                          child: Text(
                                                            "Emergency: ${jsonData['emergencyType']}",
                                                            style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      if (jsonData['contactNumber'] != null && (jsonData['contactNumber'] as String).trim().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                          child: Text(
                                                            "Contact: ${jsonData['contactNumber']}",
                                                            style: const TextStyle(fontSize: 16, color: Colors.blue),
                                                          ),
                                                        ),
                                                      if (jsonData['disabilityType'] != null && (jsonData['disabilityType'] as String).trim().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                          child: Text(
                                                            "Disability: ${jsonData['disabilityType']}",
                                                            style: const TextStyle(fontSize: 16, color: Colors.purple),
                                                          ),
                                                        ),
                                                      if (jsonData['description'] != null && (jsonData['description'] as String).trim().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                          child: Text(
                                                            "Description: ${jsonData['description']}",
                                                            style: const TextStyle(fontSize: 16, color: Colors.green),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.white,
                                                  content: Container(
                                                    width: 420,
                                                    height: 320,
                                                    color: Colors.white,
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        if (latLng != null) ...[
                                                          SizedBox(
                                                            width: 380,
                                                            height: 220,
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(12),
                                                              child: FlutterMap(
                                                                options: MapOptions(
                                                                  center: latLng,
                                                                  zoom: 16,
                                                                ),
                                                                children: [
                                                                  TileLayer(
                                                                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                                    subdomains: ['a', 'b', 'c'],
                                                                  ),
                                                                  MarkerLayer(
                                                                    markers: [
                                                                      Marker(
                                                                        point: latLng,
                                                                        width: 40,
                                                                        height: 40,
                                                                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                        ] else ...[
                                                          Text("Location data (latitude/longitude) not found in this file or is invalid.", style: TextStyle(fontSize: 14)),
                                                          SizedBox(height: 10),
                                                          Text("Raw data: ", style: TextStyle(fontSize: 14)),
                                                          Text(const JsonEncoder.withIndent('  ').convert(jsonData), style: TextStyle(fontSize: 12)),
                                                        ]
                                                      ],
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: Text("Close", style: TextStyle(color: Colors.black, fontSize: 18)),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.all(screenWidth < 400 ? 8.0 : 16.0),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final isNarrow = constraints.maxWidth < 500;
                                            if (isNarrow) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on, color: Color(0xFF0F3060)),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          address.isNotEmpty ? address : 'Unknown location',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['emergencyType'] != null &&
                                                      (jsonSnapshot.data!['emergencyType'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Emergency: ${jsonSnapshot.data!['emergencyType']}",
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.red,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['contactNumber'] != null &&
                                                      (jsonSnapshot.data!['contactNumber'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Contact: ${jsonSnapshot.data!['contactNumber']}",
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['disabilityType'] != null &&
                                                      (jsonSnapshot.data!['disabilityType'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Disability: ${jsonSnapshot.data!['disabilityType']}",
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.purple,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['description'] != null &&
                                                      (jsonSnapshot.data!['description'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Description: ${jsonSnapshot.data!['description']}",
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(dateTime),
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Icon(Icons.visibility),
                                                  ),
                                                ],
                                              );
                                            } else {
                                              return Row(
                                          children: [
                                            const Icon(Icons.location_on, color: Color(0xFF0F3060)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    address.isNotEmpty ? address : 'Unknown location',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['emergencyType'] != null &&
                                                      (jsonSnapshot.data!['emergencyType'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Emergency: ${jsonSnapshot.data!['emergencyType']}",
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.red,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['contactNumber'] != null &&
                                                      (jsonSnapshot.data!['contactNumber'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Contact: ${jsonSnapshot.data!['contactNumber']}",
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['disabilityType'] != null &&
                                                      (jsonSnapshot.data!['disabilityType'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Disability: ${jsonSnapshot.data!['disabilityType']}",
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.purple,
                                                        ),
                                                      ),
                                                    ),
                                                  if (jsonSnapshot.hasData &&
                                                      jsonSnapshot.data != null &&
                                                      jsonSnapshot.data!['description'] != null &&
                                                      (jsonSnapshot.data!['description'] as String).trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                                      child: Text(
                                                        "Description: ${jsonSnapshot.data!['description']}",
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(dateTime),
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.visibility),
                                          ],
                                              );
                                            }
                                          },
                                        ),
                                      ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 