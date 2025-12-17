# PerfectTime Link Sharing - Teknik Detaylar

## Deep Link Mekanizması

### Android Deep Link
```xml
<!-- AndroidManifest.xml -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="perfecttime" android:host="meeting" />
</intent-filter>
```

**Nasıl Çalışır:**
- Kullanıcı `perfecttime://meeting/join?id=xxx` linkine tıklar
- Android OS bu linki yakalar
- PerfectTime uygulaması otomatik açılır
- `app_links` package URI'yi parse eder
- Meeting ID alınır ve katılım ekranına yönlendirilir

### iOS Deep Link
```xml
<!-- Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>perfecttime</string>
        </array>
    </dict>
</array>
```

**Nasıl Çalışır:**
- iOS Universal Links ile entegre
- Aynı mekanizma, farklı OS

### Web Deep Link
```javascript
// URL: https://yourapp.com/join?id=meeting-id-here
// Flutter web otomatik olarak Uri.base'den query parametrelerini alır
```

## Veri Akışı

```
1. Host Setup Screen
   ↓
2. Supabase Insert
   {
     id: UUID,
     host_id: user_id,
     start_time: timestamp,
     is_recording: bool,
     reminder_minutes: int,
     join_link: "perfecttime://...",
     web_link: "https://...",
     status: "scheduled"
   }
   ↓
3. Link Paylaşımı (Share / Copy)
   ↓
4. Katılımcı Linke Tıklar
   ↓
5. Deep Link Handler
   ├─ Meeting ID'yi parse et
   ├─ Supabase'den meeting bilgilerini al
   └─ ParticipantJoinScreen'e yönlendir
   ↓
6. Participant Join Screen
   ├─ Meeting detaylarını göster
   ├─ Başlangıç zamanını göster
   └─ "Katıl" butonu
   ↓
7. Waiting Screen
   ├─ Countdown timer
   └─ Meeting başlayınca → Meeting Screen
```

## Supabase RLS Politikaları

```sql
-- Herkes meetings tablosunu okuyabilir (join için gerekli)
CREATE POLICY "Anyone can view meetings"
  ON meetings FOR SELECT
  USING (true);

-- Sadece authenticated kullanıcılar meeting oluşturabilir
CREATE POLICY "Authenticated users can create meetings"
  ON meetings FOR INSERT
  WITH CHECK (auth.uid() = host_id);

-- Sadece host kendi meeting'ini güncelleyebilir
CREATE POLICY "Hosts can update their own meetings"
  ON meetings FOR UPDATE
  USING (auth.uid() = host_id);
```

## Error Handling

### Participant Join Screen
```dart
try {
  // Supabase'den meeting bilgilerini al
  final response = await Supabase.instance.client
      .from('meetings')
      .select('start_time, status')
      .eq('id', meetingId)
      .single();
  
  // Success: Meeting bulundu
  // Navigate to waiting screen
} catch (e) {
  // Error: Meeting bulunamadı
  // Kullanıcıya hata mesajı göster
}
```

### Host Setup Screen
```dart
try {
  await Supabase.instance.client.from('meetings').insert({...});
  // Success: Dialog göster
} catch (e) {
  // Error: SnackBar ile kullanıcıyı bilgilendir
  // Tekrar denemesine izin ver
}
```

## Testing Scenarios

### Senaryo 1: Mobil Uygulama Testi
```
1. Host bir meeting oluşturur
2. Mobil link kopyalanır: perfecttime://meeting/join?id=abc-123
3. Link Notes uygulamasına yapıştırılır
4. Link tıklanır
5. ✅ Uygulama açılır ve ParticipantJoinScreen gösterilir
```

### Senaryo 2: Web Tarayıcı Testi
```
1. Host bir meeting oluşturur
2. Web link kopyalanır: https://yourapp.com/join?id=abc-123
3. Link tarayıcıda açılır
4. ✅ Web uygulaması meeting ID'yi algılar
5. ✅ ParticipantJoinScreen gösterilir
```

### Senaryo 3: Invalid Meeting ID
```
1. Kullanıcı geçersiz bir link tıklar
2. Supabase'de meeting bulunamaz
3. ✅ Error screen gösterilir: "Toplantı bulunamadı"
```

### Senaryo 4: Cancelled Meeting
```
1. Host meeting'i iptal eder (status = 'cancelled')
2. Katılımcı linke tıklar
3. ✅ Error screen: "Bu toplantı iptal edildi"
```

## Performance Optimizations

### 1. Tek Supabase Query
```dart
// Tek query ile tüm gerekli bilgiyi al
.select('start_time, status')
.eq('id', meetingId)
.single();
```

### 2. Caching (İsteğe Bağlı)
```dart
// SharedPreferences ile son katılınan meeting'i cache'le
final prefs = await SharedPreferences.getInstance();
await prefs.setString('last_meeting_id', meetingId);
```

### 3. Optimistic UI
```dart
// Dialog'u hemen göster, arka planda Supabase'e kaydet
showDialog(...);
Supabase.instance.client.from('meetings').insert({...});
```

## Güvenlik Notları

1. **Meeting ID'ler UUID**: Tahmin edilemez ve benzersiz
2. **RLS Aktif**: Veritabanı seviyesinde güvenlik
3. **Auth Kontrolü**: Host olmak için authenticated kullanıcı gerekli
4. **Status Kontrolü**: İptal edilmiş meeting'lere katılım engellenir

## Deployment Checklist

### Web Deployment İçin
- [ ] Domain satın al (örn: perfecttime.app)
- [ ] Firebase Hosting / Vercel / Netlify kurulumu
- [ ] `host_setup_screen.dart` içinde web link'i güncelle
- [ ] `flutter build web` çalıştır
- [ ] Deploy et
- [ ] Test et: https://perfecttime.app/join?id=test-123

### App Store / Play Store İçin
- [ ] Deep link schemes register edildi mi kontrol et
- [ ] Associated domains (iOS) yapılandırılsın
- [ ] App Links (Android) verification dosyası ekle
- [ ] Store listing'de deep link support belirt
