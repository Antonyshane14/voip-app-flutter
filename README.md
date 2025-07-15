# 🎯 VoIP Scam Detection System

A complete Flutter VoIP application with real-time AI-powered scam detection, optimized for global deployment.

## 🚀 Quick Start

### 1. Install Dependencies
```bash
# Flutter dependencies
flutter pub get

# Node.js dependencies  
npm install

# Python dependencies
cd python_api && pip install -r requirements.txt
```

### 2. Run the System
```bash
# Test locally first
./test_integrated_system.sh

# Or start services manually:
# 1. Python API: cd python_api && python main.py
# 2. Node.js Bridge: node bridge_server.js  
# 3. Flutter App: flutter run
```

### 3. Deploy to RunPod
```bash
# Deploy to RunPod container
./runpod_deploy_unified.sh
```

## 🏗️ Architecture

```
Flutter App → Node.js Bridge → Python AI API
    ↓              ↓              ↓
  WebRTC        Socket.IO     ML Models
```

## 🔑 Key Features

- **Real-time VoIP calling** with WebRTC
- **AI scam detection** using Whisper, emotion analysis, and LLM
- **Role-based alerts** (only victims get warnings)
- **Global deployment** ready for RunPod
- **RTX4090 optimized** for high performance

## 📦 Core Files

- `lib/main.dart` - Flutter VoIP app
- `bridge_server.js` - Node.js WebSocket bridge
- `python_api/main.py` - AI detection engine
- `runpod_deploy_unified.sh` - Deployment script
- `test_integrated_system.sh` - Local testing

## 🎯 Configuration

Update server URL in `lib/config/voip_config.dart`:
```dart
static const List<String> serverUrls = [
  'your-runpod-url.runpod.net'
];
```

## ✅ Ready for Production

This system integrates proven working components and is ready for immediate deployment to RunPod with global scam detection capabilities.
