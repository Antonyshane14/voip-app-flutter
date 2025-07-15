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
# Clone repository in RunPod
cd /workspace
git clone https://github.com/Antonyshane14/voip-app-flutter.git
cd voip-app-flutter

# Run the complete setup script
./runpod_setup.sh
```

## 🔧 Manual RunPod Setup

If you prefer to set up step by step:

### 1. Create RunPod Pod
- Choose RTX4090 or RTX3090
- Use PyTorch template: `runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04`

### 2. Clone Repository
```bash
cd /workspace
git clone https://github.com/Antonyshane14/voip-app-flutter.git
cd voip-app-flutter
```

### 3. Install System Dependencies
```bash
apt-get update && apt-get install -y nodejs npm ffmpeg build-essential

# Install Ollama for LLM processing
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve &
sleep 5
ollama pull hermes3:8b
```

### 4. Setup Python (Virtual Environment)
```bash
python3 -m venv venv
source venv/bin/activate
cd python_api
pip install -r requirements.txt
cd ..
```

### 5. Install Node.js Dependencies
```bash
npm install
```

### 6. Start Services
```bash
# Terminal 1: Python API
source venv/bin/activate
cd python_api && python main.py

# Terminal 2: Node.js Bridge  
node bridge_server.js
```

### 7. Get RunPod URLs
Your pod will be accessible at:
- Main: `https://your-pod-id-80.proxy.runpod.net`
- Python API: `https://your-pod-id-8000.proxy.runpod.net`
- Node Bridge: `https://your-pod-id-3001.proxy.runpod.net`

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
