import 'package:flutter/material.dart';
import 'package:omen_vault_v3/core/services/analytics_service.dart';
import 'package:omen_vault_v3/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class ServiceProvider extends StatelessWidget {
  final Widget child;

  const ServiceProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    developer.log('Building ServiceProvider...', name: 'my_app.service_provider');
    return MultiProvider(
      providers: [
        Provider<IAnalyticsService>(
          create: (_) => FirebaseAnalyticsService(),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
      ],
      child: child,
    );
  }
}
