
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omen_vault_v3/core/services/analytics_service.dart';

class ServiceProvider extends StatelessWidget {
  final Widget child;

  const ServiceProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<IAnalyticsService>(
          create: (_) => FirebaseAnalyticsService(),
        ),
      ],
      child: child,
    );
  }
}
