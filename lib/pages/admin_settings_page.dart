import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widget/notificationWidget.dart';
import 'admin_notifications_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? name;
  String? username;
  String? email;
  bool isLoading = true;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _nameChanged = false;
  bool _usernameChanged = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminInfo();
  }

  Future<void> _fetchAdminInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('admins').doc(user.email).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          name = data?['name'] ?? '';
          username = data?['username'] ?? '';
          email = user.email;
          isLoading = false;
          _nameController.text = name ?? '';
          _usernameController.text = username ?? '';
        });
      }
    }
  }

  Future<void> _showDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNameAndUsername() async {
    if (email == null) return;
    try {
      await _firestore.collection('admins').doc(email).update({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
      });
      setState(() {
        name = _nameController.text.trim();
        username = _usernameController.text.trim();
        _nameChanged = false;
        _usernameChanged = false;
      });
      await _showDialog('Success', 'Profile updated successfully.');
    } catch (e) {
      await _showDialog('Error', 'Failed to update profile: $e');
    }
  }

  Future<void> _changeEmail() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    bool showPassword = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            title: const Text('Change Email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400, // <-- Set your desired width here
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(labelText: 'New Email', labelStyle: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(fontSize: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility : Icons.visibility_off,
                          size: 28,
                        ),
                        onPressed: () => setState(() => showPassword = !showPassword),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 18, color: Colors.black)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'email': emailController.text.trim(),
                    'password': passwordController.text.trim(),
                  });
                },
                child: const Text('Update', style: TextStyle(fontSize: 18, color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );

    if (result != null &&
        result['email']!.isNotEmpty &&
        result['password']!.isNotEmpty &&
        _auth.currentUser != null) {
      try {
        // Re-authenticate
        final cred = EmailAuthProvider.credential(
          email: email!,
          password: result['password']!,
        );
        await _auth.currentUser!.reauthenticateWithCredential(cred);

        // Update email in Firebase Auth
        await _auth.currentUser!.updateEmail(result['email']!);

        // Move Firestore document to new email as document ID
        final oldDocRef = _firestore.collection('admins').doc(email);
        final newDocRef = _firestore.collection('admins').doc(result['email']);
        final oldData = (await oldDocRef.get()).data();
        if (oldData != null) {
          oldData['email'] = result['email'];
          await newDocRef.set(oldData);
          await oldDocRef.delete();
        }

        setState(() {
          email = result['email'];
        });
        await _showDialog('Success', 'Email updated successfully.');
      } catch (e) {
        await _showDialog('Error', 'Failed to update email: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    bool showCurrentPassword = false;
    bool showNewPassword = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            title: const Text('Change Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: !showCurrentPassword,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(fontSize: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          size: 28,
                        ),
                        onPressed: () => setState(() => showCurrentPassword = !showCurrentPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(fontSize: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showNewPassword ? Icons.visibility : Icons.visibility_off,
                          size: 28,
                        ),
                        onPressed: () => setState(() => showNewPassword = !showNewPassword),
                      ),
                      helperText: 'Password must be at least 6 characters',
                      helperStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 18,color: Colors.black)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'currentPassword': currentPasswordController.text.trim(),
                    'newPassword': newPasswordController.text.trim(),
                  });
                },
                child: const Text('Update', style: TextStyle(fontSize: 18,color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );

    if (result != null &&
        result['currentPassword']!.isNotEmpty &&
        result['newPassword']!.isNotEmpty &&
        _auth.currentUser != null) {
      // Password requirements check
      if (result['newPassword']!.length < 6) {
        await _showDialog('Error', 'Password must be at least 6 characters long.');
        return;
      }
      try {
        // Re-authenticate
        final cred = EmailAuthProvider.credential(
          email: email!,
          password: result['currentPassword']!,
        );
        await _auth.currentUser!.reauthenticateWithCredential(cred);

        await _auth.currentUser!.updatePassword(result['newPassword']!);
        await _showDialog('Success', 'Password updated successfully.');
      } catch (e) {
        await _showDialog('Error', 'Failed to update password: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: const Text(
          'ACCOUNT SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 32,
          ),
        ),
        elevation: 0,
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
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
                              width: 16,
                              height: 16,
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
                  icon: Icon(Icons.notifications, color: Colors.black, size: 32),
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
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          child: Container(
            width: isSmallScreen ? double.infinity : 600,
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _nameChanged = val.trim() != (name ?? '');
                    });
                  },
                ),
                const SizedBox(height: 28),
                const Text(
                  'Username:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 1),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _usernameChanged = val.trim() != (username ?? '');
                    });
                  },
                ),
                const SizedBox(height: 28),
                // Email row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 130,
                      child: Text(
                        'Email:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        email ?? '',
                        style: const TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _changeEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Change Email'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Password row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 130,
                      child: Text(
                        'Password:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '********',
                        style: TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Change Password'),
                    ),
                  ],
                ),
                if ((_nameChanged && _nameController.text.trim().isNotEmpty) ||
                    (_usernameChanged && _usernameController.text.trim().isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3060),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _updateNameAndUsername,
                        child: const Text('Change'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}