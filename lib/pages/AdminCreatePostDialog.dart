import 'dart:io';
import 'package:flutter/foundation.dart'; // Import this for kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // Import for ImageSource
import 'package:image_picker_web/image_picker_web.dart'; // Import for Web support
import 'package:firebase_storage/firebase_storage.dart';

class AdminPostDialogContent extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;
  final bool autoPickImage;
  final bool autoEvent;

  const AdminPostDialogContent({super.key, this.postId, this.initialData, this.autoPickImage = false, this.autoEvent = false});

  @override
  State<AdminPostDialogContent> createState() => _AdminPostDialogContent();
  
}


class _AdminPostDialogContent extends State<AdminPostDialogContent> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedType = 'General';
  List<String> _selectedFilters = [];
  bool _isEvent = false;
  DateTime? _eventDate;

  final List<String> _filters = [
    'All',
    'Hearing Impairment',
    'Speech Impairment',
    'Visual Impairment',
    "Mobility Impairment"
  ];

  bool _isPosting = false;
  final List<Uint8List> _selectedImageBytes = []; // Web (Uint8List)
  final List<File> _selectedImages = []; // Mobile (File)
  List<String> _existingImageUrls = []; // For editing: already uploaded images

  final ImagePicker _picker = ImagePicker(); // Initialize ImagePicker
  
@override
void initState() {
  super.initState();
  if (widget.initialData != null) {
    _titleController.text = widget.initialData!['title'] ?? '';
    _contentController.text = widget.initialData!['content'] ?? '';
    _selectedType = widget.initialData!['type'] ?? 'General';
    _selectedFilters = List<String>.from(widget.initialData!['filters'] ?? []);
    // Load existing images for editing
    final img = widget.initialData!['imageUrl'];
    if (img != null) {
      if (img is String) {
        _existingImageUrls = [img];
      } else if (img is List) {
        _existingImageUrls = List<String>.from(img);
      }
    }
  }

  // Auto actions for quick buttons
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (widget.autoPickImage) {
      await _pickImage();
    }
    if (widget.autoEvent) {
      setState(() {
        _isEvent = true;
      });
      // Show date picker immediately
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.black,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                ),
              ),
              dialogTheme: DialogTheme(backgroundColor: Colors.white),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _eventDate = picked;
        });
      }
    }
  });
}

  Future<void> _pickImage() async {
    if (kIsWeb) {
      if (_selectedImageBytes.length >= 3) return;
      Uint8List? pickedBytes = await ImagePickerWeb.getImageAsBytes();
      if (pickedBytes != null) {
        setState(() {
          _selectedImageBytes.add(pickedBytes);
        });
      }
    } else {
      if (_selectedImages.length >= 3) return;
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    try {
      if (kIsWeb) {
        for (var imgBytes in _selectedImageBytes) {
          String fileName = "announcements/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg";
          Reference ref = FirebaseStorage.instance.ref(fileName);
          UploadTask uploadTask = ref.putData(imgBytes);
          TaskSnapshot snapshot = await uploadTask;
          urls.add(await snapshot.ref.getDownloadURL());
        }
      } else {
        for (var imgFile in _selectedImages) {
          String fileName = "announcements/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg";
          Reference ref = FirebaseStorage.instance.ref(fileName);
          UploadTask uploadTask = ref.putFile(imgFile);
          TaskSnapshot snapshot = await uploadTask;
          urls.add(await snapshot.ref.getDownloadURL());
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload image: $e")),
      );
    }
    return urls;
  }

 Future<void> _postAnnouncement() async {
  if (_titleController.text.isEmpty || _contentController.text.isEmpty) return;
  if (_isPosting) return;

  setState(() {
    _isPosting = true;
  });

  List<String> imageUrls = [];
  // Add existing images that were not removed
  imageUrls.addAll(_existingImageUrls);
  // Upload new images
  if (_selectedImages.isNotEmpty || _selectedImageBytes.isNotEmpty) {
    imageUrls.addAll(await _uploadImages());
  }

  // Fetch admin name from Firestore
  String? adminName;
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(currentUser.email).get();
    if (adminDoc.exists) {
      adminName = adminDoc['name'] ?? 'Admin';
    } else {
      adminName = 'Admin';
    }
  } else {
    adminName = 'Admin';
  }

  final data = {
    'title': _titleController.text,
    'content': _contentController.text,
    'type': _selectedType,
    'filters': _selectedFilters,
    'timestamp': FieldValue.serverTimestamp(),
    'adminEmail': FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? 'unknown@domain.com',
    'imageUrl': imageUrls,
    'isEvent': _isEvent,
    'eventDate': _isEvent && _eventDate != null ? Timestamp.fromDate(_eventDate!) : null,
    'name': adminName,
  };

  if (widget.postId != null) {
    await FirebaseFirestore.instance.collection('announcements').doc(widget.postId).update(data);
  } else {
    await FirebaseFirestore.instance.collection('announcements').add(data);
  }

  if (mounted) {
    Navigator.of(context).pop(); // close dialog after submit
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Announcement saved successfully!")),
    );
  }

  setState(() {
    _isPosting = false;
  });
}

  void _updateFilters(String filter, bool selected) {
    setState(() {
      if (filter == 'All') {
        _selectedFilters = selected ? ['All'] : [];
      } else {
        if (selected) {
          _selectedFilters.add(filter);
          _selectedFilters.remove('All');
        } else {
          _selectedFilters.remove(filter);
        }

        List<String> specificFilters = _filters.where((f) => f != 'All').toList();
        if (_selectedFilters.toSet().containsAll(specificFilters)) {
          _selectedFilters = ['All'];
        }
      }
    });
  }
  

