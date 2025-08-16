import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _email = '';
  String _password = '';
  String _selectedRole = 'admin'; // Default role
  bool _isLoading = false;
  bool _isSuperAdmin = false;
  bool _checkingRole = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseApp? _secondaryApp;
  int entriesPerPage = 10;
  int currentPage = 0;



  // Role options
  final List<Map<String, String>> _roleOptions = [
    {'value': 'admin', 'label': 'Admin'},
    {'value': 'barangay', 'label': 'Barangay Account'},
  ];

  @override
  void initState() {
    super.initState();
    _checkIfSuperAdmin();
  }

  Future<List<QueryDocumentSnapshot>> _getAllAdmins() async {
    QuerySnapshot snapshot = await _firestore
        .collection('admins')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs;
  }

  Future<void> _checkIfSuperAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isSuperAdmin = false;
        _checkingRole = false;
      });
      return;
    }

    final adminDoc = await _firestore.collection('admins').doc(currentUser.email).get();
    if (adminDoc.exists && adminDoc.data() != null) {
      final data = adminDoc.data()!;
      if (data['superAdmin'] == true) {
        _isSuperAdmin = true;
      }
    }
    setState(() {
      _checkingRole = false;
    });
  }





  Future<void> _createAdmin({required String name}) async {
    if (_isLoading) return; // prevent double submit
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        print('Creating Firebase Auth user for: $_email');
        // Initialize a secondary Firebase app so current super admin session is not affected
        try {
          _secondaryApp = Firebase.app('accapSecondary');
        } catch (_) {
          _secondaryApp = await Firebase.initializeApp(
            name: 'accapSecondary',
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }

        final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);

        // Create the auth user with provided password
        final UserCredential created = await secondaryAuth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Send email verification
        if (created.user != null) {
          await created.user!.sendEmailVerification();
        }

        // Sign out from secondary auth to avoid impacting current admin session
        await secondaryAuth.signOut();

        // Now create Firestore document
        print('Creating Firestore document for: $_email');
        Map<String, dynamic> adminData = {
          'email': _email,
          'username': _username,
          'name': name,
          'role': _selectedRole,
          'superAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': null,
          'isOnline': false,
          'emailVerified': false,
          'verificationDate': null,
          'isLegacyAccount': false,
        };

        DocumentReference docRef = _firestore.collection('admins').doc(_email);
        await docRef.set(adminData);
        print('Firestore document created successfully');

        // Notify success and that a verification email was sent
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Account Created Successfully'),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mark_email_read,
                        color: Colors.green,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '${_selectedRole == 'barangay' ? 'Barangay account' : 'Admin account'} created successfully!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'A verification email has been sent to $_email. The user must verify their email before they can sign in.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        
      } on FirebaseException catch (e) {
        print('Firebase Exception: ${e.code} - ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        print('General Exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating admin: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAdmin(String email) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Confirm Delete'),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        content: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: 250,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to delete this admin account?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _firestore.collection('admins').doc(email).delete();
      // Note: We only delete from Firestore, not from Firebase Auth
      // The user will need to be manually deleted from Firebase Auth console if needed
    }
  }

  void _showCreateAdminDialog() {
    bool obscurePassword = true;
    String name = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Create Admin'),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: Container(
                width: 400,
                constraints: BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: AbsorbPointer(
                    absorbing: _isLoading,
                    child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                            enabled: !_isLoading,
                          decoration: InputDecoration(labelText: 'Username'),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter username' : null,
                          onSaved: (value) => _username = value!,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                            enabled: !_isLoading,
                          decoration: InputDecoration(labelText: 'Name'),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter name' : null,
                          onSaved: (value) => name = value!,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                            enabled: !_isLoading,
                          decoration: InputDecoration(labelText: 'Email'),
                          textInputAction: TextInputAction.next,
                          validator: (value) => value == null || !value.contains('@')
                              ? 'Please enter a valid email'
                              : null,
                          onSaved: (value) => _email = value!,
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(labelText: 'Role'),
                          items: _roleOptions.map((role) {
                            return DropdownMenuItem<String>(
                              value: role['value'],
                              child: Text(role['label']!),
                            );
                          }).toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedRole = value!;
                                    });
                                  },
                          validator: (value) => value == null ? 'Please select a role' : null,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                          onFieldSubmitted: (_) async {
                              if (_isLoading) return;
                              if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              await _createAdmin(name: name);
                            }
                          },
                          validator: (value) =>
                          value == null || value.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                          onSaved: (value) => _password = value!,
                        ),
                        SizedBox(height: 24),
                          _isLoading
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: () async {
                                    if (_isLoading) return;
                                    if (_formKey.currentState!.validate()) {
                                      _formKey.currentState!.save();
                                      await _createAdmin(name: name);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Submit',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editAdmin(String email, String currentUsername, {String? currentName, String? currentRole}) async {
    TextEditingController usernameController = TextEditingController(text: currentUsername);
    TextEditingController nameController = TextEditingController(text: currentName ?? '');
    TextEditingController emailController = TextEditingController(text: email);
    // Removed unused controller to satisfy lints
    TextEditingController newPasswordController = TextEditingController();
    FocusNode keyboardFocusNode = FocusNode();
    bool obscureNewPassword = true;
    bool showPasswordFields = false;
    String errorMessage = '';
    String selectedRole = currentRole ?? 'admin';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> handleSubmit() async {
            String newUsername = usernameController.text.trim();
            String newName = nameController.text.trim();
            String newEmail = emailController.text.trim();

            if (newUsername.isEmpty || newName.isEmpty || newEmail.isEmpty || !newEmail.contains('@')) {
              setState(() {
                errorMessage = "Please enter valid username, name, and email.";
              });
              return;
            }

            final docRef = _firestore.collection('admins').doc(email);

            if (newEmail != email) {
              final oldData = (await docRef.get()).data();
                              if (oldData != null) {
                  oldData['username'] = newUsername;
                  oldData['name'] = newName;
                  oldData['email'] = newEmail;
                  oldData['role'] = selectedRole;

                WriteBatch batch = _firestore.batch();
                DocumentReference newDocRef = _firestore.collection('admins').doc(newEmail);

                batch.set(newDocRef, oldData);
                batch.delete(docRef);

                await batch.commit();
              }
            } else {
              await docRef.update({
                'username': newUsername, 
                'name': newName,
                'role': selectedRole,
              });
            }

            if (showPasswordFields) {
              String newPassword = newPasswordController.text.trim();
              if (newPassword.length < 6) {
                setState(() {
                  errorMessage = "New password must be at least 6 characters.";
                });
                return;
              }
              try {
                User? user = await _auth.signInWithEmailAndPassword(email: email, password: newPassword).then((cred) => cred.user);
                if (user != null) {
                  await user.updatePassword(newPassword);
                  await _auth.signOut();
                }
              } on FirebaseAuthException catch (e) {
                setState(() {
                  errorMessage = e.message ?? "Password update failed.";
                });
                return;
              }
            }

            await Future.delayed(const Duration(milliseconds: 100));
            if (context.mounted) {
              Navigator.of(context).pop();
              setState(() {});
            }
          }

          return AlertDialog(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 0),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Admin'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            content: RawKeyboardListener(
              focusNode: keyboardFocusNode,
              autofocus: true,
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  handleSubmit();
                }
              },
              child: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: _roleOptions.map((role) {
                          return DropdownMenuItem<String>(
                            value: role['value'],
                            child: Text(role['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (showPasswordFields) ...[
                        StatefulBuilder(
                          builder: (context, setState) {
                            return TextField(
                              controller: newPasswordController,
                              obscureText: obscureNewPassword,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      obscureNewPassword = !obscureNewPassword;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextButton(
                        onPressed: () {
                          setState(() {
                            showPasswordFields = !showPasswordFields;
                          });
                        },
                        child: Text(
                          showPasswordFields ? "Cancel Password Change" : "Change Password",
                          style: const TextStyle(color: Color.fromARGB(255, 0, 48, 96)),
                        ),
                      ),
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: handleSubmit,
                child: const Text('Save', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('Unauthorized', style: TextStyle(color: Colors.black)),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Text('You do not have permission to manage admins.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        title: Text(
          'ADMIN MANAGEMENT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 25,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateAdminDialog,
              icon: Icon(Icons.add, color: Color.fromARGB(255, 0, 48, 96)),
              label: Text(
                'Create Admin',
                style: TextStyle(color: Color.fromARGB(255, 0, 48, 96)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color.fromARGB(255, 0, 48, 96),
                side: BorderSide(color: Color.fromARGB(255, 0, 48, 96)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
        iconTheme: IconThemeData(color: Colors.black),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color.fromARGB(217, 217, 217, 217),
                  child: Row(
                    children: const [
                      Expanded(flex: 1, child: Center(child: Text("Admin ID", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Username", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Role", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 3, child: Center(child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Date Created", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Email Verified", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _getAllAdmins(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      // Separate superAdmin and other admins
                      final allAdmins = snapshot.data!
                          .where((doc) => doc['createdAt'] != null)
                          .toList();

                      QueryDocumentSnapshot? superAdminDoc;
                      List<QueryDocumentSnapshot> otherAdmins = [];

                      for (var doc in allAdmins) {
                        if ((doc['role'] == 'superAdmin') || (doc['superAdmin'] == true)) {
                          superAdminDoc = doc;
                        } else {
                          otherAdmins.add(doc);
                        }
                      }

                      // Sort other admins by createdAt ascending (oldest first)
                      otherAdmins.sort((a, b) {
                        Timestamp aTime = a['createdAt'];
                        Timestamp bTime = b['createdAt'];
                        return aTime.compareTo(bTime);
                      });

                      // Compose the final list: superAdmin first, then others
                      List<QueryDocumentSnapshot> sortedAdmins = [];
                      if (superAdminDoc != null) {
                        sortedAdmins.add(superAdminDoc);
                      }
                      sortedAdmins.addAll(otherAdmins);

                      final totalAdmins = sortedAdmins.length;

                      // Pagination: superAdmin always on first page
                      int pageCount = (totalAdmins / entriesPerPage).ceil();
                      int start = currentPage * entriesPerPage;
                      int end = ((start + entriesPerPage) > totalAdmins
                          ? totalAdmins
                          : (start + entriesPerPage));
                      List<QueryDocumentSnapshot> adminsToShow;

                      if (currentPage == 0) {
                        // Always show superAdmin at the top of the first page
                        adminsToShow = sortedAdmins.sublist(start, end);
                      } else {
                        // On other pages, skip the superAdmin
                        int adjustedStart = start;
                        int adjustedEnd = end;
                        if (superAdminDoc != null) {
                          adjustedStart = start == 0 ? 1 : start;
                          adjustedEnd = end;
                          // Prevent out of range
                          if (adjustedStart > sortedAdmins.length) adjustedStart = sortedAdmins.length;
                          if (adjustedEnd > sortedAdmins.length) adjustedEnd = sortedAdmins.length;
                          adminsToShow = sortedAdmins.sublist(adjustedStart, adjustedEnd);
                        } else {
                          adminsToShow = sortedAdmins.sublist(start, end);
                        }
                      }

                      if (sortedAdmins.isEmpty) {
                        return Center(child: Text('No admins found.'));
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Keep rowsToShow for layout height; visibleRows not needed
                                int rowsToShow = entriesPerPage;
                                double rowHeight = constraints.maxHeight / rowsToShow;

                                return ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: adminsToShow.length,
                                  itemBuilder: (context, index) {
                                    var admin = adminsToShow[index];
                                    int adminId;
                                    if (currentPage == 0 && index == 0 && superAdminDoc != null) {
                                      adminId = 1;
                                    } else {
                                      // If superAdmin exists, offset IDs for others
                                      adminId = (superAdminDoc != null)
                                          ? (currentPage * entriesPerPage + index + 1)
                                          : (currentPage * entriesPerPage + index + 1);
                                      if (superAdminDoc != null && !(currentPage == 0 && index == 0)) {
                                        adminId = (currentPage == 0)
                                            ? index + 1 // first page, after superAdmin
                                            : (currentPage * entriesPerPage + index + 1);
                                      }
                                    }

                                    // If superAdmin is present, always assign 1 to the first row
                                    if (superAdminDoc != null && currentPage == 0 && index == 0) {
                                      adminId = 1;
                                    } else if (superAdminDoc != null) {
                                      adminId = (currentPage * entriesPerPage + index + 1);
                                      if (currentPage == 0) adminId = index + 1;
                                    } else {
                                      adminId = (currentPage * entriesPerPage + index + 1);
                                    }

                                    final Map<String, dynamic> adminMap = admin.data() as Map<String, dynamic>;

                                    Timestamp? createdAtTimestamp = adminMap['createdAt'] as Timestamp?;
                                    String createdAtFormatted = 'No Date';
                                    if (createdAtTimestamp != null) {
                                      DateTime createdAt = createdAtTimestamp.toDate();
                                      createdAtFormatted = "${createdAt.month}/${createdAt.day}/${createdAt.year}";
                                    }

                                    String name = (adminMap['name'] ?? '') as String;

                                    // Handle account verification status
                                    final bool isLegacyAccount = adminMap['isLegacyAccount'] == true;
                                    final bool hasEmailVerifiedField = adminMap.containsKey('emailVerified');
                                    final bool isEmailVerified = hasEmailVerifiedField ? (adminMap['emailVerified'] == true) : false;
                                    
                                    String verificationStatus;
                                    if (isLegacyAccount) {
                                      verificationStatus = 'Legacy Account';
                                    } else if (isEmailVerified) {
                                      verificationStatus = 'Verified';
                                    } else {
                                      verificationStatus = 'Pending Verification';
                                    }

                                    String verificationDateFormatted = 'N/A';
                                    Timestamp? verificationTimestamp = adminMap['verificationDate'] as Timestamp?;
                                    if (verificationTimestamp != null) {
                                      DateTime verificationDate = verificationTimestamp.toDate();
                                      verificationDateFormatted = "${verificationDate.month}/${verificationDate.day}/${verificationDate.year}";
                                    }

                                    return Container(
                                      height: rowHeight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: Text(
                                                adminId.toString(),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? Colors.blue
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                admin['username'] ?? 'No Username',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? Colors.blue
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                name.isNotEmpty ? name : '-',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? Colors.blue
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: admin['role'] == 'barangay' 
                                                      ? Colors.orange.withOpacity(0.2)
                                                      : Colors.blue.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: admin['role'] == 'barangay' 
                                                        ? Colors.orange
                                                        : Colors.blue,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  admin['role'] == 'barangay' ? 'Barangay' : 'Admin',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: admin['role'] == 'barangay' 
                                                        ? Colors.orange.shade700
                                                        : Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Center(
                                              child: Text(
                                                admin['email'],
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? Colors.blue
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                createdAtFormatted,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: (superAdminDoc != null && currentPage == 0 && index == 0)
                                                      ? Colors.blue
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: (() {
                                                bool isOnline = adminMap['isOnline'] == true;
                                                Timestamp? lastLoginTimestamp = adminMap['lastLogin'];
                                                String lastLoginFormatted = 'Never';
                                                if (lastLoginTimestamp != null) {
                                                  DateTime lastLogin = lastLoginTimestamp.toDate();
                                                  lastLoginFormatted = "${lastLogin.month}/${lastLogin.day}/${lastLogin.year} ${lastLogin.hour}:${lastLogin.minute.toString().padLeft(2, '0')}";
                                                }
                                                return Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          isOnline ? Icons.circle : Icons.circle_outlined,
                                                          color: isOnline ? Colors.green : Colors.grey,
                                                          size: 12,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          isOnline ? "Online" : "Offline",
                                                          style: TextStyle(fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                    if (!isOnline)
                                                      Text(
                                                        lastLoginTimestamp != null
                                                            ? "Last online: $lastLoginFormatted"
                                                            : "Never logged in",
                                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                  ],
                                                );
                                              })(),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: verificationStatus == 'Verified'
                                                          ? Colors.green.withOpacity(0.2)
                                                          : verificationStatus == 'Legacy Account'
                                                              ? Colors.grey.withOpacity(0.2)
                                                              : Colors.orange.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: verificationStatus == 'Verified'
                                                            ? Colors.green
                                                            : verificationStatus == 'Legacy Account'
                                                                ? Colors.grey
                                                                : Colors.orange,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      verificationStatus,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: verificationStatus == 'Verified'
                                                            ? Colors.green.shade700
                                                            : verificationStatus == 'Legacy Account'
                                                                ? Colors.grey.shade700
                                                                : Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (verificationStatus == 'Verified')
                                                    Text(
                                                      "Verified: $verificationDateFormatted",
                                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                                    ),
                                                  if (verificationStatus == 'Legacy Account')
                                                    Text(
                                                      "Created before 2FA",
                                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                                    ),
                                                  if (verificationStatus == 'Pending Verification')
                                                    Text(
                                                      "Awaiting email verification",
                                                      style: TextStyle(fontSize: 10, color: Colors.orange),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: () => _editAdmin(admin['email'], admin['username'], currentName: admin['name'], currentRole: admin['role']),
                                                    icon: Icon(Icons.edit, color: Colors.white, size: 16),
                                                    label: Text('Edit', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Color.fromARGB(255, 0, 48, 96),
                                                      foregroundColor: Colors.white,
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: Size(0, 32),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _deleteAdmin(admin['email']),
                                                    icon: Icon(Icons.delete, color: Colors.white, size: 16),
                                                    label: Text('Delete', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: Size(0, 32),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),

                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          if (pageCount > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
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
                      );
                    },
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