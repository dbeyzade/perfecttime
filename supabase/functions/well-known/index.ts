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
      sha256_cert_fingerprints: []
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
  
  // Redirect to meeting join
  if (url.pathname.startsWith("/meeting/join")) {
    const meetingId = url.searchParams.get("id")
    if (meetingId) {
      return new Response(
        `<!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>PerfecTime Toplantısı</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
              text-align: center;
              padding: 20px;
            }
            .container {
              max-width: 500px;
            }
            h1 { font-size: 2em; margin-bottom: 20px; }
            p { font-size: 1.1em; margin: 15px 0; opacity: 0.9; }
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
            }
            .button:hover { transform: scale(1.05); }
            .spinner {
              border: 3px solid rgba(255,255,255,0.3);
              border-top: 3px solid white;
              border-radius: 50%;
              width: 40px;
              height: 40px;
              animation: spin 1s linear infinite;
              margin: 20px auto;
            }
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>🎯 PerfecTime</h1>
            <div class="spinner"></div>
            <p>Uygulama açılıyor...</p>
            <p style="font-size: 0.9em; margin-top: 30px;">Eğer uygulama otomatik açılmazsa:</p>
            <a href="perfecttime://meeting/join?id=${meetingId}" class="button">Uygulamayı Aç</a>
          </div>
          <script>
            // Try to open the app immediately
            window.location.href = "perfecttime://meeting/join?id=${meetingId}";
            
            // Fallback after 3 seconds
            setTimeout(() => {
              // If still on this page, show instructions
            }, 3000);
          </script>
        </body>
        </html>`,
        {
          headers: { 
            "Content-Type": "text/html",
            "Cache-Control": "no-cache"
          }
        }
      )
    }
  }
  
  return new Response("Not found", { status: 404 })
})
