import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/subscription_service.dart';
import 'paywall_screen.dart';

class SubscriptionHelper {
  static final SubscriptionService _subscriptionService =
      SubscriptionService(Supabase.instance.client);

  /// Check if user should see paywall
  static Future<bool> shouldShowPaywall(String userId) async {
    final subscription = await _subscriptionService.getUserSubscription(userId);
    
    if (subscription == null) {
      return true; // New user, show paywall
    }

    final planType = subscription['plan_type'];
    
    // Paid users don't see paywall
    if (planType != 'free') {
      return false;
    }

    // Free users check if they've hit the limit
    final canUse = await _subscriptionService.canUseApp(userId);
    return !canUse;
  }

  /// Show paywall dialog if needed
  static Future<bool> checkAndShowPaywall(
    BuildContext context,
    String userId,
  ) async {
    if (await shouldShowPaywall(userId)) {
      if (!context.mounted) return false;
      
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            child: PaywallScreen(
              onSubscriptionComplete: () {
                Navigator.pop(context, true);
              },
            ),
          );
        },
      );
      
      return result ?? false;
    }
    
    return true;
  }

  /// Log usage and check if limit is reached
  static Future<bool> logUsageAndCheck(
    BuildContext context,
    String userId,
  ) async {
    // Increment usage
    await _subscriptionService.incrementUsageCount(userId);
    
    // Check if should show paywall
    return await checkAndShowPaywall(context, userId);
  }

  /// Get subscription info for UI display
  static Future<Map<String, dynamic>?> getSubscriptionInfo(String userId) async {
    final subscription = await _subscriptionService.getUserSubscription(userId);
    if (subscription == null) return null;

    final planType = subscription['plan_type'];
    final remaining = await _subscriptionService.getRemainingFreeUses(userId);

    return {
      'plan': planType,
      'remaining': remaining,
      'total': SubscriptionService.FREE_USES,
      'subscription': subscription,
    };
  }

  /// Format plan type to Turkish
  static String getPlanDisplay(String planType) {
    switch (planType) {
      case 'free':
        return 'Ücretsiz Plan';
      case 'monthly':
        return 'Aylık Üyelik';
      case 'yearly':
        return 'Yıllık Üyelik';
      case 'lifetime':
        return 'Ömür Boyu Üyelik';
      default:
        return planType;
    }
  }
}
