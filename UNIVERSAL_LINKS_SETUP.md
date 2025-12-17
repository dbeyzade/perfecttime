# Universal Link Kurulumu

## Supabase'de Yapılacaklar

Universal Link'lerin çalışması için `.well-known` dosyalarını Supabase'de host etmeniz gerekiyor.

### 1. Supabase Storage'da public bucket oluştur

```sql
-- Supabase SQL Editor'de çalıştır
insert into storage.buckets (id, name, public)
values ('public', 'public', true);
```

### 2. `.well-known` dosyalarını yükle

Şu 2 dosyayı Supabase Storage'a yüklemen gerekiyor:

**Dosya 1:** `.well-known/apple-app-site-association` (iOS için)
**Dosya 2:** `.well-known/assetlinks.json` (Android için)

Bu dosyalar workspace'inizde `.well-known/` klasöründe hazır.

### 3. Supabase Edge Functions ile serve et

Alternatif olarak, Supabase Edge Function kullanarak bu dosyaları serve edebilirsin:

```typescript
// supabase/functions/well-known/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const appleAppSiteAssociation = {
  applinks: {
    apps: [],
    details: [
      {
        appID: "DT4UT73T4X.com.example.perfectTime",
        paths: ["/meeting/join", "/meeting/join/*"]
      }
    ]
  }
}

const assetlinks = [
  {
    relation: ["delegate_permission/common.handle_all_urls"],
    target: {
      namespace: "android_app",
      package_name: "com.example.perfect_time",
      sha256_cert_fingerprints: ["BURAYA_SIGNING_KEY_SHA256_EKLE"]
    }
  }
]

serve(async (req) => {
  const url = new URL(req.url)
  
  if (url.pathname === "/.well-known/apple-app-site-association") {
    return new Response(JSON.stringify(appleAppSiteAssociation), {
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    })
  }
  
  if (url.pathname === "/.well-known/assetlinks.json") {
    return new Response(JSON.stringify(assetlinks), {
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    })
  }
  
  return new Response("Not found", { status: 404 })
})
```

### 4. Android signing key SHA256 al

Terminal'de çalıştır:

```bash
# Debug key için
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release key için (eğer varsa)
keytool -list -v -keystore /path/to/your/release.keystore -alias your-key-alias
```

SHA256 fingerprint'i kopyala ve `assetlinks.json` dosyasına ekle.

### 5. Test et

iOS'ta test:
```
https://gtprewofeojifmvnjqhc.supabase.co/.well-known/apple-app-site-association
```

Android'de test:
```
https://gtprewofeojifmvnjqhc.supabase.co/.well-known/assetlinks.json
```

Bu URL'ler tarayıcıda açılmalı ve JSON döndürmeli.

---

## Xcode'da Yapılacaklar

1. Xcode'da `Runner.xcworkspace` aç
2. Runner target seç
3. "Signing & Capabilities" tab'ine git
4. "+ Capability" butonuna tıkla
5. "Associated Domains" seç
6. Domain ekle: `applinks:gtprewofeojifmvnjqhc.supabase.co`

Runner.entitlements dosyası otomatik oluşturulacak (zaten oluşturdum).

---

## Sonraki Adımlar

1. ✅ iOS entitlements oluşturuldu
2. ✅ Android manifest güncellendi
3. ⏳ Supabase'de `.well-known` dosyalarını host et
4. ⏳ Android signing key SHA256 ekle
5. ⏳ Xcode'da Associated Domains capability ekle
6. ⏳ App'i yeniden build et ve test et
