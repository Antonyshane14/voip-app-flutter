# VoIP Scam Detection System - Unified Deployment

## 🎯 Complete Integrated System

This is a unified VoIP scam detection system that includes:

- **📱 Flutter VoIP App** - Real-time calling with scam detection
- **📡 Signaling Server** (Port 3000) - WebRTC signaling for calls  
- **🌉 Bridge Server** (Port 3001) - Connects VoIP app to AI analysis
- **🐍 Python API** (Port 8000) - Advanced AI scam detection engine

### 🏗️ Architecture

```
Flutter App ↔ Signaling Server (3000) ↔ WebRTC Calls
     ↓
Bridge Server (3001) ↔ Python API (8000) ↔ AI Models
     ↓
Role-Based Scam Alerts (Victims Only)
```

## 🚀 Quick Deployment

### Option 1: RunPod Deployment (Recommended)

```bash
# Deploy complete system to RunPod
./runpod_deploy_unified.sh
```

### Option 2: Local Development

```bash
# Start all services locally
./start_unified_system.sh
```

### Option 3: Docker Deployment

```bash
# Build and run with Docker
docker build -t voip-scam-detection .
docker run -p 3000:3000 -p 3001:3001 -p 8000:8000 voip-scam-detection
```

## 🧠 AI Components

### Core AI Models:
- **Whisper** (medium) - Speech transcription
- **Deepfake Audio Detection** - AI voice detection  
- **Wav2Vec2** - Emotion analysis
- **PyAnnote** - Speaker diarization
- **Hermes3:8b** - LLM scam pattern analysis

### Detection Features:
- Real-time transcription and analysis
- AI-generated voice detection
- Emotional manipulation detection
- Scam keyword pattern matching
- Speaker change detection
- Background noise analysis

## 🔒 Security Features

### Role-Based Alert System:
- **Outgoing Calls (Callers)**: No alerts sent (prevents scammer awareness)
- **Incoming Calls (Receivers)**: Real-time scam warnings delivered

### Alert Levels:
- **🔴 HIGH**: Immediate scam threat detected
- **🟡 MEDIUM**: Suspicious patterns identified

## 📊 API Endpoints

### Python API (Port 8000):
- `POST /analyze-audio` - Analyze audio chunk for scam indicators
- `GET /health` - Health check endpoint

### Bridge Server (Port 3001):
- `POST /analyze-call-chunk` - Receive audio from VoIP app
- `WebSocket` - Real-time scam alert delivery
- `GET /health` - Health check endpoint

### Signaling Server (Port 3000):
- `WebSocket` - WebRTC signaling for VoIP calls
- `GET /` - Server status page

## 🌍 Environment Variables

```bash
# Python API Configuration
HF_TOKEN=your_huggingface_token          # Required for some models
PYTHON_API_URL=http://localhost:8000     # Python API URL

# AI Model Configuration  
WHISPER_MODEL_SIZE=medium                # Whisper model size
OLLAMA_MODEL=hermes3:8b                  # LLM model for analysis

# Processing Configuration
MAX_WORKERS=4                            # Parallel processing workers
CHUNK_DURATION=10                        # Analysis chunk duration (seconds)
```

## 📱 Flutter App Configuration

The Flutter app automatically:
1. **Detects Network**: WiFi, mobile data, hotspot support
2. **Finds Server**: Auto-scans for signaling server
3. **Connects Services**: Links to bridge server for scam detection
4. **Role Detection**: Identifies caller vs receiver for targeted alerts

## 🔧 Development Setup

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   npm install
   cd scam_detection_bridge && npm install
   cd ../signaling_server && npm install
   ```

2. **Start Services**:
   ```bash
   ./start_unified_system.sh
   ```

3. **Flutter Development**:
   ```bash
   flutter run --hot
   ```

## 📋 Service Management

### Start Individual Services:
```bash
# Python API
cd python_api && python main.py

# Bridge Server  
cd scam_detection_bridge && node bridge_server.js

# Signaling Server
cd signaling_server && node server.js
```

### Monitor Logs:
```bash
# RunPod service logs
journalctl -u voip-python-api -f
journalctl -u voip-bridge -f
journalctl -u voip-signaling -f
```

## 🎯 Testing the System

1. **Deploy to RunPod**: `./runpod_deploy_unified.sh`
2. **Build Flutter APK**: `flutter build apk`
3. **Install on 2 devices**: Test caller/receiver roles
4. **Make test call**: Verify scam detection alerts
5. **Check role-based alerts**: Only receiver should get warnings

## 🛠️ Troubleshooting

### Common Issues:
- **Port conflicts**: Kill existing processes on ports 3000, 3001, 8000
- **Model download**: First run downloads large AI models (may take time)
- **Memory usage**: AI models require significant RAM (8GB+ recommended)
- **Network scanning**: App may take time to find signaling server

### Health Checks:
```bash
curl http://localhost:8000/health    # Python API
curl http://localhost:3001/health    # Bridge Server  
curl http://localhost:3000/          # Signaling Server
```

## 📊 Performance Optimization

- **GPU Support**: RunPod GPU instances for faster AI inference
- **Model Caching**: Models cached after first download
- **Parallel Processing**: Multi-worker audio analysis
- **Memory Management**: Automatic cleanup of temporary files

## 🎉 Ready for Production!

Your VoIP scam detection system is now fully integrated and ready for deployment. The system provides real-time protection for call recipients while maintaining stealth from potential scammers.
