# VoIP Scam Detection - RunPod Git Clone Setup

## 🎯 Quick RunPod Deployment

### Step 1: Create RunPod Instance
1. Go to [RunPod.io](https://runpod.io)
2. Create a new Pod with:
   - **Template**: PyTorch 2.0+ or Python 3.10+
   - **GPU**: Optional (CPU works, GPU is faster for AI models)
   - **Storage**: At least 20GB for AI models
   - **Ports**: Expose ports 3000, 3001, 8000

### Step 2: Clone and Setup
```bash
# SSH into your RunPod instance, then:

# Clone the repository
git clone https://github.com/Antonyshane14/voip-app-flutter.git
cd voip-app-flutter

# Run the unified deployment script
chmod +x runpod_deploy_unified.sh
./runpod_deploy_unified.sh
```

### Step 3: Start Services
```bash
# Start all services with monitoring
./start_unified_system.sh
```

## 🌐 Connection Details

After deployment, your services will be available at:

- **🐍 Python API**: `http://[RUNPOD_IP]:8000`
- **🌉 Bridge Server**: `http://[RUNPOD_IP]:3001`  
- **📡 Signaling Server**: `http://[RUNPOD_IP]:3000`

## 📱 Flutter App Connection

Your Flutter app will automatically:
1. Detect mobile/WiFi network
2. Scan for the signaling server on port 3000
3. Connect to RunPod IP when found
4. Enable real-time scam detection

## 🔧 Environment Variables (Optional)

Set these in your RunPod environment:
```bash
export HF_TOKEN="your_huggingface_token"  # For some AI models
export PYTHON_API_URL="http://localhost:8000"
```

## 📊 Monitoring

Check service status:
```bash
# Check if services are running
curl http://localhost:8000/health     # Python API
curl http://localhost:3001/health     # Bridge Server
curl http://localhost:3000/           # Signaling Server

# Monitor logs
tail -f python_api/logs/*.log
```

## 🚀 That's It!

- ✅ **Complete AI scam detection** with Whisper, deepfake detection, emotion analysis
- ✅ **Role-based alerts** - only victims get warned, not scammers
- ✅ **Real-time analysis** - 10-second audio chunks with live alerts
- ✅ **Mobile data support** - works on WiFi, 4G/5G, hotspots
- ✅ **Auto-discovery** - Flutter app finds RunPod server automatically

Your VoIP scam detection system is ready for production use! 🎉
