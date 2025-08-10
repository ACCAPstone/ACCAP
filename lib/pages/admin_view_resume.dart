import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewResumePage extends StatelessWidget {
  final String resumeUrl; // The URL to the resume in Firebase Storage

  const ViewResumePage({super.key, required this.resumeUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Resume'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Open the resume using the URL (if it's a PDF file)
            if (await canLaunch(resumeUrl)) {
              await launch(resumeUrl);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open the resume.')),
              );
            }
          },
          child: const Text('Open Resume'),
        ),
      ),
    );
  }
}