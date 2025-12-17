# 🚀 Hızlı Başlangıç - Toplantı Linkleri

## Adım 1: Supabase Kurulumu
Supabase projenizde SQL Editor'ü açın ve şu komutu çalıştırın:

```sql
-- Dosya: supabase_meetings_table.sql içeriğini yapıştırın
```

veya doğrudan dosyayı yükleyin:
```bash
supabase db push --file supabase_meetings_table.sql
```

## Adım 2: Uygulamayı Başlatın
```bash
flutter pub get
flutter run
```

## Adım 3: Test Edin

### Oturum Oluşturma
1. "Oturum Sahibi" seçin
2. Tarih ve saat seçin
3. "Oturumu Başlat" tıklayın
4. Çıkan dialog'da linkleri görün

### Linkleri Paylaşma
**Mobil için:**
```
perfecttime://meeting/join?id=xxxxx
```
Bu linki Notes'a yapıştırıp tıklayın → Uygulama açılır

**Web için:**
```
https://yourapp.com/join?id=xxxxx
```
Tarayıcıda açın (deploy sonrası)

## ⚙️ Önemli: Web Domain Ayarı

`lib/host_setup_screen.dart` dosyasında 116. satırı güncelleyin:
```dart
final String webLink = 'https://SIZIN-DOMAIN.com/join?id=$_meetingId';
```

## 📱 Kullanım Akışı

```
Oturum Sahibi                 Katılımcı
     │                             │
     ├─ Toplantı oluştur           │
     ├─ Linkleri paylaş ──────────>│
     │                             ├─ Linke tıkla
     │                             ├─ Toplantı bilgilerini gör
     │                             ├─ "Katıl" tıkla
     │                             │
     └────── Bekleme Odası ────────┘
                    │
              Toplantı Başlar
```

## ✅ Kontrol Listesi

- [ ] Supabase meetings tablosu oluşturuldu
- [ ] `flutter pub get` çalıştırıldı
- [ ] Web domain güncellendi (deployment için)
- [ ] Test toplantısı oluşturuldu
- [ ] Mobil link test edildi
- [ ] Paylaşım özelliği denendi

## 🎉 Hazırsınız!

Artık kullanıcılarınız hem mobil cihazlarından hem de web tarayıcılarından toplantılara katılabilir.
