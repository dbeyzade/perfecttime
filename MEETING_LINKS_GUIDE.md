# PerfectTime - Oturum Linkleri Entegrasyonu

## 🎯 Özellikler

Bu güncelleme ile oturum sahibi bir toplantı oluşturduğunda:
- ✅ Otomatik olarak mobil ve web linkleri oluşturulur
- ✅ Katılımcılar bu linkler üzerinden hem mobil cihazdan hem de web tarayıcıdan katılabilir
- ✅ Tüm toplantı bilgileri Supabase'de saklanır
- ✅ Linkler kolayca kopyalanabilir ve paylaşılabilir

## 📋 Kurulum Adımları

### 1. Supabase Veritabanı Yapılandırması

Supabase projenize giriş yapın ve SQL Editor'de aşağıdaki dosyayı çalıştırın:
```bash
supabase_meetings_table.sql
```

Bu dosya `meetings` tablosunu oluşturur ve gerekli RLS (Row Level Security) politikalarını ayarlar.

### 2. Deep Link Yapılandırması

#### Android (zaten yapılandırılmış)
`android/app/src/main/AndroidManifest.xml` dosyası şu şekilde yapılandırılmış:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="perfecttime" android:host="meeting" />
</intent-filter>
```

#### iOS (zaten yapılandırılmış)
`ios/Runner/Info.plist` dosyasında URL scheme ayarlanmış:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>perfecttime</string>
</array>
```

### 3. Bağımlılıkları Yükleyin
```bash
flutter pub get
```

## 🚀 Kullanım

### Oturum Sahibi İçin

1. **Oturum Oluştur**: Ana ekrandan "Oturum Sahibi" seçin
2. **Tarih ve Saat Belirle**: Toplantı başlangıç zamanını ayarlayın
3. **Ayarları Yapılandır**: 
   - Kayıt yapılsın mı? (Galeriye kayıt)
   - Hatırlatma (dakika olarak)
4. **Oturumu Başlat**: Buton ile oluşturun
5. **Linkleri Paylaş**: Dialog'da görünen linkleri kopyalayın veya paylaşın

#### Oluşturulan Linkler:
- **Mobil Link**: `perfecttime://meeting/join?id={meeting-id}`
- **Web Link**: `https://yourapp.com/join?id={meeting-id}` (deploy edilecek domain ile güncellenecek)

### Katılımcı İçin

#### Mobil Uygulama Üzerinden:
1. Paylaşılan mobil linke tıklayın
2. Link otomatik olarak PerfectTime uygulamasını açar
3. Toplantı bilgileri gösterilir
4. "Toplantıya Katıl" butonuna tıklayın
5. Bekleme odasına yönlendirilirsiniz

#### Web Tarayıcı Üzerinden:
1. Paylaşılan web linkine tıklayın
2. Uygulama web tarayıcıda açılır
3. Aynı şekilde toplantıya katılabilirsiniz

## 🧪 Test Etme

### Mobil Link Testi (iOS/Android)
1. Toplantı oluşturduktan sonra mobil linki kopyalayın
2. Notlar uygulamasına (Notes) yapıştırın
3. Link üzerine tıklayın
4. Uygulama otomatik açılmalı ve toplantı ekranı gösterilmeli

### Web Link Testi
1. Web linki tarayıcıda açın
2. Query parametresinde meeting ID olduğundan emin olun
3. Uygulama meeting ID'yi algılamalı ve katılım ekranını göstermeli

## 📱 Ekran Akışı

```
1. Host Setup Screen
   ↓
2. Dialog (Link Paylaşımı)
   ↓
3. Participant Join Screen (Deep link ile)
   ↓
4. Waiting Screen
   ↓
5. Meeting Screen
```

## 🗄️ Veritabanı Şeması

### meetings Tablosu
```sql
- id: UUID (primary key)
- host_id: UUID (auth.users referansı)
- created_at: TIMESTAMP
- start_time: TIMESTAMP (toplantı başlangıç zamanı)
- is_recording: BOOLEAN (kayıt yapılacak mı)
- reminder_minutes: INTEGER (hatırlatma süresi)
- status: TEXT (scheduled, active, completed, cancelled)
- join_link: TEXT (mobil uygulama linki)
- web_link: TEXT (web tarayıcı linki)
```

## 🔐 Güvenlik

- Row Level Security (RLS) aktif
- Herkes toplantıları görüntüleyebilir (katılım için gerekli)
- Sadece oturum sahibi kendi toplantısını güncelleyebilir
- Sadece giriş yapmış kullanıcılar toplantı oluşturabilir

## 🛠️ Geliştirme Notları

### Web Deployment İçin
`host_setup_screen.dart` dosyasında web link'i güncellemeniz gerekiyor:
```dart
final String webLink = 'https://yourapp.com/join?id=$_meetingId';
```
Bu kısmı kendi domain'iniz ile değiştirin.

### Örnek Deep Link Formatları
- Mobil: `perfecttime://meeting/join?id=123e4567-e89b-12d3-a456-426614174000`
- Web: `https://yourapp.com/join?id=123e4567-e89b-12d3-a456-426614174000`

## 📦 Yeni Dosyalar
- `lib/participant_join_screen.dart` - Katılımcı giriş ekranı
- `supabase_meetings_table.sql` - Veritabanı şeması

## 🔄 Değişiklikler
- `lib/host_setup_screen.dart` - Link oluşturma ve paylaşma
- `lib/main.dart` - Deep link handling güncellendi
- Android/iOS yapılandırmaları (zaten mevcuttu)

## 💡 İpuçları

1. **Test için**: Mobil linki test etmek için Notes uygulamasını kullanın
2. **Paylaşım**: Kullanıcılar "Paylaş" butonu ile WhatsApp, SMS vb. üzerinden paylaşabilir
3. **Kopyalama**: Her link için ayrı kopyalama butonu mevcut
4. **Hatırlatma**: İsteğe bağlı hatırlatma özelliği kullanılabilir

## 🐛 Sorun Giderme

**Deep link çalışmıyor?**
- Android/iOS manifest dosyalarını kontrol edin
- Uygulamayı yeniden derleyin: `flutter run`
- Cihazda uygulamanın yüklü olduğundan emin olun

**Supabase bağlantı hatası?**
- `main.dart` dosyasında Supabase credentials'ı kontrol edin
- Internet bağlantısını kontrol edin
- Supabase projesinin aktif olduğundan emin olun

**Meeting bulunamadı hatası?**
- Supabase'de meetings tablosunun oluşturulduğundan emin olun
- RLS politikalarının doğru yapılandırıldığından emin olun
