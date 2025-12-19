import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  final SupabaseClient supabase;
  
  // Üye olmadan 10 kez kullanım hakkı
  static const int FREE_GUEST_USES = 10;
  // Üye olduktan sonra free plan için kullanım hakkı
  static const int FREE_MEMBER_USES = 10;
  
  // SharedPreferences key for guest usage
  static const String _guestUsageKey = 'guest_usage_count';

  SubscriptionService(this.supabase);

  /// Get guest usage count (for non-logged in users)
  static Future<int> getGuestUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestUsageKey) ?? 0;
  }

  /// Increment guest usage count
  static Future<void> incrementGuestUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_guestUsageKey) ?? 0;
    await prefs.setInt(_guestUsageKey, current + 1);
  }

  /// Check if guest can use app (not logged in)
  static Future<bool> canGuestUseApp() async {
    final usageCount = await getGuestUsageCount();
    return usageCount < FREE_GUEST_USES;
  }

  /// Get remaining guest uses
  static Future<int> getRemainingGuestUses() async {
    final usageCount = await getGuestUsageCount();
    return FREE_GUEST_USES - usageCount;
  }

  /// Reset guest usage (call after successful login/registration)
  static Future<void> resetGuestUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_guestUsageKey, 0);
  }

  /// Create free subscription for new user
  Future<void> createFreeSubscription(String userId) async {
    try {
      // Check if subscription already exists
      final existing = await getUserSubscription(userId);
      if (existing != null) return;
      
      final now = DateTime.now();
      await supabase.from('subscriptions').insert({
        'user_id': userId,
        'plan_type': 'free',
        'status': 'active',
        'starts_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      
      // Also create usage tracking record
      await supabase.from('usage_tracking').insert({
        'user_id': userId,
        'usage_count': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      
      print('Created free subscription for user $userId');
    } catch (e) {
      print('Error creating free subscription: $e');
    }
  }

  /// Get user subscription
  Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    try {
      final response = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting subscription: $e');
      return null;
    }
  }

  /// Get user usage
  Future<int?> getUserUsageCount(String userId) async {
    try {
      final response = await supabase
          .from('usage_tracking')
          .select('usage_count')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['usage_count'] ?? 0;
    } catch (e) {
      print('Error getting usage count: $e');
      return null;
    }
  }

  /// Increment usage count
  Future<void> incrementUsageCount(String userId) async {
    try {
      final currentUsage = await getUserUsageCount(userId);
      await supabase
          .from('usage_tracking')
          .update({'usage_count': (currentUsage ?? 0) + 1})
          .eq('user_id', userId);
    } catch (e) {
      print('Error incrementing usage: $e');
    }
  }

  /// Check if user can use app
  Future<bool> canUseApp(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      
      if (subscription == null) {
        return false;
      }

      final planType = subscription['plan_type'];
      
      // Paid users can always use
      if (planType != 'free') {
        return true;
      }

      // Free users check usage count
      final usageCount = await getUserUsageCount(userId);
      return (usageCount ?? 0) < FREE_MEMBER_USES;
    } catch (e) {
      print('Error checking app usage: $e');
      return false;
    }
  }

  /// Get pricing plans
  Future<List<Map<String, dynamic>>> getPricingPlans() async {
    try {
      final response = await supabase
          .from('pricing_plans')
          .select()
          .order('price', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting pricing plans: $e');
      return [];
    }
  }

  /// Upgrade subscription
  Future<void> upgradeSubscription(String userId, String planType) async {
    try {
      final now = DateTime.now();
      DateTime? endsAt;

      if (planType == 'monthly') {
        endsAt = now.add(Duration(days: 30));
      } else if (planType == 'yearly') {
        endsAt = now.add(Duration(days: 365));
      }
      // lifetime has no end date

      await supabase
          .from('subscriptions')
          .update({
            'plan_type': planType,
            'status': 'active',
            'starts_at': now.toIso8601String(),
            if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      print('Error upgrading subscription: $e');
      rethrow;
    }
  }

  /// Get remaining free uses
  Future<int> getRemainingFreeUses(String userId) async {
    try {
      final usageCount = await getUserUsageCount(userId);
      return FREE_MEMBER_USES - (usageCount ?? 0);
    } catch (e) {
      print('Error getting remaining uses: $e');
      return 0;
    }
  }

  /// Check subscription expiry and auto-renew for yearly
  Future<void> checkSubscriptionExpiry(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      
      if (subscription == null || subscription['plan_type'] == 'free' || subscription['plan_type'] == 'lifetime') {
        return;
      }

      final endsAt = DateTime.parse(subscription['ends_at']);
      final now = DateTime.now();

      if (now.isAfter(endsAt)) {
        // Subscription expired, revert to free
        await supabase
            .from('subscriptions')
            .update({
              'plan_type': 'free',
              'status': 'expired',
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', userId);
      }
    } catch (e) {
      print('Error checking subscription expiry: $e');
    }
  }
}
