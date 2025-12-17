import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static LocalizationService? _instance;
  
  Locale _currentLocale = const Locale('tr'); // Default Turkish
  
  Locale get currentLocale => _currentLocale;
  String get languageCode => _currentLocale.languageCode;
  bool get isTurkish => _currentLocale.languageCode == 'tr';
  bool get isEnglish => _currentLocale.languageCode == 'en';
  
  static LocalizationService get instance {
    _instance ??= LocalizationService._();
    return _instance!;
  }
  
  LocalizationService._();
  
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey) ?? 'tr';
    _currentLocale = Locale(savedLanguage);
    debugPrint('=== LANGUAGE LOADED: $savedLanguage ===');
    notifyListeners();
  }
  
  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'tr' && languageCode != 'en') return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    _currentLocale = Locale(languageCode);
    debugPrint('=== LANGUAGE SET TO: $languageCode ===');
    notifyListeners();
  }
  
  Future<void> toggleLanguage() async {
    final newLanguage = _currentLocale.languageCode == 'tr' ? 'en' : 'tr';
    await setLanguage(newLanguage);
  }
  
  // App Strings
  String get appName => isTurkish ? 'PerfecTime' : 'PerfecTime';
  
  // Home Selection Screen
  String get startSession => isTurkish ? 'Oturum Başlat' : 'Start Session';
  String get startSessionDesc => isTurkish ? 'Yeni bir toplantı oluşturun ve yönetin' : 'Create and manage a new meeting';
  String get joinSession => isTurkish ? 'Oturuma Katıl' : 'Join Session';
  String get joinSessionDesc => isTurkish ? 'Mevcut bir toplantıya dahil olun' : 'Join an existing meeting';
  
  // Biometric
  String get enableBiometric => isTurkish ? 'Biyometrik Girişi aktif et' : 'Enable Biometric Login';
  String get biometricDesc => isTurkish 
      ? 'Parmak izi veya Face ID ile anında ve güvenli giriş yapın. Cihazınızdaki biyometrik verileri kullanarak hesaba hızla erişin.'
      : 'Sign in instantly and securely with fingerprint or Face ID. Access your account quickly using your device\'s biometric data.';
  String get touchIdFaceId => isTurkish ? 'Touch ID / Face ID' : 'Touch ID / Face ID';
  String get quickLogin => isTurkish ? 'Hızlı giriş' : 'Quick login';
  String get secureSession => isTurkish ? 'Güvenli oturum' : 'Secure session';
  String get enableNow => isTurkish ? 'Hemen etkinleştir' : 'Enable now';
  String get later => isTurkish ? 'Daha sonra' : 'Later';
  String get dontShowAgain => isTurkish ? 'Bir daha gösterme' : 'Don\'t show again';
  String get biometricEnabled => isTurkish ? 'Biyometrik giriş etkinleştirildi!' : 'Biometric login enabled!';
  String get biometricFailed => isTurkish ? 'Biyometrik doğrulama başarısız!' : 'Biometric authentication failed!';
  
  // Login Screen
  String get welcomeBack => isTurkish ? 'Tekrar Hoş Geldiniz' : 'Welcome Back';
  String get email => isTurkish ? 'E-posta' : 'Email';
  String get password => isTurkish ? 'Şifre' : 'Password';
  String get login => isTurkish ? 'Giriş Yap' : 'Login';
  String get register => isTurkish ? 'Kayıt Ol' : 'Register';
  String get forgotPassword => isTurkish ? 'Şifremi Unuttum' : 'Forgot Password';
  String get noAccount => isTurkish ? 'Hesabınız yok mu?' : 'Don\'t have an account?';
  String get alreadyHaveAccount => isTurkish ? 'Zaten hesabınız var mı?' : 'Already have an account?';
  String get createAccount => isTurkish ? 'Hesap Oluştur' : 'Create Account';
  String get loginSuccess => isTurkish ? 'Giriş başarılı!' : 'Login successful!';
  String get loginFailed => isTurkish ? 'Giriş başarısız!' : 'Login failed!';
  String get registerSuccess => isTurkish ? 'Kayıt başarılı! E-postanızı doğrulayın.' : 'Registration successful! Please verify your email.';
  String get invalidEmail => isTurkish ? 'Geçersiz e-posta adresi' : 'Invalid email address';
  String get invalidPassword => isTurkish ? 'Şifre en az 6 karakter olmalı' : 'Password must be at least 6 characters';
  String get fullName => isTurkish ? 'Ad Soyad' : 'Full Name';
  String get confirmPassword => isTurkish ? 'Şifre Tekrar' : 'Confirm Password';
  String get passwordsDoNotMatch => isTurkish ? 'Şifreler eşleşmiyor' : 'Passwords do not match';
  String get phone => isTurkish ? 'Tel No' : 'Phone';
  String get username => isTurkish ? 'Kullanıcı Adı' : 'Username';
  
  // Host Setup Screen
  String get setupMeeting => isTurkish ? 'Toplantı Ayarları' : 'Meeting Setup';
  String get planSession => isTurkish ? 'Oturum Planla' : 'Plan Session';
  String get meetingInfoHeader => isTurkish ? 'TOPLANTI BİLGİLERİ' : 'MEETING INFO';
  String get meetingSubject => isTurkish ? 'Toplantı Konusu' : 'Meeting Subject';
  String get scheduling => isTurkish ? 'ZAMANLAMA' : 'SCHEDULING';
  String get date => isTurkish ? 'Tarih' : 'Date';
  String get time => isTurkish ? 'Saat' : 'Time';
  String get select => isTurkish ? 'Seçiniz' : 'Select';
  String get settingsSection => isTurkish ? 'AYARLAR' : 'SETTINGS';
  String get record => isTurkish ? 'Kaydet' : 'Record';
  String get saveToGallery => isTurkish ? 'Galeriye kaydet' : 'Save to gallery';
  String get reminder => isTurkish ? 'Hatırlatma' : 'Reminder';
  String get minutesShort => isTurkish ? 'dk' : 'min';
  String get launchSession => isTurkish ? 'Oturumu Başlat' : 'Launch Session';
  String get meetingCreated => isTurkish ? 'Toplantı Oluşturuldu' : 'Meeting Created';
  String get subject => isTurkish ? 'Konu' : 'Subject';
  String get joinLink => isTurkish ? 'Katılım Linki' : 'Join Link';
  String get shareLink => isTurkish ? 'Linki Paylaş' : 'Share Link';
  String get other => isTurkish ? 'Diğer' : 'Other';
  String get copy => isTurkish ? 'Kopyala' : 'Copy';
  String get meetingTitle => isTurkish ? 'Toplantı Başlığı' : 'Meeting Title';
  String get enterMeetingTitle => isTurkish ? 'Toplantı başlığını girin' : 'Enter meeting title';
  String get startMeeting => isTurkish ? 'Toplantıyı Başlat' : 'Start Meeting';
  String get meetingDuration => isTurkish ? 'Toplantı Süresi' : 'Meeting Duration';
  String get minutes => isTurkish ? 'dakika' : 'minutes';
  String get hours => isTurkish ? 'saat' : 'hours';
  String get selectDateAndTime => isTurkish ? 'Lütfen tarih ve saat seçiniz.' : 'Please select date and time.';
  String get enterMeetingSubject => isTurkish ? 'Lütfen toplantı konusunu giriniz.' : 'Please enter meeting subject.';
  String get meetingCreatedWithReminder => isTurkish ? 'Toplantı oluşturuldu!' : 'Meeting created!';
  String get reminderSet => isTurkish ? 'dakika öncesine hatırlatma kuruldu.' : 'minute reminder set.';
  String get meetingCreateError => isTurkish ? 'Toplantı oluşturulurken hata:' : 'Error creating meeting:';
  
  // Participant Join Screen
  String get joinMeeting => isTurkish ? 'Toplantıya Katıl' : 'Join Meeting';
  String get meetingCode => isTurkish ? 'Toplantı Kodu' : 'Meeting Code';
  String get enterMeetingCode => isTurkish ? 'Toplantı kodunu girin' : 'Enter meeting code';
  String get join => isTurkish ? 'Katıl' : 'Join';
  String get yourName => isTurkish ? 'Adınız' : 'Your Name';
  String get enterYourName => isTurkish ? 'Adınızı girin' : 'Enter your name';
  
  // Meeting Screen
  String get meeting => isTurkish ? 'Toplantı' : 'Meeting';
  String get participants => isTurkish ? 'Katılımcılar' : 'Participants';
  String get endMeeting => isTurkish ? 'Toplantıyı Bitir' : 'End Meeting';
  String get leaveMeeting => isTurkish ? 'Toplantıdan Ayrıl' : 'Leave Meeting';
  String get mute => isTurkish ? 'Sessiz' : 'Mute';
  String get unmute => isTurkish ? 'Sesi Aç' : 'Unmute';
  String get cameraOn => isTurkish ? 'Kamera Açık' : 'Camera On';
  String get cameraOff => isTurkish ? 'Kamera Kapalı' : 'Camera Off';
  String get shareScreen => isTurkish ? 'Ekran Paylaş' : 'Share Screen';
  String get stopSharing => isTurkish ? 'Paylaşımı Durdur' : 'Stop Sharing';
  String get chat => isTurkish ? 'Sohbet' : 'Chat';
  String get host => isTurkish ? 'Toplantı Sahibi' : 'Host';
  String get privateRoom => isTurkish ? 'Gizli Oda' : 'Private Room';
  String get waitingRoom => isTurkish ? 'Bekleme Odası' : 'Waiting Room';
  String get meetingEnded => isTurkish ? 'Toplantı sona erdi' : 'Meeting ended';
  String get youLeft => isTurkish ? 'Toplantıdan ayrıldınız' : 'You left the meeting';
  String get hostEndedMeeting => isTurkish ? 'Toplantı sahibi toplantıyı sonlandırdı' : 'Host ended the meeting';
  String get microphone => isTurkish ? 'Mikrofon' : 'Mic';
  String get fileSharingError => isTurkish ? 'Dosya paylaşma hatası:' : 'File sharing error:';
  String get noParticipants => isTurkish ? 'Henüz katılımcı yok' : 'No participants yet';
  String get waitingForHost => isTurkish ? 'Toplantı sahibi bekleniyor...' : 'Waiting for host...';
  String get meetingCodeCopied => isTurkish ? 'Toplantı kodu kopyalandı!' : 'Meeting code copied!';
  String get shareMeetingLink => isTurkish ? 'Toplantı Linkini Paylaş' : 'Share Meeting Link';
  String get copyLink => isTurkish ? 'Linki Kopyala' : 'Copy Link';
  String get linkCopied => isTurkish ? 'Link kopyalandı!' : 'Link copied!';
  
  // Intro/Video Screen
  String get skip => isTurkish ? 'Atla' : 'Skip';
  String get next => isTurkish ? 'İleri' : 'Next';
  String get getStarted => isTurkish ? 'Başla' : 'Get Started';
  String get welcomeTo => isTurkish ? 'Hoş Geldiniz' : 'Welcome to';
  
  // General
  String get error => isTurkish ? 'Hata' : 'Error';
  String get success => isTurkish ? 'Başarılı' : 'Success';
  String get cancel => isTurkish ? 'İptal' : 'Cancel';
  String get confirm => isTurkish ? 'Onayla' : 'Confirm';
  String get ok => isTurkish ? 'Tamam' : 'OK';
  String get yes => isTurkish ? 'Evet' : 'Yes';
  String get no => isTurkish ? 'Hayır' : 'No';
  String get loading => isTurkish ? 'Yükleniyor...' : 'Loading...';
  String get retry => isTurkish ? 'Tekrar Dene' : 'Retry';
  String get settings => isTurkish ? 'Ayarlar' : 'Settings';
  String get language => isTurkish ? 'Dil' : 'Language';
  String get turkish => isTurkish ? 'Türkçe' : 'Turkish';
  String get english => isTurkish ? 'İngilizce' : 'English';
  String get logout => isTurkish ? 'Çıkış Yap' : 'Logout';
  String get optional => isTurkish ? 'Opsiyonel' : 'Optional';
  String get allPlatforms => isTurkish ? 'Tüm Platformlar' : 'All Platforms';
  String get mobileApp => isTurkish ? 'Mobil Uygulama' : 'Mobile App';
  String get webBrowser => isTurkish ? 'Web Tarayıcı' : 'Web Browser';
  String get mobileLinkCopied => isTurkish ? 'Mobil link kopyalandı' : 'Mobile link copied';
  String get webLinkCopied => isTurkish ? 'Web link kopyalandı' : 'Web link copied';
  String get inviteByLink => isTurkish ? 'Linki paylaşarak davet edebilirsiniz' : 'You can invite by sharing the link';
  String get active => isTurkish ? 'Aktif' : 'Active';
  String get left => isTurkish ? 'Ayrıldı' : 'Left';
  String get copyList => isTurkish ? 'Listeyi Kopyala' : 'Copy List';
  String get end => isTurkish ? 'Bitir' : 'End';
  String get you => isTurkish ? 'Sen' : 'You';
  String get file => isTurkish ? 'Dosya' : 'File';
  String get sharedToPeople => isTurkish ? 'kişiye paylaşıldı' : 'person(s) shared';
  String get logoutConfirm => isTurkish ? 'Çıkış yapmak istediğinize emin misiniz?' : 'Are you sure you want to logout?';
  String get profile => isTurkish ? 'Profil' : 'Profile';
  String get close => isTurkish ? 'Kapat' : 'Close';
  String get save => isTurkish ? 'Kaydet' : 'Save';
  String get delete => isTurkish ? 'Sil' : 'Delete';
  String get edit => isTurkish ? 'Düzenle' : 'Edit';
  String get search => isTurkish ? 'Ara' : 'Search';
  String get noResults => isTurkish ? 'Sonuç bulunamadı' : 'No results found';
  String get connectionError => isTurkish ? 'Bağlantı hatası' : 'Connection error';
  String get tryAgain => isTurkish ? 'Tekrar deneyin' : 'Try again';
  String get permissionRequired => isTurkish ? 'İzin gerekli' : 'Permission required';
  String get cameraPermission => isTurkish ? 'Kamera izni gerekli' : 'Camera permission required';
  String get microphonePermission => isTurkish ? 'Mikrofon izni gerekli' : 'Microphone permission required';
  
  // Waiting Screen
  String get waitingForMeeting => isTurkish ? 'Toplantı bekleniyor...' : 'Waiting for meeting...';
  String get pleaseWait => isTurkish ? 'Lütfen bekleyin' : 'Please wait';
  String get connecting => isTurkish ? 'Bağlanıyor...' : 'Connecting...';
  String get untilMeetingStarts => isTurkish ? 'Toplantının Başlamasına' : 'Until Meeting Starts';
  String get waitingMessage => isTurkish ? 'Lütfen bekleyiniz, oturum sahibi toplantıyı başlattığında otomatik olarak bağlanacaksınız.' : 'Please wait, you will be connected automatically when the host starts the meeting.';
  String get day => isTurkish ? 'GÜN' : 'DAY';
  String get hour => isTurkish ? 'SAAT' : 'HOUR';
  String get minute => isTurkish ? 'DAKİKA' : 'MINUTE';
  String get second => isTurkish ? 'SANİYE' : 'SECOND';
  
  // Splash Screen  
  String get preparingApp => isTurkish ? 'Uygulama hazırlanıyor...' : 'Preparing app...';
  
  // Biometric Screen
  String get scanFingerOrFace => isTurkish ? 'Parmak iziniz veya yüzünüzü tarayın' : 'Scan your fingerprint or face';
  String get scanning => isTurkish ? 'Taranıyor...' : 'Scanning...';
  String get successAuth => isTurkish ? 'Başarılı! ✓' : 'Success! ✓';
  String get failedTryAgain => isTurkish ? 'Başarısız, tekrar deneyin' : 'Failed, try again';
  String get tryAgainButton => isTurkish ? 'Yeniden Dene' : 'Try Again';
  String get biometricAuth => isTurkish ? 'Biyometrik Kimlik Doğrulama' : 'Biometric Authentication';
  String get biometricDescription => isTurkish ? 'Parmak iziniz veya yüzünüzle güvenli bir şekilde giriş yapın. Çok daha hızlı ve kolay!' : 'Sign in securely with your fingerprint or face. Much faster and easier!';
  String get quickLoginBenefit => isTurkish ? 'Hızlı Giriş' : 'Quick Login';
  String get quickLoginDesc => isTurkish ? 'Saniyeler içinde giriş yapın' : 'Sign in within seconds';
  String get secureBenefit => isTurkish ? 'Güvenli' : 'Secure';
  String get secureDesc => isTurkish ? 'Şifrenizi hiç giremezsiniz' : 'Never enter your password';
  String get easyUseBenefit => isTurkish ? 'Kolay Kullanım' : 'Easy to Use';
  String get easyUseDesc => isTurkish ? 'Bir dokunuşla erişim sağlayın' : 'Access with a single touch';
  String get settingUp => isTurkish ? 'Ayarlanıyor...' : 'Setting up...';
  String get enable => isTurkish ? 'Etkinleştir' : 'Enable';
  String get doLater => isTurkish ? 'Sonra Yap' : 'Do Later';
  String get biometricVerifyFailed => isTurkish ? 'Biyometrik doğrulama başarısız!' : 'Biometric verification failed!';
  String get preparingForMeeting => isTurkish ? 'Toplantıya hazırlanıyor...' : 'Preparing for meeting...';
  
  // Meeting Screen - Participant Options
  String get memberNumber => isTurkish ? 'Üye' : 'Member';
  String get muteUser => isTurkish ? 'Kullanıcıyı Sessize Al' : 'Mute User';
  String get blockHandRaise => isTurkish ? 'Söz İstemesini Engelle' : 'Block Hand Raise';
  String get userCantHearMe => isTurkish ? 'Kullanıcı Beni Duymasın' : 'User Cannot Hear Me';
  String get blockUser => isTurkish ? 'Kullanıcıyı Engelle' : 'Block User';
  String get takeToPrivateRoom => isTurkish ? 'Gizli Odaya Al' : 'Take to Private Room';
  String get revokePermission => isTurkish ? 'Sözü Geri Al' : 'Revoke Permission';
  String get givePermission => isTurkish ? 'Söz Ver' : 'Give Permission';
  String get permissionRevoked => isTurkish ? 'kişisinden söz alındı' : 'permission revoked';
  String get permissionGiven => isTurkish ? 'kişisine söz verildi' : 'permission given';
  String get selectWallpaper => isTurkish ? 'Duvar Kağıdı Seç' : 'Select Wallpaper';
  String get changePassword => isTurkish ? 'Şifre Değiştir' : 'Change Password';
  String get newPassword => isTurkish ? 'Yeni Şifre' : 'New Password';
  String get passwordUpdated => isTurkish ? 'Şifre başarıyla güncellendi' : 'Password updated successfully';
  String get update => isTurkish ? 'Güncelle' : 'Update';
  String get setAlarm => isTurkish ? 'Alarm Kur' : 'Set Alarm';
  String get remindersActivated => isTurkish ? 'Toplantılarınız için hatırlatıcılar aktif edildi.' : 'Reminders have been activated for your meetings.';
  String get alarmSet => isTurkish ? 'Alarm kuruldu!' : 'Alarm set!';
  String get sharedFiles => isTurkish ? 'Paylaşılan Dosyalar' : 'Shared Files';
  String get user => isTurkish ? 'Kullanıcı' : 'User';
  String get cameraRequired => isTurkish ? 'Kamera İzni Gerekli' : 'Camera Permission Required';
  String get cameraRequiredDesc => isTurkish ? 'Toplantı sırasında görüntünüzü paylaşmak için kamera izni gereklidir. Lütfen ayarlardan izin verin.' : 'Camera permission is required to share your video during the meeting. Please grant permission in settings.';
  String get openSettings => isTurkish ? 'Ayarlar' : 'Settings';
  String get cameraError => isTurkish ? 'Kamera hatası' : 'Camera error';
  String get cameraNotFound => isTurkish ? 'Kamera bulunamadı.' : 'Camera not found.';
  String get cameraInitFailed => isTurkish ? 'Kamera başlatılamadı.' : 'Camera initialization failed.';
  String get cameraPermissionDenied => isTurkish ? 'Kamera izni reddedildi. Lütfen ayarlardan izin verin.' : 'Camera permission denied. Please grant permission in settings.';
  String get macOsCameraNotFound => isTurkish ? 'macOS\'ta kamera bulunamadı.' : 'No camera found on macOS.';
  String get macOsCameraError => isTurkish ? 'macOS Kamera hatası' : 'macOS Camera error';
  String get preparingMeeting => isTurkish ? 'Toplantıya hazırlanıyor...' : 'Preparing for meeting...';
  String get meetingStarted => isTurkish ? 'Toplantı başladı!' : 'Meeting started!';
  String get pleaseEnterName => isTurkish ? 'Lütfen adınızı giriniz.' : 'Please enter your name.';
  String get pleaseEnterValidEmail => isTurkish ? 'Lütfen geçerli bir e-posta adresi giriniz.' : 'Please enter a valid email address.';
  
  // File sharing
  String get filesLoading => isTurkish ? 'Dosyalar yükleniyor...' : 'Loading files...';
  String get noFilesShared => isTurkish ? 'Henüz dosya paylaşılmamış' : 'No files shared yet';
  String get clickToAddFile => isTurkish ? 'Dosya eklemek için yapış ikonu tıklayın' : 'Click the clip icon to add a file';
  String get fileShare => isTurkish ? 'Dosya Paylaş' : 'Share File';
  String get sendToAll => isTurkish ? 'Tüm Katılımcılara Gönder' : 'Send to All Participants';
  String get orSelectParticipants => isTurkish ? 'Veya belirli katılımcıları seçin:' : 'Or select specific participants:';
  String get selectAtLeastOne => isTurkish ? 'Lütfen en az bir katılımcı seçin' : 'Please select at least one participant';
  String get fileSharing => isTurkish ? 'Dosya paylaşılıyor' : 'Sharing file';
  String get fileSharedToAll => isTurkish ? 'Dosya tüm katılımcılara paylaşıldı' : 'File shared to all participants';
  String get fileSharedTo => isTurkish ? 'Dosya kişiye paylaşıldı' : 'File shared to person(s)';
  String get joined => isTurkish ? 'Katıldı' : 'Joined';
  String get participantListCopied => isTurkish ? 'Katılımcı listesi panoya kopyalandı' : 'Participant list copied to clipboard';
  
  // Screen sharing
  String get screenShareDesc => isTurkish ? 'Toplantıyı sunarken ekranınızı diğer cihazlara yansıtabilirsiniz.' : 'You can share your screen to other devices while presenting.';
  String get shareMeetingLinkDesc => isTurkish ? 'Katılımcıları davet etmek için toplantı linkini paylaşın.' : 'Share the meeting link to invite participants.';
  String get useDuringMeeting => isTurkish ? 'Toplantıyı sunarken kullanın' : 'Use while presenting the meeting';
  String get meetingLinks => isTurkish ? 'Toplantı linkleri' : 'Meeting links';
  String get linksDescription => isTurkish ? 'Bu linkleri paylaşarak katılımcıların uygulamadan veya tarayıcıdan toplantıya girmesini sağlayabilirsiniz.' : 'Share these links to allow participants to join from the app or browser.';
  
  // Settings menu
  String get updateAccountPassword => isTurkish ? 'Hesap şifresini güncelle' : 'Update account password';
  String get meetingReminder => isTurkish ? 'Toplantı hatırlatıcısı' : 'Meeting reminder';
  String get viewMeetingFiles => isTurkish ? 'Toplantı dosyalarını görüntüle' : 'View meeting files';
  String get manageParticipants => isTurkish ? 'Katılımcı listesini yönet' : 'Manage participant list';
  String get mode => isTurkish ? 'Mod' : 'Mode';
  String get participant => isTurkish ? 'Katılımcı' : 'Participant';
  String get camera => isTurkish ? 'Kamera' : 'Camera';
  String get off => isTurkish ? 'Kapalı' : 'Off';
  
  // Participant errors
  String get meetingCancelled => isTurkish ? 'Bu toplantı iptal edildi.' : 'This meeting has been cancelled.';
  String get meetingNotFoundOrError => isTurkish ? 'Toplantı bulunamadı veya bağlantı hatası oluştu.' : 'Meeting not found or connection error occurred.';

  // Screen mirror & projector dialogs
  String get screenMirror => isTurkish ? 'Ekran Yansıt' : 'Screen Mirror';
  String get projectToScreen => isTurkish ? 'Projektöre Yansıt' : 'Project to Screen';
  String get comingSoon => isTurkish ? 'Çok Yakında!' : 'Coming Soon!';
  String get comingSoonDesc => isTurkish ? 'Bu özellik çok yakında hizmetinizde olacaktır. Lütfen takip edin.' : 'This feature will be available very soon. Please stay tuned.';
  
  // Layout options
  String get participantLayout => isTurkish ? 'Katılımcı Yerleşimi' : 'Participant Layout';
  String get list => isTurkish ? 'Liste' : 'List';
  String get horizontalScroll => isTurkish ? 'Yatay kaydırmalı' : 'Horizontal scroll';
  String get grid => isTurkish ? 'Grid' : 'Grid';
  String get twoRowLayout => isTurkish ? '2 satır düzeni' : '2 row layout';
  String get semicircle => isTurkish ? 'Yarım Daire' : 'Semicircle';
  String get arcView => isTurkish ? 'Arc görünüm' : 'Arc view';
  String get meetingInfo => isTurkish ? 'Toplantı Bilgileri' : 'Meeting Info';
  String get people => isTurkish ? 'kişi' : 'people';
  String get yesLogout => isTurkish ? 'Evet, Çıkış Yap' : 'Yes, Logout';
  
  // Drawer badges
  String get hostBadge => isTurkish ? '👑 Toplantı Sahibi' : '👑 Host';
  String get participantBadge => isTurkish ? '👤 Katılımcı' : '👤 Participant';
  String peopleCount(int count) => isTurkish ? '$count Kişi' : '$count People';
  String get defaultUser => isTurkish ? 'Kullanıcı' : 'User';
}

// Global accessor
LocalizationService get l10n => LocalizationService.instance;
