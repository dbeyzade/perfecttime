import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/biometric_service.dart';
import 'services/localization_service.dart';

class HomeSelectionScreen extends StatefulWidget {
  final VoidCallback onHostSelected;
  final VoidCallback onParticipantSelected;
  final bool forceShowBiometric;

  const HomeSelectionScreen({
    super.key,
    required this.onHostSelected,
    required this.onParticipantSelected,
    this.forceShowBiometric = false,
  });

  @override
  State<HomeSelectionScreen> createState() => _HomeSelectionScreenState();
}

class _HomeSelectionScreenState extends State<HomeSelectionScreen> {
  bool _showBiometricPrompt = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Biyometrik prompt artık sadece login ekranında gösterilecek
    _showBiometricPrompt = false;
  }

  Future<void> _checkBiometricSetup() async {
    // Biyometrik kurulum artık login ekranında yapılıyor
    // Home selection'da prompt gösterme
  }

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
              content: Text(l10n.biometricFailed),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final lastUser = await BiometricService.getLastAuthenticatedUser();
      if (lastUser != null) {
        await BiometricService.enableBiometric(lastUser);
        
        // Refresh token'ı kaydet (sonraki otomatik girişler için)
        final session = Supabase.instance.client.auth.currentSession;
        if (session?.refreshToken != null) {
          await BiometricService.saveBiometricRefreshToken(lastUser, session!.refreshToken!);
          print('BIOMETRIC: Refresh token saved for user $lastUser');
        } else {
          print('BIOMETRIC WARNING: No refresh token available to save!');
        }
        
        await BiometricService.setSkipBiometricPrompt(true);
        if (mounted) {
          setState(() {
            _showBiometricPrompt = false;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricEnabled),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // lastUser null ise de processing'i kapat
        if (mounted) {
          setState(() {
            _showBiometricPrompt = false;
            _isProcessing = false;
          });
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('HOME_SELECTION: build() - _showBiometricPrompt=$_showBiometricPrompt, _isProcessing=$_isProcessing');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.4),
          ),

          // Language Toggle Button - Top Right
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                await l10n.toggleLanguage();
                setState(() {}); // Refresh UI
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
                    Icon(
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

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                _buildOptionCard(
                  context,
                  title: l10n.startSession,
                  subtitle: l10n.startSessionDesc,
                  icon: Icons.video_call,
                  color: Colors.blueAccent,
                  onTap: widget.onHostSelected,
                ),
                const SizedBox(height: 20),
                _buildOptionCard(
                  context,
                  title: l10n.joinSession,
                  subtitle: l10n.joinSessionDesc,
                  icon: Icons.group_add,
                  color: Colors.greenAccent,
                  onTap: widget.onParticipantSelected,
                ),
              ],
            ),
          ),

          if (_showBiometricPrompt)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/biometric.jpeg'),
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.4),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            l10n.enableBiometric,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.biometricDesc,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                  height: 1.3,
                                  fontSize: 13,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _BiometricChip(label: l10n.touchIdFaceId),
                              _BiometricChip(label: l10n.quickLogin),
                              _BiometricChip(label: l10n.secureSession),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _enableBiometric,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purpleAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: _isProcessing
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                        )
                                      : Text(
                                          l10n.enableNow,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () {
                                        setState(() {
                                          _showBiometricPrompt = false;
                                        });
                                      },
                                child: Text(l10n.later, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () async {
                                        await BiometricService.setSkipBiometricPrompt(true);
                                        if (mounted) {
                                          setState(() {
                                            _showBiometricPrompt = false;
                                          });
                                        }
                                      },
                                child: Text(
                                  l10n.dontShowAgain,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        print('HOME_SELECTION: Button tapped - $title');
        // Her zaman tıklamayı işle - overlay durumundan bağımsız
        onTap();
      },
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

class _BiometricChip extends StatelessWidget {
  final String label;

  const _BiometricChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_moon_outlined, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
