# 🎯 PerfecTime - Subscription Sistemi Setup Rehberi

## 📋 Genel Bilgi

Uygulama 10 ücretsiz kullanım hakkı vermektedir. Sonrasında kullanıcı aşağıdaki planlardan birini seçerek premium üyelik alabilir:

- **Aylık Üyelik**: $20/ay
- **Yıllık Üyelik**: $150/yıl (en popüler)
- **Ömür Boyu Üyelik**: $200 (tek seferlik)

---

## 🛠️ Kurulum Adımları

### 1. Supabase Konfigürasyonu

Veritabanında subscription tablolarını oluşturmak için:

```bash
cd perfect_time
# Supabase web console'a girin
# SQL Editor'a şu dosyanın içeriğini yapıştırın:
# supabase_subscriptions.sql
```

**Tablolar:**
- `subscriptions` - Kullanıcı abonelik durumu
- `usage_tracking` - Kullanıcı kullanım sayacı
- `pricing_plans` - Fiyatlandırma planları

### 2. RevenueCat Kurulumu

#### a) RevenueCat Hesabı Oluştur
1. [RevenueCat.com](https://www.revenuecat.com) adresine girin
2. Hesap oluşturun ve API key alın
3. Android, iOS, macOS projelerinizi ekleyin

#### b) API Key Yapılandırması
`lib/services/revenucat_service.dart` dosyasında:

```dart
static const String apiKey = 'YOUR_REVENUCAT_API_KEY'; // Buraya yapıştırın
```

#### c) Products Oluştur
RevenueCat Dashboard'da şu products'ı oluşturun:

**iOS:**
- `perfect_time_monthly` - Aylık Plan
- `perfect_time_yearly` - Yıllık Plan  
- `perfect_time_lifetime` - Ömür Boyu Plan

**Android:**
- `perfect_time_monthly_android`
- `perfect_time_yearly_android`
- `perfect_time_lifetime_android`

**macOS:**
- `perfect_time_monthly_macos`
- `perfect_time_yearly_macos`
- `perfect_time_lifetime_macos`

### 3. iOS Yapılandırması

#### a) App Store Connect
1. [App Store Connect](https://appstoreconnect.apple.com) adresine girin
2. Uygulamanız → Subscriptions → Düzenleme
3. RevenueCat'te oluşturduğunuz ürünleri oluşturun
4. Yapılandırma yapın

#### b) iOS Info.plist
Zaten yapılandırılmış. Gerekirse StoreKit2 capability ekleyin:
- Xcode → Signing & Capabilities → + Capability → "In-App Purchase"

#### c) Swift Configuration
`ios/Runner/GeneratedPluginRegistrant.swift` otomatik oluşturulur.

### 4. Android Yapılandırması

#### a) Google Play Console
1. [Google Play Console](https://play.google.com/console) adresine girin
2. Uygulamanız → In-app products
3. Abonelik ürünleri oluşturun (aynı isimlerle)

#### b) Android Manifest
`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="com.android.vending.BILLING" />
```
✅ Zaten eklenmiş

#### c) Build Gradle
`android/app/build.gradle.kts`:
```gradle
dependencies {
    // Purchases SDK otomatik eklenir
}
```

### 5. macOS Yapılandırması

#### a) App Store Connect
macOS app'i oluşturun ve abonelik ürünlerini tanımlayın

#### b) Entitlements
`macos/Runner/DebugProfile.entitlements`:
```xml
<key>com.apple.security.get-task-allow</key>
<true/>
```

---

## 📱 Kullanım Örnekleri

### Örnek 1: Home Screen'de Kullanım Kontrol

```dart
import 'subscription_helper.dart';

@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: SubscriptionHelper.logUsageAndCheck(context, userId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator();
      }
      
      if (snapshot.data == false) {
        // Paywall gösterildi, devam edemez
        return SizedBox.shrink();
      }
      
      // Normal ekran göster
      return YourMainWidget();
    },
  );
}
```

### Örnek 2: Subscription Info Göster

```dart
FutureBuilder<Map<String, dynamic>?>(
  future: SubscriptionHelper.getSubscriptionInfo(userId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final info = snapshot.data!;
      return Text(
        '${SubscriptionHelper.getPlanDisplay(info["plan"])}\n'
        'Kalan Kullanım: ${info["remaining"]}/${info["total"]}',
      );
    }
    return Text('Plan yükleniyor...');
  },
)
```

### Örnek 3: Manuel Abonelik Kontrol

```dart
final canUse = await subscriptionService.canUseApp(userId);
if (canUse) {
  // Kullanıcı kullanabilir
  await subscriptionService.incrementUsageCount(userId);
} else {
  // Paywall göster
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => PaywallScreen(),
  ));
}
```

---

## 🔄 Veri Akışı

```
Kullanıcı İlk Giriş
    ↓
subscription.plan_type = 'free'
usage_tracking.usage_count = 0
    ↓
Feature Kullanmaya Çalışır
    ↓
usage_count < 10 ? → İzin Ver
                  → usage_count++
    ↓
usage_count == 10 ? → Paywall Göster
                   → Premium Plan Seç
    ↓
RevenueCat Ödeme İşle
    ↓
Supabase: subscription.plan_type = 'monthly|yearly|lifetime'
    ↓
Sınırsız Kullanım Aktif ✅
```

---

## 🧪 Testing

### Test Cihazları (RevenueCat)
1. RevenueCat Dashboard → Settings
2. Test Devices bölümüne Apple ID / Google Play hesabı ekleyin
3. Test etmek istediğiniz cihaza giriş yapın

### Sandbox Test Hesapları

**iOS:**
- App Store Connect → Users and Access → Sandbox Testers

**Android:**
- Google Play Console → Settings → License Testing → Testers Email ekleyin

---

## 📊 Database Queries

### Aktif Üyelikleri Görmek
```sql
SELECT user_id, plan_type, ends_at 
FROM subscriptions 
WHERE status = 'active' AND plan_type != 'free';
```

### Kullanım İstatistikleri
```sql
SELECT 
  user_id, 
  usage_count, 
  CASE 
    WHEN usage_count >= 10 THEN 'Limited'
    ELSE 'Free'
  END as status
FROM usage_tracking
ORDER BY usage_count DESC;
```

### Süresi Dolan Abonelikler
```sql
SELECT user_id, ends_at 
FROM subscriptions 
WHERE ends_at < NOW() AND status = 'active';
```

---

## 🚨 Common Issues

### "No Android SDK found"
```bash
# Terminal'de:
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
flutter build apk
```

### RevenueCat API Key Hatası
- API Key'in doğru olduğunu kontrol edin
- Production vs Sandbox key'i ayırt edin

### In-App Purchase çalışmıyor
- RevenueCat'te product ID'lerin doğru olduğunu kontrol edin
- İşletim sistemi ID'leri ile match ettiğini doğrulayın

---

## 📝 Dosya Listesi

✅ Oluşturulan Dosyalar:
- `supabase_subscriptions.sql` - Veritabanı schema
- `lib/services/subscription_service.dart` - Temel servis
- `lib/services/revenucat_service.dart` - In-app purchase
- `lib/paywall_screen.dart` - UI ekranı
- `lib/subscription_helper.dart` - Helper fonksiyonlar

✏️ Düzenlenen Dosyalar:
- `pubspec.yaml` - RevenueCat dependency eklenildi
- `android/app/src/main/AndroidManifest.xml` - INTERNET permission

---

## 🎯 Next Steps

1. ✅ Android Studio kurulumu tamamla
2. ✅ APK derle: `flutter build apk`
3. ✅ RevenueCat hesabını yapılandır
4. ✅ iOS/Android products oluştur
5. ✅ Test et
6. ✅ Deploy et

---

## 📞 Support

Sorular için:
- RevenueCat Docs: https://docs.revenuecat.com
- Flutter In-App Purchase: https://pub.dev/packages/in_app_purchase
- Supabase: https://supabase.com/docs

Happy Coding! 🚀
