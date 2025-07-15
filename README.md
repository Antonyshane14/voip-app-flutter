# VoIP Flutter App with AI Scam Detection

A professional VoIP (Voice over Internet Protocol) application built with Flutter and WebRTC, featuring real-time AI-powered scam detection and global calling capabilities.

## 🌍 Global VoIP Calling

**Call Anyone, Anywhere!** This app enables global VoIP calling where:
- Person A (New York) ↔ Person B (Tokyo)  
- Through your centralized server (London)
- No need to be on same WiFi network
- Works across countries and continents

## Features

✅ **Global Voice Calls** - Call anyone worldwide through centralized server  
✅ **AI Scam Detection** - Real-time analysis with ML models  
✅ **Smart Alerts** - Warnings sent only to potential victims  
✅ **Professional UI** - Modern call interface with scam alerts  
✅ **Auto Server Discovery** - Connects to your deployed server  
✅ **Call Recording & Analysis** - 10-second chunks for scam detection  
✅ **Multi-Platform Deployment** - RunPod, Render, Railway, Heroku support  

## 🤖 AI Protection Features

- **Whisper Speech Recognition** - Real-time transcription
- **AI Voice Detection** - Identifies synthetic/deepfake voices  
- **Emotion Analysis** - Detects stress patterns in speech
- **LLM Scam Detection** - Pattern recognition for fraud schemes
- **Role-Based Alerts** - Only victims receive warnings

## Architecture

```
[Phone A] ←→ [Centralized Server + AI] ←→ [Phone B]
    ↓              ↓                    ↓
 Any Country   Your Cloud Server    Any Country
```

- **Frontend**: Flutter with WebRTC
- **Signaling**: Node.js server with Socket.IO  
- **AI Engine**: Python with Whisper, emotion detection, LLM analysis
- **Deployment**: Multi-cloud support (RunPod, Render, Railway, etc.)

## Quick Deployment

### 1. Deploy Server (Choose One Platform)

#### RunPod (GPU-powered AI)
```bash
./runpod_deploy_unified.sh
# Get URL: https://your-runpod-id.pods.run
```

#### Render (Free tier)
- Connect GitHub repo to Render
- Deploy `scam_detection_bridge` directory  
- Get URL: `https://your-app.onrender.com`

#### Railway
```bash
railway login
railway init
railway up
# Get URL: https://your-app.railway.app
```

### 2. Update App Configuration
```dart
// In lib/voip_config.dart
static const String primaryServerUrl = 'https://YOUR-ACTUAL-SERVER-URL';
```

### 3. Build & Distribute App
```bash
flutter build apk --release
# Share APK with users worldwide
```

## Quick Start

### 1. Start Signaling Server
```bash
cd signaling_server
npm install
node server.js
```

### 2. Run Flutter App
```bash
flutter pub get
flutter run
```

### 3. Make Calls
- Generate random 4-digit user ID automatically
- Enter target user ID to call
- Enjoy high-quality voice calls!

## Project Structure

```
voip/
├── lib/
│   ├── main.dart          # Main UI and dialer
│   └── voip_service.dart  # WebRTC service and recording
├── signaling_server/
│   ├── server.js          # Node.js signaling server
│   ├── package.json       # Server dependencies
│   └── recordings/        # Call recordings storage
├── android/               # Android platform code
└── pubspec.yaml          # Flutter dependencies
```

## Technologies

- **Flutter**: Cross-platform mobile framework
- **WebRTC**: Real-time peer-to-peer communication
- **Socket.IO**: WebSocket signaling
- **Node.js**: Signaling server
- **Multer**: File upload handling

## Deployment

Currently configured for local development. For global access:

1. Deploy signaling server to cloud (Heroku, AWS, etc.)
2. Update server URL in `lib/main.dart`
3. Add authentication for security
4. Distribute app to users

## Recording Feature

- Automatic recording during calls
- Chunked uploads every 30 seconds
- Server storage in `signaling_server/recordings/`
- WAV format with timestamps
