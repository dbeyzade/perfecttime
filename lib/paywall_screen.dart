import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onSubscriptionComplete;

  const PaywallScreen({Key? key, this.onSubscriptionComplete}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late SubscriptionService _subscriptionService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService(Supabase.instance.client);
    _loadPricingPlans();
  }

  Future<void> _loadPricingPlans() async {
    try {
      final plans = await _subscriptionService.getPricingPlans();
      setState(() {
        _plans = plans;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fiyatlandırma planları yüklenirken hata: $e')),
      );
    }
  }

  Future<void> _handleSubscription(String planType) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // TODO: In-app purchase integrasyonu here
      // For now, we'll directly upgrade without payment processing
      // In production, integrate with RevenueCat or Stripe
      
      await _subscriptionService.upgradeSubscription(userId, planType);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$planType aboneliğine başarıyla yükseltildi!')),
        );
        widget.onSubscriptionComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Üyelik'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '10 Kullanım Sınırınız Doldu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sınırsız kullanım için Premium\'a yükseltin',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              ..._plans.map((plan) {
                return _buildPlanCard(
                  planType: plan['plan_type'],
                  price: plan['price'],
                  currency: plan['currency'],
                  description: plan['description'],
                );
              }).toList(),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  'Güvenli ödeme ile desteklenmektedir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String planType,
    required dynamic price,
    required String currency,
    required String description,
  }) {
    final isHighlighted = planType == 'yearly';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isHighlighted ? 8 : 2,
      color: isHighlighted ? Colors.blue.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlanTitle(planType),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (isHighlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'En Popüler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$currency ${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _handleSubscription(planType),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: isHighlighted ? Colors.blue : Colors.grey[400],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Seç',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHighlighted ? Colors.white : Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlanTitle(String planType) {
    switch (planType) {
      case 'monthly':
        return 'Aylık';
      case 'yearly':
        return 'Yıllık';
      case 'lifetime':
        return 'Ömür Boyu';
      default:
        return planType;
    }
  }
}
