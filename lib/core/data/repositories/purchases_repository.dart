import '../models/purchase_models.dart';

abstract class PurchasesRepository {
  Future<List<UserEntitlementItem>> fetchUserEntitlements({required String userId});
  Stream<List<UserEntitlementItem>> watchUserEntitlements({
    required String userId,
    Duration pollInterval = const Duration(seconds: 12),
  });
  Future<void> createPurchase({
    required String userId,
    String? courseId,
    String? sectionId,
    double amountUzs = 0,
  });
}
