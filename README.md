# VoIP App with Real-Time Scam Detection

A Flutter VoIP application that uses AI to detect phone scams in real-time during calls.

## What It Does

This app allows people to make voice calls and automatically sends audio chunks to an external Python AI API for scam analysis. The app is a **client-only application** that:

1. Makes VoIP calls between users
2. Records audio in 10-second chunks during calls
3. **Posts audio data to external Python API server**
4. **Displays scam detection results** from the API response
5. Shows real-time warnings if scams are detected

**Note**: The Python AI server runs separately - this Flutter app only communicates with it via HTTP requests.

## How It Works

### System Components
```
📱 Flutter App ←→ 🌐 Node.js Server ←→ 🌍 External Python AI API
   (VoIP Client)    (WebRTC Signaling)     (Scam Detection Service)
```

**The Flutter app is a client that:**
- Handles VoIP calls via WebRTC
- Records audio chunks locally
- **Sends HTTP requests** to external Python API
- **Receives and displays** scam analysis results

### Code Flow

1. **App Startup**
   - Flutter app starts and generates random user ID (1000-9999)
   - Scans local network to find Node.js server on port 3000
   - Connects to server via WebSocket

2. **Making a Call**
   ```
   User enters target ID → WebRTC offer created → Sent to Node.js server
   → Server routes to target user → Target accepts/rejects
   → Direct peer-to-peer audio connection established
   ```

3. **Real-Time Scam Detection**
   ```
   Call starts → Auto-recording begins → Every 10 seconds:
   Audio chunk → Base64 encode → HTTP POST to Python API
   → API analyzes (speech-to-text, emotion, patterns) → Returns JSON response
   → App parses response → If scam detected → Alert shown to receiver only
   ```

4. **Client-Server Communication**
   - **App records**: 10-second WAV chunks at 16kHz
   - **App sends**: HTTP POST with base64 audio to `/analyze_audio` endpoint
   - **API processes**: Whisper transcription + pattern matching + emotion detection
   - **API returns**: JSON with risk level and analysis details
   - **App displays**: Alert dialog only to incoming call receivers (potential victims)

### Key Files

- `lib/main.dart` - Flutter UI and call interface with API integration
- `lib/voip_service.dart` - WebRTC handling and audio recording + HTTP API calls
- `bridge_server.js` - Node.js signaling server (WebRTC only)
- **External Python API** - Separate scam detection service (not included in app)

## Project Structure

```
voip/
├── lib/                    # Flutter VoIP client app
├── android/               # Android platform files  
├── bridge_server.js      # Node.js WebRTC signaling server
├── package.json          # Node.js dependencies
├── pubspec.yaml         # Flutter dependencies
└── python_api/           # External AI API (runs separately)
```

**Note**: The `python_api/` folder contains the external scam detection service that the Flutter app communicates with via HTTP requests.

## Setup Instructions

### Prerequisites
- Node.js (v18+)
- Flutter SDK
- Python 3.8+

### Quick Test
```bash
./test_system.sh  # Check if everything is ready
```

### 1. Install Dependencies

**Node.js Server:**
```bash
npm install
```

**Flutter App:**
```bash
flutter pub get
```

**Python AI API:**
```bash
cd python_api
pip install -r requirements.txt
```

### 2. Start the System (3 terminals)

**Terminal 1 - External Python AI API:**
```bash
cd python_api
python main.py
# Runs external scam detection service on http://localhost:8000
```

**Terminal 2 - Node.js WebRTC Server:**
```bash
npm start  
# Runs WebRTC signaling server on http://localhost:3000
```

**Terminal 3 - Flutter VoIP Client:**
```bash
flutter run
# App will auto-discover the signaling server and connect to API
```

### 3. Testing the System

1. Open the app on 2 devices/emulators (same network)
2. Note the User IDs shown in each app (e.g., 1234, 5678)
3. Use one device to call the other using their ID
4. During the call, say phrases like "urgent bank verification" or "send money now"
5. Watch for scam alerts to appear on the receiver's device

### 4. How the Detection Works

- **Every 10 seconds** during a call, audio is recorded and analyzed
- **AI processes** speech-to-text, emotion detection, and pattern matching
- **Scam keywords** like "urgent", "verify account", "send money" trigger alerts
- **Only receivers** of incoming calls get warnings (potential victims)
- **Privacy**: Audio is processed locally, chunks deleted after analysis

## Technical Features

- **WebRTC**: Direct peer-to-peer calling between devices
- **Real-time AI**: 10-second audio chunk analysis
- **Multi-modal Detection**: Speech, emotion, and pattern analysis  
- **Network Discovery**: Automatically finds servers on local network
- **Cross-platform**: Works on Android, iOS, and desktop
- **Privacy-first**: Local recording, no permanent storage

## Network Requirements

- All devices must be on the same local network for VoIP calls
- Default ports: **3000** (Node.js), **8000** (Python)
- The app automatically discovers the bridge server IP
- For cloud AI: Configure RunPod URL in the "Server Test" tab

## Troubleshooting

- **Can't find server**: Run `./test_system.sh` to check setup
- **Calls not connecting**: Ensure both devices are on same network
- **AI not working**: Check Python API is running on port 8000
- **Port conflicts**: Check with `lsof -i :3000` and `lsof -i :8000`
