# 🍎 App Store'a Yükleme Kılavuzu - PerfecTime

## ✅ Tamamlanan Ayarlar

| Ayar | Değer | Durum |
|------|-------|-------|
| Bundle ID | `com.dogukanbeyzade.perfectime` | ✅ |
| Team ID | `DT4UT73T4X` | ✅ |
| Version | `1.0.0` | ✅ |
| Build Number | `1` | ✅ |
| App Icons | Tüm boyutlar mevcut | ✅ |
| Privacy Permissions | Kamera, Mikrofon, Fotoğraf, FaceID | ✅ |

---

## 📝 Apple Developer Console'da Yapılacaklar

### 1. App ID Oluştur (Görseldeki Sayfa)

**Certificates, Identifiers & Profiles** > **Identifiers** > **+** butonuna tıkla

Doldurulacak alanlar:
- **Description:** `PerfecTime - Profesyonel toplantı yönetimi uygulaması`
- **Bundle ID:** `com.dogukanbeyzade.perfectime` (Explicit seçili olmalı)

#### Capabilities (Aktif Edilmesi Gerekenler):
- [x] **Associated Domains** (Universal Links için)
- [x] **Push Notifications** (Bildirimler için - opsiyonel)
- [x] **Sign in with Apple** (Apple ile giriş için - opsiyonel)
- [x] **In-App Purchase** (Abonelikler için - purchases_flutter kullanıyorsun)

**Continue** > **Register** butonlarına tıkla.

---

### 2. App Store Connect'te Uygulama Oluştur

1. [App Store Connect](https://appstoreconnect.apple.com) adresine git
2. **My Apps** > **+** > **New App**
3. Doldur:
   - **Platforms:** iOS
   - **Name:** PerfecTime
   - **Primary Language:** Türkçe veya İngilizce
   - **Bundle ID:** `com.dogukanbeyzade.perfectime` (listeden seç)
   - **SKU:** `perfectime001`
   - **User Access:** Full Access

---

### 3. App Store Bilgileri

#### Gerekli Görseller (App Store Connect > App Information)

| Tür | Boyut | Adet |
|-----|-------|------|
| iPhone Screenshots | 1290 x 2796 px (6.7") | En az 3 |
| iPhone Screenshots | 1179 x 2556 px (6.1") | En az 3 |
| iPad Screenshots | 2048 x 2732 px (12.9") | En az 3 (iPad destekliyorsa) |
| App Preview Video | 1920 x 1080 px | Opsiyonel |
| App Icon | 1024 x 1024 px | 1 (otomatik kullanılır) |

#### Uygulama Açıklaması (Türkçe)
```
PerfecTime ile toplantılarınızı profesyonelce yönetin!

🎯 ÖNE ÇIKAN ÖZELLİKLER:

📹 Video Toplantılar
Yüksek kaliteli video ve sesli toplantılar oluşturun. Katılımcılarınızı kolayca davet edin.

⏰ Zamanlama
Toplantılarınızı planlayın, hatırlatıcılar alın ve zamanınızı verimli kullanın.

🔒 Güvenlik
Biyometrik doğrulama (Face ID / Touch ID) ile toplantılarınızı koruyun.

📱 Kolay Kullanım
Sade ve modern arayüz ile toplantı oluşturmak saniyeler sürüyor.

🎥 Kayıt
Önemli toplantılarınızı kaydedin ve daha sonra izleyin.

📤 Paylaşım
Toplantı linklerini kolayca paylaşın, katılımcılar tek tıkla katılsın.

PerfecTime - Zamanın Mükemmel Yönetimi
```

#### Anahtar Kelimeler
```
toplantı, video, konferans, meeting, görüşme, iş, business, zaman, timer
```

#### Gizlilik Politikası URL'si
Bir gizlilik politikası sayfası oluşturmanız gerekiyor.

---

## 🔨 Build ve Upload Komutları

### Terminal'de Çalıştırılacak Komutlar:

```bash
# 1. Proje klasörüne git
cd /Users/dogukanbeyzade/Desktop/PerfecTime/perfect_time

# 2. Pod'ları güncelle
cd ios && pod install --repo-update && cd ..

# 3. Flutter cache temizle
flutter clean

# 4. Bağımlılıkları al
flutter pub get

# 5. App Store için build al
flutter build ipa --release

# 6. Build tamamlandıktan sonra IPA dosyası burada olacak:
# build/ios/ipa/perfect_time.ipa
```

### Xcode ile Upload (Önerilen):

```bash
# Xcode'da aç
open ios/Runner.xcworkspace
```

1. **Product** > **Archive**
2. **Distribute App** > **App Store Connect**
3. **Upload** seçeneğini seç
4. Otomatik signing kullan
5. **Upload** butonuna tıkla

### Command Line ile Upload (Alternatif):

```bash
# Transporter uygulaması ile veya:
xcrun altool --upload-app -f build/ios/ipa/perfect_time.ipa -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD
```

---

## ⚠️ App Store Review Öncesi Kontrol Listesi

### Teknik Gereksinimler:
- [ ] iOS 13.0+ desteği (mevcut ✅)
- [ ] 64-bit desteği (Flutter varsayılan ✅)
- [ ] IPv6 ağ desteği
- [ ] App Transport Security (HTTPS)

### İçerik Gereksinimleri:
- [ ] Gizlilik politikası URL'si
- [ ] Kullanım şartları (opsiyonel)
- [ ] İletişim bilgileri
- [ ] Destek URL'si

### Test:
- [ ] Tüm özellikler çalışıyor
- [ ] Crash yok
- [ ] Memory leak yok
- [ ] Arka plan davranışı doğru

---

## 📋 In-App Purchase Ayarları (RevenueCat)

`purchases_flutter` kullandığınız için:

1. **App Store Connect** > **Features** > **In-App Purchases**
2. Abonelik planlarını ekle
3. **RevenueCat Dashboard**'da ürünleri yapılandır
4. Sandbox test hesabı oluştur

---

## 🚀 Sonraki Adımlar

1. ✅ Bundle ID tamamlandı
2. ⏳ Apple Developer Console'da App ID oluştur
3. ⏳ App Store Connect'te uygulama oluştur
4. ⏳ Ekran görüntüleri hazırla
5. ⏳ Gizlilik politikası oluştur
6. ⏳ Build al ve yükle
7. ⏳ Review'e gönder

---

## 📞 Yardım

Herhangi bir sorun yaşarsan, şu dosyaları kontrol et:
- `ios/Runner.xcodeproj/project.pbxproj` - Bundle ID ayarları
- `ios/Runner/Info.plist` - Uygulama bilgileri
- `ios/ExportOptions.plist` - Export ayarları
- `pubspec.yaml` - Versiyon bilgisi

**Başarılar! 🎉**
