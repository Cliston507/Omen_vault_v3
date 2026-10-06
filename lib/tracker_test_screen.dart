import 'package:flutter/material.dart';
import 'package:omen_vault_v3/core/services/analytics_service.dart';
import 'main.dart';
import 'package:omen_vault_v3/profile_screen.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class TrackerTestScreen extends StatefulWidget {
  const TrackerTestScreen({super.key});

  @override
  State<TrackerTestScreen> createState() => _TrackerTestScreenState();
}

class _TrackerTestScreenState extends State<TrackerTestScreen> {
  Future<void> _logVideoRecordingTestEvent() async {
    developer.log('Logging video_recording_test event...', name: 'my_app.tracker');
    final analyticsService = Provider.of<IAnalyticsService>(context, listen: false);
    await analyticsService.logAction(
      name: 'video_recording_test',
      parameters: {
        'user_id': 'test_user_123',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('"video_recording_test" event logged successfully!'),
      ),
    );
    developer.log('Finished logging video_recording_test event.', name: 'my_app.tracker');
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building TrackerTestScreen...', name: 'my_app.tracker');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omen Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Center(
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.analytics, size: 64, color: Colors.deepPurple),
                const SizedBox(height: 24),
                Text(
                  'Firebase Analytics Tracker',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Press the button below to log a custom event to Firebase Analytics.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _logVideoRecordingTestEvent,
                  child: const Text('Log Video Recording Test'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
