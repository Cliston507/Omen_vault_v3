/// Compile-time switches for features that are still being built.
///
/// Each Elite5 feature ships behind its own flag so an unfinished feature
/// can be held back without blocking a release. Flags default to off and
/// can be turned on for a build with, for example:
///   flutter run --dart-define=FF_ELITE_LOCK=true
///
/// Remote control (Firebase Remote Config) can be layered on later; until
/// then, flags are fixed per build so behaviour is predictable.
class FeatureFlags {
  const FeatureFlags._();

  /// Feature 1: encrypted attachments, encrypted export, key rotation.
  static const bool eliteEncryption =
      bool.fromEnvironment('FF_ELITE_ENCRYPTION', defaultValue: false);

  /// Feature 2: per-note lock, custom auto-lock, screenshot block, wipe.
  static const bool eliteLock =
      bool.fromEnvironment('FF_ELITE_LOCK', defaultValue: false);

  /// Feature 3: unlimited devices, device manager, version history.
  static const bool eliteSync =
      bool.fromEnvironment('FF_ELITE_SYNC', defaultValue: false);

  /// Feature 4: on-device summaries, smart search, auto-tags.
  static const bool eliteInsights =
      bool.fromEnvironment('FF_ELITE_INSIGHTS', defaultValue: false);

  /// Feature 5: health score, device and sign-in alerts, leak check.
  static const bool eliteGuard =
      bool.fromEnvironment('FF_ELITE_GUARD', defaultValue: false);

  /// The paywall and plan purchase screens.
  static const bool paywall =
      bool.fromEnvironment('FF_PAYWALL', defaultValue: false);
}
