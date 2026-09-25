import 'package:firebase_analytics/firebase_analytics.dart';

abstract class IAnalyticsService {
  Future<void> logScreen({required String screenName});
  Future<void> logAction({required String name, Map<String, Object>? parameters});
  Future<void> setUserId(String? userId);
}

class FirebaseAnalyticsService implements IAnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  @override
  Future<void> logScreen({required String screenName}) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  @override
  Future<void> logAction({required String name, Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }
}