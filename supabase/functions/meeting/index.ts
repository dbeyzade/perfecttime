import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const appleAppSiteAssociation = {
  applinks: {
    apps: [],
    details: [{
      appID: "DT4UT73T4X.com.example.perfectTime",
      paths: ["/functions/v1/meeting", "/functions/v1/meeting/*", "/meeting/join", "/meeting/join/*"]
    }]
  }
}

const assetlinks = [{
  relation: ["delegate_permission/common.handle_all_urls"],
  target: {
    namespace: "android_app",
    package_name: "com.example.perfect_time",
    sha256_cert_fingerprints: []
  }
}]

serve(async (req) => {
  const url = new URL(req.url)
  
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }
    })
  }
  
  if (url.pathname === "/.well-known/apple-app-site-association") {
    return new Response(JSON.stringify(appleAppSiteAssociation), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    })
  }
  
  if (url.pathname === "/.well-known/assetlinks.json") {
    return new Response(JSON.stringify(assetlinks), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    })
  }
  
  // Meeting ID'yi al - query param veya path'den
  // Format: ?id=xxx veya /join/xxx
  let meetingId = url.searchParams.get("id")
  
  // Path'den de dene: /functions/v1/meeting/join/xxx
  if (!meetingId) {
    const pathParts = url.pathname.split('/')
    const lastPart = pathParts[pathParts.length - 1]
    // Son kısım 'meeting' veya 'join' değilse, meeting ID'dir
    if (lastPart && lastPart !== 'meeting' && lastPart !== 'join') {
      meetingId = lastPart
    }
  }
  if (meetingId) {
    const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PerfecTime - Toplantıya Katılın</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      text-align: center;
      padding: 20px;
    }
    .container { max-width: 500px; }
    h1 { font-size: 2.5em; margin-bottom: 20px; }
    p { font-size: 1.2em; margin: 15px 0; opacity: 0.95; }
    .spinner {
      border: 4px solid rgba(255,255,255,0.3);
      border-top: 4px solid white;
      border-radius: 50%;
      width: 50px;
      height: 50px;
      animation: spin 1s linear infinite;
      margin: 30px auto;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .button {
      display: inline-block;
      padding: 15px 40px;
      margin: 20px 10px;
      background: white;
      color: #667eea;
      text-decoration: none;
      border-radius: 50px;
      font-weight: bold;
      font-size: 1.1em;
      transition: transform 0.2s;
      cursor: pointer;
      border: none;
    }
    .button:hover { transform: scale(1.05); }
    .info {
      margin-top: 30px;
      padding: 15px;
      background: rgba(255,255,255,0.1);
      border-radius: 10px;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🎯 PerfecTime</h1>
    <div class="spinner"></div>
    <p>Uygulama açılıyor...</p>
    <button class="button" onclick="openApp()">Toplantıya Katıl</button>
    <div class="info">
      💡 Eğer uygulama yüklü değilse, App Store'dan indirin
    </div>
  </div>
  <script>
    const meetingId = "${meetingId}";
    const deepLink = "perfecttime://meeting/join?id=" + meetingId;
    const iosAppStore = "https://apps.apple.com/app/perfecttime/id123456789";
    const androidPlayStore = "https://play.google.com/store/apps/details?id=com.example.perfect_time";
    
    function openApp() {
      // Önce deep link'i dene
      window.location.href = deepLink;
      
      // 2 saniye sonra store'a yönlendir (app yoksa)
      setTimeout(() => {
        const userAgent = navigator.userAgent || navigator.vendor;
        if (/android/i.test(userAgent)) {
          window.location.href = androidPlayStore;
        } else if (/iPad|iPhone|iPod/.test(userAgent)) {
          window.location.href = iosAppStore;
        }
      }, 2000);
    }
    
    // Otomatik açma denemesi
    setTimeout(() => {
      openApp();
    }, 800);
  </script>
</body>
</html>`;
    
    return new Response(html, {
      headers: { 
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-cache",
        "Access-Control-Allow-Origin": "*"
      }
    })
  }
  
  // Varsayılan: Boş meeting sayfası (ID olmadan)
  const defaultHtml = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PerfecTime</title>
  <style>
    body { font-family: -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-align: center; }
    h1 { font-size: 2em; }
    p { opacity: 0.9; }
  </style>
</head>
<body>
  <div>
    <h1>🎯 PerfecTime</h1>
    <p>Toplantıya katılmak için geçerli bir link kullanın.</p>
  </div>
</body>
</html>`;
  
  return new Response(defaultHtml, {
    headers: { "Content-Type": "text/html; charset=utf-8" }
  })
})
