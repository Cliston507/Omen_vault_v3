import 'package:flutter/material.dart';

class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsupported Platform'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'This application uses native encryption and local storage features that are not available in the web preview. Please run on a native Android or iOS device for full functionality.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
