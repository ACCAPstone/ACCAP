import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailTextController = TextEditingController();
  final passwordTextController = TextEditingController();
  final confirmPasswordTextController = TextEditingController();
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  bool _isPasswordVisible = false;

  Future<void> register() async {
    setState(() {
      emailError = null;
      passwordError = null;
      confirmPasswordError = null;
    });

    if (passwordTextController.text.trim() != confirmPasswordTextController.text.trim()) {
      setState(() {
        confirmPasswordError = 'Passwords do not match.';
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextController.text.trim(),
        password: passwordTextController.text.trim(),
      );
      User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('admins').doc(user.email).set({
          'email': user.email,
          'role': 'admin',
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle registration errors
      if (e.code == 'email-already-in-use') {
        setState(() {
          emailError = "This email is already in use.";
        });
      } else {
        setState(() {
          emailError = "Error: ${e.message}";
        });
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 250, 250, 250),
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 30, 136, 229),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double cardWidth = screenWidth > 800
            ? 500
            : screenWidth > 600
                ? 400
                : screenWidth * 0.9;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/ACCAP_LOGO.png',
                  width: 150,
                  height: 150,
                ),
                Stack(
                  children: [
                    Text(
                      "ACCAP",
                      style: TextStyle(
                        letterSpacing: 3.0,
                        fontFamily: "Inter",
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = const Color.fromARGB(255, 28, 113, 166),
                      ),
                    ),
                    const Text(
                      "ACCAP",
                      style: TextStyle(
                        letterSpacing: 3.0,
                        fontFamily: "Inter",
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Color.fromARGB(255, 28, 113, 166),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Accessibility-Centered Community\nApplication for PWD",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextField(
                          controller: emailTextController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            errorText: emailError,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextField(
                          controller: passwordTextController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Password",
                            errorText: passwordError,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextField(
                          controller: confirmPasswordTextController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            errorText: confirmPasswordError,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed: register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 5, 92, 157),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            minimumSize: const Size.fromHeight(50),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Register",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}