@override
Widget build(BuildContext context) {
  return Center(
    child: Container(
     constraints: BoxConstraints(
  maxWidth: MediaQuery.of(context).size.width * 0.9,
),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:  [
        Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: const [
        Icon(Icons.campaign, color: Color.fromARGB(255, 4, 57, 138), size: 32),
        SizedBox(width: 12),
        Text(
          "Create Post",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    ),
    IconButton(
      icon: const Icon(Icons.close, color: Colors.grey),
      onPressed: () => Navigator.of(context).pop(),
      tooltip: "Close",
    ),
  ],
),
          const SizedBox(height: 32),
          const Text("Post Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Wrap(
            spacing: 10,
            children: [
              for (var type in ['General', 'Seminar', 'Job Offering'])
                ChoiceChip(
                  label: Text(
                    type,
                    style: TextStyle(
                      color: _selectedType == type ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: _selectedType == type,
                  selectedColor: const Color(0xFF0F3060),
                  backgroundColor: Colors.white,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                ),

            ],
          ),

          const SizedBox(height: 16),
          const Text("Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _filters.map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: _selectedFilters.contains(filter),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                selectedColor: const Color(0xFF0F3060),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: _selectedFilters.contains(filter) ? Colors.white : Colors.black,
                ),
                onSelected: (selected) => _updateFilters(filter, selected),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          const Text("Title", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Enter post title",
              filled: true,
              fillColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Enter Description",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Is this an event?"),
              value: _isEvent,
              activeColor: Color.fromARGB(255, 0, 48, 96),
              onChanged: (bool? value) {
                setState(() {
                  _isEvent = value ?? false;
                });
              },
            ),

            if (_isEvent)
              Container(
                color: Colors.white,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Event Date"),
                  subtitle: Text(
                    _eventDate != null
                        ? "${_eventDate!.month}/${_eventDate!.day}/${_eventDate!.year}"
                        : "Select a date",
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.black, // Header and selected date
                              onPrimary: Colors.white, // Text on header
                              onSurface: Colors.black, // Default text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black, // OK/Cancel button color
                              ),
                            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _eventDate = picked;
                      });
                    }
                  },
                ),
              ),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: _pickImage,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: const BorderSide(color: Colors.black12),
              backgroundColor: Color.fromARGB(255, 0, 48, 96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text("Select Image",style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),),
          ),

          const SizedBox(height: 16),

          if (_selectedImages.isNotEmpty || _selectedImageBytes.isNotEmpty || _existingImageUrls.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Preview:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final imageSize = (width - 12) / 3; // 3 images per row, 2*6px gap
                    final border = Border.all(color: Colors.grey.shade300, width: 5);
                    final borderRadius = BorderRadius.circular(10);

                    List<Widget> buildImageTiles<T>(List<T> images, bool isWeb, {bool isExisting = false}) {
                      return List.generate(images.length, (i) {
                        return Stack(
                          children: [
                            Container(
                              width: imageSize,
                              height: imageSize,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                border: border,
                                borderRadius: borderRadius,
                              ),
                              child: ClipRRect(
                                borderRadius: borderRadius,
                                child: isExisting
                                  ? Image.network(images[i] as String, fit: BoxFit.cover)
                                  : isWeb
                                    ? Image.memory(images[i] as Uint8List, fit: BoxFit.cover)
                                    : Image.file(images[i] as File, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isExisting) {
                                      _existingImageUrls.removeAt(i);
                                    } else if (isWeb) {
                                      _selectedImageBytes.removeAt(i);
                                    } else {
                                      _selectedImages.removeAt(i);
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        );
                      });
                    }

                    final existingTiles = buildImageTiles(_existingImageUrls, false, isExisting: true);
                    final newTiles = kIsWeb
                      ? buildImageTiles(_selectedImageBytes, true)
                      : buildImageTiles(_selectedImages, false);

                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [...existingTiles, ...newTiles],
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 24),

         Align(
  alignment: Alignment.center,
  child: SizedBox(
    width: double.infinity, // Make button stretch to full width
    child: ElevatedButton(
      onPressed: _isPosting ? null : _postAnnouncement,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F3060),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: _isPosting
          ? const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
              "Post Announcement",
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
    ),
  ),
),

        ],
      ),
    ),
  )));
}
}