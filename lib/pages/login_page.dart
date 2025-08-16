import 'package:flutter/material.dart';
import 'package:firebase/pages/admin_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class LoginPage extends StatefulWidget {
  final Function()? onTap;
  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameTextController = TextEditingController();
  final passwordTextController = TextEditingController();
  String? emailError;
  String? passwordError;
  bool _isPasswordVisible = false;

    Future<void> signIn() async {
    if (!mounted) return;
    
    setState(() {
      emailError = null;
      passwordError = null;
    });

    try {
      final input = usernameTextController.text.trim();
      String emailToUse = '';
      
      if (input.contains('@')) {
        // Input is an email
        emailToUse = input;
      } else {
        // Input is a username, look up email
        final query = await FirebaseFirestore.instance
            .collection('admins')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();
            
        if (query.docs.isEmpty) {
          if (mounted) {
            setState(() {
              emailError = "No account found for that username.";
            });
          }
          return;
        }
        final adminData = query.docs.first.data();
        emailToUse = adminData['email'];
      }

      // Check if user exists in admins collection first
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(emailToUse)
          .get();

      if (!adminDoc.exists) {
        if (mounted) {
          setState(() {
            emailError = "Account not found in admin system. Please contact administrator.";
          });
        }
        return;
      }

      final adminData = adminDoc.data() as Map<String, dynamic>?;
      if (adminData == null) {
        if (mounted) {
          setState(() {
            emailError = "Invalid account data.";
          });
        }
        return;
      }

      // Enforce email verification only for non-legacy accounts
      bool isLegacyAccount = adminData['isLegacyAccount'] == true;
      await _completeLogin(
        emailToUse,
        passwordTextController.text.trim(),
        enforceEmailVerified: !isLegacyAccount,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          emailError = "Error: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _completeLogin(String email, String password, {bool enforceEmailVerified = true}) async {
    try {
      // Sign in with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Optionally enforce email verification for new accounts
        if (enforceEmailVerified) {
          await user.reload();
          user = FirebaseAuth.instance.currentUser;
          if (!(user?.emailVerified ?? false)) {
            try {
              await user?.sendEmailVerification();
            } catch (_) {}
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() {
                emailError = "Email not verified. A verification link has been sent to your email.";
              });
            }
            return;
          }
        }

        // Check if user exists in admins collection
        final String emailDocId = (FirebaseAuth.instance.currentUser?.email) ?? email;
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(emailDocId)
            .get();

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>?;
          
          // Check if user is admin or barangay
          if (adminData != null && (adminData['role'] == 'admin' || adminData['role'] == 'barangay')) {
            // Update last login and mark as verified
            await FirebaseFirestore.instance
                .collection('admins')
                .doc(emailDocId)
                .update({
              'lastLogin': FieldValue.serverTimestamp(),
              'isOnline': true,
              'emailVerified': true,
              'verificationDate': FieldValue.serverTimestamp(),
            });

            // Navigate to admin page
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminHomePage()),
              );
            }
          } else {
            // Not authorized
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() {
                emailError = "You are not authorized to access this system.";
              });
            }
          }
        } else {
          // Account not found in admin system
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() {
              emailError = "Account not found in admin system. Please contact administrator.";
            });
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      if (e.code == 'user-not-found') {
        setState(() {
          emailError = "No user found for that username or email.";
        });
      } else if (e.code == 'wrong-password') {
        setState(() {
          passwordError = "Wrong password.";
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
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left Branding Side
                  if (screenWidth > 600)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/ACCAP_LOGO.png', width: 200, height: 200),
                          const SizedBox(height: 20),
                          Text(
                            "ACCAP",
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 28, 113, 166),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Accessibility-Centered Community\nApplication for PWD",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Right Login Form Side
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: usernameTextController,
                            decoration: InputDecoration(
                              labelText: "Username or Email",
                              errorText: emailError,
                              border: const OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordTextController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: "Password",
                              errorText: passwordError,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => signIn(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                final emailController = TextEditingController();
                                String? errorMessage;

                                await showDialog<String>(
                                  context: context,
                                  builder: (context) => LayoutBuilder(
                                    builder: (context, constraints) {
                                      double dialogWidth = constraints.maxWidth < 400 ? constraints.maxWidth * 0.95 : 350;
                                      double horizontalPadding = constraints.maxWidth < 400 ? 10 : 20;
                                      double verticalPadding = constraints.maxWidth < 400 ? 10 : 20;
                                      double titleFontSize = constraints.maxWidth < 400 ? 18 : 20;
                                      double textFontSize = constraints.maxWidth < 400 ? 13 : 14;
                                      return StatefulBuilder(
                                        builder: (context, setState) => Dialog(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: dialogWidth),
                                            child: SingleChildScrollView(
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Text(
                                                      'Forgot Password',
                                                      style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Enter the admin email to receive a password reset link.',
                                                      style: TextStyle(fontSize: textFontSize, color: Colors.black54),
                                                    ),
                                                    SizedBox(height: 18),
                                                    TextField(
                                                      controller: emailController,
                                                      decoration: InputDecoration(
                                                        labelText: 'Admin Email',
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                      ),
                                                      textInputAction: TextInputAction.done,
                                                      onSubmitted: (_) async {
                                                        final email = emailController.text.trim();
                                                        if (email.isEmpty) {
                                                          setState(() {
                                                            errorMessage = "Please enter an email address";
                                                          });
                                                          return;
                                                        }

                                                        try {
                                                          final adminDoc = await FirebaseFirestore.instance
                                                              .collection('admins')
                                                              .doc(email)
                                                              .get();

                                                          if (!adminDoc.exists) {
                                                            setState(() {
                                                              errorMessage = "Admin not found with this email";
                                                            });
                                                            return;
                                                          }
                                                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                                          Navigator.pop(context, 'success');
                                                        } on FirebaseAuthException catch (e) {
                                                          setState(() {
                                                            errorMessage = "Error: ${e.message ?? ""}";
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    if (errorMessage != null)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8),
                                                        child: Text(
                                                          errorMessage!,
                                                          style: const TextStyle(color: Colors.red),
                                                        ),
                                                      ),
                                                    SizedBox(height: 20),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Cancel',style: TextStyle(color: Colors.black),),
                                                        ),
                                                        SizedBox(width: 8),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color.fromARGB(255, 5, 92, 157),
                                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                          onPressed: () async {
                                                            final email = emailController.text.trim();
                                                            if (email.isEmpty) {
                                                              setState(() {
                                                                errorMessage = "Please enter an email address";
                                                              });
                                                              return;
                                                            }

                                                            try {
                                                              // Check if the email exists in admins collection
                                                              final adminDoc = await FirebaseFirestore.instance
                                                                  .collection('admins')
                                                                  .doc(email)
                                                                  .get();

                                                              if (!adminDoc.exists) {
                                                                setState(() {
                                                                  errorMessage = "Admin not found with this email";
                                                                });
                                                                return;
                                                              }

                                                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                                                              Navigator.pop(context, 'success');
                                                            } on FirebaseAuthException catch (e) {
                                                              setState(() {
                                                                errorMessage = "Error: ${e.message ?? ""}";
                                                              });
                                                            }
                                                          },
                                                          child: const Text(
                                                            'Reset Password',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: Color.fromARGB(255, 250, 250, 250),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ).then((result) {
                                  if (result == 'success') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Color.fromARGB(255, 250, 250, 250),
                                        title: const Text('Success'),
                                        content: const Text('Password reset link sent successfully!'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('OK', style: TextStyle(color: Colors.black)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                });
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 0, 48, 96),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 5, 92, 157),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }
}