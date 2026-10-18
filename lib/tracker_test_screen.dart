import 'package:flutter/material.dart';
import 'package:omen_vault_v3/theme_provider.dart';
import 'package:provider/provider.dart';

class TrackerTestScreen extends StatefulWidget {
  const TrackerTestScreen({super.key});

  @override
  State<TrackerTestScreen> createState() => _TrackerTestScreenState();
}

class _TrackerTestScreenState extends State<TrackerTestScreen> {
  String _lastAction = 'none';

  void _logAction(String action) {
    setState(() {
      _lastAction = action;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Tracker Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Last action logged:',
            ),
            Text(
              _lastAction,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _logAction('button_press'),
              child: const Text('Log Button Press'),
            ),
            SwitchListTile(
              title: const Text('Toggle Dark Mode'),
              value: Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark,
              onChanged: (value) {
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                _logAction(value ? 'dark_mode_on' : 'dark_mode_off');
              },
            ),
          ],
        ),
      ),
    );
  }
}
