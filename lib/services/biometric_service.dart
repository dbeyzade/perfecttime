import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Cihazda biyometrik kimlik doğrulama desteklenip desteklenmediğini kontrol et
  static Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.canCheckBiometrics;
      return isDeviceSupported;
    } catch (e) {
      print('Biyometrik kontrol hatası: $e');
      return false;
    }
  }

  /// Kullanılabilir biyometrik türlerini al
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Biyometrik türlerini alma hatası: $e');
      return [];
    }
  }

  /// Biyometrik kimlik doğrulamayı gerçekleştir
  static Future<bool> authenticate() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Devam etmek için lütfen kimlik doğrulama yapın',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      print('Biyometrik kimlik doğrulama hatası: $e');
      return false;
    }
  }

  /// Biyometrik giriş etkin mi kontrol et
  static Future<bool> isBiometricEnabled(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_enabled_$userId') ?? false;
    } catch (e) {
      print('Biyometrik durum kontrol hatası: $e');
      return false;
    }
  }

  /// Biyometrik girişi etkinleştir
  static Future<bool> enableBiometric(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('biometric_enabled_$userId', true);
    } catch (e) {
      print('Biyometrik etkinleştirme hatası: $e');
      return false;
    }
  }

  /// Biyometrik girişi devre dışı bırak
  static Future<bool> disableBiometric(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('biometric_enabled_$userId', false);
    } catch (e) {
      print('Biyometrik devre dışı bırakma hatası: $e');
      return false;
    }
  }

  /// Son giriş yapan kullanıcıyı al (biyometrik giriş için)
  static Future<String?> getLastAuthenticatedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_authenticated_user');
    } catch (e) {
      print('Son kullanıcı bilgisi alma hatası: $e');
      return null;
    }
  }

  /// Son giriş yapan kullanıcı kimliğini kaydet
  static Future<bool> saveLastAuthenticatedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('last_authenticated_user', userId);
    } catch (e) {
      print('Kullanıcı kimliği kaydetme hatası: $e');
      return false;
    }
  }

  /// Kullanıcı e-postasını biyometrik giriş için kaydet
  static Future<bool> saveBiometricEmail(String userId, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('biometric_email_$userId', email);
    } catch (e) {
      print('E-posta kaydetme hatası: $e');
      return false;
    }
  }

  /// Biyometrik giriş için kaydedilmiş e-postayı al
  static Future<String?> getBiometricEmail(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('biometric_email_$userId');
    } catch (e) {
      print('Biyometrik e-posta alma hatası: $e');
      return null;
    }
  }

  /// Supabase session token'ını kaydet (biometrik giriş için)
  static Future<bool> saveBiometricToken(String userId, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('biometric_token_$userId', token);
    } catch (e) {
      print('Token kaydetme hatası: $e');
      return false;
    }
  }

  /// Kayıtlı session token'ını al
  static Future<String?> getBiometricToken(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('biometric_token_$userId');
    } catch (e) {
      print('Token alma hatası: $e');
      return null;
    }
  }

  /// Supabase refresh token'ını kaydet (biometrik auto-login için)
  static Future<bool> saveBiometricRefreshToken(String userId, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('biometric_refresh_token_$userId', token);
    } catch (e) {
      print('Refresh token kaydetme hatası: $e');
      return false;
    }
  }

  /// Kayıtlı refresh token'ını al
  static Future<String?> getBiometricRefreshToken(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('biometric_refresh_token_$userId');
    } catch (e) {
      print('Refresh token alma hatası: $e');
      return null;
    }
  }

  /// Logout sırasında tüm biyometrik verilerini temizle
  static Future<bool> clearBiometricData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('biometric_enabled_$userId');
      await prefs.remove('biometric_email_$userId');
      await prefs.remove('biometric_token_$userId');
      await prefs.remove('biometric_refresh_token_$userId');
      await prefs.remove('last_authenticated_user');
      return true;
    } catch (e) {
      print('Biyometrik veri silme hatası: $e');
      return false;
    }
  }

  /// Son giriş yapılan kullanıcı kimliğini temizle (logout'ta)
  static Future<bool> clearLastAuthenticatedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_authenticated_user');
      return true;
    } catch (e) {
      print('Son kullanıcı temizleme hatası: $e');
      return false;
    }
  }

  /// Biyometrik tam ekranı bir daha göstermemek için kullanılır
  static Future<bool> setSkipBiometricPrompt(bool skip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('biometric_prompt_skip', skip);
    } catch (e) {
      print('Biyometrik ekran geçiş hatası: $e');
      return false;
    }
  }

  /// Kullanıcı "bir daha gösterme" seçtiyse true döner
  static Future<bool> shouldSkipBiometricPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_prompt_skip') ?? false;
    } catch (e) {
      print('Biyometrik ekran kontrol hatası: $e');
      return false;
    }
  }
}
