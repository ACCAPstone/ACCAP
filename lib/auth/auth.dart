
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
  @override
  Widget build(BuildContext context) {
    return LoginPage(onTap: () {});
  }
}
