import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'services/subscription_service.dart';
import 'services/revenucat_service.dart';
import 'services/localization_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onSubscriptionComplete;

  const PaywallScreen({Key? key, this.onSubscriptionComplete}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with TickerProviderStateMixin {
  late SubscriptionService _subscriptionService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _plans = [];
  int _selectedPlanIndex = 1;
  
  late AnimationController _shimmerController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  LocalizationService get l10n => LocalizationService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService(Supabase.instance.client);
    _loadPricingPlans();
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
    
    _scaleController.forward();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
    }
  }

  Future<void> _loadPricingPlans() async {
    try {
      final plans = await _subscriptionService.getPricingPlans();
      setState(() {
        _plans = plans;
      });
    } catch (e) {
      setState(() {
        _plans = [
          {'plan_type': 'monthly', 'price': 19.99, 'currency': 'USD', 'description': 'Monthly'},
          {'plan_type': 'yearly', 'price': 149.99, 'currency': 'USD', 'description': 'Yearly'},
          {'plan_type': 'lifetime', 'price': 199.99, 'currency': 'USD', 'description': 'Lifetime'},
        ];
      });
    }
  }

  Future<void> _handleSubscription(String planType) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Use RevenueCat for iOS/Android/macOS purchases
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
        // Get packages from RevenueCat
        debugPrint('📦 Fetching RevenueCat packages...');
        final packages = await RevenuesCatService.getPackages();
        debugPrint('📦 Received ${packages.length} packages');
        
        for (final pkg in packages) {
          debugPrint('  - ${pkg.identifier} (${pkg.packageType})');
        }
        
        if (packages.isEmpty) {
          debugPrint('❌ No packages available from RevenueCat');
          throw Exception(l10n.isTurkish 
              ? 'Abonelik paketleri yüklenemedi. Lütfen daha sonra tekrar deneyin.' 
              : 'Could not load subscription packages. Please try again later.');
        }
        
        // Find the matching package based on planType
        Package? selectedPackage;
        for (final package in packages) {
          final packageId = package.identifier.toLowerCase();
          if (planType == 'monthly' && (packageId.contains('monthly') || packageId.contains('\$rc_monthly'))) {
            selectedPackage = package;
            break;
          } else if (planType == 'yearly' && (packageId.contains('yearly') || packageId.contains('annual') || packageId.contains('\$rc_annual'))) {
            selectedPackage = package;
            break;
          } else if (planType == 'lifetime' && (packageId.contains('lifetime') || packageId.contains('\$rc_lifetime'))) {
            selectedPackage = package;
            break;
          }
        }
        
        // If no specific match found, try to use based on package type
        if (selectedPackage == null && packages.isNotEmpty) {
          if (planType == 'monthly') {
            selectedPackage = packages.firstWhere(
              (p) => p.packageType == PackageType.monthly,
              orElse: () => packages.first,
            );
          } else if (planType == 'yearly') {
            selectedPackage = packages.firstWhere(
              (p) => p.packageType == PackageType.annual,
              orElse: () => packages.length > 1 ? packages[1] : packages.first,
            );
          } else if (planType == 'lifetime') {
            selectedPackage = packages.firstWhere(
              (p) => p.packageType == PackageType.lifetime,
              orElse: () => packages.last,
            );
          }
        }
        
        if (selectedPackage == null) {
          debugPrint('❌ No package found for plan type: $planType');
          throw Exception(l10n.isTurkish 
              ? 'Seçilen abonelik paketi bulunamadı.' 
              : 'Selected subscription package not found.');
        }
        
        debugPrint('✅ Selected package: ${selectedPackage.identifier}');
        debugPrint('💳 Initiating purchase...');
        
        // Make the purchase via RevenueCat
        await RevenuesCatService.purchasePackage(selectedPackage);
        
        debugPrint('✅ Purchase completed successfully');
        
        // After successful purchase, update local database
        await _subscriptionService.upgradeSubscription(userId, planType);
      } else {
        // For web/desktop, just update the database (for testing)
        await _subscriptionService.upgradeSubscription(userId, planType);
      }
      
      if (mounted) {
        widget.onSubscriptionComplete?.call();
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Subscription error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = e.toString();
        
        // Handle common RevenueCat errors with user-friendly messages
        if (errorMessage.contains('PurchaseCancelledError') || errorMessage.contains('userCancelled')) {
          errorMessage = l10n.isTurkish ? 'İşlem iptal edildi' : 'Purchase cancelled';
        } else if (errorMessage.contains('PurchaseNotAllowedError')) {
          errorMessage = l10n.isTurkish 
              ? 'Satın alma izni yok. Lütfen ayarlarınızı kontrol edin.'
              : 'Purchases not allowed. Please check your settings.';
        } else if (errorMessage.contains('ProductNotAvailableForPurchaseError')) {
          errorMessage = l10n.isTurkish 
              ? 'Ürün şu anda satın alınamaz. Lütfen daha sonra tekrar deneyin.'
              : 'Product not available for purchase. Please try again later.';
        } else if (errorMessage.contains('NetworkError')) {
          errorMessage = l10n.isTurkish 
              ? 'Ağ hatası. Lütfen internet bağlantınızı kontrol edin.'
              : 'Network error. Please check your internet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.isTurkish ? 'Hata: $errorMessage' : 'Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
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
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
              ),
              // Language Toggle Button - Top Right
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () async {
                    await l10n.toggleLanguage();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.language,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.isTurkish ? 'TR' : 'EN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Header with close button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48), // Balance the close button
            ],
          ),
        ),
        
        // Title
        Text(
          l10n.isTurkish ? 'Premium\'a Yükseltin' : 'Upgrade to Premium',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 4),
        
        Text(
          l10n.isTurkish ? 'Sınırsız erişim için' : 'For unlimited access',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Plans Section
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Plan title with shimmer
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: const [Colors.amber, Colors.white, Colors.amber],
                          stops: [
                            _shimmerController.value - 0.3,
                            _shimmerController.value,
                            _shimmerController.value + 0.3,
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        l10n.isTurkish ? '✨ Plan Seçin' : '✨ Choose Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Plan cards in a row
                Expanded(
                  child: Row(
                    children: _plans.asMap().entries.map((entry) {
                      final index = entry.key;
                      final plan = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 4,
                            right: index == _plans.length - 1 ? 0 : 4,
                          ),
                          child: _buildCompactPlanCard(
                            index: index,
                            planType: plan['plan_type'],
                            price: plan['price'],
                            currency: plan['currency'],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subscribe button
                _buildSubscribeButton(),
                
                const SizedBox(height: 12),
                
                // Subscription Details - Required by Apple
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      // Auto-renewal info
                      Row(
                        children: [
                          const Icon(Icons.autorenew, size: 14, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.isTurkish
                                  ? 'Abonelikler iptal edilene kadar otomatik yenilenir'
                                  : 'Subscriptions auto-renew until cancelled',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Payment info
                      Row(
                        children: [
                          const Icon(Icons.payment, size: 14, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.isTurkish
                                  ? 'Ödeme satın alma onayında Apple ID hesabınızdan alınır'
                                  : 'Payment charged to Apple ID at confirmation of purchase',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Cancel info
                      Row(
                        children: [
                          const Icon(Icons.settings, size: 14, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.isTurkish
                                  ? 'App Store hesap ayarlarından yönetilebilir'
                                  : 'Manage in App Store account settings',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Legal Links - Required by Apple (More Prominent)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.policy, size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openUrl('https://dbeyzade.github.io/perfecttime/eula.html'),
                        child: Text(
                          l10n.termsOfUse,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.amber)),
                      GestureDetector(
                        onTap: () => _openUrl('https://dbeyzade.github.io/perfecttime/privacy.html'),
                        child: Text(
                          l10n.privacyPolicy,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left side - Benefits
        Expanded(
          flex: 4,
          child: _buildBenefitsSection(),
        ),
        // Right side - Plans
        Expanded(
          flex: 6,
          child: _buildPlansSection(),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            l10n.isTurkish ? 'Premium\'a\nYükseltin' : 'Upgrade to\nPremium',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 6),
          
          Text(
            l10n.isTurkish ? 'Sınırsız erişim için' : 'For unlimited access',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildBenefitItem(Icons.all_inclusive, 
                      l10n.isTurkish ? 'Sınırsız Toplantı' : 'Unlimited Meetings'),
                  _buildBenefitItem(Icons.hd, 
                      l10n.isTurkish ? 'HD Video Kalitesi' : 'HD Video Quality'),
                  _buildBenefitItem(Icons.videocam, 
                      l10n.isTurkish ? 'Toplantı Kaydı' : 'Meeting Recording'),
                  _buildBenefitItem(Icons.screen_share, 
                      l10n.isTurkish ? 'Ekran Paylaşımı' : 'Screen Sharing'),
                  _buildBenefitItem(Icons.support_agent, 
                      l10n.isTurkish ? 'Öncelikli Destek' : 'Priority Support'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: const [Colors.amber, Colors.white, Colors.amber],
                    stops: [
                      _shimmerController.value - 0.3,
                      _shimmerController.value,
                      _shimmerController.value + 0.3,
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  l10n.isTurkish ? '✨ Plan Seçin' : '✨ Choose Plan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: Row(
              children: _plans.asMap().entries.map((entry) {
                final index = entry.key;
                final plan = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == _plans.length - 1 ? 0 : 4,
                    ),
                    child: _buildCompactPlanCard(
                      index: index,
                      planType: plan['plan_type'],
                      price: plan['price'],
                      currency: plan['currency'],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          _buildSubscribeButton(),
          
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 10, color: Colors.white38),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.isTurkish 
                      ? 'Güvenli ödeme • İstediğiniz zaman iptal' 
                      : 'Secure payment • Cancel anytime',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Subscription Details - Required by Apple
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.autorenew, size: 10, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.isTurkish
                            ? 'Abonelikler iptal edilene kadar otomatik yenilenir'
                            : 'Auto-renews until cancelled',
                        style: const TextStyle(fontSize: 8, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.payment, size: 10, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.isTurkish
                            ? 'Ödeme satın alma onayında Apple ID\'den alınır'
                            : 'Payment charged to Apple ID',
                        style: const TextStyle(fontSize: 8, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Legal Links - Required by Apple (More Prominent)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.policy, size: 10, color: Colors.amber),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _openUrl('https://dbeyzade.github.io/perfecttime/eula.html'),
                  child: Text(
                    l10n.termsOfUse,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(' • ', style: TextStyle(color: Colors.amber, fontSize: 10)),
                GestureDetector(
                  onTap: () => _openUrl('https://dbeyzade.github.io/perfecttime/privacy.html'),
                  child: Text(
                    l10n.privacyPolicy,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlanCard({
    required int index,
    required String planType,
    required dynamic price,
    required String currency,
  }) {
    final isSelected = _selectedPlanIndex == index;
    
    IconData icon;
    String title;
    String period;
    String? badge;
    Color accentColor;
    
    switch (planType) {
      case 'monthly':
        icon = Icons.calendar_today;
        title = l10n.isTurkish ? 'Aylık' : 'Monthly';
        period = l10n.isTurkish ? '/ay' : '/mo';
        accentColor = Colors.blue;
        break;
      case 'yearly':
        icon = Icons.star;
        title = l10n.isTurkish ? 'Yıllık' : 'Yearly';
        period = l10n.isTurkish ? '/yıl' : '/yr';
        badge = l10n.isTurkish ? '%37' : '37%';
        accentColor = Colors.purple;
        break;
      case 'lifetime':
        icon = Icons.diamond;
        title = l10n.isTurkish ? 'Ömür Boyu' : 'Lifetime';
        period = l10n.isTurkish ? 'tek sefer' : 'once';
        badge = l10n.isTurkish ? 'En İyi' : 'Best';
        accentColor = Colors.amber;
        break;
      default:
        icon = Icons.card_membership;
        title = planType;
        period = '';
        accentColor = Colors.grey;
    }
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.3),
                    accentColor.withOpacity(0.1),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox(height: 18),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            
            const SizedBox(height: 8),
            
            // Title
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 4),
            
            // Price
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    price.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Period
            Text(
              period,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 6),
            
            // Selection indicator
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.white38,
                  width: 2,
                ),
                color: isSelected ? accentColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    if (_plans.isEmpty) return const SizedBox.shrink();
    
    final selectedPlan = _plans[_selectedPlanIndex];
    final planType = selectedPlan['plan_type'];
    
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleSubscription(planType),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366f1).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        l10n.isTurkish ? 'Premium\'a Başla' : 'Start Premium',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
