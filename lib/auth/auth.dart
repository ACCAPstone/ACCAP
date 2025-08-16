
import 'package:firebase/pages/login_page.dart'; // Login Page
// Admin Home Page
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
