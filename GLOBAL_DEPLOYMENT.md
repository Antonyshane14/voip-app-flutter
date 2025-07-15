# Global VoIP Deployment Guide
*Allow people to call each other from anywhere in the world*

## Overview
This guide helps you deploy your VoIP server to a cloud platform so users can call each other from different locations (place A ↔ place B) through your centralized server at location C.

## Quick Setup Steps

### 1. Deploy Server to Cloud Platform

#### Option A: RunPod (Recommended for AI features)
```bash
# Use the provided Git-based deployment
./runpod_deploy_unified.sh
```
- Creates a RunPod instance with GPU support
- Includes full AI scam detection features
- Public URL format: `https://your-runpod-id.pods.run`

#### Option B: Render (Free tier available)
1. Connect your GitHub repo to Render
2. Create new Web Service
3. Build command: `npm install && cd scam_detection_bridge && npm install`
4. Start command: `./start_unified_system.sh`
5. Public URL format: `https://your-app-name.onrender.com`

#### Option C: Railway (Simple deployment)
1. Connect GitHub repo to Railway
2. Deploy the `scam_detection_bridge` directory
3. Auto-detected start command
4. Public URL format: `https://your-app-name.railway.app`

#### Option D: Heroku
```bash
# Use existing Heroku setup
./deploy_to_heroku.sh
```
- Follow the Heroku deployment guide
- Public URL format: `https://your-app-name.herokuapp.com`

#### Option E: Your Own VPS/Cloud Server
```bash
# On your server:
git clone https://github.com/Antonyshane14/voip-app-flutter
cd voip-app-flutter
./start_unified_system.sh
```
- Make sure port 3000 is accessible
- URL format: `http://your-server-ip:3000`

### 2. Update App Configuration

Edit `lib/voip_config.dart`:
```dart
static const String primaryServerUrl = 'https://YOUR-ACTUAL-SERVER-URL';
```

For example:
```dart
static const String primaryServerUrl = 'https://my-voip-app.onrender.com';
```

### 3. Build and Distribute App

```bash
# Build APK for Android
flutter build apk --release

# The APK will be in: build/app/outputs/flutter-apk/app-release.apk
```

### 4. How Users Connect

1. **Person A** (in New York) installs the app
2. **Person B** (in Tokyo) installs the app  
3. **Your server** (running in London cloud)
4. Both users see their unique 4-digit IDs
5. Person A enters Person B's ID and calls
6. The call routes through your London server
7. **Global VoIP calling works!**

## Architecture

```
[Phone A - New York] ←→ [Your Server - London] ←→ [Phone B - Tokyo]
```

- **Signaling**: WebRTC connection setup via your server
- **Media**: Direct P2P when possible, server relay when needed
- **AI Analysis**: Real-time scam detection on server
- **Alerts**: Only sent to call recipients (victims)

## Server Features

### Basic VoIP Features (Always Active)
- WebRTC signaling server
- Call routing and management
- User presence tracking
- Call recording coordination

### AI Features (When Python API is running)
- Real-time speech transcription (Whisper)
- AI voice/deepfake detection
- Emotion analysis
- LLM-based scam pattern detection
- Automated scam alerts

## Scaling Considerations

### For Testing (1-10 users)
- Free tier on Render/Railway works
- Basic VPS ($5/month) sufficient

### For Production (100+ users)
- Dedicated server or cloud instance
- RunPod with GPU for AI features
- Consider CDN for global latency

### For Enterprise (1000+ users)
- Multiple server regions
- Load balancing
- Database for user management
- Professional scam detection APIs

## Security Features

- **Role-based alerts**: Only victims get scam warnings
- **End-to-end call privacy**: Audio analysis without storage
- **No permanent recording**: Files deleted after analysis
- **Transport encryption**: HTTPS/WSS connections

## Troubleshooting

### App Can't Connect to Server
1. Check server URL in `voip_config.dart`
2. Verify server is running and accessible
3. Check firewall/security group settings
4. Test server URL in browser

### Calls Don't Connect
1. Verify WebRTC STUN/TURN configuration
2. Check network NAT/firewall issues
3. Test with users on same network first

### AI Features Not Working
1. Check Python API is running on port 8000
2. Verify Node.js bridge connects to Python API
3. Check server logs for errors

## Support

- Server logs: Check your cloud platform dashboard
- App logs: Connect device and check Flutter logs
- Network issues: Test with simple ping/traceroute

---

**Ready to deploy?** Choose your preferred cloud platform and follow the deployment steps above!
