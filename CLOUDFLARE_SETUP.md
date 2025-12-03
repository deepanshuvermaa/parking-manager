# Cloudflare Worker Setup Guide

## Why We Need This

Indian mobile ISPs (Jio, Airtel, Vi, BSNL) block Railway.app domains on cellular networks. This proxy allows your app to work on mobile data.

## Setup Steps (5 minutes)

### 1. Create Cloudflare Account
- Go to https://workers.cloudflare.com
- Sign up (free account)
- Verify email

### 2. Deploy Worker
1. Click "Create a Worker"
2. Copy the code from `cloudflare-worker.js` file
3. Paste it into the worker editor
4. Click "Save and Deploy"
5. Copy your worker URL (e.g., `https://parkease-api.YOUR-SUBDOMAIN.workers.dev`)

### 3. Update Flutter App
Edit `lib/config/api_config.dart`:

```dart
static String get baseUrl {
  // OLD (blocked on mobile data)
  // return 'https://parkease-production-6679.up.railway.app/api';

  // NEW (works everywhere)
  return 'https://YOUR-WORKER-NAME.YOUR-SUBDOMAIN.workers.dev/api';
}
```

Replace `YOUR-WORKER-NAME.YOUR-SUBDOMAIN` with your actual Cloudflare worker URL.

### 4. Test the Proxy

Test from your PC:
```bash
curl https://YOUR-WORKER-URL/health
```

Should return:
```json
{"status":"healthy","timestamp":"..."}
```

### 5. Rebuild APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Benefits
- ✅ Works on ALL mobile networks
- ✅ Free (100,000 requests/day)
- ✅ Fast (Cloudflare global CDN)
- ✅ No ISP blocking

## Costs
- **Free Tier:** 100,000 requests/day
- For your parking app: ~1,000-5,000 requests/day
- **Cost:** $0/month (unless you exceed 100k/day)

## Alternative: Custom Domain
If you have a domain, you can point it to Railway instead of using Cloudflare.
