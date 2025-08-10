
import 'package:firebase/pages/login_page.dart'; // Login Page
import 'package:firebase/pages/admin_page.dart'; // Admin Home Page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  User? _user;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _checkIfAdmin(user.email!);
      } else {
        setState(() {
          _user = null;
          _isAdmin = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkIfAdmin(String email) async {
    try {
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(email).get();

      if (!mounted) return;

      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _isAdmin = adminDoc.exists && (adminDoc.data()?['role'] == 'admin' || adminDoc.data()?['role'] == 'barangay');
        _isLoading = false;
      });

      if (_isAdmin) {
        _navigateTo(const AdminHomePage());
      } else {
        await FirebaseAuth.instance.signOut(); // Log out if not admin
        _navigateTo(LoginPage(onTap: () {})); // Redirect back to login
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error checking admin role: $e");
    }
  }

  void _navigateTo(Widget page) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _user == null ? LoginPage(onTap: () {}) : const Scaffold();
  }
}
