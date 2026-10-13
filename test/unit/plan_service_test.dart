import 'package:flutter_test/flutter_test.dart';
import 'package:omen_vault_v3/core/feature_flags.dart';
import 'package:omen_vault_v3/core/services/plan_service.dart';

void main() {
  test('Phase 0: every user is on the free plan', () async {
    final plans = FreePlanService();
    expect(await plans.currentPlan(), Plan.free);
    expect(await plans.isElite5(), isFalse);
  });

  test('isElite5 reflects the reported plan', () async {
    expect(await FixedPlanService(Plan.elite5).isElite5(), isTrue);
    expect(await FixedPlanService(Plan.free).isElite5(), isFalse);
  });

  test('all Elite5 feature flags are off by default', () {
    expect(FeatureFlags.eliteEncryption, isFalse);
    expect(FeatureFlags.eliteLock, isFalse);
    expect(FeatureFlags.eliteSync, isFalse);
    expect(FeatureFlags.eliteInsights, isFalse);
    expect(FeatureFlags.eliteGuard, isFalse);
    expect(FeatureFlags.paywall, isFalse);
  });
}
