# Heroku Deployment Guide for VoIP Signaling Server

## Prerequisites
1. Install Heroku CLI: https://devcenter.heroku.com/articles/heroku-cli
2. Create a Heroku account: https://signup.heroku.com/

## Deployment Steps

### 1. Login to Heroku
```bash
heroku login
```

### 2. Navigate to signaling server directory
```bash
cd signaling_server
```

### 3. Initialize Git repository (if not already done)
```bash
git init
git add .
git commit -m "Initial VoIP signaling server"
```

### 4. Create Heroku app
```bash
heroku create your-voip-app
```
Note: Replace 'your-voip-app' with your desired app name (must be unique)

### 5. Deploy to Heroku
```bash
git push heroku main
```

### 6. Check app status
```bash
heroku ps:status
heroku logs --tail
```

### 7. Open your app
```bash
heroku open
```

## Update Flutter App

After deployment, update the cloud server URL in your Flutter app:

1. Replace `'https://your-voip-app.herokuapp.com'` in `lib/main.dart` with your actual Heroku app URL
2. Rebuild the APK:
   ```bash
   flutter build apk --release
   ```

## Testing

1. **WiFi networks**: App will auto-detect local signaling server
2. **Mobile data**: App will automatically use Heroku cloud server
3. **Fallback**: If local server fails, cloud server is used as backup

## App URLs
- Your app will be available at: `https://your-voip-app.herokuapp.com`
- Health check: `https://your-voip-app.herokuapp.com/health`
- Connected users: `https://your-voip-app.herokuapp.com/users`

## Environment Variables (if needed)
```bash
heroku config:set NODE_ENV=production
```

## Scaling (if needed)
```bash
heroku ps:scale web=1
```

## Monitoring
```bash
heroku logs --tail
heroku ps
```

## Important Notes
- Heroku apps go to sleep after 30 minutes of inactivity on free tier
- First request after sleep may take 10-30 seconds to wake up
- For production use, consider upgrading to paid tier for always-on
- File uploads (recordings) are ephemeral on Heroku - consider cloud storage for production
