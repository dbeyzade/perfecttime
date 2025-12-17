import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/biometric_service.dart';
import 'services/localization_service.dart';
import 'home_selection_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isProcessing = false;

  Future<void> _enableBiometric() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Önce Face ID/Touch ID doğrulaması yap
      final isAuthenticated = await BiometricService.authenticate();
      
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricVerifyFailed),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      // Doğrulama başarılıysa biyometriği etkinleştir
      final lastUser = await BiometricService.getLastAuthenticatedUser();
      if (lastUser != null) {
        await BiometricService.enableBiometric(lastUser);
        
        // Refresh token'ı kaydet (sonraki otomatik girişler için)
        final session = Supabase.instance.client.auth.currentSession;
        if (session?.refreshToken != null) {
          await BiometricService.saveBiometricRefreshToken(lastUser, session!.refreshToken!);
        }
        
        // ÖNEMLİ: SkipPrompt'u aktif et - bir sonraki açılışta otomatik giriş yapsın
        await BiometricService.setSkipBiometricPrompt(true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricEnabled),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeSelectionScreen(
                  onHostSelected: () {},
                  onParticipantSelected: () {},
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image - AI Circuit Face
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Gemini_Generated_Image_pbh6efpbh6efpbh6.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          // Content - Full scrollable
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purpleAccent.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.purpleAccent,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              size: 60,
                              color: Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Title - Fancy style
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [Colors.purpleAccent, Colors.pinkAccent, Colors.purpleAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              l10n.biometricAuth,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                    color: Colors.purpleAccent.withOpacity(0.5),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Description
                          Text(
                            l10n.biometricDescription,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          // Benefits
                          _BenefitItem(
                            icon: Icons.speed,
                            title: l10n.quickLoginBenefit,
                            description: l10n.quickLoginDesc,
                          ),
                          const SizedBox(height: 16),
                          _BenefitItem(
                            icon: Icons.security,
                            title: l10n.secureBenefit,
                            description: l10n.secureDesc,
                          ),
                          const SizedBox(height: 16),
                          _BenefitItem(
                            icon: Icons.touch_app,
                            title: l10n.easyUseBenefit,
                            description: l10n.easyUseDesc,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                ],
              ),
            ),
          ),
          // Buttons - Fixed bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Enable Button - Kısaltılmış
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _enableBiometric,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: _isProcessing
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.fingerprint, size: 18),
                          label: Text(
                            _isProcessing ? l10n.settingUp : l10n.enable,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Skip Button - Kısaltılmış
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isProcessing ? null : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => HomeSelectionScreen(
                                  onHostSelected: () {},
                                  onParticipantSelected: () {},
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white70),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            l10n.doLater,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purpleAccent.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: Colors.purpleAccent,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
