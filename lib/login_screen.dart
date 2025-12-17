import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/biometric_service.dart';
import 'services/localization_service.dart';
import 'biometric_fullscreen.dart';
import 'main.dart'; // AuthGate için

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _rememberMe = true;
  bool _showBiometricButton = false;
  bool _canUseBiometric = false;
  bool _showEmailSuggestion = false;
  bool _biometricAutoTried = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _checkBiometricAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoBiometricLogin();
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Email suggestion listener
    _emailController.addListener(() {
      final text = _emailController.text;
      if (text.contains('@') && !text.contains('@hotmail.com')) {
        final atIndex = text.lastIndexOf('@');
        final afterAt = text.substring(atIndex + 1);
        if (afterAt.isEmpty || 'hotmail.com'.startsWith(afterAt)) {
          setState(() {
            _showEmailSuggestion = true;
          });
        } else {
          setState(() {
            _showEmailSuggestion = false;
          });
        }
      } else {
        setState(() {
          _showEmailSuggestion = false;
        });
      }
    });
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final canAuthenticate = await BiometricService.canAuthenticateWithBiometrics();
    final lastUser = await BiometricService.getLastAuthenticatedUser();
    final isEnabled = lastUser != null ? await BiometricService.isBiometricEnabled(lastUser) : false;
    
    print('=== BIOMETRIC AVAILABILITY CHECK ===');
    print('canAuthenticate: $canAuthenticate');
    print('lastUser: $lastUser');
    print('isEnabled: $isEnabled');
    print('====================================');
    
    if (mounted) {
      setState(() {
        _canUseBiometric = canAuthenticate && lastUser != null && isEnabled;
        _showBiometricButton = _canUseBiometric;
      });
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final lastUser = await BiometricService.getLastAuthenticatedUser();
      if (lastUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biyometrik giriş için önce normal giriş yapın'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show full screen biometric authentication
      if (mounted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const BiometricFullScreen(),
            fullscreenDialog: true,
          ),
        );

        if (result == true) {
          // Biometric successful, restore session
          try {
            final refreshToken = await BiometricService.getBiometricRefreshToken(lastUser);
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final response = await Supabase.instance.client.auth.setSession(refreshToken);
                if (response.session != null && mounted) {
                  // ÖNEMLİ: Bir sonraki açılışta otomatik giriş yapsın
                  await BiometricService.setSkipBiometricPrompt(true);
                  // Session ayarlandı - HomeSelectionScreen'e git
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
                    (route) => false,
                  );
                }
              } catch (sessionError) {
                debugPrint('Session restore failed: $sessionError');
                // Token geçersiz, şifre ile giriş yapılacak - sessizce devam et
                if (mounted) {
                  final email = await BiometricService.getBiometricEmail(lastUser);
                  setState(() {
                    if (email != null) {
                      _emailController.text = email;
                    }
                  });
                  // Uyarı göstermeden temiz açılış
                }
              }
            } else {
              // Refresh token yok, şifre ile giriş yapılacak
              if (mounted) {
                final email = await BiometricService.getBiometricEmail(lastUser);
                setState(() {
                  if (email != null) {
                    _emailController.text = email;
                  }
                });
              }
            }
          } catch (e) {
            debugPrint('Biometric session error: $e');
            if (mounted) {
              // Sessiyon açılamadı; şifreyle giriş yapılacak.
              final email = await BiometricService.getBiometricEmail(lastUser);
              setState(() {
                if (email != null) {
                  _emailController.text = email;
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biyometrik hata: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showBiometricEnableDialog(String userId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.purpleAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.enableBiometric,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.biometricDesc,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.later, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.enableNow, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      // Biyometrik doğrulama yap
      final isAuthenticated = await BiometricService.authenticate();
      if (isAuthenticated) {
        await BiometricService.enableBiometric(userId);
        
        // Refresh token kaydet
        final session = Supabase.instance.client.auth.currentSession;
        if (session?.refreshToken != null) {
          await BiometricService.saveBiometricRefreshToken(userId, session!.refreshToken!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricEnabled),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

    // Ana sayfaya git - HomeSelectionScreen'e doğrudan yönlendir
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
        (route) => false,
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Save for biometric authentication
        if (response.user != null) {
          await BiometricService.saveLastAuthenticatedUser(response.user!.id);
          await BiometricService.saveBiometricEmail(
            response.user!.id,
            _emailController.text.trim(),
          );
          // Get session token for biometric login
          final session = response.session;
          final accessToken = session?.accessToken;
          if (accessToken != null) {
            await BiometricService.saveBiometricToken(
              response.user!.id,
              accessToken,
            );
          }
          final refreshToken = session?.refreshToken;
          if (refreshToken != null) {
            await BiometricService.saveBiometricRefreshToken(
              response.user!.id,
              refreshToken,
            );
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', _emailController.text.trim());
        
        if (mounted) {
          final canAuth = await BiometricService.canAuthenticateWithBiometrics();
          
          // Biyometrik zaten etkinse, prompt gösterme
          if (response.user != null) {
            final isEnabled = await BiometricService.isBiometricEnabled(response.user!.id);
            if (isEnabled) {
              // Biyometrik zaten etkin, direkt ana sayfaya git
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
                (route) => false,
              );
              return;
            }
          }
          
          // Biyometrik etkin değilse ve cihaz destekliyorsa, etkinleştirme sor
          if (canAuth && response.user != null) {
            await _showBiometricEnableDialog(response.user!.id);
          } else {
            // Biyometrik desteklenmiyorsa direkt ana sayfaya git
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
              (route) => false,
            );
          }
        }
      } else {
        // Signup validations
        final email = _emailController.text.trim();
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();
        final confirmPassword = _confirmPasswordController.text.trim();
        
        if (email.isEmpty || username.isEmpty) {
          throw const AuthException('E-posta ve Kullanıcı Adı zorunludur.');
        }
        
        if (password != confirmPassword) {
          throw const AuthException('Şifreler uyuşmuyor.');
        }

        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
            'full_name': _fullNameController.text.trim(),
            'phone_number': _phoneController.text.trim(),
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Giriş yapılıyor...'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
          
          if (response.user != null) {
            await BiometricService.saveLastAuthenticatedUser(response.user!.id);
            await BiometricService.saveBiometricEmail(response.user!.id, email);
            // Get session token for biometric login
            final session = response.session;
            final accessToken = session?.accessToken;
            if (accessToken != null) {
              await BiometricService.saveBiometricToken(
                response.user!.id,
                accessToken,
              );
            }
            final refreshToken = session?.refreshToken;
            if (refreshToken != null) {
              await BiometricService.saveBiometricRefreshToken(
                response.user!.id,
                refreshToken,
              );
            }
          }
          
          // Biyometrik etkinleştirme sor (signup sonrası)
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && response.user != null) {
            final canAuth = await BiometricService.canAuthenticateWithBiometrics();
            if (canAuth) {
              await _showBiometricEnableDialog(response.user!.id);
            } else {
              // Biyometrik desteklenmiyorsa direkt ana sayfaya git
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beklenmedik bir hata oluştu'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enableBiometric() async {
    try {
      // Önce Face ID/Touch ID doğrulaması yap
      final isAuthenticated = await BiometricService.authenticate();
      
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biyometrik doğrulama başarısız!'),
              backgroundColor: Colors.redAccent,
            ),
          );
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
        }
        
        await BiometricService.setSkipBiometricPrompt(true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biyometrik giriş etkinleştirildi!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _showBiometricButton = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _tryAutoBiometricLogin() async {
    if (_biometricAutoTried) return;
    _biometricAutoTried = true;

    bool skipPrompt = false;
    bool canAuthenticate = false;
    String? lastUser;
    bool isEnabled = false;
    String? refreshToken;

    try {
      skipPrompt = await BiometricService.shouldSkipBiometricPrompt();
      canAuthenticate = await BiometricService.canAuthenticateWithBiometrics();
      lastUser = await BiometricService.getLastAuthenticatedUser();
      isEnabled = lastUser != null ? await BiometricService.isBiometricEnabled(lastUser) : false;
      refreshToken = lastUser != null ? await BiometricService.getBiometricRefreshToken(lastUser) : null;

      print('=== BIOMETRIC AUTO LOGIN DEBUG ===');
      print('skipPrompt: $skipPrompt');
      print('canAuthenticate: $canAuthenticate');
      print('lastUser: $lastUser');
      print('isEnabled: $isEnabled');
      print('refreshToken exists: ${refreshToken != null}');
      print('==================================');

      if (!canAuthenticate || lastUser == null || !isEnabled || refreshToken == null) {
        print('BIOMETRIC: Skipping - conditions not met');
        return;
      }
    } catch (e) {
      print('BIOMETRIC ERROR: $e');
      return;
    }

    if (!mounted) return;

    if (skipPrompt && refreshToken != null) {
      try {
        print('BIOMETRIC: Trying silent session restore...');
        final response = await Supabase.instance.client.auth.setSession(refreshToken);
        if (response.session != null && mounted) {
          print('BIOMETRIC: Silent restore successful!');
          // Session ayarlandı - HomeSelectionScreen'e git
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
            (route) => false,
          );
          return;
        }
      } catch (e) {
        print('BIOMETRIC: Silent restore failed: $e');
        // Fall through to prompt if silent resume fails
      }
    }

    if (!mounted) return;

    print('BIOMETRIC: Showing BiometricFullScreen...');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const BiometricFullScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    print('BIOMETRIC: BiometricFullScreen result: $result');
    if (result == true && refreshToken != null) {
      try {
        print('BIOMETRIC: Trying to set session after auth...');
        final response = await Supabase.instance.client.auth.setSession(refreshToken);
        print('BIOMETRIC: Session response: ${response.session != null}');
        if (response.session != null && mounted) {
          // ÖNEMLİ: Bir sonraki açılışta da otomatik giriş yapsın
          await BiometricService.setSkipBiometricPrompt(true);
          if (!mounted) return;
          // Session ayarlandı - HomeSelectionScreen'e git
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate(skipSignOut: true)),
            (route) => false,
          );
        }
      } catch (e) {
        print('BIOMETRIC: Session error: $e');
        // Refresh token geçersiz - biyometrik verileri temizle
        // Böylece bir sonraki açılışta normal login gösterilir
        if (e.toString().contains('refresh_token') || 
            e.toString().contains('Invalid Refresh Token')) {
          print('BIOMETRIC: Clearing invalid biometric data...');
          await BiometricService.clearLastAuthenticatedUser();
          // Sessizce login ekranına yönlendir - mesaj gösterme
          // Kullanıcı zaten login ekranında, normal şekilde giriş yapabilir
        }
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen şifre sıfırlama için e-posta adresinizi girin.')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF0F2027),
                child: const Center(
                  child: Text(
                    'Please add login_bg.png to assets/images folder',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
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
          
          // Overlay Gradient for better readability at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content with Scrollable Support
          SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.only(
                  top: size.height * 0.15,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 450,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Inputs Row (Compact for Landscape)
                          if (!_isLogin) ...[
                            // Signup Form
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactField(
                                        controller: _fullNameController,
                                        hint: l10n.fullName,
                                        icon: Icons.person_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactField(
                                        controller: _phoneController,
                                        hint: l10n.phone,
                                        icon: Icons.phone,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildCompactField(
                                                controller: _emailController,
                                                hint: l10n.email,
                                                icon: Icons.email,
                                                color: Colors.yellowAccent,
                                              ),
                                              if (_showEmailSuggestion) ...[
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () {
                                                    final text = _emailController.text;
                                                    final atIndex = text.lastIndexOf('@');
                                                    final beforeAt = text.substring(0, atIndex);
                                                    _emailController.text = '$beforeAt@hotmail.com';
                                                    _emailController.selection = TextSelection.fromPosition(
                                                      TextPosition(offset: _emailController.text.length),
                                                    );
                                                    setState(() {
                                                      _showEmailSuggestion = false;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.yellowAccent.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.yellowAccent, width: 1),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: const [
                                                        Icon(Icons.email, color: Colors.yellowAccent, size: 12),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'hotmail.com',
                                                          style: TextStyle(
                                                            color: Colors.yellowAccent,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildCompactField(
                                            controller: _usernameController,
                                            hint: l10n.username,
                                            icon: Icons.person,
                                            color: Colors.greenAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactField(
                                        controller: _passwordController,
                                        hint: l10n.password,
                                        icon: Icons.lock,
                                        obscureText: true,
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactField(
                                        controller: _confirmPasswordController,
                                        hint: l10n.confirmPassword,
                                        icon: Icons.lock_outline,
                                        obscureText: true,
                                        color: Colors.purpleAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ] else ...[
                            // Login Form
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildCompactField(
                                        controller: _emailController,
                                        hint: l10n.email,
                                        icon: Icons.email,
                                      ),
                                      if (_showEmailSuggestion) ...[
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            final text = _emailController.text;
                                            final atIndex = text.lastIndexOf('@');
                                            final beforeAt = text.substring(0, atIndex);
                                            _emailController.text = '$beforeAt@hotmail.com';
                                            _emailController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: _emailController.text.length),
                                            );
                                            setState(() {
                                              _showEmailSuggestion = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.blueAccent, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.email, color: Colors.blueAccent, size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  'hotmail.com',
                                                  style: TextStyle(
                                                    color: Colors.blueAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCompactField(
                                    controller: _passwordController,
                                    hint: l10n.password,
                                    icon: Icons.lock,
                                    obscureText: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const SizedBox.shrink(),
                          ],
                          
                          const SizedBox(height: 15),
                          
                          // Secondary Buttons (Small, Side-by-Side)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _resetPassword,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  l10n.forgotPassword,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                                ),
                              ),
                              Container(width: 1, height: 12, color: Colors.white.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 8)),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _isLogin ? l10n.createAccount : l10n.login,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 15),
                          
                          // Main Button with Heartbeat
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 5,
                                shadowColor: Colors.blueAccent.withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _isLogin ? l10n.login : l10n.register,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Color? color,
  }) {
    final effectiveColor = color ?? Colors.cyanAccent;
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), // Increased opacity for better contrast
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withOpacity(0.3), width: 1), // Subtle border
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(
          color: effectiveColor, 
          fontSize: 13, 
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2.0,
              color: Colors.black,
            ),
          ],
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: effectiveColor.withOpacity(0.9), // Increased opacity
            fontSize: 13,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 2.0,
                color: Colors.black,
              ),
            ],
          ),
          prefixIcon: Icon(icon, color: effectiveColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
