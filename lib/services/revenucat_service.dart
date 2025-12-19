import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class RevenuesCatService {
  static const String _iosApiKey = 'appl_nBSYDuXGywbqjOnMlhdxhgUYfKn';
  static const String _macOSApiKey = 'appl_nBSYDuXGywbqjOnMlhdxhgUYfKn'; // macOS için aynı Apple key kullanılır
  static const String _androidApiKey = 'goog_YOUR_ANDROID_KEY'; // Android için sonra eklenecek

  static Future<void> initialize() async {
    String apiKey;
    if (Platform.isIOS) {
      apiKey = _iosApiKey;
    } else if (Platform.isMacOS) {
      apiKey = _macOSApiKey;
    } else if (Platform.isAndroid) {
      apiKey = _androidApiKey;
    } else {
      // Diğer platformlar için iOS key kullan
      apiKey = _iosApiKey;
    }
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Get available packages for subscription
  static Future<List<Package>> getPackages() async {
    try {
      print('🔄 Fetching offerings from RevenueCat...');
      final offerings = await Purchases.getOfferings();
      print('📦 Offerings received: ${offerings.all.keys.toList()}');
      
      if (offerings.current != null) {
        final packages = offerings.current!.availablePackages;
        print('✅ Current offering has ${packages.length} packages');
        for (final pkg in packages) {
          print('   - ${pkg.identifier}: ${pkg.storeProduct.priceString} (${pkg.packageType})');
        }
        return packages;
      }
      
      print('⚠️ No current offering found');
      return [];
    } catch (e, stackTrace) {
      print('❌ Error getting packages: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Throw the error to show user-friendly message
    }
  }

  /// Make purchase
  static Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      print('💳 Starting purchase for: ${package.identifier}');
      print('   Price: ${package.storeProduct.priceString}');
      print('   Product ID: ${package.storeProduct.identifier}');
      
      final purchaseResult = await Purchases.purchasePackage(package);
      
      print('✅ Purchase completed!');
      print('   Active entitlements: ${purchaseResult.entitlements.active.keys.toList()}');
      
      return purchaseResult;
    } catch (e) {
      print('❌ Error purchasing package: $e');
      if (e is PlatformException) {
        print('   Code: ${e.code}');
        print('   Message: ${e.message}');
        print('   Details: ${e.details}');
      }
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
  static Future<bool> validateReceipt(String productId) async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo != null) {
        final activeEntitlements = customerInfo.entitlements.active;
        return activeEntitlements.containsKey(productId);
      }
      return false;
    } catch (e) {
      print('Error validating receipt: $e');
      return false;
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
