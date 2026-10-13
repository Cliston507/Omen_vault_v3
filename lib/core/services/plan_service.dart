/// The user's subscription plan.
enum Plan { free, elite5 }

/// Answers "which plan is this user on?".
///
/// The app asks this service before showing an Elite5 feature. It is only a
/// display decision: limits that cost money (devices, storage) are also
/// enforced by the Firebase security rules, because a modified app could
/// always answer "elite5" here.
abstract class IPlanService {
  /// The current plan. Never throws: on any error, report [Plan.free].
  Future<Plan> currentPlan();

  /// Convenience check used by Elite5 features.
  Future<bool> isElite5() async => await currentPlan() == Plan.elite5;
}

/// Phase 0 implementation: every user is on the free plan.
///
/// Replaced in Phase 3 by a RevenueCat-backed service that reads the
/// `elite5` entitlement.
class FreePlanService extends IPlanService {
  @override
  Future<Plan> currentPlan() async => Plan.free;
}

/// Test double that reports a fixed plan.
class FixedPlanService extends IPlanService {
  final Plan plan;
  FixedPlanService(this.plan);

  @override
  Future<Plan> currentPlan() async => plan;
}
