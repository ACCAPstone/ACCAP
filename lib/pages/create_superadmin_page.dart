import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateSuperAdminPage extends StatefulWidget {
  const CreateSuperAdminPage({super.key});

  @override
  State<CreateSuperAdminPage> createState() => _CreateSuperAdminPageState();
}

class _CreateSuperAdminPageState extends State<CreateSuperAdminPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _email = '';
  String _password = '';
  String _name = '';
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _createSuperAdmin() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        // Create Firebase Auth user
        print('Creating Superadmin Firebase Auth user for: $_email');
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        print('Superadmin Firebase Auth user created successfully');

        // Create Firestore document
        print('Creating Superadmin Firestore document for: $_email');
        
        Map<String, dynamic> adminData = {
          'email': _email,
          'username': _username,
          'name': _name,
          'role': 'admin',
          'superAdmin': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isOnline': true,
        };
        
        print('Superadmin data to save: $adminData');
        
        await _firestore.collection('admins').doc(_email).set(adminData);
        print('Superadmin Firestore document created successfully');
        
        // Verify the document was created
        DocumentSnapshot verifyDoc = await _firestore.collection('admins').doc(_email).get();
        if (verifyDoc.exists) {
          print('Superadmin document verification successful: ${verifyDoc.data()}');
        } else {
          print('Superadmin document verification failed: document does not exist');
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Superadmin account created successfully! You can now log in.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to login or home
        Navigator.of(context).pop();
        
      } on FirebaseAuthException catch (e) {
        print('Firebase Auth Exception: ${e.code} - ${e.message}');
        String errorMessage = 'An error occurred';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already in use.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } on FirebaseException catch (e) {
        print('Firebase Exception: ${e.code} - ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firestore error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        print('General Exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating superadmin: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        title: const Text(
          'CREATE SUPERADMIN ACCOUNT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 64,
                      color: Color.fromARGB(255, 0, 48, 96),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Create New Superadmin Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 48, 96),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will create a new Superadmin account to replace the deleted one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter username' : null,
                      onSaved: (value) => _username = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter full name' : null,
                      onSaved: (value) => _name = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) => value == null || !value.contains('@')
                          ? 'Please enter a valid email'
                          : null,
                      onSaved: (value) => _email = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) =>
                          value == null || value.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                      onSaved: (value) => _password = value!,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _createSuperAdmin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Create Superadmin Account',
                                style: TextStyle(
                                  fontSize: 16,
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
        ),
      ),
    );
  }
}
