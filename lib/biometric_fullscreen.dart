import 'package:flutter/material.dart';
import 'services/biometric_service.dart';
import 'services/localization_service.dart';

class BiometricFullScreen extends StatefulWidget {
  const BiometricFullScreen({super.key});

  @override
  State<BiometricFullScreen> createState() => _BiometricFullScreenState();
}

class _BiometricFullScreenState extends State<BiometricFullScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  String _message = '';
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _message = l10n.scanFingerOrFace;
    
    // Yanıp sönen efekt için animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _startBiometricAuth();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startBiometricAuth() async {
    setState(() {
      _isAuthenticating = true;
      _message = l10n.scanning;
    });

    try {
      final isAuthenticated = await BiometricService.authenticate();

      if (isAuthenticated) {
        if (mounted) {
          setState(() {
            _message = l10n.successAuth;
          });
          // Return to previous screen with success
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _message = l10n.failedTryAgain;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _message = '${l10n.error}: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/biometric.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Biometric Icon - Yanıp Sönen Efekt
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purpleAccent.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.purpleAccent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(_glowAnimation.value),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(_glowAnimation.value * 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.fingerprint,
                          size: 70,
                          color: Colors.purpleAccent.withOpacity(0.8 + (_glowAnimation.value * 0.2)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // Message
                Text(
                  _message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                // Retry Button
                if (!_isAuthenticating)
                  ElevatedButton.icon(
                    onPressed: _startBiometricAuth,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.tryAgainButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await BiometricService.setSkipBiometricPrompt(true);
                    if (mounted) Navigator.of(context).pop(false);
                  },
                  child: Text(
                    l10n.dontShowAgain,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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
}
