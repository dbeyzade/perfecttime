import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class RevenuesCatService {
  static const String _iosApiKey = 'test_wMILQkAmKmiGITYNhKfMHYDLvIe';
  static const String _androidApiKey = 'test_wMILQkAmKmiGITYNhKfMHYDLvIe';

  static Future<void> initialize() async {
    String apiKey;
    if (Platform.isIOS) {
      apiKey = _iosApiKey;
    } else if (Platform.isAndroid) {
      apiKey = _androidApiKey;
    } else {
      // macOS, web vs. için şimdilik iOS key kullan
      apiKey = _iosApiKey;
    }
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Get available packages for subscription
  static Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      print('Error getting packages: $e');
      return [];
    }
  }

  /// Make purchase
  static Future<void> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } catch (e) {
      print('Error purchasing package: $e');
      rethrow;
    }
  }

  /// Check user subscription status
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      print('Error getting customer info: $e');
      return null;
    }
  }

  /// Verify receipt
  static Future<String?> validateReceipt(String productId) async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo != null) {
        final activeEntitlements = customerInfo.entitlements.active;
        return activeEntitlements.containsKey(productId)
            ? activeEntitlements[productId]?.verificationResult
            : null;
      }
      return null;
    } catch (e) {
      print('Error validating receipt: $e');
      return null;
    }
  }

  /// Restore purchases
  static Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
      return null;
    }
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo?.entitlements.active.isNotEmpty ?? false;
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  /// Get subscription type
  static Future<String?> getSubscriptionType() async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo != null && customerInfo.entitlements.active.isNotEmpty) {
        // Return the first active entitlement
        return customerInfo.entitlements.active.keys.first;
      }
      return null;
    } catch (e) {
      print('Error getting subscription type: $e');
      return null;
    }
  }
}
